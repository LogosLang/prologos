#lang racket/base

;;;
;;; PROLOGOS METAVARIABLE STORE
;;; Infrastructure for type inference metavariables.
;;;
;;; A metavariable represents an unknown term (type, implicit argument,
;;; universe level, etc.) that will be solved during elaboration and
;;; unification. Each metavariable has:
;;;   - A unique gensym ID
;;;   - The typing context in which it was created
;;;   - The expected type of its solution
;;;   - A status ('unsolved or 'solved)
;;;   - An optional solution (expr or #f)
;;;   - A list of constraints (for Sprint 5)
;;;   - Source info for error reporting
;;;
;;; The store is a mutable hash wrapped in a Racket parameter,
;;; enabling per-definition isolation via parameterize.
;;;

(require racket/list
         racket/match
         (for-syntax racket/base)
         "syntax.rkt"
         "prelude.rkt"
         "sessions.rkt"
         "source-location.rkt"
         "performance-counters.rkt"
         "champ.rkt"
         "infra-cell.rkt"   ;; Phase 1a: merge-list-append for constraint cell
         "global-env.rkt")  ;; Phase 3a: current-definition-cells-content for with-fresh-meta-env
         ;; NOTE: elaborator-network.rkt and type-lattice.rkt are NOT required
         ;; directly to avoid a circular dependency:
         ;;   metavar-store → elaborator-network → type-lattice → reduction → metavar-store
         ;; Instead, network operations are injected via callback parameters
         ;; (same pattern as current-retry-unify for breaking the unify→metavar-store cycle).

(provide
 ;; Meta-info struct
 (struct-out meta-info)
 ;; Store parameter
 current-meta-store
 ;; API
 fresh-meta
 solve-meta!
 meta-solved?
 meta-solution
 meta-lookup
 reset-meta-store!
 all-unsolved-metas
 ;; Phase 4d: save-meta-state/restore-meta-state! are internal to the
 ;; speculation bridge. External code should use with-speculative-rollback.
 ;; Exported only for elab-speculation-bridge.rkt — do not use directly.
 save-meta-state
 restore-meta-state!
 ;; Sprint 5: Constraint postponement
 (struct-out constraint)
 ;; Vestigial parameters removed in Phase 8 cleanup:
 ;; current-constraint-store, current-wakeup-registry
 current-retry-unify
 add-constraint!
 collect-meta-ids
 get-wakeup-constraints
 retry-constraints-via-cells!
 reset-constraint-store!
 ;; Track 6 Phase 1c: functional constraint updates
 read-constraint-by-cid
 write-constraint-to-store!
 all-postponed-constraints
 all-failed-constraints
 ;; Sprint 6: Universe level metavariables
 current-level-meta-store
 fresh-level-meta
 solve-level-meta!
 level-meta-solved?
 level-meta-solution
 zonk-level
 zonk-level-default
 ;; Sprint 7: Multiplicity metavariables
 current-mult-meta-store
 fresh-mult-meta
 solve-mult-meta!
 mult-meta-solved?
 mult-meta-solution
 zonk-mult
 zonk-mult-default
 ;; Sprint 8: Session metavariables
 current-sess-meta-store
 fresh-sess-meta
 solve-sess-meta!
 sess-meta-solved?
 sess-meta-solution
 zonk-session
 zonk-session-default
 ;; Sprint 9: Structured provenance
 (struct-out meta-source-info)
 (struct-out constraint-provenance)
 meta-category
 primary-unsolved-metas
 ;; Phase C: Trait constraint tracking + incremental resolution
 (struct-out trait-constraint-info)
 ;; Vestigial: current-trait-constraint-map, current-trait-wakeup-map
 current-retry-trait-resolve
 register-trait-constraint!
 lookup-trait-constraint
 install-trait-resolve-callback!
 retry-traits-via-cells!
 ;; Vestigial: current-trait-cell-map
 ;; Phase 3a: HasMethod constraint tracking
 (struct-out hasmethod-constraint-info)
 ;; Vestigial: current-hasmethod-constraint-map, current-hasmethod-wakeup-map
 current-retry-hasmethod-resolve
 register-hasmethod-constraint!
 lookup-hasmethod-constraint
 install-hasmethod-resolve-callback!
 retry-hasmethod-for-meta!
 ;; Phase 4: Capability constraint tracking
 (struct-out capability-constraint-info)
 ;; Vestigial: current-capability-constraint-map
 register-capability-constraint!
 lookup-capability-constraint
 ;; Phase 8b: Propagator-backed internal state
 current-prop-net-box
 current-prop-id-map-box
 current-prop-meta-info-box
 prop-meta-id-hash
 ;; Phase B: Auxiliary meta CHAMP boxes
 current-level-meta-champ-box
 current-mult-meta-champ-box
 current-sess-meta-champ-box
 ;; Phase 8b: Network operation callbacks (set by driver at startup)
 current-prop-make-network
 current-prop-fresh-meta
 current-prop-cell-write
 current-prop-cell-read
 current-prop-add-unify-constraint
 install-prop-network-callbacks!
 ;; Phase 1a: Infrastructure cell callback
 current-prop-new-infra-cell
 ;; Track 6 Phase 1a: id-map access callbacks
 current-prop-id-map-read
 current-prop-id-map-set
 current-constraint-cell-id
 read-constraint-store
 read-trait-constraints
 read-hasmethod-constraints
 read-capability-constraints
 read-wakeup-registry
 read-trait-wakeup-map
 read-hasmethod-wakeup-map
 read-trait-cell-map
 read-hasmethod-cell-map
 ;; Phase 1b: Trait/HasMethod/Capability constraint cell IDs
 current-trait-constraint-cell-id
 current-trait-cell-map-cell-id
 current-hasmethod-constraint-cell-id
 current-hasmethod-cell-map-cell-id
 current-capability-constraint-cell-id
 ;; Phase 1c: Wakeup registry cell IDs
 current-wakeup-registry-cell-id
 current-trait-wakeup-cell-id
 current-hasmethod-wakeup-cell-id
 ;; Track 2 Phase 2: Constraint status cell
 current-constraint-status-cell-id
 read-constraint-status-map
 write-constraint-status-cell!
 ;; Track 2 Phase 7: Error descriptor cell
 current-error-descriptor-cell-id
 read-error-descriptors
 write-error-descriptor!
 ;; Track 2 Phase 3: Stratified resolution (progress box is internal)
 current-in-stratified-resolution?
 current-stratified-progress-box
 ;; Track 2 Phase 4: Action descriptors
 (struct-out action-retry-constraint)
 (struct-out action-resolve-trait)
 (struct-out action-resolve-hasmethod)
 collect-ready-constraints-via-cells
 collect-ready-traits-via-cells
 collect-ready-hasmethods-via-cells
 execute-resolution-action!
 execute-resolution-actions!
 ;; P5b: Multiplicity cell callbacks
 current-prop-fresh-mult-cell
 current-prop-mult-cell-write
 ;; Track 4 Phase 3: Level and session cell callbacks
 current-prop-fresh-level-cell
 current-prop-fresh-sess-cell
 ;; P1-G2: Network contradiction check
 current-prop-has-contradiction?
 ;; Propagator quiescence + rewrap (used by solve-meta!)
 current-prop-run-quiescence
 current-prop-unwrap-net
 current-prop-rewrap-net
 ;; P-U3c: Flush network quiescence (no-op if no network or worklist empty)
 maybe-flush-network!
 ;; Phase 4c: Meta cell lookup (for structural decomposition propagators)
 prop-meta-id->cell-id
 ;; Hash removal: test isolation helper
 with-fresh-meta-env)

;; ========================================
;; Meta-info: everything about a single metavariable
;; ========================================
(struct meta-info
  (id          ;; symbol (gensym), e.g. 'meta42
   ctx         ;; typing context at creation (list of (cons type mult))
   type        ;; expected type of the solution (Expr)
   status      ;; 'unsolved or 'solved
   solution    ;; Expr or #f if unsolved
   constraints ;; (listof any) — empty in Sprint 1, used by Sprint 2
   source)     ;; any — debug info (source location, description string)
  #:transparent)

;; ========================================
;; Sprint 5: Constraint postponement
;; ========================================
;; A constraint is a deferred unification obligation that can't be solved
;; immediately (e.g., when pattern-check fails for an applied metavariable).
;; Constraints are retried when the metavariables they mention get solved.

(struct constraint
  (cid       ;; symbol (gensym) — unique identity for status cell keying (Track 2 Phase 2)
   lhs       ;; Expr — left side of unification
   rhs       ;; Expr — right side of unification
   ctx       ;; Context — typing context at creation
   source    ;; any — debug info (string or constraint-provenance)
   status    ;; 'postponed | 'retrying | 'solved | 'failed
   cell-ids) ;; (listof cell-id) — propagator cells for metas in lhs/rhs (P1-E3a)
  #:transparent)

;; ========================================
;; Sprint 9: Structured provenance for error messages
;; ========================================

;; Structured source info for metavariables.
;; Replaces the string previously stored in meta-info.source.
;; Both strings and meta-source-info are accepted by the source field.
(struct meta-source-info
  (loc          ;; srcloc — where in user code this meta was created
   kind         ;; symbol: 'implicit | 'implicit-app | 'pi-param | 'lambda-param | 'bare-Type | 'other
   description  ;; string — human-readable description
   def-name     ;; symbol or #f — which definition this meta belongs to
   name-map)    ;; (listof string) or #f — de Bruijn name stack at creation site
  #:transparent)

;; Structured provenance for constraints.
;; Replaces the string stored in constraint.source.
(struct constraint-provenance
  (loc          ;; srcloc — where in user code this constraint arose
   description  ;; string — human-readable
   meta-source) ;; meta-source-info or #f — the meta that triggered this constraint
  #:transparent)

;; ========================================
;; Track 2 Phase 4: Resolution Action Descriptors
;; ========================================
;; Data-oriented descriptions of resolution actions. Produced by S1 (readiness
;; scan), consumed by S2 (resolution commitment). The interpreter loop in
;; run-stratified-resolution! processes these as a worklist.
;;
;; This is the free monad pattern: instead of executing effects inline,
;; resolution functions return data describing what should happen.

;; Retry a postponed unification constraint.
(struct action-retry-constraint
  (constraint)    ;; constraint struct — the constraint to retry
  #:transparent)

;; Resolve a trait dictionary (e.g., find the Eq Int instance).
(struct action-resolve-trait
  (dict-meta-id   ;; symbol — the dictionary metavariable to solve
   tc-info)       ;; trait-constraint-info — trait name + type args
  #:transparent)

;; Resolve a hasmethod constraint (e.g., find .length method).
(struct action-resolve-hasmethod
  (meta-id        ;; symbol — the hasmethod metavariable
   hm-info)       ;; hasmethod-constraint-info — method details
  #:transparent)

;; ========================================
;; Trait constraint tracking (Phase C)
;; ========================================
;; When the elaborator inserts implicit metas for trait-constraint
;; parameters (e.g., the Eq A dict in a where (Eq A) function),
;; we tag those metas with trait-constraint-info so the resolution
;; engine can solve them to dictionary expressions after type-checking.

(struct trait-constraint-info
  (trait-name       ;; symbol — e.g., 'Eq
   type-arg-exprs)  ;; (listof Expr) — elaborated type args (may contain metas initially)
  #:transparent)

;; Phase 8 cleanup: current-trait-constraint-map and current-trait-wakeup-map
;; removed — superseded by trait-constraint and trait-wakeup cells.

;; Phase C: Callback for incremental trait resolution.
;; Signature: (dict-meta-id trait-constraint-info) → void
;; Injected from driver.rkt to break circular dependency.
(define current-retry-trait-resolve (make-parameter #f))

;; Phase C: Install the trait resolve callback.
(define (install-trait-resolve-callback! resolve-fn)
  (current-retry-trait-resolve resolve-fn))

;; Phase 8 cleanup: current-trait-cell-map removed — superseded by trait-cell-map cell.

;; Register a trait constraint and build wakeup index for incremental resolution.
(define (register-trait-constraint! meta-id info)
  ;; Track 1 Phase 6c: Cell-only write (network-everywhere).
  (define tc-cid (current-trait-constraint-cell-id))
  (define tc-net-box (current-prop-net-box))
  (define write-fn (current-prop-cell-write))
  (set-box! tc-net-box (write-fn (unbox tc-net-box) tc-cid (hasheq meta-id info)))
  ;; Phase C: Build reverse index from type-arg metas → this dict meta
  (define type-arg-metas (extract-shallow-meta-ids-from-list
                           (trait-constraint-info-type-arg-exprs info)))
  ;; Phase 1e: Filter to only unsolved metas for wakeup — solved metas won't trigger
  ;; future solve-meta! calls. If all type-args are already solved, immediate resolution
  ;; fires below (same pattern as hasmethod wakeup).
  (define unsolved-ta-metas (filter (lambda (id) (not (meta-solved? id))) type-arg-metas))
  ;; Track 1 Phase 6c: Cell-only wakeup write (network-everywhere).
  (define tw-cid (current-trait-wakeup-cell-id))
  (when (pair? unsolved-ta-metas)
    (let ([tw-delta
           (for/fold ([acc (hasheq)]) ([ta-id (in-list unsolved-ta-metas)])
             (hash-set acc ta-id (list meta-id)))])
      (set-box! tc-net-box (write-fn (unbox tc-net-box) tw-cid tw-delta))))
  ;; P3a: Record cell-ids for type-arg metas for cell-state-driven resolution.
  (define id-map (if (current-prop-id-map-read)
                     ((current-prop-id-map-read) (unbox tc-net-box))
                     champ-empty))
  (define cell-ids
    (for*/list ([ta-id (in-list type-arg-metas)]
                [cid (in-value (champ-lookup id-map (prop-meta-id-hash ta-id) ta-id))]
                #:when (not (eq? cid 'none)))
      cid))
  ;; Phase 7b: Cell-only write for trait-cell-map (removed dual-write to parameter).
  (when (not (null? cell-ids))
    (define tcm-cid (current-trait-cell-map-cell-id))
    (set-box! tc-net-box
              (write-fn (unbox tc-net-box) tcm-cid
                        (hasheq meta-id (remove-duplicates cell-ids eq?)))))
  ;; Phase 3d: If all type-args are already ground (no unsolved metas to trigger wakeup),
  ;; attempt immediate resolution via the callback.
  (when (null? unsolved-ta-metas)
    (define resolve-fn (current-retry-trait-resolve))
    (when resolve-fn
      (resolve-fn meta-id info))))

;; Track 1 Phase 2a: read from cell.
(define (lookup-trait-constraint meta-id)
  (hash-ref (read-trait-constraints) meta-id #f))

;; ========================================
;; Phase 3a: HasMethod constraint tracking
;; ========================================
;; When a spec has :method P eq? : T, the elaborator inserts an implicit
;; evidence parameter for the projected method. At call sites, the meta
;; for this evidence is tagged with hasmethod-constraint-info so the
;; resolver can project the method from the trait dict once P is ground.

(struct hasmethod-constraint-info
  (trait-var-expr    ;; Expr — the trait variable (typically (expr-meta ?P-id))
   method-name       ;; symbol — e.g., 'eq?
   type-arg-exprs    ;; (listof Expr) — type args [?A-meta]
   dict-meta-id)     ;; symbol | #f — meta-id of the dict param for projection
  #:transparent)

;; Phase 8 cleanup: current-hasmethod-constraint-map and current-hasmethod-wakeup-map
;; removed — superseded by hasmethod-constraint and hasmethod-wakeup cells.

;; Phase 1d: Callback for incremental hasmethod resolution.
;; Signature: (hasmethod-meta-id hasmethod-constraint-info) → void
;; Injected from driver.rkt to break circular dependency (same pattern as trait resolve).
(define current-retry-hasmethod-resolve (make-parameter #f))

;; Phase 1d: Install the hasmethod resolve callback.
(define (install-hasmethod-resolve-callback! resolve-fn)
  (current-retry-hasmethod-resolve resolve-fn))

(define (register-hasmethod-constraint! meta-id info)
  ;; Track 1 Phase 6c: Cell-only write (network-everywhere).
  (define hm-cid (current-hasmethod-constraint-cell-id))
  (define hm-net-box (current-prop-net-box))
  (define write-fn (current-prop-cell-write))
  (set-box! hm-net-box (write-fn (unbox hm-net-box) hm-cid (hasheq meta-id info)))
  ;; Phase 1d: Build reverse wakeup index from dependency metas → this hasmethod meta.
  ;; Dependencies are: metas in trait-var-expr + metas in type-arg-exprs.
  (define trait-var-metas (extract-shallow-meta-ids
                            (hasmethod-constraint-info-trait-var-expr info)))
  (define type-arg-metas (extract-shallow-meta-ids-from-list
                            (hasmethod-constraint-info-type-arg-exprs info)))
  (define all-dep-metas (append trait-var-metas type-arg-metas))
  ;; Phase 1e: Filter to only unsolved metas for wakeup tracking.
  ;; Already-solved metas won't trigger future solve-meta! calls, so they
  ;; can't fire wakeup. If all deps are solved, immediate resolution fires below.
  (define unsolved-dep-metas (filter (lambda (id) (not (meta-solved? id))) all-dep-metas))
  ;; Phase 7a: Cell-only wakeup write (mirrors trait-wakeup pattern).
  (define hw-cid (current-hasmethod-wakeup-cell-id))
  (when (pair? unsolved-dep-metas)
    (let ([hw-delta
           (for/fold ([acc (hasheq)]) ([dep-id (in-list unsolved-dep-metas)])
             (hash-set acc dep-id (list meta-id)))])
      (set-box! hm-net-box (write-fn (unbox hm-net-box) hw-cid hw-delta))))
  ;; Track 2 Phase 6: Record cell-ids for dependency metas (cell-state-driven resolution).
  ;; Mirrors trait-cell-map pattern: enables collect-ready-hasmethods-via-cells.
  (define id-map-read-fn (current-prop-id-map-read))
  (when (and hm-net-box id-map-read-fn)
    (define id-map (id-map-read-fn (unbox hm-net-box)))
    (define cell-ids
      (for*/list ([dep-id (in-list all-dep-metas)]
                  [cid (in-value (champ-lookup id-map (prop-meta-id-hash dep-id) dep-id))]
                  #:when (not (eq? cid 'none)))
        cid))
    (when (not (null? cell-ids))
      (define hcm-cid (current-hasmethod-cell-map-cell-id))
      (when hcm-cid
        (set-box! hm-net-box
                  (write-fn (unbox hm-net-box) hcm-cid
                            (hasheq meta-id (remove-duplicates cell-ids eq?)))))))
  ;; Phase 1d: If all deps are already ground (no unsolved metas to trigger wakeup),
  ;; attempt immediate resolution via the callback.
  (when (null? unsolved-dep-metas)
    (define resolve-fn (current-retry-hasmethod-resolve))
    (when resolve-fn
      (resolve-fn meta-id info))))

;; Track 1 Phase 2b: read from cell.
(define (lookup-hasmethod-constraint meta-id)
  (hash-ref (read-hasmethod-constraints) meta-id #f))

;; Phase 1d: Try to resolve hasmethod constraints that reference a just-solved meta.
;; Called from solve-meta! when a dependency meta is solved. Checks the wakeup
;; map for any hasmethod constraints referencing this meta, and if all their
;; dependencies are now ground, triggers resolution via the callback.
(define (retry-hasmethod-for-meta! meta-id)
  (define resolve-fn (current-retry-hasmethod-resolve))
  (when resolve-fn
    ;; Phase 7a: Read from cell (was direct parameter access).
    (define wakeup (read-hasmethod-wakeup-map))
    (define hm-metas (hash-ref wakeup meta-id '()))
    (for ([hm-id (in-list hm-metas)])
      (unless (meta-solved? hm-id)
        ;; Track 1 Phase 2b: read from cell.
        (define hm-info (hash-ref (read-hasmethod-constraints) hm-id #f))
        (when hm-info
          (resolve-fn hm-id hm-info))))))

;; ========================================
;; Phase 4: Capability constraint tracking
;; ========================================
;; When the elaborator inserts implicit metas for capability-constraint
;; parameters (e.g., {cap :0 ReadCap}), and no matching capability is
;; found in lexical scope, the meta is tagged with capability-constraint-info
;; so the error-reporting engine can produce E2001/E2002 messages.

(struct capability-constraint-info
  (cap-name       ;; symbol — e.g., 'ReadCap (functor name)
   cap-type-expr) ;; type expression — e.g., (expr-fvar 'ReadCap) or (expr-app (expr-fvar 'FileCap) ...)
  #:transparent)

;; Phase 8 cleanup: current-capability-constraint-map removed — superseded by capability-constraint cell.

(define (register-capability-constraint! meta-id info)
  ;; Track 1 Phase 6c: Cell-only write (network-everywhere).
  (define cap-cid (current-capability-constraint-cell-id))
  (define cap-net-box (current-prop-net-box))
  (define write-fn (current-prop-cell-write))
  (set-box! cap-net-box (write-fn (unbox cap-net-box) cap-cid (hasheq meta-id info))))

;; Track 1 Phase 2c: read from cell.
(define (lookup-capability-constraint meta-id)
  (hash-ref (read-capability-constraints) meta-id #f))


;; Phase 8 cleanup: current-constraint-store and current-wakeup-registry
;; removed — superseded by constraint and wakeup-registry cells.

;; Callback for constraint retry (set by unify.rkt at initialization).
;; This avoids a circular dependency: metavar-store.rkt -> unify.rkt.
(define current-retry-unify (make-parameter #f))

;; Walk an expression and collect all unsolved meta IDs referenced in it.
;; Uses struct->vector generic traversal (same pattern as occurs? in unify.rkt).
(define (collect-meta-ids expr)
  (let walk ([e expr] [acc '()])
    (cond
      [(expr-meta? e)
       (let ([id (expr-meta-id e)])
         (if (meta-solved? id)
             ;; Follow solved meta's solution to find transitive metas
             (let ([sol (meta-solution id)])
               (if sol (walk sol acc) acc))
             (if (memq id acc) acc (cons id acc))))]
      [(struct? e)
       (let ([v (struct->vector e)])
         (for/fold ([a acc])
                   ([i (in-range 1 (vector-length v))])
           (let ([field (vector-ref v i)])
             (if (or (struct? field) (expr-meta? field))
                 (walk field a)
                 a))))]
      [else acc])))

;; Shallow meta-id extractor for propagator constraints.
;; Walks the expression tree and collects all meta-ids (without following solutions).
;; Unlike collect-meta-ids, does NOT chase solved metas transitively —
;; we just want the structural meta references for creating propagator edges.
(define (extract-shallow-meta-ids expr)
  (let walk ([e expr] [acc '()])
    (cond
      [(expr-meta? e)
       (define id (expr-meta-id e))
       (if (memq id acc) acc (cons id acc))]
      [(or (symbol? e) (number? e) (string? e) (boolean? e) (char? e))
       acc]
      [(struct? e)
       (define v (struct->vector e))
       (for/fold ([a acc])
                 ([i (in-range 1 (vector-length v))])
         (define field (vector-ref v i))
         (if (or (struct? field) (expr-meta? field))
             (walk field a)
             a))]
      [else acc])))

;; Phase C: Extract meta-ids from a list of expressions (for trait wakeup index).
(define (extract-shallow-meta-ids-from-list exprs)
  (let loop ([es exprs] [acc '()])
    (if (null? es)
        acc
        (loop (cdr es) (extract-shallow-meta-ids (car es))))))

;; Phase C: Try to resolve trait constraints that reference a just-solved meta.
;; Called from solve-meta! when a type-arg meta is solved. Checks the wakeup
;; map for any trait constraints referencing this meta, and if all their
;; type-args are now ground, triggers resolution via the callback.
(define (retry-trait-for-meta! meta-id)
  (define resolve-fn (current-retry-trait-resolve))
  (when resolve-fn
    ;; Track 1 Phase 3b: read from cell.
    (define wakeup (read-trait-wakeup-map))
    (define dict-metas (hash-ref wakeup meta-id '()))
    (for ([dict-id (in-list dict-metas)])
      (unless (meta-solved? dict-id)
        ;; Track 1 Phase 2a: read from cell.
        (define tc-info (hash-ref (read-trait-constraints) dict-id #f))
        (when tc-info
          (resolve-fn dict-id tc-info))))))

;; P3a: Retry trait resolution using propagator cell state.
;; After run-to-quiescence, scans ALL trait constraints whose type-arg cells
;; have become non-bot. This captures transitive propagation that the wakeup
;; map might miss (e.g., if a type-arg meta was solved indirectly via network).
(define (retry-traits-via-cells!)
  (define resolve-fn (current-retry-trait-resolve))
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (when (and resolve-fn net-box read-fn)
    (define enet (unbox net-box))
    ;; Phase 7b: Read from cell (was direct parameter access).
    (define tcm (read-trait-cell-map))
    (for ([(dict-id cell-ids) (in-hash tcm)])
      (unless (meta-solved? dict-id)
        ;; Track 1 Phase 2a: read from cell.
        (define tc-info (hash-ref (read-trait-constraints) dict-id #f))
        (when tc-info
          ;; Check if any type-arg cell has become non-bot
          (define any-solved?
            (for/or ([cid (in-list cell-ids)])
              (let ([v (read-fn enet cid)])
                (and (not (prop-type-bot? v)) (not (prop-type-top? v))))))
          (when any-solved?
            (resolve-fn dict-id tc-info)))))))

;; Create a postponed constraint, add to global store, register for wakeup.
;; Phase 8b: Also adds unify propagators on the network between cells
;; referenced by metas in lhs/rhs.
(define (add-constraint! lhs rhs ctx source)
  (perf-inc-constraint!)
  (define c0 (constraint (gensym 'cst) lhs rhs ctx source 'postponed '()))
  ;; Collect meta-ids early (needed for wakeup + cell-ids).
  (define meta-ids (append (collect-meta-ids lhs) (collect-meta-ids rhs)))
  ;; Propagator path: add unify constraints between cells and compute cell-ids.
  (define net-box (current-prop-net-box))
  (define add-unify-fn (current-prop-add-unify-constraint))
  (define c
    (if (and net-box add-unify-fn)
        (let ()
          (define enet (unbox net-box))
          (define id-map ((current-prop-id-map-read) enet))
          (define lhs-metas (extract-shallow-meta-ids lhs))
          (define rhs-metas (extract-shallow-meta-ids rhs))
          (define enet*
            (for*/fold ([net enet])
                       ([lm (in-list lhs-metas)]
                        [rm (in-list rhs-metas)])
              (define lcid (champ-lookup id-map (prop-meta-id-hash lm) lm))
              (define rcid (champ-lookup id-map (prop-meta-id-hash rm) rm))
              (if (and (not (eq? lcid 'none)) (not (eq? rcid 'none))
                       (not (equal? lcid rcid)))
                  (let-values ([(net* _pid) (add-unify-fn net lcid rcid)])
                    net*)
                  net)))
          (set-box! net-box enet*)
          ;; P1-E3a: Record cell-ids for all metas in constraint.
          ;; Track 6 Phase 1c: immutable constraint with cell-ids populated.
          (define all-cell-ids
            (for*/list ([mid (in-list meta-ids)]
                        [cid (in-value (champ-lookup id-map (prop-meta-id-hash mid) mid))]
                        #:when (not (eq? cid 'none)))
              cid))
          (struct-copy constraint c0 [cell-ids (remove-duplicates all-cell-ids eq?)]))
        c0))
  ;; Track 6 Phase 1c: write as hash entry keyed by constraint cid.
  ;; The constraint now has cell-ids populated before being written to store.
  (define cstore-cid (current-constraint-cell-id))
  (define cstore-net-box (current-prop-net-box))
  (define write-fn (current-prop-cell-write))
  (let ([enet (unbox cstore-net-box)])
    (set-box! cstore-net-box (write-fn enet cstore-cid (hasheq (constraint-cid c) c))))
  ;; Track 2 Phase 2: Write initial 'pending status to cell.
  (write-constraint-status-cell! (constraint-cid c) 'pending)
  ;; Register for wakeup on all mentioned metas.
  (define wr-cid (current-wakeup-registry-cell-id))
  (when (pair? meta-ids)
    (let ([wr-delta
           (for/fold ([acc (hasheq)]) ([id (in-list meta-ids)])
             (hash-set acc id (list c)))])
      (set-box! cstore-net-box (write-fn (unbox cstore-net-box) wr-cid wr-delta))))
  c)

;; Get constraints associated with a metavariable for wakeup.
;; Track 1 Phase 3a: read from cell.
(define (get-wakeup-constraints meta-id)
  (hash-ref (read-wakeup-registry) meta-id '()))

;; Retry postponed constraints that mention the given meta.
;; Uses 'retrying guard to prevent infinite re-entrant loops.
;; Track 6 Phase 1c: functional status updates via write-constraint-to-store!.
(define (retry-constraints-for-meta! meta-id)
  (perf-inc-constraint-retry!)
  (define retry-fn (current-retry-unify))
  (when retry-fn
    (define constraints (get-wakeup-constraints meta-id))
    (for ([c (in-list constraints)])
      (define c-cid (constraint-cid c))
      ;; Read fresh from store to get current status.
      (define current-c (read-constraint-by-cid c-cid))
      (when (and current-c (eq? (constraint-status current-c) 'postponed))
        ;; Guard against re-entrant retry
        (write-constraint-to-store! (struct-copy constraint current-c [status 'retrying]))
        (retry-fn current-c)
        ;; Read fresh again — retry-fn may have written 'solved/'failed
        (define post-c (read-constraint-by-cid c-cid))
        (when (and post-c (eq? (constraint-status post-c) 'retrying))
          (write-constraint-to-store! (struct-copy constraint post-c [status 'postponed])))))))

;; P1-E3a: Retry postponed constraints using propagator cell state.
;; After run-to-quiescence, checks ALL postponed constraints that have cell-ids.
;; A constraint is retried if any of its meta cells has become non-bot
;; (i.e., some meta was solved, possibly via transitive propagation).
;; This captures transitive wakeups that the legacy wakeup registry misses.
;; Track 6 Phase 1c: functional status updates via write-constraint-to-store!.
(define (retry-constraints-via-cells!)
  (define retry-fn (current-retry-unify))
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (when (and retry-fn net-box read-fn)
    (define enet (unbox net-box))
    ;; Track 1 Phase 1c: read from cell (primary) with parameter fallback.
    (for ([c (in-list (read-constraint-store))])
      (define c-cid (constraint-cid c))
      (when (and (eq? (constraint-status c) 'postponed)
                 (not (null? (constraint-cell-ids c))))
        ;; Check if any meta cell has become non-bot (meta solved)
        (define any-solved?
          (for/or ([cid (in-list (constraint-cell-ids c))])
            (let ([v (read-fn enet cid)])
              (and (not (prop-type-bot? v)) (not (prop-type-top? v))))))
        (when any-solved?
          ;; Guard against re-entrant retry (same as legacy path)
          (write-constraint-to-store! (struct-copy constraint c [status 'retrying]))
          (retry-fn c)
          ;; Read fresh from store — retry-fn may have written 'solved/'failed
          (define post-c (read-constraint-by-cid c-cid))
          (when (and post-c (eq? (constraint-status post-c) 'retrying))
            (write-constraint-to-store! (struct-copy constraint post-c [status 'postponed]))))))))

;; ========================================
;; Track 2 Phase 4: Readiness Scan (Stratum 1)
;; ========================================
;; Pure scan functions that produce action descriptors without executing.
;; These implement S1 (readiness detection) — observation only.

;; Scan postponed constraints via cell state, return ready ones as descriptors.
;; Production path: checks which constraints have non-bot meta cells.
(define (collect-ready-constraints-via-cells)
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (cond
    [(and net-box read-fn)
     (define enet (unbox net-box))
     (for*/list ([c (in-list (read-constraint-store))]
                 #:when (and (eq? (constraint-status c) 'postponed)
                             (not (null? (constraint-cell-ids c))))
                 #:when (for/or ([cid (in-list (constraint-cell-ids c))])
                          (let ([v (read-fn enet cid)])
                            (and (not (prop-type-bot? v)) (not (prop-type-top? v))))))
       (action-retry-constraint c))]
    [else '()]))

;; Scan postponed constraints for a specific meta (test fallback path).
(define (collect-ready-constraints-for-meta meta-id)
  (define constraints (get-wakeup-constraints meta-id))
  (for/list ([c (in-list constraints)]
             #:when (eq? (constraint-status c) 'postponed))
    (action-retry-constraint c)))

;; Scan trait constraints via cell state, return ready ones as descriptors.
(define (collect-ready-traits-via-cells)
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (cond
    [(and net-box read-fn)
     (define enet (unbox net-box))
     (define tcm (read-trait-cell-map))
     (for*/list ([(dict-id cell-ids) (in-hash tcm)]
                 #:when (not (meta-solved? dict-id))
                 [tc-info (in-value (hash-ref (read-trait-constraints) dict-id #f))]
                 #:when tc-info
                 #:when (for/or ([cid (in-list cell-ids)])
                          (let ([v (read-fn enet cid)])
                            (and (not (prop-type-bot? v)) (not (prop-type-top? v))))))
       (action-resolve-trait dict-id tc-info))]
    [else '()]))

;; Scan trait constraints for a specific meta (targeted wakeup).
(define (collect-ready-traits-for-meta meta-id)
  (define wakeup (read-trait-wakeup-map))
  (define dict-metas (hash-ref wakeup meta-id '()))
  (for*/list ([dict-id (in-list dict-metas)]
              #:when (not (meta-solved? dict-id))
              [tc-info (in-value (hash-ref (read-trait-constraints) dict-id #f))]
              #:when tc-info)
    (action-resolve-trait dict-id tc-info)))

;; Scan hasmethod constraints for a specific meta (targeted wakeup).
(define (collect-ready-hasmethods-for-meta meta-id)
  (define wakeup (read-hasmethod-wakeup-map))
  (define hm-metas (hash-ref wakeup meta-id '()))
  (for*/list ([hm-id (in-list hm-metas)]
              #:when (not (meta-solved? hm-id))
              [hm-info (in-value (hash-ref (read-hasmethod-constraints) hm-id #f))]
              #:when hm-info)
    (action-resolve-hasmethod hm-id hm-info)))

;; Track 2 Phase 6: Scan hasmethod constraints via cell state.
;; Symmetric to collect-ready-traits-via-cells — reads hasmethod-cell-map
;; and checks whether any dependency cells have non-bot values.
(define (collect-ready-hasmethods-via-cells)
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (cond
    [(and net-box read-fn)
     (define enet (unbox net-box))
     (define hcm (read-hasmethod-cell-map))
     (for*/list ([(hm-id cell-ids) (in-hash hcm)]
                 #:when (not (meta-solved? hm-id))
                 [hm-info (in-value (hash-ref (read-hasmethod-constraints) hm-id #f))]
                 #:when hm-info
                 #:when (for/or ([cid (in-list cell-ids)])
                          (let ([v (read-fn enet cid)])
                            (and (not (prop-type-bot? v)) (not (prop-type-top? v))))))
       (action-resolve-hasmethod hm-id hm-info))]
    [else '()]))

;; ========================================
;; Track 2 Phase 4: Action Interpreter (Stratum 2)
;; ========================================
;; Consumes action descriptors produced by S1 and executes them.
;; Each action may produce new cell writes that feed back to S0.

(define (execute-resolution-action! action)
  (match action
    [(action-retry-constraint c)
     ;; Re-check: constraint may have been resolved by a prior action in this batch.
     ;; Track 6 Phase 1c: read fresh from store for current status.
     (define c-cid (constraint-cid c))
     (define current-c (read-constraint-by-cid c-cid))
     (when (and current-c (eq? (constraint-status current-c) 'postponed))
       (perf-inc-constraint-retry!)
       (define retry-fn (current-retry-unify))
       (when retry-fn
         ;; Guard still present as safety net (structurally dead under stratified loop).
         (write-constraint-to-store! (struct-copy constraint current-c [status 'retrying]))
         (retry-fn current-c)
         (define post-c (read-constraint-by-cid c-cid))
         (when (and post-c (eq? (constraint-status post-c) 'retrying))
           (write-constraint-to-store! (struct-copy constraint post-c [status 'postponed])))))]
    [(action-resolve-trait dict-id tc-info)
     ;; Re-check: dict meta may have been solved by a prior action.
     (unless (meta-solved? dict-id)
       (define resolve-fn (current-retry-trait-resolve))
       (when resolve-fn
         (resolve-fn dict-id tc-info)))]
    [(action-resolve-hasmethod hm-id hm-info)
     ;; Re-check: hasmethod meta may have been solved by a prior action.
     (unless (meta-solved? hm-id)
       (define resolve-fn (current-retry-hasmethod-resolve))
       (when resolve-fn
         (resolve-fn hm-id hm-info)))]))

;; Execute a batch of action descriptors.
(define (execute-resolution-actions! actions)
  (for ([a (in-list actions)])
    (execute-resolution-action! a)))

;; ========================================
;; Cell-Primary Read Accessors
;; ========================================
;; Each reads from the cell (primary) with parameter fallback.
;; Track 1: constraint store, trait/hasmethod/capability maps.

;; Track 1 Phase 6f: Cell-primary reads.
;; Reads go through cells when the network is active. When no network
;; exists (pre-initialization, between reset-constraint-store! and
;; cell recreation), returns the empty default. This is semantically
;; correct: no constraints exist before initialization.
;; Note: WRITES remain cell-only (crash without network = data loss prevention).

;; Read the constraint store from the cell.
;; Track 6 Phase 1c: constraint store is now a hasheq keyed by constraint cid.
;; Returns the current list of all constraints (hash-values for backward compat).
(define (read-constraint-store)
  (define cid (current-constraint-cell-id))
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (if (and cid net-box read-fn)
      (hash-values (read-fn (unbox net-box) cid))
      '()))

;; Track 6 Phase 1c: Read a single constraint by its cid from the store.
(define (read-constraint-by-cid c-cid)
  (define cid (current-constraint-cell-id))
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (if (and cid net-box read-fn)
      (hash-ref (read-fn (unbox net-box) cid) c-cid #f)
      #f))

;; Track 6 Phase 1c: Write a single constraint update to the store (functional).
;; Merges a single-entry hash — merge-hasheq-union replaces the entry.
(define (write-constraint-to-store! updated-c)
  (define cid (current-constraint-cell-id))
  (define net-box (current-prop-net-box))
  (define write-fn (current-prop-cell-write))
  (when (and cid net-box write-fn)
    (set-box! net-box (write-fn (unbox net-box) cid
                                (hasheq (constraint-cid updated-c) updated-c)))))

;; Read trait constraint map from cell.
;; Returns hasheq: meta-id → trait-constraint-info.
(define (read-trait-constraints)
  (define cid (current-trait-constraint-cell-id))
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (if (and cid net-box read-fn)
      (read-fn (unbox net-box) cid)
      (hasheq)))

;; Read hasmethod constraint map from cell.
;; Returns hasheq: meta-id → hasmethod-constraint-info.
(define (read-hasmethod-constraints)
  (define cid (current-hasmethod-constraint-cell-id))
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (if (and cid net-box read-fn)
      (read-fn (unbox net-box) cid)
      (hasheq)))

;; Read capability constraint map from cell.
;; Returns hasheq: meta-id → capability-constraint-info.
(define (read-capability-constraints)
  (define cid (current-capability-constraint-cell-id))
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (if (and cid net-box read-fn)
      (read-fn (unbox net-box) cid)
      (hasheq)))

;; Read wakeup registry from cell.
;; Returns hasheq: meta-id → (listof constraint).
(define (read-wakeup-registry)
  (define cid (current-wakeup-registry-cell-id))
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (if (and cid net-box read-fn)
      (read-fn (unbox net-box) cid)
      (hasheq)))

;; Read trait wakeup map from cell.
;; Returns hasheq: meta-id → (listof dict-meta-id).
(define (read-trait-wakeup-map)
  (define cid (current-trait-wakeup-cell-id))
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (if (and cid net-box read-fn)
      (read-fn (unbox net-box) cid)
      (hasheq)))

;; Phase 7a: Read hasmethod wakeup map from cell.
;; Returns hasheq: meta-id → (listof hasmethod-meta-id).
(define (read-hasmethod-wakeup-map)
  (define cid (current-hasmethod-wakeup-cell-id))
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (if (and cid net-box read-fn)
      (read-fn (unbox net-box) cid)
      (hasheq)))

;; Phase 7b: Read trait cell-map from cell.
;; Returns hasheq: dict-meta-id → (listof cell-id).
(define (read-trait-cell-map)
  (define cid (current-trait-cell-map-cell-id))
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (if (and cid net-box read-fn)
      (read-fn (unbox net-box) cid)
      (hasheq)))

;; Track 2 Phase 6: Read hasmethod cell-map from cell.
;; Returns hasheq: hasmethod-meta-id → (listof cell-id).
(define (read-hasmethod-cell-map)
  (define cid (current-hasmethod-cell-map-cell-id))
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (if (and cid net-box read-fn)
      (read-fn (unbox net-box) cid)
      (hasheq)))

;; Track 2 Phase 2: Read constraint status map from cell.
;; Returns hasheq: constraint-id → 'pending | 'resolved.
(define (read-constraint-status-map)
  (define cid (current-constraint-status-cell-id))
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (if (and cid net-box read-fn)
      (read-fn (unbox net-box) cid)
      (hasheq)))

;; Track 2 Phase 2: Write a constraint's status to the status cell.
;; Dual-writes alongside set-constraint-status! until Phase 3 eliminates
;; the struct's mutable status field.
(define (write-constraint-status-cell! constraint-id status-sym)
  (define cid (current-constraint-status-cell-id))
  (define net-box (current-prop-net-box))
  (define write-fn (current-prop-cell-write))
  (when (and cid net-box write-fn)
    (set-box! net-box (write-fn (unbox net-box) cid (hasheq constraint-id status-sym)))))

;; Track 2 Phase 7: Read error descriptors from cell.
;; Returns hasheq: meta-id → no-instance-error.
(define (read-error-descriptors)
  (define cid (current-error-descriptor-cell-id))
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (if (and cid net-box read-fn)
      (read-fn (unbox net-box) cid)
      (hasheq)))

;; Track 2 Phase 7: Write an error descriptor to the error cell.
;; Called by resolution callbacks when resolution fails for a ground constraint.
(define (write-error-descriptor! meta-id error)
  (define cid (current-error-descriptor-cell-id))
  (define net-box (current-prop-net-box))
  (define write-fn (current-prop-cell-write))
  (when (and cid net-box write-fn)
    (set-box! net-box (write-fn (unbox net-box) cid (hasheq meta-id error)))))

;; Reset the constraint store (called by reset-meta-store!).
;; Clears cell IDs — new cells are created by reset-meta-store! when the network is recreated.
(define (reset-constraint-store!)
  (current-constraint-cell-id #f)
  ;; Phase 1b: Clear cell IDs (new cells are created per-command by reset-meta-store!).
  (current-trait-constraint-cell-id #f)
  (current-trait-cell-map-cell-id #f)
  (current-hasmethod-constraint-cell-id #f)
  (current-capability-constraint-cell-id #f)
  ;; Phase 1c: Clear wakeup cell IDs.
  (current-wakeup-registry-cell-id #f)
  (current-trait-wakeup-cell-id #f)
  ;; Phase 7a: Clear hasmethod wakeup cell ID (was hash-clear! on parameter).
  (current-hasmethod-wakeup-cell-id #f)
  ;; Track 2 Phase 6: Clear hasmethod cell-map cell ID.
  (current-hasmethod-cell-map-cell-id #f)
  ;; Track 2 Phase 2: Clear constraint status cell ID.
  (current-constraint-status-cell-id #f)
  ;; Track 2 Phase 7: Clear error descriptor cell ID.
  (current-error-descriptor-cell-id #f)
  ;; Track 6 Phase 1d: Clear unsolved metas cell ID.
  (current-unsolved-metas-cell-id #f))

;; Query: all postponed constraints.
;; Track 1 Phase 1a: reads from cell (primary) with parameter fallback.
(define (all-postponed-constraints)
  (filter (lambda (c) (eq? (constraint-status c) 'postponed))
          (read-constraint-store)))

;; Query: all failed constraints.
;; Track 1 Phase 1b: reads from cell (primary) with parameter fallback.
(define (all-failed-constraints)
  (filter (lambda (c) (eq? (constraint-status c) 'failed))
          (read-constraint-store)))

;; ========================================
;; Global metavariable store
;; ========================================
;; Mutable hash (symbol -> meta-info) inside a parameter.
;; Use parameterize with (make-hasheq) for isolation in tests/modules.
(define current-meta-store (make-parameter (make-hasheq)))

;; ========================================
;; Phase 8b: Propagator-backed internal state
;; ========================================
;; When initialized (by reset-meta-store!), expression meta solutions
;; are stored in an immutable propagator network (CHAMP-backed elab-network).
;; When #f, the legacy mutable hash path is used (test compatibility).

;; Box of elab-network | #f
(define current-prop-net-box (make-parameter #f))
;; DEPRECATED: Box of CHAMP: meta-id (gensym) → cell-id | #f
;; Retained for external consumers (driver.rkt, test files). New code should use
;; current-prop-id-map-read / current-prop-id-map-set callbacks instead.
(define current-prop-id-map-box (make-parameter #f))
;; Box of CHAMP: meta-id (gensym) → meta-info | #f
;; Phase A: Primary metadata store (replaces hash for production reads).
(define current-prop-meta-info-box (make-parameter #f))

;; Phase B: Auxiliary meta CHAMP boxes (level, mult, session).
;; Each stores id → 'unsolved | solution. Included in save/restore for
;; correct speculative rollback (fixes latent bug where level/mult/session
;; meta mutations leaked through with-speculative-rollback).
(define current-level-meta-champ-box (make-parameter #f))
(define current-mult-meta-champ-box (make-parameter #f))
(define current-sess-meta-champ-box (make-parameter #f))

;; Symbol hash for gensym meta-ids.
(define (prop-meta-id-hash id) (eq-hash-code id))

;; Callback parameters for network operations.
;; These are set by install-prop-network-callbacks! (called from driver.rkt)
;; to break the circular dependency with elaborator-network.rkt.
(define current-prop-make-network (make-parameter #f))      ;; (→ elab-network)
(define current-prop-fresh-meta (make-parameter #f))        ;; (enet ctx type source → (values enet* cell-id))
(define current-prop-cell-write (make-parameter #f))        ;; (enet cell-id value → enet*)
(define current-prop-cell-read (make-parameter #f))         ;; (enet cell-id → value)
(define current-prop-add-unify-constraint (make-parameter #f))  ;; (enet cid-a cid-b → (values enet* pid))

;; Phase 1a: Infrastructure cell creation callback (set by driver.rkt).
;; (enet initial-value merge-fn → (values enet* cell-id))
(define current-prop-new-infra-cell (make-parameter #f))

;; Track 6 Phase 1a: id-map access callbacks (set by driver.rkt).
;; Break circular dep: metavar-store doesn't import elaborator-network.
(define current-prop-id-map-read (make-parameter #f))   ;; (enet → champ)
(define current-prop-id-map-set (make-parameter #f))    ;; (enet champ → enet)

;; Phase 1a: Cell ID for the constraint store cell (set by reset-meta-store!).
;; When #f, falls back to legacy parameter-based storage.
(define current-constraint-cell-id (make-parameter #f))

;; Phase 1b: Cell IDs for trait/hasmethod/capability constraint registry cells.
;; Each is a registry cell with merge-hasheq-union, mirroring the legacy hasheq maps.
(define current-trait-constraint-cell-id (make-parameter #f))
(define current-trait-cell-map-cell-id (make-parameter #f))
(define current-hasmethod-constraint-cell-id (make-parameter #f))
(define current-capability-constraint-cell-id (make-parameter #f))

;; Phase 1c: Cell IDs for wakeup registries.
;; These map meta-id → (listof value), using merge-hasheq-list-append.
(define current-wakeup-registry-cell-id (make-parameter #f))
(define current-trait-wakeup-cell-id (make-parameter #f))
;; Phase 7a: Hasmethod wakeup cell (was missing — the only wakeup map without a cell).
(define current-hasmethod-wakeup-cell-id (make-parameter #f))

;; Track 2 Phase 6: HasMethod cell-map cell (mirrors trait-cell-map).
;; Maps hasmethod-meta-id → (listof cell-id), using merge-hasheq-union.
(define current-hasmethod-cell-map-cell-id (make-parameter #f))

;; Track 2 Phase 2: Constraint status cell.
;; Maps constraint-id (gensym) → 'pending | 'resolved.
;; Monotone lattice: pending < resolved. Once resolved, stays resolved.
;; The struct's mutable status field ('postponed/'retrying/'solved/'failed)
;; stays in place until Phase 3 eliminates re-entrancy.
(define current-constraint-status-cell-id (make-parameter #f))

;; Track 2 Phase 7: Error descriptor cell.
;; Maps meta-id → no-instance-error. Written by resolution callbacks when
;; resolution fails; read by post-fixpoint error sweep.
(define current-error-descriptor-cell-id (make-parameter #f))

;; Track 6 Phase 1d: Unsolved metas tracking cell.
;; Maps meta-id → #t (unsolved) | #f (solved). Incrementally maintained
;; by fresh-meta (add) and solve-meta-core! (remove).
(define current-unsolved-metas-cell-id (make-parameter #f))

;; P5b: Multiplicity cell callbacks
(define current-prop-fresh-mult-cell (make-parameter #f))   ;; (enet source → (values enet* cell-id))
(define current-prop-mult-cell-write (make-parameter #f))   ;; (enet cell-id value → enet*)

;; Track 4 Phase 3: Level and session cell callbacks
(define current-prop-fresh-level-cell (make-parameter #f))  ;; (enet source → (values enet* cell-id))
(define current-prop-fresh-sess-cell (make-parameter #f))   ;; (enet source → (values enet* cell-id))

;; P1-G2: Network contradiction check (set by driver.rkt).
;; Returns #t if the current propagator network has a contradiction, #f otherwise.
(define current-prop-has-contradiction? (make-parameter #f))  ;; (→ boolean)

;; Propagator quiescence callbacks (set by driver.rkt).
;; current-prop-run-quiescence: (prop-network → prop-network) — runs scheduler.
;; current-prop-unwrap-net: (elab-network → prop-network) — extract inner net.
;; current-prop-rewrap-net: (elab-network prop-network → elab-network) — rewrap.
(define current-prop-run-quiescence (make-parameter #f))
(define current-prop-unwrap-net (make-parameter #f))
(define current-prop-rewrap-net (make-parameter #f))

;; Inline type-lattice predicates (avoid requiring type-lattice.rkt).
;; type-bot and type-top are sentinel symbols — see type-lattice.rkt.
(define (prop-type-bot? v) (eq? v 'type-bot))
(define (prop-type-top? v) (eq? v 'type-top))

;; Install network operation callbacks. Called once at startup from driver.rkt.
(define (install-prop-network-callbacks! make-net fresh-m cell-w cell-r add-unify)
  (current-prop-make-network make-net)
  (current-prop-fresh-meta fresh-m)
  (current-prop-cell-write cell-w)
  (current-prop-cell-read cell-r)
  (current-prop-add-unify-constraint add-unify))

;; Look up cell-id for a meta-id in the prop id-map. Returns cell-id or #f.
;; Track 6 Phase 1a: Reads from elab-network id-map field (was: separate box).
(define (prop-meta-id->cell-id id)
  (define net-box (current-prop-net-box))
  (define id-map-read (current-prop-id-map-read))
  (and net-box id-map-read
       (let ([v (champ-lookup (id-map-read (unbox net-box)) (prop-meta-id-hash id) id)])
         (if (eq? v 'none) #f v))))

;; ========================================
;; Hash removal: Test isolation macro
;; ========================================
;; Provides a fresh, isolated meta environment for unit tests.
;; Sets up all hash stores and constraint infrastructure, then calls
;; reset-meta-store! to create CHAMP boxes and propagator network+cells
;; (when callbacks are installed, e.g., via driver.rkt).
;;
;; Phase 6a: Network-everywhere — with-fresh-meta-env always creates a
;; propagator network when callbacks are available. This eliminates the
;; parameter fallback pattern and ensures a single write path (cell-only).
;;
;; Usage in tests:
;;   (with-fresh-meta-env (fresh-meta ...) (solve-meta! ...) ...)
;; For tests needing extra params:
;;   (with-fresh-meta-env (parameterize ([current-retry-unify ...]) ...))
(define-syntax-rule (with-fresh-meta-env body ...)
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-level-meta-store (make-hasheq)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-sess-meta-store (make-hasheq)]
                 [current-definition-cells-content (hasheq)]  ;; Phase 3a
                 [current-definition-dependencies (hasheq)]  ;; Phase 3b
                 ;; Cell IDs: #f — reset-meta-store! populates when callbacks available
                 [current-constraint-cell-id #f]
                 [current-trait-constraint-cell-id #f]
                 [current-trait-cell-map-cell-id #f]
                 [current-hasmethod-constraint-cell-id #f]
                 [current-capability-constraint-cell-id #f]
                 [current-wakeup-registry-cell-id #f]
                 [current-trait-wakeup-cell-id #f]
                 [current-hasmethod-wakeup-cell-id #f]
                 [current-hasmethod-cell-map-cell-id #f]
                 [current-constraint-status-cell-id #f]
                 [current-error-descriptor-cell-id #f]
                 [current-unsolved-metas-cell-id #f]
                 ;; CHAMP boxes + network: #f — reset-meta-store! creates fresh
                 [current-prop-meta-info-box #f]
                 [current-prop-net-box #f]
                 [current-level-meta-champ-box #f]
                 [current-mult-meta-champ-box #f]
                 [current-sess-meta-champ-box #f])
    (reset-meta-store!)
    body ...))

;; ========================================
;; API
;; ========================================

;; Create a fresh metavariable, register it in the store, return expr-meta.
;; Hash removal: Always writes to CHAMP meta-info store. Optionally allocates
;; propagator cell when network is available (production path via driver.rkt).
(define (fresh-meta ctx type source)
  (perf-inc-meta-created!)
  (define id (gensym 'meta))
  (define info (meta-info id ctx type 'unsolved #f '() source))
  ;; Write to CHAMP meta-info store (always available)
  (define mi-box (current-prop-meta-info-box))
  (set-box! mi-box (champ-insert (unbox mi-box) (prop-meta-id-hash id) id info))
  ;; Optionally allocate cell on propagator network
  (define net-box (current-prop-net-box))
  (define fresh-fn (current-prop-fresh-meta))
  (when (and net-box fresh-fn)
    (define enet (unbox net-box))
    (define-values (enet* cid) (fresh-fn enet ctx type source))
    ;; Track 6 Phase 1a: id-map is a field of elab-network
    (define id-map-read (current-prop-id-map-read))
    (define id-map-set (current-prop-id-map-set))
    (define enet** (id-map-set enet*
                     (champ-insert (id-map-read enet*)
                                   (prop-meta-id-hash id) id cid)))
    ;; Track 6 Phase 1d: write to unsolved-metas tracking cell
    (define write-fn (current-prop-cell-write))
    (define um-cid (current-unsolved-metas-cell-id))
    (define enet***
      (if (and write-fn um-cid)
          (write-fn enet** um-cid (hasheq id #t))
          enet**))
    (set-box! net-box enet***))
  (expr-meta id))

;; Track 2 Phase 3: Stratified resolution flag.
;; When #t, solve-meta! only writes the solution (core) and defers retries
;; to the outer stratified loop. Prevents recursive re-entrancy.
(define current-in-stratified-resolution? (make-parameter #f))

;; Track 2 Phase 3: Progress box for the stratified loop.
;; Contains a box (or #f). When set, solve-meta-core! writes #t to the box
;; to signal that progress was made during the current S2 round.
(define current-stratified-progress-box (make-parameter #f))

;; Track 2 Phase 3: Maximum iterations for the S0→S1→S2 loop.
;; The CALM theorem guarantees convergence for monotone operations, but
;; Stratum 2 (resolution commitment) is a non-monotone barrier — fuel is
;; the safety net. Replaces the per-constraint `retrying` guard.
(define stratified-resolution-fuel 100)

;; Assign a solution to a metavariable. Errors if already solved.
;; Track 2 Phase 3: After solving, enters a stratified resolution loop
;; (if not already inside one). Recursive solve-meta! calls from within
;; retries only write the solution — the outer loop handles further rounds.
;; Hash removal: Always reads/writes CHAMP meta-info store.
(define (solve-meta! id solution)
  (solve-meta-core! id solution)
  ;; If already inside a stratified resolution loop, defer retries to the
  ;; outer loop. This eliminates recursive re-entrancy — the call stack is
  ;; always flat regardless of constraint graph depth.
  (unless (current-in-stratified-resolution?)
    (run-stratified-resolution! id)))

;; Core of solve-meta!: write solution to CHAMP + propagator cell.
;; No retry logic — that lives in run-stratified-resolution!.
(define (solve-meta-core! id solution)
  (perf-inc-meta-solved!)
  ;; Track 2 Phase 3: Signal to the stratified loop that progress was made.
  (define progress-box (current-stratified-progress-box))
  (when progress-box
    (set-box! progress-box #t))
  (define mi-box (current-prop-meta-info-box))
  (define info
    (let ([v (champ-lookup (unbox mi-box) (prop-meta-id-hash id) id)])
      (if (eq? v 'none) #f v)))
  (unless info
    (error 'solve-meta! "unknown metavariable: ~a" id))
  (when (eq? (meta-info-status info) 'solved)
    (error 'solve-meta! "metavariable ~a already solved" id))
  ;; Insert updated meta-info into CHAMP (immutable update)
  (define updated (meta-info id (meta-info-ctx info) (meta-info-type info)
                              'solved solution
                              (meta-info-constraints info) (meta-info-source info)))
  (set-box! mi-box (champ-insert (unbox mi-box) (prop-meta-id-hash id) id updated))
  ;; Propagator path: write to cell
  (define net-box (current-prop-net-box))
  (define write-fn (current-prop-cell-write))
  (when (and net-box write-fn)
    (define cid (prop-meta-id->cell-id id))
    (when cid
      (set-box! net-box (write-fn (unbox net-box) cid solution))
      ;; P-U2b: Post-write consistency validation.
      ;; After writing solution to cell, read it back and verify it matches.
      ;; A mismatch would indicate a lattice merge conflict (cell had a prior
      ;; value that doesn't unify with solution). Log as advisory — the
      ;; propagator contradiction check will catch actual errors.
      (define read-fn (current-prop-cell-read))
      (when read-fn
        (define cell-val (read-fn (unbox net-box) cid))
        (when (and cell-val
                   (not (equal? cell-val solution))
                   ;; Don't flag bot/top — those are expected lattice states
                   (not (prop-type-bot? cell-val))
                   (not (prop-type-top? cell-val)))
          (perf-inc-cell-write-mismatch!))))
    ;; Track 6 Phase 1d: mark meta as solved in unsolved-metas tracking cell
    (define um-cid (current-unsolved-metas-cell-id))
    (when um-cid
      (set-box! net-box (write-fn (unbox net-box) um-cid (hasheq id #f))))))

;; Track 2 Phase 3+4: Stratified resolution loop with action descriptors.
;; S0 (type propagation) → S1 (collect ready actions) → S2 (execute) → repeat.
;;
;; Phase 4 change: S1 and S2 are now separate. S1 produces action descriptors
;; (data), S2 executes them. This enables inspectability, testability, and
;; ordering control per the free monad / semi-naive evaluation design.
;;
;; The loop terminates when S1 produces no actions (fixpoint) or fuel exhausted.
;;
;; `trigger-meta-id` is the meta that was just solved, used for targeted
;; wakeup in the test fallback path and trait/hasmethod scans.
(define (run-stratified-resolution! trigger-meta-id)
  (define progress-box (box #f))
  (parameterize ([current-in-stratified-resolution? #t]
                 [current-stratified-progress-box progress-box])
    (define net-box (current-prop-net-box))
    (define has-network?
      (and net-box (current-prop-run-quiescence)
           (current-prop-unwrap-net) (current-prop-rewrap-net)))
    (let loop ([fuel stratified-resolution-fuel]
               [meta-id trigger-meta-id])
      (when (> fuel 0)
        ;; ── Stratum 0: Type propagation (quiescence) ──
        ;; Run the propagator network so type information flows between
        ;; connected meta cells. This can transitively solve metas.
        (when has-network?
          (define run-fn (current-prop-run-quiescence))
          (define unwrap (current-prop-unwrap-net))
          (define rewrap (current-prop-rewrap-net))
          (define enet (unbox net-box))
          (define pnet (unwrap enet))
          (define pnet* (run-fn pnet))
          (set-box! net-box (rewrap enet pnet*)))
        ;; ── Stratum 1: Readiness scan (collect action descriptors) ──
        (define actions
          (append
           ;; Constraint readiness (cell-state scan or targeted wakeup).
           (if has-network?
               (collect-ready-constraints-via-cells)
               (collect-ready-constraints-for-meta meta-id))
           ;; Trait readiness (cell-state scan + targeted wakeup).
           (collect-ready-traits-via-cells)
           (collect-ready-traits-for-meta meta-id)
           ;; HasMethod readiness (cell-state scan + targeted wakeup).
           (collect-ready-hasmethods-via-cells)
           (collect-ready-hasmethods-for-meta meta-id)))
        ;; ── Stratum 2: Resolution commitment (execute actions) ──
        ;; Reset progress box. Any solve-meta-core! calls during S2 set it.
        (set-box! progress-box #f)
        (execute-resolution-actions! actions)
        ;; ── Check for progress ──
        ;; If any new metas were solved during S2, loop for another round.
        (when (unbox progress-box)
          (loop (sub1 fuel) meta-id))))))

;; P-U3c: Lightweight quiescence flush.
;; Runs the propagator network to quiescence if available.
;; No-op when: no network, no quiescence function, or worklist already empty.
;; This is cheaper than solve-meta!'s full flush because it skips constraint
;; retry and trait resolution — those are only needed after meta state changes.
(define (maybe-flush-network!)
  (define net-box (current-prop-net-box))
  (define run-fn (current-prop-run-quiescence))
  (define unwrap (current-prop-unwrap-net))
  (define rewrap (current-prop-rewrap-net))
  (when (and net-box run-fn unwrap rewrap)
    (define enet (unbox net-box))
    (define pnet (unwrap enet))
    (define pnet* (run-fn pnet))
    (set-box! net-box (rewrap enet pnet*))))

;; Check if a metavariable has been solved.
;; Hash removal: Propagator cell (primary), CHAMP meta-info (fallback).
(define (meta-solved? id)
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (cond
    [(and net-box read-fn)
     ;; Propagator path: check cell value
     (define cid (prop-meta-id->cell-id id))
     (and cid
          (let ([v (read-fn (unbox net-box) cid)])
            (and (not (prop-type-bot? v)) (not (prop-type-top? v)))))]
    [else
     ;; CHAMP path (test context without network)
     (define mi-box (current-prop-meta-info-box))
     (if (not mi-box) #f  ;; No meta store initialized — treat as unsolved
         (let ([v (champ-lookup (unbox mi-box) (prop-meta-id-hash id) id)])
           (and (not (eq? v 'none)) (eq? (meta-info-status v) 'solved))))]))

;; Retrieve the solution of a metavariable, or #f if unsolved/unknown.
;; Hash removal: Propagator cell (primary), CHAMP meta-info (fallback).
(define (meta-solution id)
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (cond
    [(and net-box read-fn)
     ;; Propagator path: read cell value
     (define cid (prop-meta-id->cell-id id))
     (and cid
          (let ([v (read-fn (unbox net-box) cid)])
            (and (not (prop-type-bot? v)) (not (prop-type-top? v)) v)))]
    [else
     ;; CHAMP path (test context without network)
     (define mi-box (current-prop-meta-info-box))
     (if (not mi-box) #f  ;; No meta store initialized
         (let ([v (champ-lookup (unbox mi-box) (prop-meta-id-hash id) id)])
           (and (not (eq? v 'none)) (meta-info-solution v))))]))

;; Retrieve the full meta-info struct, or #f if unknown.
;; Hash removal: Always reads from CHAMP meta-info store.
(define (meta-lookup id)
  (define mi-box (current-prop-meta-info-box))
  (if (not mi-box) #f  ;; No meta store initialized
      (let ([v (champ-lookup (unbox mi-box) (prop-meta-id-hash id) id)])
        (if (eq? v 'none) #f v))))

;; ========================================
;; Sprint 6: Universe level metavariables
;; ========================================
;; Simpler than expr-metas: no context, type, or constraints needed.
;; Store maps level-meta id → solution (a ground level) or 'unsolved.

(define current-level-meta-store (make-parameter (make-hasheq)))

;; Create a fresh level metavariable, register in store, return level-meta.
;; Hash removal: Always writes to CHAMP.
;; Track 4 Phase 3: Allocates a TMS cell on the propagator network if available.
(define (fresh-level-meta source)
  (define id (gensym 'lvl))
  (define box (current-level-meta-champ-box))
  (set-box! box (champ-insert (unbox box) (prop-meta-id-hash id) id 'unsolved))
  ;; Track 4 Phase 3: Allocate level cell on propagator network if available
  (define net-box (current-prop-net-box))
  (define fresh-fn (current-prop-fresh-level-cell))
  (when (and net-box fresh-fn)
    (define enet (unbox net-box))
    (define-values (enet* cid) (fresh-fn enet source))
    (set-box! net-box enet*)
    ;; Record mapping: level-meta-id → cell-id in the prop id-map
    (define id-map-read (current-prop-id-map-read))
    (define id-map-set (current-prop-id-map-set))
    (when (and net-box id-map-read id-map-set)
      (set-box! net-box (id-map-set (unbox net-box)
                          (champ-insert (id-map-read (unbox net-box))
                                        (prop-meta-id-hash id) id cid)))))
  (level-meta id))

;; Assign a solution to a level metavariable.
;; Hash removal: Always reads/writes CHAMP.
;; Track 4 Phase 3: Also writes to propagator TMS cell if available.
(define (solve-level-meta! id solution)
  (define box (current-level-meta-champ-box))
  (define status
    (let ([v (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
      (if (eq? v 'none) #f v)))
  (unless status
    (error 'solve-level-meta! "unknown level-meta: ~a" id))
  (when (not (eq? status 'unsolved))
    (error 'solve-level-meta! "level-meta ~a already solved" id))
  (set-box! box (champ-insert (unbox box) (prop-meta-id-hash id) id solution))
  ;; Track 4 Phase 3: Write to propagator level cell
  (define net-box (current-prop-net-box))
  (define write-fn (current-prop-cell-write))
  (when (and net-box write-fn)
    (define id-map-read-fn (current-prop-id-map-read))
    (define cid (and net-box id-map-read-fn
                     (champ-lookup (id-map-read-fn (unbox net-box)) (prop-meta-id-hash id) id)))
    (when (and cid (not (eq? cid 'none)))
      (define enet (unbox net-box))
      (set-box! net-box (write-fn enet cid solution)))))

;; Check if a level metavariable has been solved.
;; Track 4 Phase 3: Reads from TMS cell when network available, CHAMP fallback.
(define (level-meta-solved? id)
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (define id-map-read-fn (current-prop-id-map-read))
  (cond
    [(and net-box read-fn id-map-read-fn)
     (define cid (champ-lookup (id-map-read-fn (unbox net-box)) (prop-meta-id-hash id) id))
     (cond
       [(eq? cid 'none)
        ;; Not in id-map — fallback to CHAMP
        (define box (current-level-meta-champ-box))
        (define v (champ-lookup (unbox box) (prop-meta-id-hash id) id))
        (and (not (eq? v 'none)) (not (eq? v 'unsolved)))]
       [else
        (define v (read-fn (unbox net-box) cid))
        (not (eq? v 'unsolved))])]
    [else
     ;; No network — CHAMP fallback
     (define box (current-level-meta-champ-box))
     (define v
       (let ([r (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
         (if (eq? r 'none) #f r)))
     (and v (not (eq? v 'unsolved)))]))

;; Retrieve the solution of a level metavariable, or #f if unsolved/unknown.
;; Track 4 Phase 3: Reads from TMS cell when network available, CHAMP fallback.
(define (level-meta-solution id)
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (define id-map-read-fn (current-prop-id-map-read))
  (cond
    [(and net-box read-fn id-map-read-fn)
     (define cid (champ-lookup (id-map-read-fn (unbox net-box)) (prop-meta-id-hash id) id))
     (cond
       [(eq? cid 'none)
        ;; Not in id-map — fallback to CHAMP
        (define box (current-level-meta-champ-box))
        (define v (champ-lookup (unbox box) (prop-meta-id-hash id) id))
        (and (not (eq? v 'none)) (not (eq? v 'unsolved)) v)]
       [else
        (define v (read-fn (unbox net-box) cid))
        (and (not (eq? v 'unsolved)) v)])]
    [else
     ;; No network — CHAMP fallback
     (define box (current-level-meta-champ-box))
     (define v
       (let ([r (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
         (if (eq? r 'none) #f r)))
     (and v (not (eq? v 'unsolved)) v)]))

;; Zonk a level: follow solved level-metas, leave unsolved in place.
;; Use zonk-level-default for final output (defaults unsolved to lzero).
(define (zonk-level l)
  (match l
    [(level-meta id)
     (let ([sol (level-meta-solution id)])
       (if sol (zonk-level sol) l))]    ;; leave unsolved in place
    [(lsuc pred) (lsuc (zonk-level pred))]
    [_ l]))

;; Final zonk: defaults unsolved level-metas to lzero (for output/display).
(define (zonk-level-default l)
  (match l
    [(level-meta id)
     (let ([sol (level-meta-solution id)])
       (if sol (zonk-level-default sol) (lzero)))]
    [(lsuc pred) (lsuc (zonk-level-default pred))]
    [_ l]))

;; ========================================
;; Sprint 7: Multiplicity metavariables
;; ========================================
;; Same pattern as level-metas: simple id → solution or 'unsolved store.
;; mult-meta solutions are concrete multiplicities ('m0, 'm1, 'mw).

(define current-mult-meta-store (make-parameter (make-hasheq)))

;; Create a fresh mult metavariable, register in store, return mult-meta.
;; Hash removal: Always writes to CHAMP.
;; P5b: Optionally allocates a mult cell on the propagator network.
(define (fresh-mult-meta source)
  (define id (gensym 'mmeta))
  (define box (current-mult-meta-champ-box))
  (set-box! box (champ-insert (unbox box) (prop-meta-id-hash id) id 'unsolved))
  ;; P5b: Allocate mult cell on propagator network if available
  (define net-box (current-prop-net-box))
  (define fresh-fn (current-prop-fresh-mult-cell))
  (when (and net-box fresh-fn)
    (define enet (unbox net-box))
    (define-values (enet* cid) (fresh-fn enet source))
    (set-box! net-box enet*)
    ;; Record mapping: mult-meta-id → cell-id in the prop id-map
    (define id-map-read (current-prop-id-map-read))
    (define id-map-set (current-prop-id-map-set))
    (when (and net-box id-map-read id-map-set)
      (set-box! net-box (id-map-set (unbox net-box)
                          (champ-insert (id-map-read (unbox net-box))
                                        (prop-meta-id-hash id) id cid)))))
  (mult-meta id))

;; Assign a solution to a mult metavariable.
;; Hash removal: Always reads/writes CHAMP.
;; P5b: Also writes to propagator mult cell if available.
(define (solve-mult-meta! id solution)
  (define box (current-mult-meta-champ-box))
  (define status
    (let ([v (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
      (if (eq? v 'none) #f v)))
  (unless status
    (error 'solve-mult-meta! "unknown mult-meta: ~a" id))
  (when (not (eq? status 'unsolved))
    (error 'solve-mult-meta! "mult-meta ~a already solved" id))
  (set-box! box (champ-insert (unbox box) (prop-meta-id-hash id) id solution))
  ;; P5b: Write to propagator mult cell
  (define net-box (current-prop-net-box))
  (define write-fn (current-prop-mult-cell-write))
  (when (and net-box write-fn)
    (define id-map-read-fn (current-prop-id-map-read))
    (define cid (and net-box id-map-read-fn
                     (champ-lookup (id-map-read-fn (unbox net-box)) (prop-meta-id-hash id) id)))
    (when (and (not (eq? cid 'none)) cid)
      (define enet (unbox net-box))
      (set-box! net-box (write-fn enet cid solution)))))

;; Check if a mult metavariable has been solved.
;; Track 4 Phase 3: Reads from TMS cell when network available, CHAMP fallback.
(define (mult-meta-solved? id)
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (define id-map-read-fn (current-prop-id-map-read))
  (cond
    [(and net-box read-fn id-map-read-fn)
     (define cid (champ-lookup (id-map-read-fn (unbox net-box)) (prop-meta-id-hash id) id))
     (cond
       [(eq? cid 'none)
        (define box (current-mult-meta-champ-box))
        (define v (champ-lookup (unbox box) (prop-meta-id-hash id) id))
        (and (not (eq? v 'none)) (not (eq? v 'unsolved)))]
       [else
        (define v (read-fn (unbox net-box) cid))
        (and (not (eq? v 'mult-bot)) (not (eq? v 'unsolved)))])]
    [else
     (define box (current-mult-meta-champ-box))
     (define v
       (let ([r (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
         (if (eq? r 'none) #f r)))
     (and v (not (eq? v 'unsolved)))]))

;; Retrieve the solution of a mult metavariable, or #f if unsolved/unknown.
;; Track 4 Phase 3: Reads from TMS cell when network available, CHAMP fallback.
(define (mult-meta-solution id)
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (define id-map-read-fn (current-prop-id-map-read))
  (cond
    [(and net-box read-fn id-map-read-fn)
     (define cid (champ-lookup (id-map-read-fn (unbox net-box)) (prop-meta-id-hash id) id))
     (cond
       [(eq? cid 'none)
        (define box (current-mult-meta-champ-box))
        (define v (champ-lookup (unbox box) (prop-meta-id-hash id) id))
        (and (not (eq? v 'none)) (not (eq? v 'unsolved)) v)]
       [else
        (define v (read-fn (unbox net-box) cid))
        (and (not (eq? v 'mult-bot)) (not (eq? v 'unsolved)) v)])]
    [else
     (define box (current-mult-meta-champ-box))
     (define v
       (let ([r (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
         (if (eq? r 'none) #f r)))
     (and v (not (eq? v 'unsolved)) v)]))

;; Zonk a multiplicity: follow solved mult-metas, leave unsolved in place.
;; Use zonk-mult-default for final output (defaults unsolved to 'mw).
(define (zonk-mult m)
  (if (mult-meta? m)
      (let ([sol (mult-meta-solution (mult-meta-id m))])
        (if sol (zonk-mult sol) m))
      m))

;; Final zonk: defaults unsolved mult-metas to 'mw (for output/display).
(define (zonk-mult-default m)
  (if (mult-meta? m)
      (let ([sol (mult-meta-solution (mult-meta-id m))])
        (if sol (zonk-mult-default sol) 'mw))
      m))

;; ========================================
;; Sprint 8: Session metavariables
;; ========================================
;; Same pattern as level-metas/mult-metas: simple id → solution or 'unsolved store.
;; sess-meta solutions are session types (sess-send, sess-recv, sess-end, etc.).

(define current-sess-meta-store (make-parameter (make-hasheq)))

;; Create a fresh sess metavariable, register in store, return sess-meta.
;; Hash removal: Always writes to CHAMP.
;; Track 4 Phase 3: Allocates a TMS cell on the propagator network if available.
(define (fresh-sess-meta source)
  (define id (gensym 'smeta))
  (define box (current-sess-meta-champ-box))
  (set-box! box (champ-insert (unbox box) (prop-meta-id-hash id) id 'unsolved))
  ;; Track 4 Phase 3: Allocate session cell on propagator network if available
  (define net-box (current-prop-net-box))
  (define fresh-fn (current-prop-fresh-sess-cell))
  (when (and net-box fresh-fn)
    (define enet (unbox net-box))
    (define-values (enet* cid) (fresh-fn enet source))
    (set-box! net-box enet*)
    ;; Record mapping: sess-meta-id → cell-id in the prop id-map
    (define id-map-read (current-prop-id-map-read))
    (define id-map-set (current-prop-id-map-set))
    (when (and net-box id-map-read id-map-set)
      (set-box! net-box (id-map-set (unbox net-box)
                          (champ-insert (id-map-read (unbox net-box))
                                        (prop-meta-id-hash id) id cid)))))
  (sess-meta id))

;; Assign a solution to a sess metavariable.
;; Hash removal: Always reads/writes CHAMP.
;; Track 4 Phase 3: Also writes to propagator TMS cell if available.
(define (solve-sess-meta! id solution)
  (define box (current-sess-meta-champ-box))
  (define status
    (let ([v (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
      (if (eq? v 'none) #f v)))
  (unless status
    (error 'solve-sess-meta! "unknown sess-meta: ~a" id))
  (when (not (eq? status 'unsolved))
    (error 'solve-sess-meta! "sess-meta ~a already solved" id))
  (set-box! box (champ-insert (unbox box) (prop-meta-id-hash id) id solution))
  ;; Track 4 Phase 3: Write to propagator session cell
  (define net-box (current-prop-net-box))
  (define write-fn (current-prop-cell-write))
  (when (and net-box write-fn)
    (define id-map-read-fn (current-prop-id-map-read))
    (define cid (and net-box id-map-read-fn
                     (champ-lookup (id-map-read-fn (unbox net-box)) (prop-meta-id-hash id) id)))
    (when (and cid (not (eq? cid 'none)))
      (define enet (unbox net-box))
      (set-box! net-box (write-fn enet cid solution)))))

;; Check if a sess metavariable has been solved.
;; Track 4 Phase 3: Reads from TMS cell when network available, CHAMP fallback.
(define (sess-meta-solved? id)
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (define id-map-read-fn (current-prop-id-map-read))
  (cond
    [(and net-box read-fn id-map-read-fn)
     (define cid (champ-lookup (id-map-read-fn (unbox net-box)) (prop-meta-id-hash id) id))
     (cond
       [(eq? cid 'none)
        (define box (current-sess-meta-champ-box))
        (define v (champ-lookup (unbox box) (prop-meta-id-hash id) id))
        (and (not (eq? v 'none)) (not (eq? v 'unsolved)))]
       [else
        (define v (read-fn (unbox net-box) cid))
        (not (eq? v 'unsolved))])]
    [else
     (define box (current-sess-meta-champ-box))
     (define v
       (let ([r (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
         (if (eq? r 'none) #f r)))
     (and v (not (eq? v 'unsolved)))]))

;; Retrieve the solution of a sess metavariable, or #f if unsolved/unknown.
;; Track 4 Phase 3: Reads from TMS cell when network available, CHAMP fallback.
(define (sess-meta-solution id)
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (define id-map-read-fn (current-prop-id-map-read))
  (cond
    [(and net-box read-fn id-map-read-fn)
     (define cid (champ-lookup (id-map-read-fn (unbox net-box)) (prop-meta-id-hash id) id))
     (cond
       [(eq? cid 'none)
        (define box (current-sess-meta-champ-box))
        (define v (champ-lookup (unbox box) (prop-meta-id-hash id) id))
        (and (not (eq? v 'none)) (not (eq? v 'unsolved)) v)]
       [else
        (define v (read-fn (unbox net-box) cid))
        (and (not (eq? v 'unsolved)) v)])]
    [else
     (define box (current-sess-meta-champ-box))
     (define v
       (let ([r (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
         (if (eq? r 'none) #f r)))
     (and v (not (eq? v 'unsolved)) v)]))

;; Zonk a session: follow solved sess-metas, leave unsolved in place.
;; Use zonk-session-default for final output (defaults unsolved to sess-end).
(define (zonk-session s)
  (cond
    [(sess-meta? s)
     (let ([sol (sess-meta-solution (sess-meta-id s))])
       (if sol (zonk-session sol) s))]
    [(sess-send? s) (sess-send (sess-send-type s) (zonk-session (sess-send-cont s)))]
    [(sess-recv? s) (sess-recv (sess-recv-type s) (zonk-session (sess-recv-cont s)))]
    [(sess-dsend? s) (sess-dsend (sess-dsend-type s) (zonk-session (sess-dsend-cont s)))]
    [(sess-drecv? s) (sess-drecv (sess-drecv-type s) (zonk-session (sess-drecv-cont s)))]
    [(sess-choice? s)
     (sess-choice (map (lambda (b) (cons (car b) (zonk-session (cdr b))))
                       (sess-choice-branches s)))]
    [(sess-offer? s)
     (sess-offer (map (lambda (b) (cons (car b) (zonk-session (cdr b))))
                      (sess-offer-branches s)))]
    [(sess-mu? s) (sess-mu (zonk-session (sess-mu-body s)))]
    [else s]))  ;; sess-end, sess-svar, sess-branch-error

;; Final zonk: defaults unsolved sess-metas to sess-end (for output/display).
(define (zonk-session-default s)
  (cond
    [(sess-meta? s)
     (let ([sol (sess-meta-solution (sess-meta-id s))])
       (if sol (zonk-session-default sol) (sess-end)))]
    [(sess-send? s) (sess-send (sess-send-type s) (zonk-session-default (sess-send-cont s)))]
    [(sess-recv? s) (sess-recv (sess-recv-type s) (zonk-session-default (sess-recv-cont s)))]
    [(sess-dsend? s) (sess-dsend (sess-dsend-type s) (zonk-session-default (sess-dsend-cont s)))]
    [(sess-drecv? s) (sess-drecv (sess-drecv-type s) (zonk-session-default (sess-drecv-cont s)))]
    [(sess-choice? s)
     (sess-choice (map (lambda (b) (cons (car b) (zonk-session-default (cdr b))))
                       (sess-choice-branches s)))]
    [(sess-offer? s)
     (sess-offer (map (lambda (b) (cons (car b) (zonk-session-default (cdr b))))
                      (sess-offer-branches s)))]
    [(sess-mu? s) (sess-mu (zonk-session-default (sess-mu-body s)))]
    [else s]))

;; Clear all metavariables and constraints from the store.
;; Hash removal: Always resets CHAMP boxes (creates if needed).
;; Propagator network only reset when callbacks are available.
(define (reset-meta-store!)
  (hash-clear! (current-meta-store))
  (hash-clear! (current-level-meta-store))
  (hash-clear! (current-mult-meta-store))
  (hash-clear! (current-sess-meta-store))
  ;; Phase 8 cleanup: vestigial hash-clear! calls removed — cells handle reset.
  (reset-constraint-store!)
  ;; Always reset CHAMP meta-info + auxiliary boxes
  (define mi-box (current-prop-meta-info-box))
  (if mi-box
      (begin
        (set-box! mi-box champ-empty)
        (set-box! (current-level-meta-champ-box) champ-empty)
        (set-box! (current-mult-meta-champ-box) champ-empty)
        (set-box! (current-sess-meta-champ-box) champ-empty))
      (begin
        ;; First call — create CHAMP boxes
        (current-prop-meta-info-box (box champ-empty))
        (current-level-meta-champ-box (box champ-empty))
        (current-mult-meta-champ-box (box champ-empty))
        (current-sess-meta-champ-box (box champ-empty))))
  ;; Propagator network: only when callbacks available
  (define make-net (current-prop-make-network))
  (when make-net
    (define net-box (current-prop-net-box))
    (if net-box
        (set-box! net-box (make-net))
        (current-prop-net-box (box (make-net))))
    ;; id-map is now a field of elab-network, initialized to champ-empty
    ;; by make-elaboration-network — no separate box needed.
    ;; Phase 1a: Create constraint store cell in the unified network.
    ;; Track 6 Phase 1c: changed from list-cell (merge-list-append) to registry-cell
    ;; (merge-hasheq-union) keyed by constraint cid. Enables functional status updates.
    (define new-cell-fn (current-prop-new-infra-cell))
    (when new-cell-fn
      (define nb (current-prop-net-box))
      (define enet0 (unbox nb))
      (define-values (enet1 cstore-cid) (new-cell-fn enet0 (hasheq) merge-hasheq-union))
      (current-constraint-cell-id cstore-cid)
      ;; Phase 1b: Create registry cells for trait/hasmethod/capability constraints.
      (define-values (enet2 tc-cid) (new-cell-fn enet1 (hasheq) merge-hasheq-union))
      (current-trait-constraint-cell-id tc-cid)
      (define-values (enet3 tcm-cid) (new-cell-fn enet2 (hasheq) merge-hasheq-union))
      (current-trait-cell-map-cell-id tcm-cid)
      (define-values (enet4 hm-cid) (new-cell-fn enet3 (hasheq) merge-hasheq-union))
      (current-hasmethod-constraint-cell-id hm-cid)
      (define-values (enet5 cap-cid) (new-cell-fn enet4 (hasheq) merge-hasheq-union))
      (current-capability-constraint-cell-id cap-cid)
      ;; Phase 1c: Create wakeup registry cells (merge-hasheq-list-append).
      (define-values (enet6 wr-cid) (new-cell-fn enet5 (hasheq) merge-hasheq-list-append))
      (current-wakeup-registry-cell-id wr-cid)
      (define-values (enet7 tw-cid) (new-cell-fn enet6 (hasheq) merge-hasheq-list-append))
      (current-trait-wakeup-cell-id tw-cid)
      ;; Phase 7a: Hasmethod wakeup cell (was missing — now parallel to trait wakeup).
      (define-values (enet8 hw-cid) (new-cell-fn enet7 (hasheq) merge-hasheq-list-append))
      (current-hasmethod-wakeup-cell-id hw-cid)
      ;; Track 2 Phase 2: Constraint status cell (constraint-id → 'pending | 'resolved).
      (define-values (enet9 cs-cid) (new-cell-fn enet8 (hasheq) merge-constraint-status-map))
      (current-constraint-status-cell-id cs-cid)
      ;; Track 2 Phase 6: HasMethod cell-map (meta-id → (listof cell-id)).
      (define-values (enet10 hcm-cid) (new-cell-fn enet9 (hasheq) merge-hasheq-union))
      (current-hasmethod-cell-map-cell-id hcm-cid)
      ;; Track 2 Phase 7: Error descriptor cell (meta-id → no-instance-error).
      (define-values (enet11 ed-cid) (new-cell-fn enet10 (hasheq) merge-error-descriptor-map))
      (current-error-descriptor-cell-id ed-cid)
      ;; Track 6 Phase 1d: Unsolved metas tracking cell (meta-id → #t/#f).
      (define-values (enet12 um-cid) (new-cell-fn enet11 (hasheq) merge-hasheq-union))
      (current-unsolved-metas-cell-id um-cid)
      (set-box! nb enet12))))

;; ========================================
;; Meta state save/restore for speculative type-checking
;; ========================================
;; Used by check-reduce to save meta state before a speculative Church fold
;; attempt and restore it if the attempt fails, preventing meta contamination
;; when falling back to structural PM.
;;
;; Saves the status and solution of all metas in the current store.
;; Restore resets each meta back to its saved state.

;; Phase 4d: INTERNAL to elab-speculation-bridge.rkt — do not call directly.
;; Use with-speculative-rollback instead.
;;
;; Track 4 Phase 3: Captures 3 CHAMP references (network, id-map, meta-info).
;; Down from 6 — level/mult/session meta state now lives in per-meta TMS cells
;; within the network. Restoring the network restores their cell values.
;; O(1) — reads immutable CHAMP references from boxes.
;; Track 6 Phase 1a: 3→2 box — id-map is now a field of elab-network,
;; automatically captured/restored with the network snapshot.
(define (save-meta-state)
  (define net-box (current-prop-net-box))
  (list 'prop
        (and net-box (unbox net-box))
        (unbox (current-prop-meta-info-box))))

(define (restore-meta-state! saved)
  ;; All O(1) — swap immutable CHAMP references
  (define net-box (current-prop-net-box))
  (when net-box (set-box! net-box (list-ref saved 1)))
  (set-box! (current-prop-meta-info-box) (list-ref saved 2)))

;; List all unsolved metavariable infos.
;; Hash removal: Always reads from CHAMP.
;; Track 6 Phase 1d: Read from unsolved-metas tracking cell when available.
;; Falls back to CHAMP scan when no cell exists (pre-initialization).
(define (all-unsolved-metas)
  (define um-cid (current-unsolved-metas-cell-id))
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (define mi-box (current-prop-meta-info-box))
  (if (and um-cid net-box read-fn)
      ;; Cell path: read the tracking hash, filter for #t (unsolved)
      (let ([um-hash (read-fn (unbox net-box) um-cid)])
        (for/list ([(mid unsolved?) (in-hash um-hash)]
                   #:when unsolved?)
          (let ([v (champ-lookup (unbox mi-box) (prop-meta-id-hash mid) mid)])
            (if (eq? v 'none) #f v))))
      ;; Fallback: CHAMP scan (legacy, pre-initialization)
      (champ-fold (unbox mi-box)
                  (lambda (k v acc)
                    (if (eq? (meta-info-status v) 'unsolved)
                        (cons v acc)
                        acc))
                  '())))

;; ========================================
;; Sprint 9: Noise filtering for error display
;; ========================================

;; Categorize a meta for error display.
;; Returns 'primary | 'secondary | 'internal.
(define (meta-category info)
  (define src (meta-info-source info))
  (cond
    [(meta-source-info? src)
     (case (meta-source-info-kind src)
       [(implicit implicit-app) 'secondary]    ;; implicit elaboration
       [(pi-param lambda-param) 'primary]      ;; user-written binder
       [(bare-Type) 'internal]                  ;; universe level inference
       [else 'primary])]
    [(string? src)
     (cond
       [(member src '("implicit" "implicit-app")) 'secondary]
       [(equal? src "bare-Type") 'internal]
       [else 'primary])]
    [else 'primary]))

;; Filter to only primary unsolved metas for error display.
(define (primary-unsolved-metas)
  (filter (lambda (info) (eq? (meta-category info) 'primary))
          (all-unsolved-metas)))
