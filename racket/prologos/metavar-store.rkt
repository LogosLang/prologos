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
 current-constraint-store
 current-wakeup-registry
 current-retry-unify
 add-constraint!
 collect-meta-ids
 get-wakeup-constraints
 retry-constraints-via-cells!
 reset-constraint-store!
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
 current-trait-constraint-map
 current-trait-wakeup-map
 current-retry-trait-resolve
 register-trait-constraint!
 lookup-trait-constraint
 install-trait-resolve-callback!
 retry-traits-via-cells!
 current-trait-cell-map
 ;; Phase 3a: HasMethod constraint tracking
 (struct-out hasmethod-constraint-info)
 current-hasmethod-constraint-map
 current-hasmethod-wakeup-map
 current-retry-hasmethod-resolve
 register-hasmethod-constraint!
 lookup-hasmethod-constraint
 install-hasmethod-resolve-callback!
 retry-hasmethod-for-meta!
 ;; Phase 4: Capability constraint tracking
 (struct-out capability-constraint-info)
 current-capability-constraint-map
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
 current-constraint-cell-id
 read-constraint-store
 ;; Phase 1b: Trait/HasMethod/Capability constraint cell IDs
 current-trait-constraint-cell-id
 current-trait-cell-map-cell-id
 current-hasmethod-constraint-cell-id
 current-capability-constraint-cell-id
 ;; Phase 1c: Wakeup registry cell IDs
 current-wakeup-registry-cell-id
 current-trait-wakeup-cell-id
 ;; P5b: Multiplicity cell callbacks
 current-prop-fresh-mult-cell
 current-prop-mult-cell-write
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
  #:transparent
  #:mutable)

;; ========================================
;; Sprint 5: Constraint postponement
;; ========================================
;; A constraint is a deferred unification obligation that can't be solved
;; immediately (e.g., when pattern-check fails for an applied metavariable).
;; Constraints are retried when the metavariables they mention get solved.

