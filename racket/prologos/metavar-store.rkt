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
         "syntax.rkt"
         "prelude.rkt"
         "sessions.rkt"
         "source-location.rkt"
         "performance-counters.rkt"
         "champ.rkt")
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
 ;; Meta state save/restore (for speculative type-checking)
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
 install-prop-network-callbacks!)

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
   status)   ;; 'postponed | 'retrying | 'solved | 'failed
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

;; Register a trait constraint and build wakeup index for incremental resolution.
(define (register-trait-constraint! meta-id info)
  (hash-set! (current-trait-constraint-map) meta-id info)
  ;; Phase C: Build reverse index from type-arg metas → this dict meta
  (define type-arg-metas (extract-shallow-meta-ids-from-list
                           (trait-constraint-info-type-arg-exprs info)))
  (define wakeup (current-trait-wakeup-map))
  (for ([ta-id (in-list type-arg-metas)])
    (define existing (hash-ref wakeup ta-id '()))
    (hash-set! wakeup ta-id (cons meta-id existing))))

(define (lookup-trait-constraint meta-id)
  (hash-ref (current-trait-constraint-map) meta-id #f))


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

;; Create a postponed constraint, add to global store, register for wakeup.
;; Phase 8b: Also adds unify propagators on the network between cells
;; referenced by metas in lhs/rhs.
(define (add-constraint! lhs rhs ctx source)
  (perf-inc-constraint!)
  (define c (constraint lhs rhs ctx source 'postponed))
  ;; Add to global store
  (current-constraint-store (cons c (current-constraint-store)))
  ;; Register for wakeup on all mentioned metas
  (define meta-ids (append (collect-meta-ids lhs) (collect-meta-ids rhs)))
  (define registry (current-wakeup-registry))
  (for ([id (in-list meta-ids)])
    (define existing (hash-ref registry id '()))
    (hash-set! registry id (cons c existing)))
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
    (set-box! net-box enet*))
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

;; Reset the constraint store (called by reset-meta-store!).
(define (reset-constraint-store!)
  (current-constraint-store '())
  (hash-clear! (current-wakeup-registry)))

;; Query: all postponed constraints.
(define (all-postponed-constraints)
  (filter (lambda (c) (eq? (constraint-status c) 'postponed))
          (current-constraint-store)))

;; Query: all failed constraints.
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
;; API
;; ========================================

;; Create a fresh metavariable, register it in the store, return expr-meta.
;; Phase A: Writes to CHAMP meta-info store (primary) and propagator network.
;; Falls back to hash-only when CHAMP not initialized (test compatibility).
(define (fresh-meta ctx type source)
  (perf-inc-meta-created!)
  (define id (gensym 'meta))
  (define info (meta-info id ctx type 'unsolved #f '() source))
  (define mi-box (current-prop-meta-info-box))
  (cond
    [mi-box
     ;; Production path: write to CHAMP meta-info store
     (set-box! mi-box (champ-insert (unbox mi-box) (prop-meta-id-hash id) id info))
     ;; Allocate cell on propagator network
     (define net-box (current-prop-net-box))
     (define fresh-fn (current-prop-fresh-meta))
     (when (and net-box fresh-fn)
       (define enet (unbox net-box))
       (define-values (enet* cid) (fresh-fn enet ctx type source))
       (define id-box (current-prop-id-map-box))
       (set-box! id-box (champ-insert (unbox id-box) (prop-meta-id-hash id) id cid))
       (set-box! net-box enet*))]
    [else
     ;; Legacy path: write to hash (test compatibility)
     (hash-set! (current-meta-store) id info)])
  (expr-meta id))

;; Assign a solution to a metavariable. Errors if already solved.
;; After solving, retries any postponed constraints that mention this meta.
;; Phase A: Reads/writes CHAMP meta-info store (primary), propagator cell.
(define (solve-meta! id solution)
  (perf-inc-meta-solved!)
  (define mi-box (current-prop-meta-info-box))
  (define info
    (if mi-box
        ;; Production path: read from CHAMP
        (let ([v (champ-lookup (unbox mi-box) (prop-meta-id-hash id) id)])
          (if (eq? v 'none) #f v))
        ;; Legacy path: read from hash
        (hash-ref (current-meta-store) id #f)))
  (unless info
    (error 'solve-meta! "unknown metavariable: ~a" id))
  (when (eq? (meta-info-status info) 'solved)
    (error 'solve-meta! "metavariable ~a already solved" id))
  (cond
    [mi-box
     ;; Production path: insert updated meta-info into CHAMP (immutable update)
     (define updated (meta-info id (meta-info-ctx info) (meta-info-type info)
                                'solved solution
                                (meta-info-constraints info) (meta-info-source info)))
     (set-box! mi-box (champ-insert (unbox mi-box) (prop-meta-id-hash id) id updated))]
    [else
     ;; Legacy path: mutate hash entry
     (set-meta-info-status! info 'solved)
     (set-meta-info-solution! info solution)])
  ;; Propagator path: write to cell
  (define net-box (current-prop-net-box))
  (define write-fn (current-prop-cell-write))
  (when (and net-box write-fn)
    (define cid (prop-meta-id->cell-id id))
    (when cid
      (set-box! net-box (write-fn (unbox net-box) cid solution))))
  ;; Sprint 5: retry postponed constraints that mention this meta
  (retry-constraints-for-meta! id)
  ;; Phase C: try incremental trait resolution for trait constraints
  ;; referencing this meta as a type-arg
  (retry-trait-for-meta! id))

;; Check if a metavariable has been solved.
;; Phase 8b: Reads from propagator network when available (primary).
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
     ;; Legacy path: read from hash
     (define info (hash-ref (current-meta-store) id #f))
     (and info (eq? (meta-info-status info) 'solved))]))

;; Retrieve the solution of a metavariable, or #f if unsolved/unknown.
;; Phase 8b: Reads from propagator network when available (primary).
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
     ;; Legacy path: read from hash
     (define info (hash-ref (current-meta-store) id #f))
     (and info (meta-info-solution info))]))

;; Retrieve the full meta-info struct, or #f if unknown.
;; Phase A: Reads from CHAMP meta-info store (primary), falls back to hash.
(define (meta-lookup id)
  (define mi-box (current-prop-meta-info-box))
  (if mi-box
      (let ([v (champ-lookup (unbox mi-box) (prop-meta-id-hash id) id)])
        (if (eq? v 'none) #f v))
      (hash-ref (current-meta-store) id #f)))

;; ========================================
;; Sprint 6: Universe level metavariables
;; ========================================
;; Simpler than expr-metas: no context, type, or constraints needed.
;; Store maps level-meta id → solution (a ground level) or 'unsolved.

(define current-level-meta-store (make-parameter (make-hasheq)))

;; Create a fresh level metavariable, register in store, return level-meta.
;; Phase B: CHAMP primary, hash fallback.
(define (fresh-level-meta source)
  (define id (gensym 'lvl))
  (define box (current-level-meta-champ-box))
  (if box
      (set-box! box (champ-insert (unbox box) (prop-meta-id-hash id) id 'unsolved))
      (hash-set! (current-level-meta-store) id 'unsolved))
  (level-meta id))

;; Assign a solution to a level metavariable.
;; Phase B: CHAMP primary, hash fallback.
(define (solve-level-meta! id solution)
  (define box (current-level-meta-champ-box))
  (define status
    (if box
        (let ([v (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
          (if (eq? v 'none) #f v))
        (hash-ref (current-level-meta-store) id #f)))
  (unless status
    (error 'solve-level-meta! "unknown level-meta: ~a" id))
  (when (not (eq? status 'unsolved))
    (error 'solve-level-meta! "level-meta ~a already solved" id))
  (if box
      (set-box! box (champ-insert (unbox box) (prop-meta-id-hash id) id solution))
      (hash-set! (current-level-meta-store) id solution)))

;; Check if a level metavariable has been solved.
;; Phase B: CHAMP primary, hash fallback.
(define (level-meta-solved? id)
  (define box (current-level-meta-champ-box))
  (define v
    (if box
        (let ([r (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
          (if (eq? r 'none) #f r))
        (hash-ref (current-level-meta-store) id #f)))
  (and v (not (eq? v 'unsolved))))

;; Retrieve the solution of a level metavariable, or #f if unsolved/unknown.
;; Phase B: CHAMP primary, hash fallback.
(define (level-meta-solution id)
  (define box (current-level-meta-champ-box))
  (define v
    (if box
        (let ([r (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
          (if (eq? r 'none) #f r))
        (hash-ref (current-level-meta-store) id #f)))
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
;; Phase B: CHAMP primary, hash fallback.
(define (fresh-mult-meta source)
  (define id (gensym 'mmeta))
  (define box (current-mult-meta-champ-box))
  (if box
      (set-box! box (champ-insert (unbox box) (prop-meta-id-hash id) id 'unsolved))
      (hash-set! (current-mult-meta-store) id 'unsolved))
  (mult-meta id))

;; Assign a solution to a mult metavariable.
;; Phase B: CHAMP primary, hash fallback.
(define (solve-mult-meta! id solution)
  (define box (current-mult-meta-champ-box))
  (define status
    (if box
        (let ([v (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
          (if (eq? v 'none) #f v))
        (hash-ref (current-mult-meta-store) id #f)))
  (unless status
    (error 'solve-mult-meta! "unknown mult-meta: ~a" id))
  (when (not (eq? status 'unsolved))
    (error 'solve-mult-meta! "mult-meta ~a already solved" id))
  (if box
      (set-box! box (champ-insert (unbox box) (prop-meta-id-hash id) id solution))
      (hash-set! (current-mult-meta-store) id solution)))

;; Check if a mult metavariable has been solved.
;; Phase B: CHAMP primary, hash fallback.
(define (mult-meta-solved? id)
  (define box (current-mult-meta-champ-box))
  (define v
    (if box
        (let ([r (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
          (if (eq? r 'none) #f r))
        (hash-ref (current-mult-meta-store) id #f)))
  (and v (not (eq? v 'unsolved))))

;; Retrieve the solution of a mult metavariable, or #f if unsolved/unknown.
;; Phase B: CHAMP primary, hash fallback.
(define (mult-meta-solution id)
  (define box (current-mult-meta-champ-box))
  (define v
    (if box
        (let ([r (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
          (if (eq? r 'none) #f r))
        (hash-ref (current-mult-meta-store) id #f)))
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
;; Phase B: CHAMP primary, hash fallback.
(define (fresh-sess-meta source)
  (define id (gensym 'smeta))
  (define box (current-sess-meta-champ-box))
  (if box
      (set-box! box (champ-insert (unbox box) (prop-meta-id-hash id) id 'unsolved))
      (hash-set! (current-sess-meta-store) id 'unsolved))
  (sess-meta id))

;; Assign a solution to a sess metavariable.
;; Phase B: CHAMP primary, hash fallback.
(define (solve-sess-meta! id solution)
  (define box (current-sess-meta-champ-box))
  (define status
    (if box
        (let ([v (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
          (if (eq? v 'none) #f v))
        (hash-ref (current-sess-meta-store) id #f)))
  (unless status
    (error 'solve-sess-meta! "unknown sess-meta: ~a" id))
  (when (not (eq? status 'unsolved))
    (error 'solve-sess-meta! "sess-meta ~a already solved" id))
  (if box
      (set-box! box (champ-insert (unbox box) (prop-meta-id-hash id) id solution))
      (hash-set! (current-sess-meta-store) id solution)))

;; Check if a sess metavariable has been solved.
;; Phase B: CHAMP primary, hash fallback.
(define (sess-meta-solved? id)
  (define box (current-sess-meta-champ-box))
  (define v
    (if box
        (let ([r (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
          (if (eq? r 'none) #f r))
        (hash-ref (current-sess-meta-store) id #f)))
  (and v (not (eq? v 'unsolved))))

;; Retrieve the solution of a sess metavariable, or #f if unsolved/unknown.
;; Phase B: CHAMP primary, hash fallback.
(define (sess-meta-solution id)
  (define box (current-sess-meta-champ-box))
  (define v
    (if box
        (let ([r (champ-lookup (unbox box) (prop-meta-id-hash id) id)])
          (if (eq? r 'none) #f r))
        (hash-ref (current-sess-meta-store) id #f)))
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
;; Phase A: Initializes CHAMP meta-info store alongside propagator network.
;; Phase B: Also initializes level/mult/sess CHAMP boxes.
(define (reset-meta-store!)
  (hash-clear! (current-meta-store))
  (hash-clear! (current-level-meta-store))
  (hash-clear! (current-mult-meta-store))
  (hash-clear! (current-sess-meta-store))
  (hash-clear! (current-trait-constraint-map))
  (hash-clear! (current-trait-wakeup-map))
  (reset-constraint-store!)
  ;; Initialize propagator network + CHAMP stores
  (define make-net (current-prop-make-network))
  (when make-net
    (define net-box (current-prop-net-box))
    (cond
      [net-box
       ;; Already have boxes — reset contents
       (set-box! net-box (make-net))
       (set-box! (current-prop-id-map-box) champ-empty)
       (set-box! (current-prop-meta-info-box) champ-empty)
       ;; Phase B: reset auxiliary meta CHAMPs
       (set-box! (current-level-meta-champ-box) champ-empty)
       (set-box! (current-mult-meta-champ-box) champ-empty)
       (set-box! (current-sess-meta-champ-box) champ-empty)]
      [else
       ;; First call or test context — create boxes
       (current-prop-net-box (box (make-net)))
       (current-prop-id-map-box (box champ-empty))
       (current-prop-meta-info-box (box champ-empty))
       ;; Phase B: create auxiliary meta CHAMP boxes
       (current-level-meta-champ-box (box champ-empty))
       (current-mult-meta-champ-box (box champ-empty))
       (current-sess-meta-champ-box (box champ-empty))])))

;; ========================================
;; Meta state save/restore for speculative type-checking
;; ========================================
;; Used by check-reduce to save meta state before a speculative Church fold
;; attempt and restore it if the attempt fails, preventing meta contamination
;; when falling back to structural PM.
;;
;; Saves the status and solution of all metas in the current store.
;; Restore resets each meta back to its saved state.

;; Phase A+B: save-meta-state is fully O(1) when CHAMP stores are active.
;; All six CHAMPs (network, id-map, meta-info, level, mult, sess) are
;; immutable — capturing the root reference is sufficient. Legacy path is O(N).
;; Phase B: Including level/mult/sess fixes the latent speculation bug where
;; mutations to these stores leaked through with-speculative-rollback.
(define (save-meta-state)
  (define mi-box (current-prop-meta-info-box))
  (cond
    [mi-box
     ;; Production path: all O(1) — capture immutable CHAMP references
     (list 'prop
           (unbox (current-prop-net-box))
           (unbox (current-prop-id-map-box))
           (unbox mi-box)
           (unbox (current-level-meta-champ-box))
           (unbox (current-mult-meta-champ-box))
           (unbox (current-sess-meta-champ-box)))]
    [else
     ;; Legacy path: O(N) hash snapshot
     (for/hasheq ([(id info) (in-hash (current-meta-store))])
       (values id (cons (meta-info-status info) (meta-info-solution info))))]))

(define (restore-meta-state! saved)
  (cond
    [(and (list? saved) (eq? (car saved) 'prop))
     ;; Production path: all O(1) — swap immutable CHAMP references
     (set-box! (current-prop-net-box) (list-ref saved 1))
     (set-box! (current-prop-id-map-box) (list-ref saved 2))
     (set-box! (current-prop-meta-info-box) (list-ref saved 3))
     ;; Phase B: restore auxiliary meta CHAMPs
     (set-box! (current-level-meta-champ-box) (list-ref saved 4))
     (set-box! (current-mult-meta-champ-box) (list-ref saved 5))
     (set-box! (current-sess-meta-champ-box) (list-ref saved 6))]
    [else
     ;; Legacy path: restore hash only (O(N))
     (for ([(id state) (in-hash saved)])
       (define info (hash-ref (current-meta-store) id #f))
       (when info
         (set-meta-info-status! info (car state))
         (set-meta-info-solution! info (cdr state))))]))

;; List all unsolved metavariable infos.
;; Phase A: reads from CHAMP (primary) or hash (fallback).
(define (all-unsolved-metas)
  (define mi-box (current-prop-meta-info-box))
  (if mi-box
      ;; Production path: fold over CHAMP
      (champ-fold (unbox mi-box)
                  (lambda (k v acc)
                    (if (eq? (meta-info-status v) 'unsolved)
                        (cons v acc)
                        acc))
                  '())
      ;; Legacy path: iterate hash
      (for/list ([(id info) (in-hash (current-meta-store))]
                 #:when (eq? (meta-info-status info) 'unsolved))
        info)))

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