(struct constraint
  (lhs       ;; Expr — left side of unification
   rhs       ;; Expr — right side of unification
   ctx       ;; Context — typing context at creation
   source    ;; any — debug info (string or constraint-provenance)
   status    ;; 'postponed | 'retrying | 'solved | 'failed
   cell-ids) ;; (listof cell-id) — propagator cells for metas in lhs/rhs (P1-E3a)
  #:transparent
  #:mutable)

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

;; Auxiliary map: meta-id → trait-constraint-info
;; Keyed by meta-id (symbol), cleared by reset-meta-store!.
;; Separate from meta-info to avoid extending that struct (which would
;; require touching every fresh-meta call site).
(define current-trait-constraint-map (make-parameter (make-hasheq)))

;; Phase C: Reverse index for incremental trait resolution.
;; Maps type-arg-meta-id → (listof dict-meta-id). When a type-arg meta is
;; solved, we can immediately check if any trait constraints become resolvable.
(define current-trait-wakeup-map (make-parameter (make-hasheq)))

;; Phase C: Callback for incremental trait resolution.
;; Signature: (dict-meta-id trait-constraint-info) → void
;; Injected from driver.rkt to break circular dependency.
(define current-retry-trait-resolve (make-parameter #f))

;; Phase C: Install the trait resolve callback.
(define (install-trait-resolve-callback! resolve-fn)
  (current-retry-trait-resolve resolve-fn))

;; P3a: Trait constraint → cell-ids mapping for cell-state-driven resolution.
;; Maps dict-meta-id → (listof cell-id) for type-arg metas.
(define current-trait-cell-map (make-parameter (make-hasheq)))

;; Register a trait constraint and build wakeup index for incremental resolution.
(define (register-trait-constraint! meta-id info)
  (hash-set! (current-trait-constraint-map) meta-id info)
  ;; Phase 1b: Dual-write to trait constraint cell.
  (define tc-cid (current-trait-constraint-cell-id))
  (define tc-net-box (current-prop-net-box))
  (define write-fn (current-prop-cell-write))
  (when (and tc-cid tc-net-box write-fn)
    (set-box! tc-net-box (write-fn (unbox tc-net-box) tc-cid (hasheq meta-id info))))
  ;; Phase C: Build reverse index from type-arg metas → this dict meta
  (define type-arg-metas (extract-shallow-meta-ids-from-list
                           (trait-constraint-info-type-arg-exprs info)))
  ;; Phase 1e: Filter to only unsolved metas for wakeup — solved metas won't trigger
  ;; future solve-meta! calls. If all type-args are already solved, immediate resolution
  ;; fires below (same pattern as hasmethod wakeup).
  (define unsolved-ta-metas (filter (lambda (id) (not (meta-solved? id))) type-arg-metas))
  (define wakeup (current-trait-wakeup-map))
  (for ([ta-id (in-list unsolved-ta-metas)])
    (define existing (hash-ref wakeup ta-id '()))
    (hash-set! wakeup ta-id (cons meta-id existing)))
  ;; Phase 1c: Dual-write trait wakeup map to cell.
  (define tw-cid (current-trait-wakeup-cell-id))
  (when (and tw-cid tc-net-box write-fn (pair? unsolved-ta-metas))
    (define tw-delta
      (for/fold ([acc (hasheq)]) ([ta-id (in-list unsolved-ta-metas)])
        (hash-set acc ta-id (list meta-id))))
    (set-box! tc-net-box (write-fn (unbox tc-net-box) tw-cid tw-delta)))
  ;; P3a: Record cell-ids for type-arg metas for cell-state-driven resolution.
  (define id-map-box (current-prop-id-map-box))
  (when id-map-box
    (define id-map (unbox id-map-box))
    (define cell-ids
      (for*/list ([ta-id (in-list type-arg-metas)]
                  [cid (in-value (champ-lookup id-map (prop-meta-id-hash ta-id) ta-id))]
                  #:when (not (eq? cid 'none)))
        cid))
    (when (not (null? cell-ids))
      (hash-set! (current-trait-cell-map) meta-id
                 (remove-duplicates cell-ids eq?))
      ;; Phase 1b: Dual-write trait-cell-map.
      (define tcm-cid (current-trait-cell-map-cell-id))
      (when (and tcm-cid tc-net-box write-fn)
        (set-box! tc-net-box
                  (write-fn (unbox tc-net-box) tcm-cid
                            (hasheq meta-id (remove-duplicates cell-ids eq?)))))))
  ;; Phase 3d: If all type-args are already ground (no unsolved metas to trigger wakeup),
  ;; attempt immediate resolution via the callback.
  (when (null? unsolved-ta-metas)
    (define resolve-fn (current-retry-trait-resolve))
    (when resolve-fn
      (resolve-fn meta-id info))))

(define (lookup-trait-constraint meta-id)
  (hash-ref (current-trait-constraint-map) meta-id #f))

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

;; Auxiliary map: meta-id → hasmethod-constraint-info
(define current-hasmethod-constraint-map (make-parameter (make-hasheq)))

;; Phase 1d: Hasmethod wakeup map — reverse index from dependency meta → hasmethod meta-id.
;; Maps meta-id (of type-arg or trait-var) → (listof hasmethod-meta-id).
(define current-hasmethod-wakeup-map (make-parameter (make-hasheq)))

;; Phase 1d: Callback for incremental hasmethod resolution.
;; Signature: (hasmethod-meta-id hasmethod-constraint-info) → void
;; Injected from driver.rkt to break circular dependency (same pattern as trait resolve).
(define current-retry-hasmethod-resolve (make-parameter #f))

;; Phase 1d: Install the hasmethod resolve callback.
(define (install-hasmethod-resolve-callback! resolve-fn)
  (current-retry-hasmethod-resolve resolve-fn))

(define (register-hasmethod-constraint! meta-id info)
  (hash-set! (current-hasmethod-constraint-map) meta-id info)
  ;; Phase 1b: Dual-write to hasmethod constraint cell.
  (define hm-cid (current-hasmethod-constraint-cell-id))
  (define hm-net-box (current-prop-net-box))
  (define write-fn (current-prop-cell-write))
  (when (and hm-cid hm-net-box write-fn)
    (set-box! hm-net-box (write-fn (unbox hm-net-box) hm-cid (hasheq meta-id info))))
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
  (define wakeup (current-hasmethod-wakeup-map))
  (for ([dep-id (in-list unsolved-dep-metas)])
    (define existing (hash-ref wakeup dep-id '()))
    (hash-set! wakeup dep-id (cons meta-id existing)))
  ;; Phase 1d: If all deps are already ground (no unsolved metas to trigger wakeup),
  ;; attempt immediate resolution via the callback.
  (when (null? unsolved-dep-metas)
    (define resolve-fn (current-retry-hasmethod-resolve))
    (when resolve-fn
      (resolve-fn meta-id info))))

(define (lookup-hasmethod-constraint meta-id)
  (hash-ref (current-hasmethod-constraint-map) meta-id #f))

;; Phase 1d: Try to resolve hasmethod constraints that reference a just-solved meta.
;; Called from solve-meta! when a dependency meta is solved. Checks the wakeup
;; map for any hasmethod constraints referencing this meta, and if all their
;; dependencies are now ground, triggers resolution via the callback.
(define (retry-hasmethod-for-meta! meta-id)
  (define resolve-fn (current-retry-hasmethod-resolve))
  (when resolve-fn
    (define wakeup (current-hasmethod-wakeup-map))
    (define hm-metas (hash-ref wakeup meta-id '()))
    (for ([hm-id (in-list hm-metas)])
      (unless (meta-solved? hm-id)
        (define hm-info (hash-ref (current-hasmethod-constraint-map) hm-id #f))
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

;; Auxiliary map: meta-id → capability-constraint-info
(define current-capability-constraint-map (make-parameter (make-hasheq)))

(define (register-capability-constraint! meta-id info)
  (hash-set! (current-capability-constraint-map) meta-id info)
  ;; Phase 1b: Dual-write to capability constraint cell.
  (define cap-cid (current-capability-constraint-cell-id))
  (define cap-net-box (current-prop-net-box))
  (define write-fn (current-prop-cell-write))
  (when (and cap-cid cap-net-box write-fn)
    (set-box! cap-net-box (write-fn (unbox cap-net-box) cap-cid (hasheq meta-id info)))))

(define (lookup-capability-constraint meta-id)
  (hash-ref (current-capability-constraint-map) meta-id #f))


;; Global constraint store: list of all constraints
(define current-constraint-store (make-parameter '()))

;; Per-meta wakeup registry: maps meta-id -> (listof constraint)
(define current-wakeup-registry (make-parameter (make-hasheq)))

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
    (define wakeup (current-trait-wakeup-map))
    (define dict-metas (hash-ref wakeup meta-id '()))
    (for ([dict-id (in-list dict-metas)])
      (unless (meta-solved? dict-id)
        (define tc-info (hash-ref (current-trait-constraint-map) dict-id #f))
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
    (define tcm (current-trait-cell-map))
    (for ([(dict-id cell-ids) (in-hash tcm)])
      (unless (meta-solved? dict-id)
        (define tc-info (hash-ref (current-trait-constraint-map) dict-id #f))
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
  (define c (constraint lhs rhs ctx source 'postponed '()))
  ;; Add to global store (legacy parameter path)
  (current-constraint-store (cons c (current-constraint-store)))
  ;; Phase 1a: Also write to constraint cell if available.
  ;; merge-list-append appends (list c) to the existing cell contents.
  (define cstore-cid (current-constraint-cell-id))
  (define cstore-net-box (current-prop-net-box))
  (define write-fn (current-prop-cell-write))
  (when (and cstore-cid cstore-net-box write-fn)
    (define enet (unbox cstore-net-box))
    (set-box! cstore-net-box (write-fn enet cstore-cid (list c))))
  ;; Register for wakeup on all mentioned metas
  (define meta-ids (append (collect-meta-ids lhs) (collect-meta-ids rhs)))
  (define registry (current-wakeup-registry))
  (for ([id (in-list meta-ids)])
    (define existing (hash-ref registry id '()))
    (hash-set! registry id (cons c existing)))
  ;; Phase 1c: Dual-write wakeup registry to cell.
  (define wr-cid (current-wakeup-registry-cell-id))
  (when (and wr-cid cstore-net-box write-fn (pair? meta-ids))
    (define wr-delta
      (for/fold ([acc (hasheq)]) ([id (in-list meta-ids)])
        (hash-set acc id (list c))))
    (set-box! cstore-net-box (write-fn (unbox cstore-net-box) wr-cid wr-delta)))
  ;; Propagator path: add unify constraints between cells
  (define net-box (current-prop-net-box))
  (define add-unify-fn (current-prop-add-unify-constraint))
  (when (and net-box add-unify-fn)
    (define enet (unbox net-box))
    (define id-map (unbox (current-prop-id-map-box)))
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
    ;; P1-E3a: Record cell-ids for all metas in constraint for cell-state retry.
    ;; Uses full collect-meta-ids (not just shallow) to capture nested metas.
    (define all-cell-ids
      (for*/list ([mid (in-list meta-ids)]
                  [cid (in-value (champ-lookup id-map (prop-meta-id-hash mid) mid))]
                  #:when (not (eq? cid 'none)))
        cid))
    (set-constraint-cell-ids! c (remove-duplicates all-cell-ids eq?)))
  c)

;; Get constraints associated with a metavariable for wakeup.
(define (get-wakeup-constraints meta-id)
  (hash-ref (current-wakeup-registry) meta-id '()))

;; Retry postponed constraints that mention the given meta.
;; Uses 'retrying guard to prevent infinite re-entrant loops.
(define (retry-constraints-for-meta! meta-id)
  (perf-inc-constraint-retry!)
  (define retry-fn (current-retry-unify))
  (when retry-fn
    (define constraints (get-wakeup-constraints meta-id))
    (for ([c (in-list constraints)])
      (when (eq? (constraint-status c) 'postponed)
        ;; Guard against re-entrant retry
        (set-constraint-status! c 'retrying)
        (retry-fn c)
        ;; If still 'retrying after the call, set back to 'postponed
        (when (eq? (constraint-status c) 'retrying)
          (set-constraint-status! c 'postponed))))))

;; P1-E3a: Retry postponed constraints using propagator cell state.
;; After run-to-quiescence, checks ALL postponed constraints that have cell-ids.
;; A constraint is retried if any of its meta cells has become non-bot
;; (i.e., some meta was solved, possibly via transitive propagation).
;; This captures transitive wakeups that the legacy wakeup registry misses.
(define (retry-constraints-via-cells!)
  (define retry-fn (current-retry-unify))
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (when (and retry-fn net-box read-fn)
    (define enet (unbox net-box))
    (for ([c (in-list (current-constraint-store))])
      (when (and (eq? (constraint-status c) 'postponed)
                 (not (null? (constraint-cell-ids c))))
        ;; Check if any meta cell has become non-bot (meta solved)
        (define any-solved?
          (for/or ([cid (in-list (constraint-cell-ids c))])
            (let ([v (read-fn enet cid)])
              (and (not (prop-type-bot? v)) (not (prop-type-top? v))))))
        (when any-solved?
          ;; Guard against re-entrant retry (same as legacy path)
          (set-constraint-status! c 'retrying)
          (retry-fn c)
          (when (eq? (constraint-status c) 'retrying)
            (set-constraint-status! c 'postponed)))))))

;; Phase 1a: Read the constraint store from the cell (preferred) or legacy parameter.
;; Returns the current list of all constraints.
;; NOTE: Phase 1a is "storage only" — constraint cell is write-only for now.
;; All reads go through legacy parameter until save/restore is updated (Phase 1d+).
;; This function is exported for future use and tests.
(define (read-constraint-store)
  (define cid (current-constraint-cell-id))
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (if (and cid net-box read-fn)
      (read-fn (unbox net-box) cid)
      (current-constraint-store)))

;; Reset the constraint store (called by reset-meta-store!).
;; Phase 1a: constraint cell is inherently reset when the network is recreated.
;; Only need to clear the legacy parameter and wakeup registry.
(define (reset-constraint-store!)
  (current-constraint-store '())
  (current-constraint-cell-id #f)
  ;; Phase 1b: Clear cell IDs (new cells are created per-command by reset-meta-store!).
  (current-trait-constraint-cell-id #f)
  (current-trait-cell-map-cell-id #f)
  (current-hasmethod-constraint-cell-id #f)
  (current-capability-constraint-cell-id #f)
  ;; Phase 1c: Clear wakeup cell IDs.
  (current-wakeup-registry-cell-id #f)
  (current-trait-wakeup-cell-id #f)
  (hash-clear! (current-wakeup-registry))
  ;; Phase 1d: Clear hasmethod wakeup map.
  (hash-clear! (current-hasmethod-wakeup-map)))

;; Query: all postponed constraints.
;; Phase 1a: still reads from legacy parameter (not cell) for save/restore compatibility.
(define (all-postponed-constraints)
  (filter (lambda (c) (eq? (constraint-status c) 'postponed))
          (current-constraint-store)))

;; Query: all failed constraints.
;; Phase 1a: still reads from legacy parameter (not cell) for save/restore compatibility.
(define (all-failed-constraints)
  (filter (lambda (c) (eq? (constraint-status c) 'failed))
          (current-constraint-store)))

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
;; Box of CHAMP: meta-id (gensym) → cell-id | #f
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

;; P5b: Multiplicity cell callbacks
(define current-prop-fresh-mult-cell (make-parameter #f))   ;; (enet source → (values enet* cell-id))
(define current-prop-mult-cell-write (make-parameter #f))   ;; (enet cell-id value → enet*)

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
(define (prop-meta-id->cell-id id)
  (define box (current-prop-id-map-box))
  (and box
       (let ([v (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
         (if (eq? v 'none) #f v))))

;; ========================================
;; Hash removal: Test isolation macro
;; ========================================
;; Provides a fresh, isolated meta environment for unit tests.
;; Sets up all CHAMP boxes (meta-info, level, mult, sess) plus hash stores
;; and constraint infrastructure. No propagator network (that's driver's job).
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
                 [current-constraint-store '()]
                 [current-definition-cells-content (hasheq)]  ;; Phase 3a
                 [current-definition-dependencies (hasheq)]  ;; Phase 3b
                 [current-constraint-cell-id #f]  ;; Phase 1a
                 [current-trait-constraint-cell-id #f]  ;; Phase 1b
                 [current-trait-cell-map-cell-id #f]    ;; Phase 1b
                 [current-hasmethod-constraint-cell-id #f]  ;; Phase 1b
                 [current-capability-constraint-cell-id #f]  ;; Phase 1b
                 [current-wakeup-registry-cell-id #f]  ;; Phase 1c
                 [current-trait-wakeup-cell-id #f]     ;; Phase 1c
                 [current-wakeup-registry (make-hasheq)]
                 [current-trait-constraint-map (make-hasheq)]
                 [current-trait-wakeup-map (make-hasheq)]
                 [current-trait-cell-map (make-hasheq)]
                 [current-hasmethod-constraint-map (make-hasheq)]
                 [current-hasmethod-wakeup-map (make-hasheq)]  ;; Phase 1d
                 [current-prop-meta-info-box (box champ-empty)]
                 [current-prop-net-box #f]
                 [current-prop-id-map-box #f]
                 [current-level-meta-champ-box (box champ-empty)]
                 [current-mult-meta-champ-box (box champ-empty)]
                 [current-sess-meta-champ-box (box champ-empty)])
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
    (define id-box (current-prop-id-map-box))
    (set-box! id-box (champ-insert (unbox id-box) (prop-meta-id-hash id) id cid))
    (set-box! net-box enet*))
  (expr-meta id))

;; Assign a solution to a metavariable. Errors if already solved.
;; After solving, retries any postponed constraints that mention this meta.
;; Hash removal: Always reads/writes CHAMP meta-info store.
(define (solve-meta! id solution)
  (perf-inc-meta-solved!)
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
          (perf-inc-cell-write-mismatch!)))))
  ;; Constraint retry: three-layer approach.
  ;;
  ;; Layer 1 (network quiescence): Run the propagator network so type information
  ;; flows between connected meta cells. This can transitively solve metas.
  ;;
  ;; Layer 2 (cell-state full scan): After quiescence, retry-constraints-via-cells!
  ;; scans ALL postponed constraints and retries those whose meta cells changed.
  ;; This catches transitive propagation that targeted wakeup (layer 3) misses.
  ;;
  ;; Layer 3 (targeted wakeup): retry-constraints-for-meta! retries only constraints
  ;; mentioning this specific meta. Fast but misses transitive propagation.
  ;;
  ;; Production uses layers 1+2; test fallback uses layer 3 only.
  (cond
    [(and net-box (current-prop-run-quiescence)
          (current-prop-unwrap-net) (current-prop-rewrap-net))
     ;; Production path: quiescence + cell-state scan.
     (define run-fn (current-prop-run-quiescence))
     (define unwrap (current-prop-unwrap-net))
     (define rewrap (current-prop-rewrap-net))
     (define enet (unbox net-box))
     (define pnet (unwrap enet))
     (define pnet* (run-fn pnet))
     (set-box! net-box (rewrap enet pnet*))
     (retry-constraints-via-cells!)]
    [else
     ;; Fallback for test contexts without propagator network
     (retry-constraints-for-meta! id)])
  ;; Trait resolution: cell-state scan + targeted wakeup (both run for safety).
  ;; The full scan catches transitive propagation via the network.
  (retry-traits-via-cells!)
  ;; Targeted wakeup: fast path for direct dependencies.
  (retry-trait-for-meta! id)
  ;; Phase 1d: HasMethod resolution — reactive wakeup when dependency metas solved.
  (retry-hasmethod-for-meta! id))

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
(define (fresh-level-meta source)
  (define id (gensym 'lvl))
  (define box (current-level-meta-champ-box))
  (set-box! box (champ-insert (unbox box) (prop-meta-id-hash id) id 'unsolved))
  (level-meta id))

;; Assign a solution to a level metavariable.
;; Hash removal: Always reads/writes CHAMP.
(define (solve-level-meta! id solution)
  (define box (current-level-meta-champ-box))
  (define status
    (let ([v (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
      (if (eq? v 'none) #f v)))
  (unless status
    (error 'solve-level-meta! "unknown level-meta: ~a" id))
  (when (not (eq? status 'unsolved))
    (error 'solve-level-meta! "level-meta ~a already solved" id))
  (set-box! box (champ-insert (unbox box) (prop-meta-id-hash id) id solution)))

;; Check if a level metavariable has been solved.
;; Hash removal: Always reads from CHAMP.
(define (level-meta-solved? id)
  (define box (current-level-meta-champ-box))
  (define v
    (let ([r (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
      (if (eq? r 'none) #f r)))
  (and v (not (eq? v 'unsolved))))

;; Retrieve the solution of a level metavariable, or #f if unsolved/unknown.
;; Hash removal: Always reads from CHAMP.
(define (level-meta-solution id)
  (define box (current-level-meta-champ-box))
  (define v
    (let ([r (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
      (if (eq? r 'none) #f r)))
  (and v (not (eq? v 'unsolved)) v))

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
    (define id-map-box (current-prop-id-map-box))
    (when id-map-box
      (set-box! id-map-box
        (champ-insert (unbox id-map-box) (prop-meta-id-hash id) id cid))))
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
    (define id-map-box (current-prop-id-map-box))
    (define cid (and id-map-box
                     (champ-lookup (unbox id-map-box) (prop-meta-id-hash id) id)))
    (when (and (not (eq? cid 'none)) cid)
      (define enet (unbox net-box))
      (set-box! net-box (write-fn enet cid solution)))))

;; Check if a mult metavariable has been solved.
;; Hash removal: Always reads from CHAMP.
(define (mult-meta-solved? id)
  (define box (current-mult-meta-champ-box))
  (define v
    (let ([r (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
      (if (eq? r 'none) #f r)))
  (and v (not (eq? v 'unsolved))))

;; Retrieve the solution of a mult metavariable, or #f if unsolved/unknown.
;; Hash removal: Always reads from CHAMP.
(define (mult-meta-solution id)
  (define box (current-mult-meta-champ-box))
  (define v
    (let ([r (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
      (if (eq? r 'none) #f r)))
  (and v (not (eq? v 'unsolved)) v))

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
(define (fresh-sess-meta source)
  (define id (gensym 'smeta))
  (define box (current-sess-meta-champ-box))
  (set-box! box (champ-insert (unbox box) (prop-meta-id-hash id) id 'unsolved))
  (sess-meta id))

;; Assign a solution to a sess metavariable.
;; Hash removal: Always reads/writes CHAMP.
(define (solve-sess-meta! id solution)
  (define box (current-sess-meta-champ-box))
  (define status
    (let ([v (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
      (if (eq? v 'none) #f v)))
  (unless status
    (error 'solve-sess-meta! "unknown sess-meta: ~a" id))
  (when (not (eq? status 'unsolved))
    (error 'solve-sess-meta! "sess-meta ~a already solved" id))
  (set-box! box (champ-insert (unbox box) (prop-meta-id-hash id) id solution)))

;; Check if a sess metavariable has been solved.
;; Hash removal: Always reads from CHAMP.
(define (sess-meta-solved? id)
  (define box (current-sess-meta-champ-box))
  (define v
    (let ([r (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
      (if (eq? r 'none) #f r)))
  (and v (not (eq? v 'unsolved))))

;; Retrieve the solution of a sess metavariable, or #f if unsolved/unknown.
;; Hash removal: Always reads from CHAMP.
(define (sess-meta-solution id)
  (define box (current-sess-meta-champ-box))
  (define v
    (let ([r (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
      (if (eq? r 'none) #f r)))
  (and v (not (eq? v 'unsolved)) v))

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
  (hash-clear! (current-trait-constraint-map))
  (hash-clear! (current-trait-wakeup-map))
  (hash-clear! (current-trait-cell-map))
  (hash-clear! (current-hasmethod-constraint-map))
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
        (begin
          (set-box! net-box (make-net))
          (set-box! (current-prop-id-map-box) champ-empty))
        (begin
          (current-prop-net-box (box (make-net)))
          (current-prop-id-map-box (box champ-empty))))
    ;; Phase 1a: Create constraint store cell in the unified network.
    ;; merge-list-append ensures constraints accumulate monotonically.
    (define new-cell-fn (current-prop-new-infra-cell))
    (when new-cell-fn
      (define nb (current-prop-net-box))
      (define enet0 (unbox nb))
      (define-values (enet1 cstore-cid) (new-cell-fn enet0 '() merge-list-append))
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
      (set-box! nb enet7))))

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
;; Captures all six CHAMP references (network, id-map, meta-info, level, mult, sess).
;; O(1) — reads immutable CHAMP references from boxes.
;; NOTE: Does NOT capture current-constraint-store (Racket parameter).
;; The bridge handles constraint store save/restore separately (Phase 4b).
;; When no network is available (test context), net/id-map are #f — still captured.
(define (save-meta-state)
  (define net-box (current-prop-net-box))
  (define id-box (current-prop-id-map-box))
  (list 'prop
        (and net-box (unbox net-box))
        (and id-box (unbox id-box))
        (unbox (current-prop-meta-info-box))
        (unbox (current-level-meta-champ-box))
        (unbox (current-mult-meta-champ-box))
        (unbox (current-sess-meta-champ-box))))

(define (restore-meta-state! saved)
  ;; All O(1) — swap immutable CHAMP references
  (define net-box (current-prop-net-box))
  (define id-box (current-prop-id-map-box))
  (when net-box (set-box! net-box (list-ref saved 1)))
  (when id-box (set-box! id-box (list-ref saved 2)))
  (set-box! (current-prop-meta-info-box) (list-ref saved 3))
  (set-box! (current-level-meta-champ-box) (list-ref saved 4))
  (set-box! (current-mult-meta-champ-box) (list-ref saved 5))
  (set-box! (current-sess-meta-champ-box) (list-ref saved 6)))

;; List all unsolved metavariable infos.
;; Hash removal: Always reads from CHAMP.
(define (all-unsolved-metas)
  (define mi-box (current-prop-meta-info-box))
  (champ-fold (unbox mi-box)
              (lambda (k v acc)
                (if (eq? (meta-info-status v) 'unsolved)
                    (cons v acc)
                    acc))
              '()))

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
