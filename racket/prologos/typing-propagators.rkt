#lang racket/base

;;;
;;; typing-propagators.rkt — PPN Track 4: Elaboration as Attribute Evaluation
;;;
;;; Propagator-native type inference. Typing propagators are installed via
;;; net-add-propagator. They read type-map positions from the form cell's PU
;;; value and write computed types back. Information flows through cells —
;;; no function-call dispatch, no delegation, no imperative wrappers.
;;;
;;; Phase 1c: Context lattice — typing context as cells.
;;; Phase 2 (D.4): Propagator fire functions + install-typing-network.
;;; Phase 4b-i: Fan-in meta-readiness.
;;; Phase 6: Constraint lattice.
;;;

(require racket/match
         racket/set
         racket/string
         "syntax.rkt"
         "prelude.rkt"
         "substitution.rkt"
         "global-env.rkt"
         "propagator.rkt"
         "surface-rewrite.rkt"
         (only-in "subtype-predicate.rkt" type-tensor-core subtype-lattice-merge subtype?)
         (only-in "type-lattice.rkt" type-bot type-bot? type-top type-top? type-lattice-merge type-unify-or-top has-unsolved-meta?)
         (only-in "metavar-store.rkt" meta-solution/cell-id current-prop-net-box
                  trait-constraint-info trait-constraint-info?
                  trait-constraint-info-trait-name trait-constraint-info-type-arg-exprs
                  read-trait-constraints
                  solve-meta! meta-solved?
                  current-persistent-registry-net-box)
         "constraint-cell.rkt"  ;; Track 4B Phase 2: reuse existing constraint lattice
         "constraint-propagators.rkt"  ;; Track 4B Phase 2: build-trait-constraint, refine-constraint-by-type-tag
         (only-in "infra-cell.rkt" merge-list-append)  ;; PPN 4C Phase 1d-C: named merge fn for warning-output cell
         (only-in "sre-core.rkt" make-sre-domain register-domain!)  ;; PPN 4C Phase 2: facet SRE registration
         (only-in "merge-fn-registry.rkt" register-merge-fn!/lattice)  ;; PPN 4C Phase 2: Tier 2 linkage
         ;; PPN 4C Phase 3c-i: tag-layer shim for :type facet value + :term magic keyword.
         ;; `:type` facet's VALUE SHAPE is now classify-inhabit-value; that-read unwraps
         ;; the classifier layer; that-write wraps raw values as classifier-only. `:term`
         ;; is a magic keyword routing to the inhabitant layer of the same facet.
         (only-in "classify-inhabit.rkt"
                  classify-inhabit-value classify-inhabit-value?
                  classify-inhabit-value-bot?
                  classify-inhabit-value-classifier-or-bot
                  classify-inhabit-value-inhabitant-or-bot
                  classifier-only inhabitant-only
                  merge-classify-inhabit
                  classify-inhabit-contradiction?)
         (only-in "qtt.rkt" zero-usage single-usage add-usage scale-usage)  ;; Track 4B Phase 4
         (only-in "typing-core.rkt" numeric-join
                  refine-arith refine-arith1 base-numeric-type
                  negatable-numeric-type? concrete-numeric-type? divisible-numeric-type?)  ;; Phase T + N5de sign transfer
         (only-in "sign-refinement.rkt"
                  sign-transfer-add sign-transfer-sub sign-transfer-mul sign-transfer-div
                  sign-transfer-neg sign-transfer-abs
                  refined-name?)  ;; N5de sign transfer; N5f: refined-name? drives the exact classifier
         (only-in "warnings.rkt" emit-coercion-warning!)  ;; Phase 9 prep: coercion bridge
         (only-in "trait-resolution.rkt" resolve-trait-constraints!)  ;; Phase 9: parametric bridge
         ;; Note (PPN 4C Path T-3 Commit A.2-a, 2026-04-22): pre-T-3 expr-union
         ;; install case's worldview-bitmask branching retired (atms.rkt imports
         ;; were removed). PPN 4C Phase 3A.a (2026-05-22) re-introduces atms.rkt
         ;; imports for the on-network fork-on-union mechanism — but for a
         ;; different (non-imperative) purpose: per-branch worldview tagging on
         ;; shared carrier (Realization B), not the pre-T-3 imperative branching.
         (only-in "atms.rkt" assumption-id-n solver-state-amb)
         ;; PPN 4C Phase 3A.a (2026-05-22): per-command ATMS box for fresh-aid
         ;; allocation. Per-command scope verified at audit §9.3.2.4 / driver.rkt:464.
         (only-in "elab-speculation-bridge.rkt" current-command-atms)
         ;; PPN 4C Phase 3C.b.4 (2026-05-23): chain-construction wrapper for
         ;; per-fork threshold-fire propagator. Wraps 3C.a's static-reverse-walk;
         ;; enriches with assumption-names; consumed by threshold body to write
         ;; structured derivation-chain into cell-19 (union-derivation-chains-cell-id).
         (only-in "error-explanation.rkt" derivation-chain-for/union-contradict)
         ;; PPN 4C Phase 3A.a (2026-05-22): flatten-union for N-ary decomposition.
         (only-in "union-types.rkt" flatten-union)
         ;; PPN 4C Phase 3A.b (2026-05-22): tagged-cell-value accessors for the
         ;; tagged-attribute-map-read-with-base-merge helper. Used to inspect
         ;; per-branch entries explicitly when reading at branch worldview
         ;; positions other than the branch's own write position.
         (only-in "decision-cell.rkt"
                  tagged-cell-value? tagged-cell-value-base tagged-cell-value-entries)
         "elab-network-types.rkt"
         "errors.rkt"
         "pretty-print.rkt"
         "source-location.rkt")

(provide
 ;; Phase 1c: Context lattice
 (struct-out context-cell-value)
 context-empty-value
 context-extend-value
 context-lookup-type
 context-lookup-mult
 context-cell-merge
 context-facet-merge  ;; PPN 4C Phase 2: bot-safe wrapper for :context SRE registration
 context-cell-contradicts?
 ;; Track 4B Phase 1: Attribute Record PU
 attribute-map-merge-fn
 ;; Track 4B Phase 2: Constraint Attribute Propagators
 make-constraint-creation-fire-fn
 make-type-narrows-constraints-fire-fn
 type-expr->tag
 ;; Track 4B Phase 7: Coercion Detection
 type-family
 make-coercion-detection-fire-fn
 ;; Track 4B Phase 3: Trait Resolution
 make-trait-resolution-fire-fn
 candidate->dict-expr
 ;; Track 4B Phase 0c+6: Persistent attribute-map cell + meta-bridge
 init-attribute-map-cell!
 current-attribute-map-cell-id
 current-meta-solution-output-cell-id
 meta-solution-merge
 make-meta-solution-output-fire-fn
 that-read
 that-write
 facet-bot
 facet-bot?
 facet-merge
 ;; PPN 4C Phase 3c-ii: :term (INHABITANT layer) helpers, symmetric to
 ;; type-map-read / type-map-write for the :type (CLASSIFIER layer) helpers.
 type-map-read
 type-map-write
 type-map-write-unified  ;; PPN 4C Path T-3 Commit A.2-b: Role B equality-enforce write
 ;; PPN 4C Phase 3A.b (2026-05-22): defensive helper for branch propagators that
 ;; need to read attribute-map at positions OTHER than their fork's union position.
 ;; Staged for Phase 9b multi-candidate γ hole-fill cross-position read need.
 tagged-attribute-map-read-with-base-merge
 term-map-read
 term-map-write
 ;; PPN 4C Phase 3c-iii: cross-tag residuation infrastructure.
 type-of-expr
 make-classify-inhabit-residuation-fire-fn
 process-classify-inhabit-request
 ;; PPN 4C Phase 3A.a (2026-05-22): fork-on-union mechanism API.
 ;; Exposed for: (i) test-union-types-atms.rkt direct + E2E testing;
 ;; (ii) future 3A.c classifier-watcher install that writes to cell-15.
 make-branch-check-fire-fn
 make-branch-contradiction-watcher-fire-fn  ;; PPN 4C Phase 3A.b — per-branch contradiction watcher
 make-fork-chain-threshold-fire-fn          ;; PPN 4C Phase 3C.b.4 — per-fork threshold-fire (chain emission)
 process-fork-on-union
 process-fork-contradiction
 ;; PPN 4C Phase 3A.c.3-R7 (2026-05-22): union-detection lives inline in
 ;; type-map-write (helper `maybe-emit-fork-on-union-request`). The earlier
 ;; classifier-watcher API (make-classifier-watcher-fire-fn + install-
 ;; classifier-watcher; 3A.c.2 commit 4e8e9ad4) was retired in 3A.c.3-R7.c
 ;; per addendum §9.3.7. Phase 9b γ multi-candidate watcher (if a use case
 ;; surfaces) can resurrect the pattern from git history.
 ;; Track 4B Phase 6b: Fire-once propagator pattern (now in propagator.rkt, re-exported)
 net-add-fire-once-propagator
 ;; Phase 2 (D.4): Propagator-native typing
 install-typing-network
 make-literal-fire-fn
 make-universe-fire-fn
 make-app-fire-fn
 make-bvar-fire-fn
 make-fvar-fire-fn
 make-lam-fire-fn
 make-pi-fire-fn
 ;; Pattern 5: Context-extension propagator
 make-context-extension-fire-fn
 ;; §16 SRE Typing Domain
 (struct-out typing-domain-rule)
 make-typing-domain
 register-typing-rule!
 lookup-typing-rule
 install-default-typing-domain!
 unhandled-expr-counts
 ;; Phase 3 (D.4): Production integration
 infer-on-network
 type-map-merge-fn
 ;; Phase 7 (D.4): Surface→Type bridge — production entry point
 infer-on-network/err
 on-network-success-count
 on-network-fallback-count
 ;; Phase 4b-i: Fan-in meta-readiness infrastructure
 (struct-out meta-readiness-value)
 meta-readiness-empty
 meta-readiness-register
 meta-readiness-solve
 meta-readiness-unsolved
 meta-readiness-all-solved?
 meta-readiness-merge
 meta-readiness-contradicts?
 ;; Phase 6: Constraint SRE domain
 (struct-out constraint-cell-value)
 constraint-pending
 constraint-resolved
 constraint-contradicted
 constraint-pending?
 constraint-resolved?
 constraint-contradicted?
 constraint-cell-merge
 constraint-cell-meet
 constraint-cell-contradicts?)


;; ============================================================
;; Phase 1c: Context Lattice
;; ============================================================
;;
;; The typing context IS a cell. Its PU value is a binding stack
;; (list of (type . mult) pairs using de Bruijn indices).
;;
;; Lattice structure:
;;   bot = empty context (no bindings)
;;   merge = pointwise on bindings at each position
;;   tensor (extension) = prepend new binding (creates child cell)
;;
;; This parallels Module Theory (SRE Track 7): a typing context
;; is a "local module" with positional exports.

;; A context cell's value. Wraps the binding stack with metadata
;; for lattice operations (parent tracking for scope nesting).
(struct context-cell-value
  (bindings    ;; (listof (cons type mult)): de Bruijn binding stack
   depth)      ;; Nat: nesting depth (0 = top-level)
  #:transparent)

;; Bot: empty context (top-level scope)
(define context-empty-value
  (context-cell-value '() 0))

;; Tensor: extend context with a new binding (enter a binder scope).
;; Returns a new context-cell-value (for writing to a child context cell).
;; The child is at depth+1.
(define (context-extend-value ctx-val type mult)
  (context-cell-value
   (cons (cons type mult)
         (context-cell-value-bindings ctx-val))
   (add1 (context-cell-value-depth ctx-val))))

;; Lookup type at de Bruijn position k.
;; Returns the type, or expr-error if k is out of bounds.
(define (context-lookup-type ctx-val k)
  (define bindings (context-cell-value-bindings ctx-val))
  (if (< k (length bindings))
      (car (list-ref bindings k))
      (expr-error)))

;; Lookup multiplicity at de Bruijn position k.
;; Returns the mult, or #f if k is out of bounds.
(define (context-lookup-mult ctx-val k)
  (define bindings (context-cell-value-bindings ctx-val))
  (if (< k (length bindings))
      (cdr (list-ref bindings k))
      #f))

;; Merge function for context cells.
(define (context-cell-merge old new)
  (cond
    [(null? (context-cell-value-bindings old)) new]
    [(null? (context-cell-value-bindings new)) old]
    [(= (context-cell-value-depth old) (context-cell-value-depth new))
     (context-cell-value
      (map (lambda (ob nb)
             (cons
              (if (equal? (car ob) (car nb)) (car ob) (car nb))
              (if (equal? (cdr ob) (cdr nb)) (cdr ob) (cdr nb))))
           (context-cell-value-bindings old)
           (context-cell-value-bindings new))
      (context-cell-value-depth old))]
    [(> (context-cell-value-depth new) (context-cell-value-depth old)) new]
    [else old]))

(define (context-cell-contradicts? v) #f)

;; ============================================================
;; PPN 4C Phase 2: :context facet SRE domain registration (A9)
;; ============================================================
;;
;; D2 framework per §6.9.2:
;;   Aspirational: associative; NON-commutative (binding-stack order has
;;     scope semantics); idempotent under same-depth bindings
;;   Declared (γ, conservative): minimal — don't declare algebraic
;;     properties initially; inference informs what holds
;;   Expected inference: confirm associative; refute commutative
;;   Delta: ACCEPT non-commutativity as design (quantale-like monoidal
;;     structure; analogous to session types)

;; Bot-safe wrapper: context-cell-merge assumes both args are
;; context-cell-value structs (facet-merge handles bot before
;; dispatching). For SRE registration (which invokes merge with
;; arbitrary samples including bot), wrap to handle bot explicitly.
;; This mirrors the :context case in facet-merge.
(define (context-facet-merge old new)
  (cond
    [(not old) new]                  ;; #f (bot) + X = X
    [(not new) old]                  ;; X + #f (bot) = X
    [(equal? old new) old]           ;; idempotent
    [else (context-cell-merge old new)]))

(define context-merge-registry
  (lambda (rel-name)
    (case rel-name
      [(equality) context-facet-merge]
      [else (error 'context-merge-registry "no merge for relation: ~a" rel-name)])))

(define (context-bot? v)
  (or (not v)  ;; #f is bot (distinguishable from empty context)
      (and (context-cell-value? v)
           (null? (context-cell-value-bindings v)))))

(define context-sre-domain
  (make-sre-domain
   #:name 'context
   #:merge-registry context-merge-registry
   #:contradicts? context-cell-contradicts?
   #:bot? context-bot?
   #:bot-value #f
   #:top-value #f))  ;; no distinct top — contradictions don't arise for context

;; Eager registration at module load
(register-domain! context-sre-domain)
;; Register the bot-safe wrapper (context-facet-merge), not the raw
;; context-cell-merge — the wrapper is what cells actually invoke
;; through facet-merge dispatch.
(register-merge-fn!/lattice context-facet-merge #:for-domain 'context)


;; ============================================================
;; Phase 2 (D.4 redo): Propagator-Native Typing
;; ============================================================
;;
;; Each typing propagator is a fire-fn: (prop-network → prop-network).
;; It reads type-map positions from the form cell's PU value via
;; net-cell-read, computes a type, and writes the result back to the
;; form cell via net-cell-write.
;;
;; Network Reality Check:
;;   1. net-add-propagator: YES — install-typing-network calls it per position
;;   2. net-cell-write produces result: YES — fire-fns write to type-map
;;   3. Cell trace: form cell (type-map ⊥) → propagator fires → cell write
;;      (type) → cascade → quiescence → cell read (result)
;;
;; The type-map is a hasheq inside the form cell's PU value
;; (form-pipeline-value-type-map). Positions are expr object identities.
;; Component-indexed firing (Phase 1a) selectively schedules propagators.

;; Helper: check if an expression references bvar(0) — indicates dependent type.
;; Simplified check: looks for (expr-bvar 0) in the immediate structure.
(define (codomain-is-dependent? e)
  (match e
    [(expr-bvar _) #t]  ;; ANY bvar reference means dependent
    [(expr-app f a) (or (codomain-is-dependent? f) (codomain-is-dependent? a))]
    [(expr-Pi _ d c) (or (codomain-is-dependent? d) (codomain-is-dependent? c))]
    [(expr-lam _ d b) (or (codomain-is-dependent? d) (codomain-is-dependent? b))]
    [(expr-Sigma a b) (or (codomain-is-dependent? a) (codomain-is-dependent? b))]
    [(expr-meta _ _) #t]  ;; metas may resolve to dependent types
    [_ #f]))


;; net-add-fire-once-propagator: moved to propagator.rkt (BSP-LE Track 2 Phase 5).
;; Re-exported from this module for backward compatibility.

;; ============================================================
;; Track 4B Phase 1: Attribute Record PU
;; ============================================================
;;
;; The attribute cell holds a NESTED hasheq:
;;   (hasheq position → (hasheq facet → value))
;;
;; Each position (AST node, eq?-identity) has a RECORD with one
;; field per attribute domain (§1.2 of Track 4B design).
;; Phase 1 implements :type and :context facets. Phases 2/4/7
;; add :constraints, :usage, :warnings.
;;
;; Merge is two-level pointwise: per position, then per facet.
;; Each facet has its own merge function and bot value.
;; Component-indexed firing uses compound paths (position . facet).
;;
;; Network Reality Check:
;;   Same propagators, same information flow. The cell values are
;;   richer (multi-facet records) but the computation topology is
;;   unchanged. Phase 1 is a correct-by-construction refactoring.

;; --- Facet definitions: merge function + bot per facet ---

;; PPN 4C Phase 3c-i: :type facet value is classify-inhabit-value with tag layers
;; (CLASSIFIER + INHABITANT). The :type facet's bot is the empty-layers record.
;; Module-level constant (avoid per-call allocation).
(define classify-inhabit-bot-value (classify-inhabit-value 'bot 'bot))

;; Module Theory embedding: the base type lattice embeds into the tag-layered
;; lattice as "classifier-only." Sites that construct :type facet values directly
;; (e.g., test fixtures via (hasheq ':type T) without that-write) continue to
;; work because the shim upgrades raw values to classifier-only at the boundary.
;; Raw type-bot maps to the both-layers-empty record for bot-predicate symmetry.
(define (upgrade-to-classify-inhabit v)
  (cond
    [(classify-inhabit-value? v) v]
    [(classify-inhabit-contradiction? v) v]
    [(type-bot? v) classify-inhabit-bot-value]
    [else (classifier-only v)]))

(define (facet-merge facet old-v new-v)
  (case facet
    [(:type)
     ;; PPN 4C Phase 3c-i: merge-classify-inhabit is the tag-dispatched merge.
     ;; Raw type-values at direct-construction sites are upgraded at the boundary
     ;; to preserve module-theoretic embedding (base → classifier-only).
     (merge-classify-inhabit (upgrade-to-classify-inhabit old-v)
                             (upgrade-to-classify-inhabit new-v))]
    [(:context)
     (cond
       [(not old-v) new-v]   ;; #f (bot) + X = X
       [(not new-v) old-v]   ;; X + #f (bot) = X
       [(equal? old-v new-v) old-v]
       [else (context-cell-merge old-v new-v)])]
    ;; Track 4B Phase 2: constraint domain uses existing constraint-cell lattice
    [(:constraints) (constraint-merge old-v new-v)]
    ;; Track 4B Phase 4: usage vectors merge via pointwise mult-add
    [(:usage) (add-usage old-v new-v)]
    ;; Track 4B Phase 7: warnings merge via monotone accumulation (append)
    [(:warnings) (append old-v new-v)]
    [else new-v]))

(define (facet-bot facet)
  (case facet
    [(:type) classify-inhabit-bot-value]  ;; PPN 4C Phase 3c-i: tag-layer bot
    [(:context) #f]  ;; #f = not yet written (distinguishes from context-empty-value)
    [(:constraints) constraint-bot]  ;; constraint-cell.rkt: all candidates possible
    [(:usage) '()]               ;; empty usage vector
    [(:warnings) '()]            ;; no warnings
    [else #f]))

(define (facet-bot? facet v)
  (case facet
    ;; PPN 4C Phase 3c-i: accept classify-inhabit-value bot OR raw type-bot
    ;; (backward-compat for sites constructing :type facet values directly).
    [(:type) (or (classify-inhabit-value-bot? v) (type-bot? v))]
    [(:context) (not v)]  ;; #f = bot (not yet written)
    [(:constraints) (constraint-bot? v)]
    [(:usage) (null? v)]
    [(:warnings) (null? v)]
    [else (not v)]))

;; --- Attribute map merge: two-level pointwise ---
;;
;; Outer: per position (hasheq key).
;; Inner: per facet within each position's record.
;; Each facet merges independently via facet-merge.

(define (attribute-map-merge-fn old new)
  (cond
    [(not (hash? old)) new]
    [(not (hash? new)) old]
    [else
     (for/fold ([result old]) ([(pos record) (in-hash new)])
       (define old-record (hash-ref result pos (hasheq)))
       (cond
         ;; No existing record at this position → insert new record
         [(and (hash? old-record) (zero? (hash-count old-record)))
          (hash-set result pos record)]
         ;; Both have records → merge per facet
         [else
          (define merged-record
            (for/fold ([rec old-record]) ([(facet val) (in-hash record)])
              (define old-val (hash-ref rec facet (facet-bot facet)))
              (cond
                [(facet-bot? facet old-val) (hash-set rec facet val)]
                [(facet-bot? facet val) rec]
                [(equal? old-val val) rec]  ;; idempotent
                [else (hash-set rec facet (facet-merge facet old-val val))])))
          (if (equal? merged-record old-record)
              result  ;; no change at this position
              (hash-set result pos merged-record))]))]))

;; --- that-read / that-write: the attribute record API ---
;;
;; that-read: (attribute-map, position, facet) → value
;; that-write: (net, cell-id, position, facet, value) → updated-net
;;
;; These are the INTERNAL API for all attribute access.
;; §14 of Track 4B design: designed for future user-facing exposure.

;; PPN 4C Phase 3c-i: tag-layer shims for :type / :term.
;;
;; The :type facet's VALUE SHAPE is classify-inhabit-value with two tag layers:
;; CLASSIFIER (the type a position must have) and INHABITANT (the specific value
;; solving it). Callers see the surface :type and :term keywords; the shim
;; auto-unwraps the classifier and routes :term to the inhabitant layer of the
;; SAME :type facet (not a new 6th facet — 5 facets preserved per D.3 §4.2).
;;
;; Cascade handling: when the merge produces classify-inhabit-contradiction?
;; (classifier × classifier → type-top), the :type reader returns type-top so
;; existing type-top? checks downstream continue firing. The :term reader
;; returns the sentinel explicitly (new surface; callers can test for it).

(define (read-type-layer v)
  (cond
    [(classify-inhabit-contradiction? v) type-top]
    [(classify-inhabit-value? v)
     (define c (classify-inhabit-value-classifier-or-bot v))
     (if (eq? c 'bot) type-bot c)]
    ;; Raw type-value (legacy direct-construction site): IS the classifier.
    ;; Module-theoretic embedding base → classifier-only at the read boundary.
    [else v]))

(define (read-term-layer v)
  (cond
    [(classify-inhabit-contradiction? v) 'classify-inhabit-contradiction]
    [(classify-inhabit-value? v) (classify-inhabit-value-inhabitant-or-bot v)]
    ;; Raw type-value: no inhabitant layer; return 'bot.
    [else 'bot]))

;; that-read has two forms:
;;
;;   (that-read attribute-map position)        → whole-record user-facing view
;;   (that-read attribute-map position facet)  → single-facet value
;;
;; The arity-2 form returns a user-facing hash with facet → value entries
;; for every facet actually stored at the position. The :type facet's
;; internal classify-inhabit-value is DECOMPOSED: classifier layer appears
;; under the ':type key, inhabitant layer under ':term. Consumers never see
;; the internal classify-inhabit-value wrapper through this API.
;;
;; Use cases (PPN 4C Phase 3e addendum, 2026-04-20):
;;   - LSP hover / IDE inspection: dump all attribute info at a cursor
;;   - Phase 11b diagnostic: read provenance context (srcloc + type + usage)
;;   - User-facing `that` grammar form: surface all attributes of an
;;     expression/variable in user programs
;;   - Debug/observability tooling
;;
;; Missing facets are NOT synthesized with bot defaults — iterate or use
;; hash-ref with (facet-bot facet) fallback if the caller needs a uniform
;; shape across all 5 facets. Keeps the return shape minimal and honest
;; (returns what's actually stored, not what might be stored).
(define that-read
  (case-lambda
    [(attribute-map position)
     (cond
       [(not (hash? attribute-map)) (hasheq)]
       [else
        (define record (hash-ref attribute-map position #f))
        (cond
          [(not (hash? record)) (hasheq)]
          [else
           ;; Start: all non-:type facets pass through as-is
           (define base
             (for/fold ([acc (hasheq)])
                       ([(facet val) (in-hash record)]
                        #:unless (eq? facet ':type))
               (hash-set acc facet val)))
           ;; If :type facet stored, decompose classify-inhabit-value into
           ;; user-facing :type (classifier) + :term (inhabitant) entries.
           (define raw-type-val (hash-ref record ':type #f))
           (cond
             [(not raw-type-val) base]
             [else
              (hash-set
               (hash-set base ':type (read-type-layer raw-type-val))
               ':term (read-term-layer raw-type-val))])])])]
    [(attribute-map position facet)
     (if (hash? attribute-map)
         (let ([record (hash-ref attribute-map position (hasheq))])
           (cond
             [(not (hash? record)) (facet-bot facet)]
             ;; :type and :term both read from the :type facet; dispatch on which
             ;; layer to extract (classifier vs inhabitant).
             [(eq? facet ':type)
              (read-type-layer (hash-ref record ':type (facet-bot ':type)))]
             [(eq? facet ':term)
              (read-term-layer (hash-ref record ':type (facet-bot ':type)))]
             [else (hash-ref record facet (facet-bot facet))]))
         (facet-bot facet))]))

(define (that-write net cell-id position facet value)
  ;; :type writes wrap val as classifier-only (populates CLASSIFIER layer);
  ;; :term writes wrap as inhabitant-only (populates INHABITANT layer). Both
  ;; write to the :type facet; merge-classify-inhabit composes the tags.
  (define-values (internal-facet wrapped-value)
    (cond
      [(eq? facet ':type) (values ':type (classifier-only value))]
      [(eq? facet ':term) (values ':type (inhabitant-only value))]
      [else (values facet value)]))
  (net-cell-write net cell-id
    (hasheq position (hasheq internal-facet wrapped-value))))

;; --- Backward-compatible type-map API ---
;;
;; type-map-read/write are thin wrappers over that-read/that-write
;; for the :type facet. Existing fire functions call these unchanged.
;; ~150 SRE domain rules, all fire function bodies: zero changes needed.
;; type-map-merge-fn is an alias for attribute-map-merge-fn (test compat).

(define type-map-merge-fn attribute-map-merge-fn)

(define (type-map-read net tm-cid position)
  (define tm (net-cell-read net tm-cid))
  (that-read tm position ':type))

;; PPN 4C Phase 3A.c.3-R7 (2026-05-22): inline union-detection helper.
;;
;; Centralized at the :type write API (R7 — see addendum §9.3.7). Replaces
;; the rejected classifier-watcher mechanism (3A.c.2 helpers; see §9.3.7
;; for retirement decision). When type-val is a union and the position is
;; not already in the decomposed-positions guard (cell-17), emit a fork-on-
;; union decomposition request to cell-15. The process-fork-on-union handler
;; (3A.a) consumes the request between BSP rounds and decomposes via N
;; branch propagators.
;;
;; Data Orientation: the union value IS the trigger; emission happens at
;; the moment the data is written, NOT via a watcher observing the data
;; later. Zero extra propagator wakes — predicate check is O(1) struct-tag
;; check inline with existing write.
;;
;; cell-17 guard (FP3 per §9.3.5.3): idempotence is structural. Handler
;; writes (seteq position) to cell-17 when it decomposes (Step 5 of
;; process-fork-on-union); subsequent writes to position's :type with a
;; (possibly refined) union check the guard and skip emission.
;;
;; Coverage: per R7.a audit (§9.3.7.5), 47 production :type write sites
;; flow through type-map-write or type-map-write-unified (which delegates
;; to type-map-write). The 2 direct net-cell-write bypasses at typing-
;; propagators.rkt:987 + :1055 write 'classify-inhabit-contradiction
;; SYMBOL (not expr-union struct); R7's (expr-union? type-val) check
;; correctly skips them.
(define (maybe-emit-fork-on-union-request net tm-cid position type-val)
  (cond
    [(not (expr-union? type-val)) net]
    [(set-member? (net-cell-read net decomposed-positions-cell-id) position) net]
    [else
     (define components (flatten-union type-val))
     (define request-info (hasheq 'components components 'tm-cid tm-cid))
     (net-cell-write net fork-on-union-request-cell-id
                     (hasheq position request-info))]))

(define (type-map-write net tm-cid position type-val)
  (define net1 (that-write net tm-cid position ':type type-val))
  (maybe-emit-fork-on-union-request net1 tm-cid position type-val))

;; PPN 4C Path T-3 Commit A.2-b (2026-04-22): Role B equality-enforcement write.
;;
;; Use when the write semantic is "position MUST have type `expected`"
;; (unification/check/annotation enforcement). Unlike regular type-map-write
;; — which under post-T-3 Commit B set-union merge semantics accumulates
;; unions for structurally-incompatible writes (Role A) — this helper
;; explicitly unifies via type-unify-or-top, producing type-top on
;; structural mismatch so downstream type-top consumers reliably fire.
;;
;; Preserves the contradiction signal that Role B callers (write-expected-
;; type-then-check-merge-top pattern) depend on. Both callers at B1 (app
;; fire arg-pos) and B2 (expr-ann term) previously relied on
;; merge-produces-top-on-incompat via type-lattice-merge; under set-union
;; that signal disappears. This helper makes the equality enforcement
;; explicit at the call site — Role A/B decomplection at the API level.
(define (type-map-write-unified net tm-cid position expected)
  (define current (type-map-read net tm-cid position))
  (type-map-write net tm-cid position (type-unify-or-top current expected)))

;; PPN 4C Phase 3A.b (2026-05-22): tagged-attribute-map-read-with-base-merge.
;;
;; Defensive helper for branch propagators that need to read attribute-map at
;; positions OTHER than their fork's union position. Per §9.3.4 Q1 (build the
;; helper now to design for Phase 9b γ hole-fill multi-candidate need).
;;
;; THE PROBLEM the helper closes:
;; Under Realization B (in-place worldview tagging on shared carrier per
;; §9.3.1.2), `promote-cell-to-tagged` is called on the attribute-map cell at
;; fork-on-union entry. Subsequent branch writes (under wrap-with-worldview)
;; become tagged entries at branch worldviews. The default `net-cell-read` via
;; `tagged-cell-read` returns the matching entry ALONE — it does NOT merge
;; with base. For a branch propagator that needs to see "base + my-branch's
;; delta" semantics at a position the branch did NOT write to, the default
;; read misses the base content.
;;
;; THE FIX:
;; Read the raw tagged-cell-value (via net-cell-read-raw, bypassing filter),
;; explicitly merge base with all entries whose bitmask is subset of the
;; current worldview via attribute-map-merge-fn, then perform standard
;; that-read on the merged hasheq. Position-local fast path: if the cell holds
;; a plain hasheq (pre-promote OR no entries match current wv), falls through
;; to direct hasheq lookup with no overhead.
;;
;; USAGE:
;;   (tagged-attribute-map-read-with-base-merge net tm-cid position facet)
;;     → value at (position, facet), with base correctly overlaid by branch entries
;;
;; CURRENT 3A.b CONSUMERS:
;; None — `make-branch-check-fire-fn` only reads at the union position (safe under
;; default tagged-cell-read). The helper is staged DEFENSIVELY for Phase 9b
;; multi-candidate γ hole-fill, where the candidate-check propagator may need to
;; read attribute-map at positions other than the hole position. See §9.3.4.8
;; cross-track captures.
;;
;; CONTRACT: callers wrapping at non-zero worldview should use this helper for
;; reads at positions they did NOT themselves write to. For reads at the same
;; position the caller writes (3A.a make-branch-check-fire-fn pattern), the
;; default net-cell-read + that-read suffices because the read targets the
;; entry the caller wrote.
(define (tagged-attribute-map-read-with-base-merge net tm-cid position facet)
  (define raw (net-cell-read-raw net tm-cid))
  (cond
    [(tagged-cell-value? raw)
     ;; Compute current worldview (per-propagator override OR worldview-cache cell)
     (define per-prop-wv (current-worldview-bitmask))
     (define wv (if (not (zero? per-prop-wv))
                    per-prop-wv
                    (net-cell-read net worldview-cache-cell-id)))
     (cond
       [(zero? wv)
        ;; No active worldview — read base directly (fast path)
        (define base (tagged-cell-value-base raw))
        (if (hash? base) (that-read base position facet) (facet-bot facet))]
       [else
        ;; Merge base with all entries whose bm is subset of wv,
        ;; via attribute-map-merge-fn — preserves "base + my-branch delta" semantics
        (define base (tagged-cell-value-base raw))
        (define merged
          (for/fold ([acc base])
                    ([entry (in-list (tagged-cell-value-entries raw))])
            (define entry-bm (car entry))
            (define entry-val (cdr entry))
            (if (= (bitwise-and entry-bm wv) entry-bm)
                (cond
                  [(not (hash? acc)) entry-val]
                  [(not (hash? entry-val)) acc]
                  [else (attribute-map-merge-fn acc entry-val)])
                acc)))
        (if (hash? merged) (that-read merged position facet) (facet-bot facet))])]
    [(hash? raw)
     ;; Plain attribute-map (pre-promote or never branched) — fast path
     (that-read raw position facet)]
    [else (facet-bot facet)]))

;; PPN 4C Phase 3c-ii: term-map-read/write are symmetric helpers for the
;; INHABITANT layer. :term routes to the inhabitant layer of the :type facet
;; via the that-read/that-write magic keyword dispatch (§6.15.8 Q4).
;; Used at sites where the semantic intent is "this position IS SOLVED to V"
;; (meta-feedback, trait-resolution dict assignment) vs. "this position HAS
;; TYPE T" (classifier, the type-map-* path).
(define (term-map-read net tm-cid position)
  (define tm (net-cell-read net tm-cid))
  (that-read tm position ':term))

(define (term-map-write net tm-cid position term-val)
  (that-write net tm-cid position ':term term-val))

;; ============================================================
;; Track 4B Phase 2: Constraint Attribute Propagators (S0)
;; ============================================================
;;
;; Two new propagator kinds:
;;   1. Constraint-creation: builds initial constraint domain from impl
;;      registry for each trait constraint. Fires once (no inputs to wait
;;      for — reads static impl registry at fire time).
;;   2. Type-narrows-constraints bridge: watches :type facets of constraint
;;      type-arg positions. When a type becomes concrete, narrows the
;;      constraint domain by filtering candidates. Pure S0, monotone.
;;
;; Network Reality Check:
;;   1. net-add-propagator: YES — installed per constraint during
;;      install-attribute-network
;;   2. net-cell-write produces result: YES — that-write to :constraints
;;   3. Cell trace: attribute cell → constraint-creation fires →
;;      :constraints facet written → type-narrows bridge fires when
;;      :type facet changes → narrowed :constraints written

;; Extract a type tag symbol from a TYPE expression for constraint narrowing.
;; Maps type constructors to registry-compatible tag symbols.
;; Returns #f for non-concrete types (metas, bots, complex types).
;; The tags must match what impl-entry-type-args stores (e.g., 'Nat, 'Int).
(define (type-expr->tag type-val)
  (cond
    [(expr-Int? type-val) 'Int]
    [(expr-Nat? type-val) 'Nat]
    [(expr-Bool? type-val) 'Bool]
    [(expr-String? type-val) 'String]
    ;; Named type constructors: the tag is the FQN symbol itself.
    ;; impl-entry-type-args stores the FQN (e.g., 'prologos::data::posit::Posit8),
    ;; so we need to match on that, not a short name.
    [(and (expr-fvar? type-val)
          (symbol? (expr-fvar-name type-val)))
     (expr-fvar-name type-val)]
    [else #f]))

;; N5f: last segment of a possibly-::-qualified type name → bare symbol
;; ('prologos::data::refined-int::PosInt → 'PosInt; bare 'PosInt → 'PosInt).
(define (fvar-name-last-segment name)
  (define segs (string-split (symbol->string name) "::"))
  (if (null? segs) name (string->symbol (list-ref segs (sub1 (length segs))))))

;; Type family classifier for coercion detection.
;; exact = arbitrary-precision (Int, Nat, Rat and subtypes)
;; approximate = machine-precision (Posit*, Float*)
;; other = no coercion concern (Bool, String, etc.)
(define (type-family type-val)
  (cond
    ;; Direct struct types (builtins)
    [(or (expr-Int? type-val) (expr-Nat? type-val)) 'exact]
    [(expr-Rat? type-val) 'exact]
    [(expr-Posit8? type-val) 'approximate]
    [(expr-Posit16? type-val) 'approximate]
    [(expr-Posit32? type-val) 'approximate]
    [(expr-Posit64? type-val) 'approximate]
    [(expr-Float32? type-val) 'approximate]
    [(expr-Float64? type-val) 'approximate]
    ;; FQN types (from global env): classify by EXACT last-segment, not substring.
    ;; N5f (§8a fix 2): substring over-matched arbitrary names (Position⊃"Posit",
    ;; NonZero⊃"Zero", Rateable⊃"Rat"). refined-name? is the authoritative refined
    ;; whitelist (all 7 refined names have base Int/Rat = exact); the builtin numeric
    ;; names are a defensive no-regress case — approximate/exact builtins normally
    ;; arrive as structs above, but an FQN alias reaching here still classifies right.
    [(expr-fvar? type-val)
     (define seg (fvar-name-last-segment (expr-fvar-name type-val)))
     (cond
       [(refined-name? seg) 'exact]
       [(memq seg '(Posit8 Posit16 Posit32 Posit64 Float32 Float64)) 'approximate]
       [(memq seg '(Int Nat Rat)) 'exact]
       [else 'other])]
    [else 'other]))

;; S2 coercion-detection propagator: reads both arg types at a generic
;; op position. If they're from different families (exact vs approximate),
;; writes a coercion warning to :warnings. P2 fire-once.
(define (make-coercion-detection-fire-fn tm-cid position arg1-pos arg2-pos)
  (lambda (net)
    (define tm (net-cell-read net tm-cid))
    (define t1 (that-read tm arg1-pos ':type))
    (define t2 (that-read tm arg2-pos ':type))
    (cond
      [(or (type-bot? t1) (type-bot? t2)) net]  ;; wait for both types
      [else
       (define f1 (type-family t1))
       (define f2 (type-family t2))
       (cond
         [(and (not (eq? f1 'other)) (not (eq? f2 'other)) (not (eq? f1 f2)))
          ;; Cross-family: emit coercion warning
          (define warning (list 'coercion-warning (pp-expr t1) (pp-expr t2)))
          (that-write net tm-cid position ':warnings (list warning))]
         [else net])])))

;; Constraint-creation propagator: builds initial constraint domain from
;; the impl registry. This is a PROPAGATOR (on-network), not a literal
;; write — it fires as part of attribute evaluation and is expressible
;; in the SRE attribute domain for self-hosting.
;;
;; Reads: impl registry (off-network, static during evaluation — Track 7 migrates)
;; Writes: :constraints facet at the dict-meta position
(define (make-constraint-creation-fire-fn tm-cid dict-meta-pos trait-name)
  (lambda (net)
    (define current-constraints
      (that-read (net-cell-read net tm-cid) dict-meta-pos ':constraints))
    ;; Only write if still at bot — don't overwrite narrowed domains
    (if (constraint-bot? current-constraints)
        (let ([initial-domain (build-trait-constraint trait-name)])
          (that-write net tm-cid dict-meta-pos ':constraints initial-domain))
        net)))

;; Type-narrows-constraints bridge propagator: watches the :type facet of
;; a constraint's type-arg position. When the type becomes concrete (has a
;; recognizable type tag), narrows the constraint domain at the dict-meta
;; position by filtering candidates to those matching the type tag.
;;
;; Reads: :type facet at type-arg-pos
;; Writes: :constraints facet at dict-meta-pos (narrowed domain)
;; Monotone S0: domains only shrink (intersection)
(define (make-type-narrows-constraints-fire-fn tm-cid dict-meta-pos type-arg-pos)
  (lambda (net)
    (define tm (net-cell-read net tm-cid))
    (define type-val (that-read tm type-arg-pos ':type))
    (cond
      ;; Wait for type to be non-bot
      [(type-bot? type-val) net]
      [else
       (define tag (type-expr->tag type-val))
       (cond
         ;; No recognizable tag — can't narrow (type is complex, meta, etc.)
         [(not tag) net]
         [else
          ;; Read current constraint domain
          (define current-domain (that-read tm dict-meta-pos ':constraints))
          (cond
            ;; If still at bot, nothing to narrow yet (creation hasn't fired)
            [(constraint-bot? current-domain) net]
            ;; If already at top (contradiction) or resolved, nothing to do
            [(constraint-top? current-domain) net]
            [(constraint-one? current-domain) net]
            [else
             ;; Narrow: keep only candidates whose type-args match this tag
             (define narrowed (refine-constraint-by-type-tag current-domain tag))
             ;; Only write if narrowing actually changed something
             (if (equal? narrowed current-domain)
                 net
                 (that-write net tm-cid dict-meta-pos ':constraints narrowed))])])])))

;; ============================================================
;; Track 4B Phase 3a: Trait Resolution Propagator (S1)
;; ============================================================
;;
;; Watches the :constraints facet at a dict-meta position.
;; When the constraint domain reaches singleton (constraint-one),
;; extracts the resolved dict expression and writes it to the
;; :type facet at the same position.
;;
;; S1 = readiness-triggered: fires only when S0 (typing + constraint
;; narrowing) has produced enough information to resolve.
;;
;; Network Reality Check:
;;   1. net-add-propagator: YES — installed per dict-meta with constraint
;;   2. net-cell-write: YES — that-write to :type facet with dict expr
;;   3. Cell trace: :constraints narrowed → S1 fires → :type written →
;;      app propagators can now compute result types

;; Build the dict expression from a resolved monomorphic constraint candidate.
;; For monomorphic: simply (expr-fvar dict-name).
;; For parametric: would need pattern var bindings (Phase 3 handles monomorphic;
;; parametric deferred to later iteration).
(define (candidate->dict-expr candidate)
  (expr-fvar (constraint-candidate-dict-name candidate)))

;; S1 trait-resolution propagator: watches :constraints, writes :type when resolved.
(define (make-trait-resolution-fire-fn tm-cid dict-meta-pos)
  (lambda (net)
    (define tm (net-cell-read net tm-cid))
    (define constraint-val (that-read tm dict-meta-pos ':constraints))
    (cond
      ;; Not yet resolved — wait
      [(not (constraint-one? constraint-val)) net]
      [else
       ;; Resolved: extract the single candidate
       (define candidate (constraint-one-candidate constraint-val))
       (define dict-expr (candidate->dict-expr candidate))
       ;; PPN 4C Phase 3c-ii: dict-expr is the VALUE that solves the dict-meta.
       ;; Per §6.15.8 Q6, solver-write goes to INHABITANT layer via :term. Trait
       ;; resolution reaching a unique candidate IS the solution; the dict-meta's
       ;; type (classifier) remains governed by its originating trait constraint.
       (define current-term (that-read tm dict-meta-pos ':term))
       (if (eq? current-term 'bot)
           (that-write net tm-cid dict-meta-pos ':term dict-expr)
           net)])))  ;; already solved — don't overwrite

;; ============================================================
;; Track 4B Phase 6: Meta-Solution Output Propagator
;; ============================================================
;;
;; Per-meta propagator that watches a meta position's :type facet.
;; When the meta gets a concrete type (from feedback, S1 resolution, etc.),
;; writes (cons meta-id solution) to a shared output cell.
;; After quiescence, the output cell is read ONCE — not a scan of the
;; attribute map. The collection happens through propagator firings
;; (information flow), not post-hoc iteration.
;;
;; The output cell is a monotone list (append-merge). Each meta-bridge
;; propagator adds at most one entry.

;; Merge for the meta-solution output cell: monotone list append.
(define (meta-solution-merge old new)
  (append old new))

;; ============================================================
;; PPN 4C Phase 3c-iii: Cross-tag residuation propagator
;; ============================================================
;;
;; Per D.3 §6.15.8 Q2: the cross-tag residuation check is a quantale MEET
;; operation — "does inhabitant inhabit classifier?" via subtype-lattice-merge
;; (the 'subtype relation's merge in type-sre-domain's merge-registry).
;;
;; Architecture (§6.15.8 Q2, Module Theory lens):
;;   - Propagator watches a meta position's :type facet (component-path)
;;   - Fires when both CLASSIFIER and INHABITANT layers populated (threshold)
;;   - Fire function:
;;       subtype-lattice-merge(classifier, type-of-expr(inhabitant))
;;     Three outcomes:
;;       * Result = classifier (already subsumed) → no-op
;;       * Result = type-top → contradiction; write classify-inhabit-contradiction
;;       * Result = narrower type → emit stratum request per P4(b)
;;   - Stratum handler processes pending requests between BSP rounds.
;;
;; Merge purity (P4b): the propagator FIRE function does the check; the
;; classify-inhabit merge stays pure `(v × v → v)`. Writes to cells happen
;; outside the merge, via the stratum request mechanism.
;;
;; Phase 9 joint item (§6.15.6): the stratum request carries no worldview
;; assumption-id in 3c; Phase 9 adds TMS-tagging overlay.

;; Classifying-type-of: minimal literal/constructor classifier. Returns
;; type-bot for expressions whose classifier can't be determined locally
;; (propagator defers). This is the 3c-iii minimal form; richer inhabitant
;; classification (e.g., compound expressions, nested metas) is a 3c-iv
;; refinement candidate.
(define (type-of-expr e)
  (cond
    [(expr-int? e) (expr-Int)]
    [(expr-nat-val? e) (expr-Nat)]
    [(expr-true? e) (expr-Bool)]
    [(expr-false? e) (expr-Bool)]
    [(expr-string? e) (expr-String)]
    ;; Type constructors: Type(l) has type Type(l+1)
    [(expr-Int? e) (expr-Type (lzero))]
    [(expr-Nat? e) (expr-Type (lzero))]
    [(expr-Bool? e) (expr-Type (lzero))]
    [(expr-String? e) (expr-Type (lzero))]
    [(expr-Type? e) (expr-Type (lsuc (expr-Type-level e)))]
    ;; Meta expressions: can't classify locally — defer
    [(expr-meta? e) type-bot]
    ;; Compound expressions (Pi, Sigma, lam, app): need deeper analysis
    ;; → return type-bot (no residuation fires). 3c-iv candidate.
    [else type-bot]))

;; Residuation fire function for a meta position. Reads CLASSIFIER and
;; INHABITANT layers of the :type facet; fires when both populated.
(define (make-classify-inhabit-residuation-fire-fn tm-cid meta-pos)
  (lambda (net)
    (define tm (net-cell-read net tm-cid))
    (define record (if (hash? tm) (hash-ref tm meta-pos (hasheq)) (hasheq)))
    (define cinhab-val (if (hash? record) (hash-ref record ':type classify-inhabit-bot-value) classify-inhabit-bot-value))
    (define classifier (classify-inhabit-value-classifier-or-bot cinhab-val))
    (define inhabitant (classify-inhabit-value-inhabitant-or-bot cinhab-val))
    (cond
      ;; Threshold not met: either layer missing
      [(or (eq? classifier 'bot) (eq? inhabitant 'bot)) net]
      ;; Already contradicted
      [(classify-inhabit-contradiction? cinhab-val) net]
      [else
       (define inhabitant-type (type-of-expr inhabitant))
       (cond
         ;; Can't classify inhabitant locally — defer (3c-iv may refine)
         [(type-bot? inhabitant-type) net]
         [else
          (cond
            ;; Compatible: inhabitant's type IS a subtype of classifier.
            ;; subtype? handles equality (Int <: Int), strict subtyping
            ;; (Nat <: Num), and structural cases. No narrowing needed.
            [(subtype? inhabitant-type classifier) net]
            ;; Incompatible: inhabitant's type does NOT inhabit the classifier.
            ;; This is the quantale-MEET contradiction per §6.15.8 Q2.
            ;; Write the contradiction sentinel; merge-classify-inhabit's
            ;; contradiction-absorbs branch preserves it.
            [else
             ;; 3c-iii minimal: contradictions write inline (sentinel).
             ;; Narrowing (where inhabitant-type is STRICTLY NARROWER than
             ;; classifier — e.g., classifier=Num, inhabitant-type=Int) does
             ;; not fire here because subtype?(Int, Num) is #t, landing on
             ;; the compatible branch. Documenting the narrowing case:
             ;; when the richer semantic demand surfaces (Phase 9 TMS-tagged
             ;; fork-on-narrowing, or explicit refinement propagation), the
             ;; stratum request cell is already pre-allocated + handler
             ;; registered. For 3c-iii, narrowing is architecturally
             ;; subsumed by "compatible" via subtype?.
             (net-cell-write net tm-cid
               (hasheq meta-pos (hasheq ':type 'classify-inhabit-contradiction)))])])])))

;; Stratum handler for classify-inhabit residuation requests.
;; Minimal 3c-iii: processes pending narrowing records (does not write
;; back — Phase 9 TMS-tagged fork-on-narrowing handles propagation).
;; Contradictions are already written directly by the fire function.
(define (process-classify-inhabit-request net pending-hash)
  ;; 3c-iii minimal: log-only. The narrowing data is accumulated in the
  ;; request cell for Phase 9 to consume. Return net unchanged.
  net)

;; Register the stratum handler at module load.
(register-stratum-handler! classify-inhabit-request-cell-id
                           process-classify-inhabit-request)

;; ============================================================
;; PPN 4C Phase 3A.0 (2026-05-22): Fork-on-Union Stratum Handlers
;; ============================================================
;;
;; Per addendum design §9.3.1.6 + §9.3.2. Stratum handlers for fork-on-union
;; orchestration cells (cell-15 fork-on-union-request, cell-16
;; fork-contradiction-request). Bodies are no-op stubs at 3A.0; full bodies
;; wire at 3A.a (process-fork-on-union) + 3A.b (process-fork-contradiction).
;;
;; 3A.0 charter: establish the registration SHAPE without behavior change vs
;; pre-3A.0 baseline. Drift risk D-3A.0-handler-no-op-leak — stubs MUST
;; return net unchanged. Verified via probe diff = 0 vs baseline.
;;
;; Architectural model (per §9.3.1.2): BSP-LE 2/2B Realization B — in-place
;; worldview tagging on shared carrier; NOT fork-and-rejoin (S1 NAF style).

;; Per-branch check propagator factory (PPN 4C Phase 3A.a, 2026-05-22).
;;
;; Structurally parallel to make-classify-inhabit-residuation-fire-fn (line 841)
;; — but parameterized by branch's COMPONENT (closed over) instead of reading
;; classifier from cell. Each branch installs ONE of these wrapped via
;; wrap-with-worldview at the branch's aid-bit-position; fires under branch
;; worldview; reads e's INHABITANT (synthesized type) via worldview-filtered
;; read; checks subtype against the branch component; writes contradiction
;; sentinel tagged at branch wv (via cell merge) if incompatible.
;;
;; The contradiction sentinel ('classify-inhabit-contradiction) is what 3A.b's
;; B2-broadcast contradiction watcher detects to write to cell-16.
(define (make-branch-check-fire-fn tm-cid position component)
  (lambda (net)
    (define tm (net-cell-read net tm-cid))
    (define record (if (hash? tm) (hash-ref tm position (hasheq)) (hasheq)))
    ;; Read INHABITANT layer (classify-inhabit-value's inhabitant field).
    ;; Note: net-cell-read filters tagged entries by current-worldview-bitmask
    ;; (set by wrap-with-worldview wrapper) — so under branch wv we see
    ;; branch-tagged inhabitant + outer base inhabitant (most-specific match).
    (define cinhab-val (if (hash? record) (hash-ref record ':type classify-inhabit-bot-value) classify-inhabit-bot-value))
    (define inhabitant (classify-inhabit-value-inhabitant-or-bot cinhab-val))
    (cond
      [(eq? inhabitant 'bot) net]  ;; defer — inhabitant not yet populated under this wv
      [(classify-inhabit-contradiction? cinhab-val) net]  ;; already contradicted
      [else
       (define inhabitant-type (type-of-expr inhabitant))
       (cond
         [(type-bot? inhabitant-type) net]  ;; can't classify locally
         [(subtype? inhabitant-type component) net]  ;; compatible — branch survives
         [else
          ;; Incompatible: inhabitant's type does NOT inhabit branch component.
          ;; Write contradiction sentinel under branch wv (wrap-with-worldview
          ;; sets current-worldview-bitmask at fire time → net-cell-write tags
          ;; the entry at branch wv). 3A.b watcher detects this + writes branch
          ;; aid to cell-16 → process-fork-contradiction narrows worldview-cache.
          (net-cell-write net tm-cid
            (hasheq position (hasheq ':type 'classify-inhabit-contradiction)))])])))

;; cell-15 handler: process-fork-on-union — PPN 4C Phase 3A.a (2026-05-22).
;; Consumes per-position fork-on-union decomposition requests written by the
;; classifier-watcher (3A.c). For each request entry:
;;   1. Flatten union into N components via flatten-union (N-ary decomp)
;;   2. Allocate N fresh aids via solver-state-amb (per-command via
;;      current-command-atms; aids are integer-tagged assumption-id structs)
;;   3. Initialize worldview-cache (set N branch bits) — bitwise-or with
;;      current worldview; non-committing semantics retains successful branches
;;      until 3A.b's contradiction watcher narrows failed branches
;;   4. Install N branch check propagators (one per component); each wrapped
;;      at branch worldview via wrap-with-worldview(aid-bit-pos); fires when
;;      e's INHABITANT changes (via :component-paths); writes contradiction
;;      sentinel tagged at branch wv if incompatible
;;
;; Request entry shape (written by 3A.c classifier-watcher; for now test-stubbed):
;;   pending-hash : (hasheq position → request-info)
;;   request-info : (hasheq 'components (listof TypeExpr)
;;                          'tm-cid CellId
;;                          'source-loc (or srcloc #f))
;;
;; Idempotence: BSP outer-loop's #:reset-value (hasheq) clears cell-15 after
;; handler runs. Threshold-fire-once at classifier-watcher (3A.c) prevents
;; duplicate requests per (position, decomposition).
;;
;; Per §9.3.1.6 architecture (Realization B — in-place worldview tagging on
;; shared carrier; NOT fork-and-rejoin). Per OQ4: Level 1 (Tarski) termination
;; conditional on worldview filter correctness (3A parity axis validates).
(define (process-fork-on-union net pending-hash)
  (cond
    [(or (not (hash? pending-hash)) (zero? (hash-count pending-hash))) net]
    [else
     (for/fold ([n net]) ([(position request-info) (in-hash pending-hash)])
       (define components (hash-ref request-info 'components #f))
       (define tm-cid (hash-ref request-info 'tm-cid #f))
       (cond
         [(or (not components) (not tm-cid) (null? components)) n]  ;; defensive: malformed request
         [else
          ;; Step 1: allocate N aids via current-command-atms
          (define atms-box (current-command-atms))
          (cond
            [(not atms-box) n]  ;; defensive: no atms set (shouldn't happen in production)
            [else
             (define atms (unbox atms-box))
             (define labels
               (for/list ([i (in-naturals)] [_ (in-list components)])
                 (format "branch-~a-at-~v" i position)))
             ;; PPN 4C Phase 3B.A M0 (2026-05-22): pass #:mutual-exclusion? #f
             ;; for non-committing semantic. Union-type inhabitation is at-least-
             ;; one (any branch that succeeds keeps its inhabitant); classical
             ;; mutex nogoods (exactly-one) would be semantically wrong and were
             ;; structurally inert under the prior code path (verified §9.4.3.1
             ;; A2). Per Q2(b), amb-groups append also skipped — solve-all
             ;; semantic correctness preserved. See §9.4.3 for full rationale.
             (define-values (atms* aids)
               (solver-state-amb atms labels #:mutual-exclusion? #f))
             (set-box! atms-box atms*)
             ;; Step 2: initialize worldview-cache (set all N branch bits)
             (define branch-mask
               (for/fold ([mask 0]) ([aid (in-list aids)])
                 (bitwise-ior mask (arithmetic-shift 1 (assumption-id-n aid)))))
             (define current-wv (net-cell-read n worldview-cache-cell-id))
             (define n1 (net-cell-write n worldview-cache-cell-id
                                         (bitwise-ior current-wv branch-mask)))
             ;; Step 2.5 (PPN 4C Phase 3A.b — Option E per §9.3.4):
             ;; Promote attribute-map cell to tagged-cell-value BEFORE installing
             ;; branch propagators. This is the LOAD-BEARING step that enables
             ;; per-branch isolation under wrap-with-worldview. Without it,
             ;; attribute-map writes under branch worldviews would merge into
             ;; the plain hasheq base (no tagging), and per-branch contradictions
             ;; would be globally visible (the bug Phase 3A.b's prior session
             ;; surfaced via E2E test failure).
             ;;
             ;; The pattern mirrors relations.rkt's 5 production sites (NAF :2034,
             ;; guard :2079, fact-row :2481, multi-clause :2564, additional :2944).
             ;; `promote-cell-to-tagged` is idempotent (no-op if already tagged)
             ;; and atomically rewrites the cell's merge-fn to
             ;; `(make-tagged-merge attribute-map-merge-fn)` — preserving original
             ;; merge semantics for the both-plain case while enabling tagged
             ;; entry composition under wrap-with-worldview.
             (define n2 (promote-cell-to-tagged n1 tm-cid))
             ;; Step 3: install N branch check propagators (per branch, wrapped at branch wv).
             ;; Each check writes contradiction sentinel at branch wv under post-Step-2.5
             ;; promoted tagged-cell-value semantics — entries tagged at branch-bit, isolated
             ;; from sibling branches.
             (define n3
               (for/fold ([acc n2]) ([component (in-list components)] [aid (in-list aids)])
                 (define bit-pos (assumption-id-n aid))
                 (define-values (acc* _pid)
                   (net-add-propagator acc (list tm-cid) (list tm-cid)
                     (wrap-with-worldview
                       (make-branch-check-fire-fn tm-cid position component)
                       bit-pos)
                     #:component-paths (list (cons tm-cid (cons position ':term)))))
                 acc*))
             ;; Step 4 (PPN 4C Phase 3A.b — per §9.3.4.6 step 3):
             ;; Install N fire-once contradiction watchers (one per branch), each
             ;; wrapped at its branch worldview. Each watcher reads attribute-map
             ;; under its branch wv (via tagged-cell-value subset filtering),
             ;; detects 'classify-inhabit-contradiction sentinel, writes (seteq aid)
             ;; to cell-16 (fork-contradiction-request-cell-id; set-union merge
             ;; accumulates aids from all branches that contradicted). The
             ;; process-fork-contradiction handler then atomically narrows
             ;; worldview-cache via bitwise-AND-with-NOT-mask.
             ;;
             ;; Why N fire-once (not 1 broadcast): broadcast reads inputs ONCE
             ;; at fire time (no per-item worldview dispatch). N fire-once
             ;; propagators wrapped at per-branch worldviews matches relations.rkt
             ;; pattern and enables BSP parallel decomposition.
             ;; Step 4 — captured as n4 for Step 5's cell-17 guard write
             ;; PPN 4C Phase 3C.b.5.c BUGFIX (2026-05-23): cell-18 added to OUTPUTS
             ;; list. 3C.b.2's watcher fan-out writes to BOTH cell-16 + cell-18 in
             ;; its fire-fn body, but only cell-16 was declared as output. Per
             ;; propagator.rkt:2848-2871 + :2971-2989, writes to UNDECLARED output
             ;; cells use `struct-copy` direct-set (bypassing merge) "to avoid
             ;; double-merging with non-idempotent merge functions like append".
             ;;
             ;; This made cell-18 effectively LAST-WRITE-WINS for multiple watcher
             ;; fires in the same BSP round: when watcher-0 + watcher-1 both fire,
             ;; their cell-18 writes go through bulk-merge-writes's undeclared-
             ;; writes path → for/fold applies them sequentially via direct-set →
             ;; only the LAST write survives (typically aid-0). cell-18 was thus
             ;; de facto last-write-wins instead of monotone accumulation,
             ;; defeating its purpose as the threshold-fire latch.
             ;;
             ;; Diagnosed at 3C.b.5.c via E2E probe (cell-18 had only aid-0 even
             ;; though worldview-cache went to 0 = both bits cleared, proving
             ;; both watchers fired + cell-16 received both aids via the merge-
             ;; path). Verified by reading propagator.rkt's fire-and-collect-
             ;; writes (line 2833) + bulk-merge-writes (line 2971).
             ;;
             ;; The fix: declare cell-18 as a watcher output. Writes route
             ;; through fire-result.value-writes (line 2839-2846) → applied via
             ;; net-cell-write (line 2968) → cell-18's merge function
             ;; (contradicted-branch-aids-merge) ACCUMULATES per-position aid-
             ;; sets via set-union, as designed at 3C.b.1.
             (define n4
               (for/fold ([acc n3]) ([aid (in-list aids)])
                 (define bit-pos (assumption-id-n aid))
                 (define-values (acc* _pid)
                   (net-add-fire-once-propagator acc
                     (list tm-cid)
                     (list fork-contradiction-request-cell-id
                           contradicted-branch-aids-cell-id)        ;; 3C.b.5.c bugfix
                     (wrap-with-worldview
                       (make-branch-contradiction-watcher-fire-fn tm-cid position aid)
                       bit-pos)
                     #:component-paths (list (cons tm-cid (cons position ':type)))
                     #:assumption aid))
                 acc*))
             ;; Step 4.5 (PPN 4C Phase 3C.b.4, 2026-05-23): per-fork threshold-fire
             ;; propagator for chain emission. Per addendum §9.5.3.3 refined option (d).
             ;;
             ;; Reads cell-18 (contradicted-branch-aids latch); closes over THIS
             ;; fork's (position, branch-aid-set, request-info); fires when all
             ;; branch aids are in cell-18's per-position entry (subset check);
             ;; action: build derivation chain via 3C.b.3 wrapper + write to cell-19
             ;; (union-derivation-chains storage; 3C.c consumes from check/err).
             ;;
             ;; NOT fire-once: predicate may not be met on first cell-18 change
             ;; (branches may contradict across multiple BSP rounds). Stays
             ;; installed; structural idempotence via cell-18 stability after all
             ;; watchers fire (each fire-once) + defensive cell-19 emit-once guard.
             ;;
             ;; :component-paths precision: fires only on THIS position's cell-18
             ;; entry change (sibling positions / concurrent forks don't wake it).
             (define branch-aid-set (apply seteq aids))
             (define-values (n5 _chain-pid)
               (net-add-propagator n4
                 (list contradicted-branch-aids-cell-id)         ;; input: cell-18 latch
                 (list union-derivation-chains-cell-id)          ;; output: cell-19 storage
                 (make-fork-chain-threshold-fire-fn position branch-aid-set request-info)
                 #:component-paths (list (cons contradicted-branch-aids-cell-id position))))
             ;; Step 5 (PPN 4C Phase 3A.c.3-R7, 2026-05-22): FP3 guard write.
             ;;
             ;; Mark this position as decomposed so subsequent :type writes that
             ;; happen to yield a union (e.g., refinement from branch propagators
             ;; OR upstream propagators re-firing) do NOT trigger re-emission of
             ;; the fork-on-union request via R7's inline check in type-map-write.
             ;;
             ;; cell-17 (decomposed-positions-cell-id) is a 'monotone-set domain
             ;; cell with merge-set-union semantics — writing the same position
             ;; twice is idempotent. The on-network guard makes R7's idempotence
             ;; STRUCTURAL (Correct by Construction) rather than relying on
             ;; flag-guard semantics or downstream dedup.
             (net-cell-write n5 decomposed-positions-cell-id (seteq position))])]))]))

;; PPN 4C Phase 3A.b (2026-05-22): per-branch contradiction watcher factory.
;;
;; Fire function reads attribute-map at the union position UNDER the branch
;; worldview (wrap-with-worldview parameterizes current-worldview-bitmask
;; before fire; net-cell-read filters tagged-cell-value entries by subset
;; semantics). Detects 'classify-inhabit-contradiction sentinel set by
;; make-branch-check-fire-fn on incompatible subtype check; emits the
;; branch aid to cell-16 (fork-contradiction-request-cell-id).
;;
;; Per-branch isolation: under branch-i's wv=bit-i, tagged-cell-read returns
;; entries with bm subset of bit-i. Branch-j's writes (bm=bit-j) have bm
;; NOT subset of bit-i (disjoint bits) — invisible. Only branch-i's writes
;; matter. This is the load-bearing correctness property post-Step-2.5
;; promote-cell-to-tagged.
;;
;; Fire-once via net-add-fire-once-propagator: per-branch watcher fires AT MOST
;; once after the check propagator writes the contradiction. Idempotent under
;; cell-16's set-union merge (writing the same (seteq aid) twice is a no-op
;; under set semantics). Self-cleans dependents after firing per fire-once.
;; PPN 4C Phase 3C.b.4 (2026-05-23): per-fork threshold-fire propagator factory
;; for chain emission. Per addendum §9.5.3.3 refined option (d) — set-latch +
;; threshold canonical pattern from .claude/rules/propagator-design.md.
;;
;; The threshold propagator is installed PER FORK at process-fork-on-union
;; (step 4.5, between watcher install and cell-17 guard write). It reads cell-18
;; (contradicted-branch-aids-cell-id) — the monotone per-position aid-set
;; LATCH populated by 3C.b.2 watcher fan-out. Closes over (position,
;; branch-aid-set, request-info) for the specific fork it's emitted for.
;;
;; FIRE SEMANTICS — NOT fire-once (intentional):
;;   The threshold uses plain `net-add-propagator` (NOT
;;   net-add-fire-once-propagator) because the THRESHOLD CONDITION may not
;;   be met on the first cell-18 change. fire-once would self-clean after
;;   the first invocation regardless of whether the predicate held — but
;;   the predicate becomes true only AFTER ALL N branches have contradicted
;;   (which may span multiple BSP rounds if branches contradict at different
;;   times). The threshold must STAY INSTALLED to re-evaluate as cell-18 grows.
;;
;; STRUCTURAL IDEMPOTENCE (Q-B.1.iii landing under option (d)):
;;   After all watchers fire (each is fire-once + self-cleans), cell-18
;;   STABILIZES at its position entry; no further writes trigger re-evaluation.
;;   The threshold's body therefore fires AT MOST ONCE in practice — when
;;   the LAST watcher completes the subset. DEFENSIVE GUARD via cell-19
;;   emit-once check (hash-has-key?) handles the edge case where cell-18
;;   would re-trigger (shouldn't happen given watcher fire-once + stable
;;   monotone cell, but defensive against future fan-in extensions).
;;
;; COMPONENT-PATHS PRECISION:
;;   Declares :component-paths (list (cons contradicted-branch-aids-cell-id
;;   position)) so the threshold fires only when ITS position's aid-set
;;   changes — sibling position changes (other concurrent forks) don't
;;   wake it. Per §7.5.12.5 design-doc correction: flat hasheq cells emit
;;   bare position keys in pu-value-diff; declaration uses cons-pair shape.
;;
;; AID IDENTITY NORMALIZATION (D-3C.b-7 precedent from 3C.b.3):
;;   branch-aid-set contains canonical aid instances (preserved eq? identity
;;   through closure capture in watcher); cell-18 entries contain those
;;   same canonical instances (watcher writes (seteq aid)). For subset
;;   check, normalize BOTH to integer aid-ns to avoid eq?-vs-equal? hazard
;;   should the canonical-identity invariant ever break (e.g., per-command
;;   ATMS reset between forks). Pattern mirrors the wrapper at 3C.b.3.
(define (make-fork-chain-threshold-fire-fn position branch-aid-set request-info)
  (define branch-aid-ns
    (for/seteqv ([aid (in-set branch-aid-set)]) (assumption-id-n aid)))
  (lambda (net)
    ;; Threshold check: is the full branch-aid-set ⊆ cell-18's position entry?
    (define cell-18-val (net-cell-read net contradicted-branch-aids-cell-id))
    (define position-aids (hash-ref cell-18-val position (seteq)))
    (define position-aid-ns
      (for/seteqv ([aid (in-set position-aids)]) (assumption-id-n aid)))
    (cond
      [(not (subset? branch-aid-ns position-aid-ns))
       ;; Not all branches contradicted yet — return net unchanged (threshold
       ;; stays installed; will be re-evaluated on next cell-18 write).
       net]
      [else
       ;; All branches contradicted. Defensive idempotence guard via cell-19
       ;; presence check (subsumed by structural stability of cell-18 post-
       ;; watcher-completion; defensive against future fan-in extensions).
       (define cell-19-val (net-cell-read net union-derivation-chains-cell-id))
       (cond
         [(hash-has-key? cell-19-val position)
          ;; Already emitted for this position — no-op (true Q-B.1.iii
          ;; subsumption preserved + defensive)
          net]
         [else
          ;; All branches contradicted + not yet emitted: build PER-BRANCH chain
          ;; list (per Q-C.6 lock — addendum §9.5.4.3 lean (a)) + write.
          ;;
          ;; Per-branch list shape aligns cell-19 with union-exhaustion-error's
          ;; (listof derivation-chain) field shape (Q-B.2 lock). Sexp path
          ;; (3C.c.3 check/err writer) produces per-branch list naturally; this
          ;; writer iterates the wrapper N times (one per branch-aid) to match.
          ;;
          ;; PPN 4C 3C.c.2 (2026-05-24): adjusted from single aggregated chain
          ;; to per-branch list per §9.5.4.3 Q-C.6 audit-surfaced finding. Cost:
          ;; N walks instead of 1 (negligible — error paths not hot; diagnostic
          ;; richness justifies). Honest correction of missed-audit at 3C.b VAG,
          ;; not scope creep — same wrapper API used iteratively.
          (define per-branch-chains
            (for/list ([aid (in-set branch-aid-set)])
              (derivation-chain-for/union-contradict net (seteq aid) request-info)))
          (net-cell-write net union-derivation-chains-cell-id
                          (hasheq position per-branch-chains))])])))

(define (make-branch-contradiction-watcher-fire-fn tm-cid position aid)
  (lambda (net)
    (define tm (net-cell-read net tm-cid))
    (define record (if (hash? tm) (hash-ref tm position (hasheq)) (hasheq)))
    (define cinhab-val (if (hash? record)
                           (hash-ref record ':type classify-inhabit-bot-value)
                           classify-inhabit-bot-value))
    (cond
      [(classify-inhabit-contradiction? cinhab-val)
       ;; PPN 4C Phase 3C.b.2 (2026-05-23): fan-out write to cell-16
       ;; (existing transient narrowing handler input) AND cell-18 (NEW
       ;; persistent latch for per-fork threshold-fire-once propagator at
       ;; 3C.b.4). Per addendum design §9.5.3.3 refined option (d).
       ;;
       ;; cell-16 (fork-contradiction-request-cell-id): set-union merge;
       ;;   transient (#:reset-value (seteq) between BSP rounds); feeds the
       ;;   process-fork-contradiction handler that atomically narrows
       ;;   worldview-cache via AND-NOT-mask. UNCHANGED from 3A.b.
       ;; cell-18 (contradicted-branch-aids-cell-id): hash-union with
       ;;   set-union per-position; PERSISTS across BSP rounds within command
       ;;   (the latch for set-latch + threshold pattern per
       ;;   .claude/rules/propagator-design.md). Payload shape:
       ;;   (hasheq position (seteq aid)) — hash-union merge accumulates
       ;;   per-position aid-sets monotonically; threshold-fire-once
       ;;   propagator (3C.b.4) reads cell-18 + fires when (subset?
       ;;   branch-aid-set (hash-ref cell-18-val position)).
       ;;
       ;; Both writes are monotone (CALM-safe); order doesn't matter;
       ;; idempotent under repeated fires (but fire-once self-cleans so this
       ;; shouldn't recur). Existing handlers (process-fork-contradiction)
       ;; stay SINGLE-CONCERN — fan-out is at the watcher layer, not handler.
       ;; D-3C.b-6: watcher fan-out coupling pattern (codification candidate;
       ;; future readers install separate propagators reading cell-16, NOT
       ;; extending this watcher — bounded to 2-cell minimum).
       (let* ([n1 (net-cell-write net fork-contradiction-request-cell-id (seteq aid))]
              [n2 (net-cell-write n1 contradicted-branch-aids-cell-id
                                  (hasheq position (seteq aid)))])
         n2)]
      [else net])))

;; cell-16 handler: process-fork-contradiction — PPN 4C Phase 3A.b (2026-05-22).
;;
;; Consumes accumulated aid-set (set of branch assumption-ids that the per-branch
;; contradiction watchers wrote to cell-16 during the prior BSP round). For each
;; contradicted aid, computes its bit position; atomically narrows the
;; worldview-cache by bitwise-AND-with-NOT-mask:
;;
;;   worldview-cache = worldview-cache & (bitwise-not contradicted-bits)
;;
;; This clears the contradicted branches' bits from the active worldview.
;; Subsequent propagators wrapped at those branches' worldviews will read
;; worldview-cache and (in conjunction with the per-propagator wrap-with-worldview
;; bitmask check) become inert — the branches are structurally retracted.
;;
;; Mirrors 2A.a process-retraction pattern (atomic narrowing handler that runs
;; BETWEEN BSP rounds; one-pass over the accumulated set). BSP outer-loop's
;; #:reset-value (seteq) (registered at 3A.0) clears cell-16 after the handler
;; returns, preparing for the next BSP round's accumulation.
;;
;; Atomicity: stratum handlers run between BSP rounds, NOT during them. The
;; in-round writes to cell-16 from per-branch watchers all accumulate via
;; set-union merge; the handler reads the fully-accumulated set once and
;; performs a single narrowing write. No racing — handler runs atomically
;; per round.
;;
;; Non-committing inhabitation semantics (per OQ1 §9.3.1.3): surviving branches'
;; bits REMAIN set in worldview-cache after narrowing. Only contradicted
;; branches' bits clear. Multi-success branches coexist.
(define (process-fork-contradiction net contradiction-aid-set)
  (cond
    [(or (not (set? contradiction-aid-set))
         (set-empty? contradiction-aid-set)) net]
    [else
     ;; Compute mask of contradicted bits
     (define contradicted-bits
       (for/fold ([mask 0]) ([aid (in-set contradiction-aid-set)])
         (bitwise-ior mask (arithmetic-shift 1 (assumption-id-n aid)))))
     ;; Read current worldview, compute narrowed worldview
     (define current-wv (net-cell-read net worldview-cache-cell-id))
     (define narrowed-wv (bitwise-and current-wv (bitwise-not contradicted-bits)))
     ;; Idempotent — no write if no actual narrowing happens
     (cond
       [(= current-wv narrowed-wv) net]
       [else (net-cell-write net worldview-cache-cell-id narrowed-wv)])]))

;; Register handlers at module load. Per addendum design §9.3 deliverable 2
;; (cell-15) + deliverable 5 (cell-16). #:tier 'value places them in the
;; BSP outer-loop's value-tier stratum iteration alongside other elaboration
;; concerns (process-classify-inhabit-request, process-retraction,
;; process-resolution). #:reset-value matches each cell's initial value type
;; (hasheq for cell-15; seteq for cell-16) — BSP outer-loop auto-clears after
;; the handler returns, preparing for the next BSP round's accumulation.
(register-stratum-handler! fork-on-union-request-cell-id
                           process-fork-on-union
                           #:tier 'value
                           #:reset-value (hasheq))
(register-stratum-handler! fork-contradiction-request-cell-id
                           process-fork-contradiction
                           #:tier 'value
                           #:reset-value (seteq))

;; ============================================================
;; PPN 4C Phase 3A.c (2026-05-22): Union-detection at type-write API
;; ============================================================
;;
;; ARCHITECTURAL HISTORY: Phase 3A.c originally designed a per-position
;; classifier-watcher propagator (commit `4e8e9ad4`, 3A.c.2) per addendum
;; §9.3.5.3 Decision 1's β.1 universal install + FP3 guard. The 3A.c.3
;; attempt to invoke the watchers universally at install-typing-network
;; broke 11 polymorphic-trait-dispatch tests via fuel exhaustion
;; (~45-100 watcher wake-ups per polymorphic call consumed
;; TYPING-FUEL-LIMIT budget that trait-resolution needed).
;;
;; R8 empirical fuel test (2026-05-22, §9.3.6.8) confirmed H-compound-4
;; fuel pressure as the leading mechanism. The architecture (β.1 + FP3)
;; was correct; the WATCHER MECHANISM was wasteful.
;;
;; R7 reframe (§9.3.7, this is the implemented form): centralize the
;; union-detection inline in `type-map-write` (the canonical :type write
;; API). Zero extra propagator wakes — the predicate check fires inline
;; with the existing write. See `maybe-emit-fork-on-union-request` helper
;; at line 585+ (above) for the implementation. The classifier-watcher
;; helpers (3A.c.2) were retired in 3A.c.3-R7.c as superseded; the pattern
;; remains available in git history (commit `4e8e9ad4`) for Phase 9b γ
;; multi-candidate use case if it materializes.

;; Meta-solution output propagator: watches one meta's :term facet
;; (INHABITANT layer — the meta's SOLUTION per §6.15.8 Q6). Writes
;; (meta-id . solution) to the output cell when resolved.
;;
;; PPN 4C Phase 3c-ii: migrated from :type to :term. The meta's solution
;; semantic lives in INHABITANT; CLASSIFIER captures the meta's type-constraint
;; (e.g., Type(0) for a type-variable meta). Cross-tag residuation (3c-iii)
;; enforces inhabitant-inhabits-classifier. Zonk/substitution downstream
;; consumes the solution via the output cell, unchanged.
(define (make-meta-solution-output-fire-fn tm-cid meta-pos meta-id output-cid)
  (lambda (net)
    (define tm (net-cell-read net tm-cid))
    (define term-val (that-read tm meta-pos ':term))
    (cond
      [(eq? term-val 'bot) net]                         ;; not yet solved
      [(classify-inhabit-contradiction? term-val) net]  ;; contradiction — don't bridge
      [(expr-meta? term-val) net]                       ;; still a meta — not concrete
      [else
       ;; Concrete solution at this meta position — write to output cell
       (net-cell-write net output-cid (list (cons meta-id term-val)))])))

;; ============================================================
;; Track 4B Phase 7: Warning Propagators (S2)
;; ============================================================
;;
;; S2 propagators that fire after S0+S1 quiesce. They read computed
;; attributes and write diagnostics to the :warnings facet.
;;
;; Per §6a design guidance: S2 propagators are fire-once (P2).

;; Usage-validation propagator: checks compatible(declared, actual)
;; for each binding position. Writes multiplicity-violation warnings.
;; Reads: :usage and :context at each expression position.
;; Writes: :warnings at each position where usage violates declaration.
(define (make-usage-validation-fire-fn tm-cid expr-pos ctx-pos)
  (lambda (net)
    (define tm (net-cell-read net tm-cid))
    (define usage (that-read tm expr-pos ':usage))
    (define ctx-val (that-read tm ctx-pos ':context))
    (cond
      [(or (null? usage) (not ctx-val) (not (context-cell-value? ctx-val))) net]
      [else
       ;; Walk the usage vector against the context bindings
       (define bindings (context-cell-value-bindings ctx-val))
       (define violations
         (for/list ([binding (in-list bindings)]
                    [actual-mult (in-list usage)]
                    #:unless (compatible (cdr binding) actual-mult))
           (list 'multiplicity-violation (car binding) (cdr binding) actual-mult)))
       (if (null? violations)
           net  ;; all usages compatible — no warnings
           (that-write net tm-cid expr-pos ':warnings violations))])))

;; N6a: enumerate an expr's subterms as an eq-set, for scoping the
;; post-quiescence warning harvest to the current command's tree.
;; GENERIC transparent-struct walk — deliberately shape-agnostic: no
;; per-node-kind exhaustiveness obligation (the pipeline.md trap), and a
;; superset is harmless since the set is used only for membership
;; filtering of attr-map positions (which are exactly expr objects).
(define (expr-subterm-seteq root)
  (define seen (mutable-seteq))
  (let loop ([v root])
    (cond
      [(and (struct? v) (not (set-member? seen v)))
       (set-add! seen v)
       (define vec (struct->vector v))
       (for ([i (in-range 1 (vector-length vec))])
         (loop (vector-ref vec i)))]
      [(pair? v) (loop (car v)) (loop (cdr v))]
      [else (void)]))
  seen)

;; Warning-collection propagator: reads all :warnings facets from
;; the attribute map and writes the collected set to an output cell.
;; Fires at S2 after all warning producers have written.
;; N6a: RETIRED from production (infer-on-network now does a scoped
;; post-quiescence read); kept exported for tests (test-meta-feedback).
(define (make-warning-collection-fire-fn tm-cid output-cid)
  (lambda (net)
    (define tm (net-cell-read net tm-cid))
    (if (not (hash? tm))
        net
        (let ([all-warnings
               (for/fold ([acc '()])
                         ([(pos record) (in-hash tm)])
                 (if (hash? record)
                     (let ([warnings (hash-ref record ':warnings '())])
                       (if (null? warnings) acc (append acc warnings)))
                     acc))])
          (if (null? all-warnings)
              net
              (net-cell-write net output-cid all-warnings))))))

;; ============================================================
;; Track 4B Phase 4: Usage Tracking Propagators (S0)
;; ============================================================
;;
;; Each expression kind gets a usage propagator that reads sub-expression
;; :usage facets and the :context facet (for depth), computes the combined
;; usage via the multiplicity semiring, and writes to :usage.
;;
;; Usage vectors are context-relative: length = scope depth at this position.
;; The semiring: mult-add (combine uses), mult-mul (scale by binder mult).
;;
;; Network Reality Check:
;;   1. net-add-propagator: YES — one per expression, writes :usage
;;   2. net-cell-write: YES — via that-write to :usage facet
;;   3. Cell trace: sub-expr :usage → propagator → this :usage

;; Helper: read context depth from :context facet at a context position.
;; Returns 0 if context is not yet available.
(define (read-ctx-depth net tm-cid ctx-pos)
  (define ctx-val (that-read (net-cell-read net tm-cid) ctx-pos ':context))
  (if (context-cell-value? ctx-val)
      (context-cell-value-depth ctx-val)
      0))

;; Zero-usage propagator: for literals, type constructors, fvar.
;; Writes zero-usage(depth) to :usage facet.
(define (make-usage-zero-fire-fn tm-cid position ctx-pos)
  (lambda (net)
    (define depth (read-ctx-depth net tm-cid ctx-pos))
    (if (> depth 0)
        (that-write net tm-cid position ':usage (zero-usage depth))
        net)))  ;; wait for context

;; Single-usage propagator: for (expr-bvar k).
;; Writes single-usage(k, depth) — uses variable k exactly once.
(define (make-usage-bvar-fire-fn tm-cid position k ctx-pos)
  (lambda (net)
    (define depth (read-ctx-depth net tm-cid ctx-pos))
    (if (and (> depth 0) (< k depth))
        (that-write net tm-cid position ':usage (single-usage k depth))
        net)))  ;; wait for context or out of bounds

;; App usage propagator: add-usage(func-usage, scale-usage(m, arg-usage))
;; where m is the multiplicity from the function's Pi type.
(define (make-usage-app-fire-fn tm-cid position func-pos arg-pos)
  (lambda (net)
    (define tm (net-cell-read net tm-cid))
    (define func-usage (that-read tm func-pos ':usage))
    (define arg-usage (that-read tm arg-pos ':usage))
    (define func-type (that-read tm func-pos ':type))
    (cond
      ;; Wait for all inputs
      [(or (null? func-usage) (null? arg-usage)) net]
      [(not (expr-Pi? func-type)) net]  ;; need Pi type for mult
      [else
       (define m (expr-Pi-mult func-type))
       ;; If mult is a meta (unsolved), use mw as default for tracking
       (define effective-m (if (or (eq? m 'm0) (eq? m 'm1) (eq? m 'mw)) m 'mw))
       (define combined (add-usage func-usage (scale-usage effective-m arg-usage)))
       (that-write net tm-cid position ':usage combined)])))

;; Lambda usage propagator: body usage minus the binder's own usage.
;; The body's usage vector has one extra position (index 0 = binder usage).
;; We extract it with cdr (= utail) and return the remaining vector.
(define (make-usage-lam-fire-fn tm-cid position body-pos)
  (lambda (net)
    (define tm (net-cell-read net tm-cid))
    (define body-usage (that-read tm body-pos ':usage))
    (cond
      [(null? body-usage) net]  ;; wait for body usage
      [(pair? body-usage)
       ;; utail: drop the binder's usage from the vector
       (that-write net tm-cid position ':usage (cdr body-usage))]
      [else net])))

;; Pi usage propagator: same as lambda — body usage minus binder position.
(define (make-usage-pi-fire-fn tm-cid position cod-pos)
  (lambda (net)
    (define tm (net-cell-read net tm-cid))
    (define cod-usage (that-read tm cod-pos ':usage))
    (cond
      [(null? cod-usage) net]
      [(pair? cod-usage)
       (that-write net tm-cid position ':usage (cdr cod-usage))]
      [else net])))

;; Binary compose usage: add-usage(child1, child2).
;; Used for SRE domain rules with arity 2 (int-add, rat-mul, etc.)
(define (make-usage-binary-fire-fn tm-cid position child1-pos child2-pos)
  (lambda (net)
    (define tm (net-cell-read net tm-cid))
    (define u1 (that-read tm child1-pos ':usage))
    (define u2 (that-read tm child2-pos ':usage))
    (cond
      [(or (null? u1) (null? u2)) net]
      [else (that-write net tm-cid position ':usage (add-usage u1 u2))])))

;; Unary pass usage: child's usage unchanged.
;; Used for SRE domain rules with arity 1 (from-nat, neg, abs, etc.)
(define (make-usage-unary-fire-fn tm-cid position child-pos)
  (lambda (net)
    (define tm (net-cell-read net tm-cid))
    (define u (that-read tm child-pos ':usage))
    (if (null? u) net
        (that-write net tm-cid position ':usage u))))

;; Generic usage installer for SRE domain rules, keyed by arity.
;; Arity 0: zero-usage. Arity 1: pass child. Arity 2: add children.
;; Arity 3+: fold add-usage across all children.
(define (install-usage-from-rule net tm-cid e ctx-pos rule)
  (define children (typing-domain-rule-children rule))
  (define arity (typing-domain-rule-arity rule))
  (define child-exprs (map (lambda (fn) (fn e)) children))
  (cond
    [(= arity 0)
     ;; Zero-arity: zero usage — P2 fire-once
     (define-values (net1 _pid)
       (net-add-fire-once-propagator net (list tm-cid) (list tm-cid)
                           (make-usage-zero-fire-fn tm-cid e ctx-pos) tm-cid
                           #:component-paths
                           (list (cons tm-cid (cons ctx-pos ':context)))))
     net1]
    [(= arity 1)
     ;; Unary: pass through child usage — P2 fire-once
     (define child (car child-exprs))
     (define-values (net1 _pid)
       (net-add-fire-once-propagator net (list tm-cid) (list tm-cid)
                           (make-usage-unary-fire-fn tm-cid e child) tm-cid
                           #:component-paths
                           (list (cons tm-cid (cons child ':usage)))))
     net1]
    [(= arity 2)
     ;; Binary: add child usages — P2 fire-once
     (define c1 (car child-exprs))
     (define c2 (cadr child-exprs))
     (define-values (net1 _pid)
       (net-add-fire-once-propagator net (list tm-cid) (list tm-cid)
                           (make-usage-binary-fire-fn tm-cid e c1 c2) tm-cid
                           #:component-paths
                           (list (cons tm-cid (cons c1 ':usage))
                                 (cons tm-cid (cons c2 ':usage)))))
     net1]
    [else
     ;; Arity 3+: fold add-usage across all children
     ;; Watch all children's :usage facets
     (define paths (map (lambda (c) (cons tm-cid (cons c ':usage))) child-exprs))
     (define-values (net1 _pid)
       (net-add-propagator net (list tm-cid) (list tm-cid)
                           (lambda (n)
                             (define tm (net-cell-read n tm-cid))
                             (define usages (map (lambda (c) (that-read tm c ':usage)) child-exprs))
                             (if (ormap null? usages)
                                 n
                                 (that-write n tm-cid e ':usage
                                             (foldl add-usage (car usages) (cdr usages)))))
                           #:component-paths paths))
     net1]))

;; --- Fire functions: one per AST node kind ---
;; Each returns a (lambda (net) ...) that reads inputs, computes, writes output.
;; The tm-cid and position keys are captured in the closure.

;; Literal: write a fixed type immediately.
(define (make-literal-fire-fn tm-cid position result-type)
  (lambda (net)
    (type-map-write net tm-cid position result-type)))

;; Universe: Type(l) → Type(lsuc(l))
(define (make-universe-fire-fn tm-cid position level)
  (lambda (net)
    (type-map-write net tm-cid position (expr-Type (lsuc level)))))

;; Bound variable: read from context cell at de Bruijn position k.
(define (make-bvar-fire-fn tm-cid position k ctx-val)
  (lambda (net)
    (define raw-type (context-lookup-type ctx-val k))
    (if (expr-error? raw-type)
        net  ;; out of bounds — leave at ⊥
        (type-map-write net tm-cid position (shift (+ k 1) 0 raw-type)))))

;; Free variable: read from global environment.
(define (make-fvar-fire-fn tm-cid position name)
  (lambda (net)
    (define ty (global-env-lookup-type name))
    (if ty
        (type-map-write net tm-cid position ty)
        net)))  ;; not found — leave at ⊥

;; Application with BIDIRECTIONAL writes (§15 Typing PU Architecture).
;; DOWNWARD (check): writes domain to arg position. Merge = unification.
;; UPWARD (infer): writes subst(0, arg-EXPR, codomain) to result position.
;; FEEDBACK (Track 4B Phase 3): when domain is a meta and arg has a concrete
;;   type, write the arg's type to the meta's position. This is "unification
;;   feedback" — the merge at the arg position resolves the meta, but that
;;   resolution must flow back to the meta's position so the constraint
;;   narrowing bridge can see it. §3.5: Unification = Merge.
;;   Pattern 2: substitution uses expression keys (values), not type-map values.
;;   Dependent codomains handled correctly: subst(0, arg-pos, bvar(0)) = arg-pos.
(define (make-app-fire-fn tm-cid position func-pos arg-pos)
  (lambda (net)
    (define func-type (type-map-read net tm-cid func-pos))
    (cond
      [(type-bot? func-type) net]  ;; wait for func type
      [(expr-Pi? func-type)
       (define dom (expr-Pi-domain func-type))
       (define cod (expr-Pi-codomain func-type))
       ;; DOWNWARD: write expected domain to arg position — but NOT for meta args.
       ;; Track 4B Phase 3: Option C — skip downward write for meta positions.
       ;; Meta args (like ?A in Pi(m0, Type(0), ...)) have kind info (Type(0))
       ;; from elaboration. Writing the kind to :type conflicts with the SOLUTION
       ;; (e.g., Nat) that the feedback mechanism writes. By skipping, the meta's
       ;; :type stays at ⊥ until the feedback writes the solution.
       ;; PPN 4C Path T-3 Commit A.2-b (2026-04-22): Role B migration.
       ;; The pattern here is "arg-pos MUST have type dom" (equality enforcement
       ;; at the call site). Under post-T-3 Commit B set-union merge, a regular
       ;; type-map-write would union incompatible types instead of producing
       ;; type-top — losing the contradiction signal the check below relies on.
       ;; type-map-write-unified preserves equality-enforce semantics.
       (define net1
         (if (expr-meta? arg-pos)
             net  ;; skip downward write for meta positions
             (type-map-write-unified net tm-cid arg-pos dom)))
       ;; Contradiction check: if arg position merged to type-top → propagate error
       (define arg-after-merge (type-map-read net1 tm-cid arg-pos))
       (cond
         [(type-top? arg-after-merge)
          ;; Type mismatch at arg position → result is contradiction
          (type-map-write net1 tm-cid position type-top)]
         [else
          ;; FEEDBACK: write resolved types back to meta positions.
          ;; Simple: domain IS a meta → write arg type to meta position.
          ;; Structural: domain CONTAINS metas → extract bindings from matching
          ;; domain against arg type, write each binding.
          ;; §3.5: Unification = Merge — the feedback IS the meta-solution.
          ;;
          ;; PPN 4C Phase 3c-ii: feedback writes are INHABITANT (per §6.15.8 Q6).
          ;; Semantic: "this meta IS SOLVED to arg-type." The meta's type/classifier
          ;; (e.g., Type(0) for a type-variable meta) is orthogonal to its solution;
          ;; the cross-tag residuation propagator (3c-iii) enforces compatibility.
          (define net2
            (let ([arg-type arg-after-merge])
              (cond
                [(or (type-bot? arg-type) (expr-meta? arg-type)) net1]
                [(expr-meta? dom) (term-map-write net1 tm-cid dom arg-type)]
                [else
                 (let extract-bindings ([d dom] [a arg-type] [n net1])
                   (cond
                     [(and (expr-meta? d) (not (expr-meta? a)) (not (type-bot? a)))
                      (term-map-write n tm-cid d a)]
                     [(and (expr-app? d) (expr-app? a))
                      (extract-bindings
                       (expr-app-func d) (expr-app-func a)
                       (extract-bindings (expr-app-arg d) (expr-app-arg a) n))]
                     [(and (expr-Pi? d) (expr-Pi? a))
                      (extract-bindings
                       (expr-Pi-domain d) (expr-Pi-domain a)
                       (extract-bindings (expr-Pi-codomain d) (expr-Pi-codomain a) n))]
                     [(and (expr-Sigma? d) (expr-Sigma? a))
                      (extract-bindings
                       (expr-Sigma-fst-type d) (expr-Sigma-fst-type a)
                       (extract-bindings (expr-Sigma-snd-type d) (expr-Sigma-snd-type a) n))]
                     [(and (expr-PVec? d) (expr-PVec? a))
                      (extract-bindings (expr-PVec-elem-type d) (expr-PVec-elem-type a) n)]
                     [(and (expr-Vec? d) (expr-Vec? a))
                      (extract-bindings (expr-Vec-elem-type d) (expr-Vec-elem-type a) n)]
                     [else n]))])))
          ;; UPWARD: subst uses arg-pos (expression key) — handles ALL codomains.
          (define result-type (subst 0 arg-pos cod))
          (type-map-write net2 tm-cid position result-type)])]
      ;; Non-Pi func type — try tensor directly (union types etc.)
      [else
       (define arg-type (type-map-read net tm-cid arg-pos))
       (cond
         [(type-bot? arg-type) net]
         [else
          (define result (type-tensor-core func-type arg-type))
          (cond
            [(type-bot? result) net]
            [(type-top? result) (type-map-write net tm-cid position type-top)]
            [else (type-map-write net tm-cid position result)])])])))

;; Lambda: read domain type (must be Type(l)) and body type, write Pi.
(define (make-lam-fire-fn tm-cid position dom-pos body-pos mult)
  (lambda (net)
    (define dom-type (type-map-read net tm-cid dom-pos))
    (define body-type (type-map-read net tm-cid body-pos))
    (cond
      [(or (type-bot? dom-type) (type-bot? body-type)) net]  ;; wait
      [else
       ;; dom-type should be the domain TYPE ITSELF (from dom-pos),
       ;; not the type-of-domain. The lambda propagator assembles Pi
       ;; from the domain and body types.
       (define dom-expr dom-pos)  ;; the domain expression
       (type-map-write net tm-cid position
                       (expr-Pi mult dom-expr body-type))])))

;; Pi formation: read domain and codomain types (both must be Type(l)).
(define (make-pi-fire-fn tm-cid position dom-pos cod-pos)
  (lambda (net)
    (define dom-type (type-map-read net tm-cid dom-pos))
    (define cod-type (type-map-read net tm-cid cod-pos))
    (cond
      [(or (type-bot? dom-type) (type-bot? cod-type)) net]
      [(not (expr-Type? dom-type)) net]  ;; domain not a type
      [(not (expr-Type? cod-type)) net]  ;; codomain not a type
      [else
       (type-map-write net tm-cid position
                       (expr-Type (lmax (expr-Type-level dom-type)
                                        (expr-Type-level cod-type))))])))

;; Union formation: read left and right types (both must be Type(l)).
;; Mirrors make-pi-fire-fn. PPN 4C Path T-3 (Commit A.2-a, 2026-04-22):
;; the TYPE of a union-type expression `<A | B>` is the universe
;; `[Type (lmax level(A) level(B))]`, same as other type-formers.
;; Prior implementation (Phase 8 Option D) wrote component types (A, B)
;; to position e's :type and used worldview-bitmask branching at infer
;; time, which was (a) architecturally wrong — components are not the
;; type of the union expression, they're its COMPONENTS — and (b)
;; accidentally load-bearing under pre-T-3 merge semantics via
;; contradiction-detection-as-fallback. Branching-against-union at
;; CHECK time is a separate concern handled elsewhere (typing-errors.rkt);
;; install-typing-network is infer-time and needs no branching here.
(define (make-union-fire-fn tm-cid position left-pos right-pos)
  (lambda (net)
    (define left-type (type-map-read net tm-cid left-pos))
    (define right-type (type-map-read net tm-cid right-pos))
    (cond
      [(or (type-bot? left-type) (type-bot? right-type)) net]
      [(not (expr-Type? left-type)) net]   ;; left component not a type
      [(not (expr-Type? right-type)) net]  ;; right component not a type
      [else
       (type-map-write net tm-cid position
                       (expr-Type (lmax (expr-Type-level left-type)
                                        (expr-Type-level right-type))))])))

;; --- Pattern 5: Context as cell positions ---
;;
;; Each scope has a context POSITION in the type-map. A context-extension
;; propagator watches the parent scope's context position and the binder's
;; domain type position. When both have values, it writes the extended
;; context (via tensor) to the child scope's context position.
;;
;; This makes context flow DOWNWARD through the scope tree via cell writes.
;; When a domain type refines (meta solved), the context position updates,
;; and all body propagators fire. The scope tree IS a cell tree.

;; Context-extension propagator: watches parent-ctx-pos + domain-pos,
;; writes extended context to child-ctx-pos.
;; domain-expr is the EXPRESSION that is the domain type (e.g., (expr-Int)),
;; NOT the type-of-domain (which would be Type(0)). The context stores the
;; domain expression — `bvar(0)` in `[x : Int]` scope has type `Int`, not `Type(0)`.
;; Track 4B Phase 1: context-extension writes to :context facet.
;; No more mixing context-cell-values into the :type facet.
(define (make-context-extension-fire-fn tm-cid parent-ctx-pos domain-expr child-ctx-pos mult)
  (lambda (net)
    (define parent-ctx (that-read (net-cell-read net tm-cid) parent-ctx-pos ':context))
    (cond
      [(not (context-cell-value? parent-ctx)) net]
      [else
       ;; Extend context with the domain EXPRESSION (the type annotation)
       (define child-ctx (context-extend-value parent-ctx domain-expr mult))
       (that-write net tm-cid child-ctx-pos ':context child-ctx)])))

;; Track 4B Phase 1: bvar reads from :context facet.
(define (make-bvar-fire-fn/ctx-pos tm-cid position k ctx-pos)
  (lambda (net)
    (define ctx-val (that-read (net-cell-read net tm-cid) ctx-pos ':context))
    (cond
      [(not (context-cell-value? ctx-val)) net]  ;; wait for context
      [else
       (define raw-type (context-lookup-type ctx-val k))
       (if (expr-error? raw-type)
           net  ;; out of bounds
           (type-map-write net tm-cid position (shift (+ k 1) 0 raw-type)))])))


;; ============================================================
;; §16 SRE Typing Domain: Expression-Kind → Type as Domain Data
;; ============================================================
;;
;; Each expression kind is registered with its arity, child accessors,
;; and return type. The catch-all in install-typing-network looks up
;; the domain and installs the appropriate propagator.
;;
;; Self-hosting path: this domain IS the data a self-hosted compiler
;; consumes. Library authors register rules for new constructs.

;; A typing domain rule: one entry per expression kind.
(struct typing-domain-rule
  (predicate   ;; (expr → bool): matches this expression kind
   arity       ;; Nat: number of sub-expression children
   children    ;; (listof (expr → expr)): accessor functions for children
   return-type ;; Expr | #f: constant return type, or #f for special handling
   name)       ;; symbol: human-readable name
  #:transparent)

;; The typing domain: a list of rules (checked in order).
;; Using a list (not hash) because predicates can overlap and order matters.
(define current-typing-domain (make-parameter '()))
(define unhandled-expr-counts (make-hash))

(define (make-typing-domain) '())

(define (register-typing-rule! pred arity children return-type name)
  (current-typing-domain
   (cons (typing-domain-rule pred arity children return-type name)
         (current-typing-domain))))

;; Look up a rule for an expression. Returns the rule or #f.
(define (lookup-typing-rule e)
  (for/first ([rule (in-list (current-typing-domain))]
              #:when ((typing-domain-rule-predicate rule) e))
    rule))

;; Install a propagator from a domain rule.
;; Arity 0: literal propagator (constant return type).
;; Arity 1: recurse on child, install literal propagator.
;; Arity 2: recurse on both children, install literal propagator.
;; return-type = #f: unhandled by domain, leave at ⊥.
(define (install-from-rule net tm-cid e ctx-pos rule)
  (define children (typing-domain-rule-children rule))
  (define ret-type (typing-domain-rule-return-type rule))
  (cond
    [(not ret-type) net]  ;; special handling needed — not in domain
    [(procedure? ret-type)
     ;; COMPUTED return type: function from (listof child-type) → result type.
     ;; Install children first, then a propagator that watches ALL children's
     ;; type-map positions and applies the function when all are non-bot.
     (define child-exprs (map (lambda (fn) (fn e)) children))
     (define net-with-children
       (for/fold ([n net]) ([child-fn (in-list children)])
         (install-typing-network n tm-cid (child-fn e) ctx-pos)))
     ;; PPN 4C Phase 3e: watch each child's :type facet for ret-type computation.
     (define child-type-paths
       (map (lambda (c) (cons tm-cid (cons c ':type))) child-exprs))
     (define-values (net* _pid)
       (net-add-propagator net-with-children (list tm-cid) (list tm-cid)
         (lambda (net)
           (define child-types
             (map (lambda (c) (type-map-read net tm-cid c)) child-exprs))
           (cond
             [(ormap type-bot? child-types) net]  ;; wait for all children
             [else
              (define result (ret-type child-types))
              (if result
                  (type-map-write net tm-cid e result)
                  net)]))  ;; function returned #f — can't compute
         #:component-paths child-type-paths))
     net*]
    [else
     ;; Constant return type. Install children (if any) first.
     (define net-with-children
       (for/fold ([n net]) ([child-fn (in-list children)])
         (install-typing-network n tm-cid (child-fn e) ctx-pos)))
     (cond
       [(null? children)
        ;; True literal (arity 0): no operands to watch — fast path, write the
        ;; constant once. PPN 4C Phase 3e/follow-up (2026-04-20): literal-fire writes
        ;; a constant and reads no cell; inputs = (list) — fires once via initial-firing.
        (define-values (net* _pid)
          (net-add-propagator net-with-children (list) (list tm-cid)
                              (make-literal-fire-fn tm-cid e ret-type)))
        net*]
       [else
        ;; N4b (Option B): constant-return op WITH operands — watch each child's :type
        ;; and FORWARD a child type-top to the op position instead of masking it. A
        ;; context-typed num-lit operand whose default collides with the expected
        ;; operand type produces type-top at that child; forwarding it makes the
        ;; on-network result non-clean, so the imperative fallback runs (its op rule
        ;; checks operands + solves the literal's meta). Concrete/marker operands keep
        ;; clean child :types → no type-top → the constant ret-type is written as before.
        (define child-exprs (map (lambda (fn) (fn e)) children))
        (define child-type-paths
          (map (lambda (c) (cons tm-cid (cons c ':type))) child-exprs))
        (define-values (net* _pid)
          (net-add-propagator net-with-children (list tm-cid) (list tm-cid)
            (lambda (net)
              (define child-types
                (map (lambda (c) (type-map-read net tm-cid c)) child-exprs))
              (cond
                [(ormap type-bot? child-types) net]  ;; wait for all children
                [(ormap type-top? child-types)
                 (type-map-write net tm-cid e type-top)]
                [else (type-map-write net tm-cid e ret-type)]))
            #:component-paths child-type-paths))
        net*])]))

;; Register ALL known expression kinds.
;; Called once at module load time.
;; Helper: register a family of binary ops with the same return type.
(define (register-binary-ops! pred+acc-list return-type)
  (for ([info (in-list pred+acc-list)])
    (register-typing-rule! (car info) 2 (list (cadr info) (caddr info))
                           return-type (cadddr info))))

;; Helper: register a family of unary ops with the same return type.
(define (register-unary-ops! pred+acc-list return-type)
  (for ([info (in-list pred+acc-list)])
    (register-typing-rule! (car info) 1 (list (cadr info))
                           return-type (caddr info))))

(define (install-default-typing-domain!)

  ;; ===== LITERALS =====
  (register-typing-rule! expr-string? 0 '() (expr-String) 'string-literal)
  (register-typing-rule! expr-symbol? 0 '() (expr-Symbol) 'symbol-literal)
  (register-typing-rule! expr-zero? 0 '() (expr-Nat) 'zero-literal)
  (register-typing-rule! expr-unit? 0 '() (expr-Unit) 'unit-literal)
  (register-typing-rule! expr-nil? 0 '() (expr-Nil) 'nil-literal)
  (register-typing-rule! expr-refl? 0 '() #f 'refl)  ;; dependent: Eq a a
  (register-typing-rule! expr-hole? 0 '() #f 'hole)
  (register-typing-rule! expr-error? 0 '() #f 'error)
  (register-typing-rule! expr-cut? 0 '() #f 'cut)

  ;; Posit literals
  (register-typing-rule! expr-posit8? 0 '() (expr-Posit8) 'posit8-literal)
  (register-typing-rule! expr-posit16? 0 '() (expr-Posit16) 'posit16-literal)
  (register-typing-rule! expr-posit32? 0 '() (expr-Posit32) 'posit32-literal)
  (register-typing-rule! expr-posit64? 0 '() (expr-Posit64) 'posit64-literal)
  (register-typing-rule! expr-float32? 0 '() (expr-Float32) 'float32-literal)
  (register-typing-rule! expr-float64? 0 '() (expr-Float64) 'float64-literal)

  ;; Quire literals
  (register-typing-rule! expr-quire8-val? 0 '() (expr-Quire8) 'quire8-literal)
  (register-typing-rule! expr-quire16-val? 0 '() (expr-Quire16) 'quire16-literal)
  (register-typing-rule! expr-quire32-val? 0 '() (expr-Quire32) 'quire32-literal)
  (register-typing-rule! expr-quire64-val? 0 '() (expr-Quire64) 'quire64-literal)

  ;; Rat literal
  (register-typing-rule! expr-rat? 0 '() (expr-Rat) 'rat-literal)

  ;; ===== TYPE CONSTRUCTORS → Type(lzero) =====
  (for ([pred (list expr-Char? expr-Symbol? expr-Keyword? expr-Unit? expr-Nil?
                   expr-Posit8? expr-Posit16? expr-Posit32? expr-Posit64?
                   expr-Float32? expr-Float64?
                   expr-Quire8? expr-Quire16? expr-Quire32? expr-Quire64?
                   expr-Rat? expr-Path? expr-goal-type? expr-solver-type?
                   expr-derivation-type?)]
        [name (list 'Char 'Symbol 'Keyword 'Unit 'Nil
                    'Posit8 'Posit16 'Posit32 'Posit64
                    'Quire8 'Quire16 'Quire32 'Quire64
                    'Rat 'Path 'GoalType 'SolverType
                    'DerivationType)])
    (register-typing-rule! pred 0 '() (expr-Type (lzero)) name))

  ;; ===== INT ARITHMETIC =====
  (register-binary-ops!
   (list (list expr-int-add? expr-int-add-a expr-int-add-b 'int-add)
         (list expr-int-sub? expr-int-sub-a expr-int-sub-b 'int-sub)
         (list expr-int-mul? expr-int-mul-a expr-int-mul-b 'int-mul)
         (list expr-int-div? expr-int-div-a expr-int-div-b 'int-div)
         (list expr-int-mod? expr-int-mod-a expr-int-mod-b 'int-mod))
   (expr-Int))
  (register-unary-ops!
   (list (list expr-int-neg? expr-int-neg-a 'int-neg)
         (list expr-int-abs? expr-int-abs-a 'int-abs))
   (expr-Int))
  (register-binary-ops!
   (list (list expr-int-lt? expr-int-lt-a expr-int-lt-b 'int-lt)
         (list expr-int-le? expr-int-le-a expr-int-le-b 'int-le)
         (list expr-int-eq? expr-int-eq-a expr-int-eq-b 'int-eq))
   (expr-Bool))
  (register-typing-rule! expr-from-nat? 1 (list expr-from-nat-n) (expr-Int) 'from-nat)

  ;; ===== RAT ARITHMETIC =====
  (register-binary-ops!
   (list (list expr-rat-add? expr-rat-add-a expr-rat-add-b 'rat-add)
         (list expr-rat-sub? expr-rat-sub-a expr-rat-sub-b 'rat-sub)
         (list expr-rat-mul? expr-rat-mul-a expr-rat-mul-b 'rat-mul)
         (list expr-rat-div? expr-rat-div-a expr-rat-div-b 'rat-div))
   (expr-Rat))
  (register-unary-ops!
   (list (list expr-rat-neg? expr-rat-neg-a 'rat-neg)
         (list expr-rat-abs? expr-rat-abs-a 'rat-abs))
   (expr-Rat))
  (register-binary-ops!
   (list (list expr-rat-lt? expr-rat-lt-a expr-rat-lt-b 'rat-lt)
         (list expr-rat-le? expr-rat-le-a expr-rat-le-b 'rat-le)
         (list expr-rat-eq? expr-rat-eq-a expr-rat-eq-b 'rat-eq))
   (expr-Bool))
  (register-typing-rule! expr-from-int? 1 (list expr-from-int-n) (expr-Rat) 'from-int)
  (register-typing-rule! expr-rat-numer? 1 (list expr-rat-numer-a) (expr-Int) 'rat-numer)
  (register-typing-rule! expr-rat-denom? 1 (list expr-rat-denom-a) (expr-Int) 'rat-denom)

  ;; ===== POSIT8 ARITHMETIC =====
  (register-binary-ops!
   (list (list expr-p8-add? expr-p8-add-a expr-p8-add-b 'p8-add)
         (list expr-p8-sub? expr-p8-sub-a expr-p8-sub-b 'p8-sub)
         (list expr-p8-mul? expr-p8-mul-a expr-p8-mul-b 'p8-mul)
         (list expr-p8-div? expr-p8-div-a expr-p8-div-b 'p8-div))
   (expr-Posit8))
  (register-unary-ops!
   (list (list expr-p8-neg? expr-p8-neg-a 'p8-neg)
         (list expr-p8-abs? expr-p8-abs-a 'p8-abs)
         (list expr-p8-sqrt? expr-p8-sqrt-a 'p8-sqrt))
   (expr-Posit8))
  (register-binary-ops!
   (list (list expr-p8-lt? expr-p8-lt-a expr-p8-lt-b 'p8-lt)
         (list expr-p8-le? expr-p8-le-a expr-p8-le-b 'p8-le)
         (list expr-p8-eq? expr-p8-eq-a expr-p8-eq-b 'p8-eq))
   (expr-Bool))
  (register-typing-rule! expr-p8-from-nat? 1 (list expr-p8-from-nat-n) (expr-Posit8) 'p8-from-nat)
  (register-typing-rule! expr-p8-to-rat? 1 (list expr-p8-to-rat-a) (expr-Rat) 'p8-to-rat)
  (register-typing-rule! expr-p8-from-rat? 1 (list expr-p8-from-rat-a) (expr-Posit8) 'p8-from-rat)
  (register-typing-rule! expr-p8-from-int? 1 (list expr-p8-from-int-a) (expr-Posit8) 'p8-from-int)

  ;; ===== POSIT16 ARITHMETIC =====
  (register-binary-ops!
   (list (list expr-p16-add? expr-p16-add-a expr-p16-add-b 'p16-add)
         (list expr-p16-sub? expr-p16-sub-a expr-p16-sub-b 'p16-sub)
         (list expr-p16-mul? expr-p16-mul-a expr-p16-mul-b 'p16-mul)
         (list expr-p16-div? expr-p16-div-a expr-p16-div-b 'p16-div))
   (expr-Posit16))
  (register-unary-ops!
   (list (list expr-p16-neg? expr-p16-neg-a 'p16-neg)
         (list expr-p16-abs? expr-p16-abs-a 'p16-abs)
         (list expr-p16-sqrt? expr-p16-sqrt-a 'p16-sqrt))
   (expr-Posit16))
  (register-binary-ops!
   (list (list expr-p16-lt? expr-p16-lt-a expr-p16-lt-b 'p16-lt)
         (list expr-p16-le? expr-p16-le-a expr-p16-le-b 'p16-le)
         (list expr-p16-eq? expr-p16-eq-a expr-p16-eq-b 'p16-eq))
   (expr-Bool))
  (register-typing-rule! expr-p16-from-nat? 1 (list expr-p16-from-nat-n) (expr-Posit16) 'p16-from-nat)
  (register-typing-rule! expr-p16-to-rat? 1 (list expr-p16-to-rat-a) (expr-Rat) 'p16-to-rat)
  (register-typing-rule! expr-p16-from-rat? 1 (list expr-p16-from-rat-a) (expr-Posit16) 'p16-from-rat)
  (register-typing-rule! expr-p16-from-int? 1 (list expr-p16-from-int-a) (expr-Posit16) 'p16-from-int)

  ;; ===== POSIT32 ARITHMETIC =====
  (register-binary-ops!
   (list (list expr-p32-add? expr-p32-add-a expr-p32-add-b 'p32-add)
         (list expr-p32-sub? expr-p32-sub-a expr-p32-sub-b 'p32-sub)
         (list expr-p32-mul? expr-p32-mul-a expr-p32-mul-b 'p32-mul)
         (list expr-p32-div? expr-p32-div-a expr-p32-div-b 'p32-div))
   (expr-Posit32))
  (register-unary-ops!
   (list (list expr-p32-neg? expr-p32-neg-a 'p32-neg)
         (list expr-p32-abs? expr-p32-abs-a 'p32-abs)
         (list expr-p32-sqrt? expr-p32-sqrt-a 'p32-sqrt))
   (expr-Posit32))
  (register-binary-ops!
   (list (list expr-p32-lt? expr-p32-lt-a expr-p32-lt-b 'p32-lt)
         (list expr-p32-le? expr-p32-le-a expr-p32-le-b 'p32-le)
         (list expr-p32-eq? expr-p32-eq-a expr-p32-eq-b 'p32-eq))
   (expr-Bool))
  (register-typing-rule! expr-p32-from-nat? 1 (list expr-p32-from-nat-n) (expr-Posit32) 'p32-from-nat)
  (register-typing-rule! expr-p32-to-rat? 1 (list expr-p32-to-rat-a) (expr-Rat) 'p32-to-rat)
  (register-typing-rule! expr-p32-from-rat? 1 (list expr-p32-from-rat-a) (expr-Posit32) 'p32-from-rat)
  (register-typing-rule! expr-p32-from-int? 1 (list expr-p32-from-int-a) (expr-Posit32) 'p32-from-int)

  ;; ===== FLOAT32 OPS (Numerics N3b) =====
  (register-binary-ops!
   (list (list expr-f32-add? expr-f32-add-a expr-f32-add-b 'f32-add)
         (list expr-f32-sub? expr-f32-sub-a expr-f32-sub-b 'f32-sub)
         (list expr-f32-mul? expr-f32-mul-a expr-f32-mul-b 'f32-mul)
         (list expr-f32-div? expr-f32-div-a expr-f32-div-b 'f32-div))
   (expr-Float32))
  (register-unary-ops!
   (list (list expr-f32-neg? expr-f32-neg-a 'f32-neg)
         (list expr-f32-abs? expr-f32-abs-a 'f32-abs)
         (list expr-f32-sqrt? expr-f32-sqrt-a 'f32-sqrt))
   (expr-Float32))
  (register-binary-ops!
   (list (list expr-f32-lt? expr-f32-lt-a expr-f32-lt-b 'f32-lt)
         (list expr-f32-le? expr-f32-le-a expr-f32-le-b 'f32-le)
         (list expr-f32-eq? expr-f32-eq-a expr-f32-eq-b 'f32-eq))
   (expr-Bool))

  ;; ===== FLOAT64 OPS (Numerics N3b) =====
  (register-binary-ops!
   (list (list expr-f64-add? expr-f64-add-a expr-f64-add-b 'f64-add)
         (list expr-f64-sub? expr-f64-sub-a expr-f64-sub-b 'f64-sub)
         (list expr-f64-mul? expr-f64-mul-a expr-f64-mul-b 'f64-mul)
         (list expr-f64-div? expr-f64-div-a expr-f64-div-b 'f64-div))
   (expr-Float64))
  (register-unary-ops!
   (list (list expr-f64-neg? expr-f64-neg-a 'f64-neg)
         (list expr-f64-abs? expr-f64-abs-a 'f64-abs)
         (list expr-f64-sqrt? expr-f64-sqrt-a 'f64-sqrt))
   (expr-Float64))
  (register-binary-ops!
   (list (list expr-f64-lt? expr-f64-lt-a expr-f64-lt-b 'f64-lt)
         (list expr-f64-le? expr-f64-le-a expr-f64-le-b 'f64-le)
         (list expr-f64-eq? expr-f64-eq-a expr-f64-eq-b 'f64-eq))
   (expr-Bool))

  ;; ===== POSIT64 ARITHMETIC =====
  (register-binary-ops!
   (list (list expr-p64-add? expr-p64-add-a expr-p64-add-b 'p64-add)
         (list expr-p64-sub? expr-p64-sub-a expr-p64-sub-b 'p64-sub)
         (list expr-p64-mul? expr-p64-mul-a expr-p64-mul-b 'p64-mul)
         (list expr-p64-div? expr-p64-div-a expr-p64-div-b 'p64-div))
   (expr-Posit64))
  (register-unary-ops!
   (list (list expr-p64-neg? expr-p64-neg-a 'p64-neg)
         (list expr-p64-abs? expr-p64-abs-a 'p64-abs)
         (list expr-p64-sqrt? expr-p64-sqrt-a 'p64-sqrt))
   (expr-Posit64))
  (register-binary-ops!
   (list (list expr-p64-lt? expr-p64-lt-a expr-p64-lt-b 'p64-lt)
         (list expr-p64-le? expr-p64-le-a expr-p64-le-b 'p64-le)
         (list expr-p64-eq? expr-p64-eq-a expr-p64-eq-b 'p64-eq))
   (expr-Bool))
  (register-typing-rule! expr-p64-from-nat? 1 (list expr-p64-from-nat-n) (expr-Posit64) 'p64-from-nat)
  (register-typing-rule! expr-p64-to-rat? 1 (list expr-p64-to-rat-a) (expr-Rat) 'p64-to-rat)
  (register-typing-rule! expr-p64-from-rat? 1 (list expr-p64-from-rat-a) (expr-Posit64) 'p64-from-rat)
  (register-typing-rule! expr-p64-from-int? 1 (list expr-p64-from-int-a) (expr-Posit64) 'p64-from-int)

  ;; ===== QUIRE OPERATIONS =====
  ;; quire-fma: ternary → Quire (q, a, b → q)
  ;; quire-to: unary → Posit
  (register-typing-rule! expr-quire8-to? 1 (list expr-quire8-to-q) (expr-Posit8) 'q8-to)
  (register-typing-rule! expr-quire16-to? 1 (list expr-quire16-to-q) (expr-Posit16) 'q16-to)
  (register-typing-rule! expr-quire32-to? 1 (list expr-quire32-to-q) (expr-Posit32) 'q32-to)
  (register-typing-rule! expr-quire64-to? 1 (list expr-quire64-to-q) (expr-Posit64) 'q64-to)

  ;; ===== NAT OPERATIONS =====
  (register-typing-rule! expr-suc? 1 (list expr-suc-pred) (expr-Nat) 'suc)
  (register-typing-rule! expr-nil-check? 1 (list expr-nil-check-arg) (expr-Bool) 'nil-check)

  ;; ===== MAP OPERATIONS =====
  ;; map-get, map-assoc, etc. have structural return types (depend on collection type).
  ;; Registered with return-type=#f — falls back to imperative which handles union maps,
  ;; nested maps, and type-directed dispatch. Only constant-type ops (has-key, size) computed.
  (register-typing-rule! expr-map-get? 2 (list expr-map-get-m expr-map-get-k) #f 'map-get)
  (register-typing-rule! expr-map-has-key? 2 (list expr-map-has-key-m expr-map-has-key-k) (expr-Bool) 'map-has-key)
  (register-typing-rule! expr-map-size? 1 (list expr-map-size-m) (expr-Nat) 'map-size)
  (register-typing-rule! expr-map-assoc? 3 (list expr-map-assoc-m expr-map-assoc-k expr-map-assoc-v) #f 'map-assoc)
  (register-typing-rule! expr-map-dissoc? 2 (list expr-map-dissoc-m expr-map-dissoc-k) #f 'map-dissoc)
  (register-typing-rule! expr-map-keys? 1 (list expr-map-keys-m) #f 'map-keys)
  (register-typing-rule! expr-map-vals? 1 (list expr-map-vals-m) #f 'map-vals)

  ;; ===== SET OPERATIONS =====
  ;; Same pattern: structural ops as #f, constant ops computed.
  (register-typing-rule! expr-set-member? 2 (list expr-set-member-s expr-set-member-a) (expr-Bool) 'set-member)
  (register-typing-rule! expr-set-size? 1 (list expr-set-size-s) (expr-Nat) 'set-size)
  (register-typing-rule! expr-set-insert? 2 (list expr-set-insert-s expr-set-insert-a) #f 'set-insert)
  (register-typing-rule! expr-set-delete? 2 (list expr-set-delete-s expr-set-delete-a) #f 'set-delete)
  (register-typing-rule! expr-set-union? 2 (list expr-set-union-s1 expr-set-union-s2) #f 'set-union)
  (register-typing-rule! expr-set-intersect? 2 (list expr-set-intersect-s1 expr-set-intersect-s2) #f 'set-intersect)
  (register-typing-rule! expr-set-diff? 2 (list expr-set-diff-s1 expr-set-diff-s2) #f 'set-diff)
  (register-typing-rule! expr-set-to-list? 1 (list expr-set-to-list-s) #f 'set-to-list)

  ;; ===== GENERIC ARITHMETIC: computed return types via numeric-join =====
  ;; Binary arithmetic: numeric-join of both operand types.
  ;; Comparisons: always Bool.
  ;; Unary: identity (same as operand type).
  (define (generic-comparison-ret ts) (expr-Bool))
  ;; N5de sign-preserving arithmetic on the on-network typing path (mirrors typing-core.rkt:859-913).
  ;; SCAFFOLDING BRIDGE: the on-network ret-fn calls the imperative refine-arith; native cell-flow
  ;; refinement is deferred to the PPN track (§15). numeric-join → base; refine-arith re-refines the
  ;; sign (bare operands ⇒ sign-top ⇒ bare base). mod is unrefined; unary guard-fail returns operand t.
  (define (make-arith-ret transfer2 div?)
    (lambda (ts)
      (let ([j (numeric-join (car ts) (cadr ts))])
        (and j (or (not div?) (divisible-numeric-type? j))
             (refine-arith (car ts) (cadr ts) j transfer2)))))
  (define (generic-mod-ret ts) (numeric-join (car ts) (cadr ts)))
  (define (generic-negate-ret ts)
    (let* ([t (car ts)] [tb (base-numeric-type t)])
      (if (negatable-numeric-type? tb) (refine-arith1 t tb sign-transfer-neg) t)))
  (define (generic-abs-ret ts)
    (let* ([t (car ts)] [tb (base-numeric-type t)])
      (if (concrete-numeric-type? tb) (refine-arith1 t tb sign-transfer-abs) t)))

  ;; Binary arithmetic ops: refine-arith(numeric-join(a,b)) via the per-op Sign transfer.
  (for ([info (list (list expr-generic-add? expr-generic-add-a expr-generic-add-b 'generic-add (make-arith-ret sign-transfer-add #f))
                    (list expr-generic-sub? expr-generic-sub-a expr-generic-sub-b 'generic-sub (make-arith-ret sign-transfer-sub #f))
                    (list expr-generic-mul? expr-generic-mul-a expr-generic-mul-b 'generic-mul (make-arith-ret sign-transfer-mul #f))
                    (list expr-generic-div? expr-generic-div-a expr-generic-div-b 'generic-div (make-arith-ret sign-transfer-div #t))
                    (list expr-generic-mod? expr-generic-mod-a expr-generic-mod-b 'generic-mod generic-mod-ret))])
    (register-typing-rule! (car info) 2 (list (cadr info) (caddr info))
                           (list-ref info 4) (cadddr info)))

  ;; Comparison ops: return type = Bool
  (for ([info (list (list expr-generic-lt? expr-generic-lt-a expr-generic-lt-b 'generic-lt)
                    (list expr-generic-le? expr-generic-le-a expr-generic-le-b 'generic-le)
                    (list expr-generic-gt? expr-generic-gt-a expr-generic-gt-b 'generic-gt)
                    (list expr-generic-ge? expr-generic-ge-a expr-generic-ge-b 'generic-ge)
                    (list expr-generic-eq? expr-generic-eq-a expr-generic-eq-b 'generic-eq))])
    (register-typing-rule! (car info) 2 (list (cadr info) (caddr info))
                           generic-comparison-ret (cadddr info)))

  ;; Unary ops: N5de sign transfer (generic-negate-ret / generic-abs-ret defined above).
  (register-typing-rule! expr-generic-negate? 1 (list expr-generic-negate-a)
                         generic-negate-ret 'generic-negate)
  (register-typing-rule! expr-generic-abs? 1 (list expr-generic-abs-a)
                         generic-abs-ret 'generic-abs)

  ;; Conversion: return type = target-type field (first child EXPRESSION).
  ;; generic-from-int(target-type, arg) → target-type
  ;; The target-type is the expression itself (e.g., (expr-Int)), not Type(0).
  ;; Use identity function: the first child's "type" in the computed path
  ;; is actually the target-type expression flowing through as a value.
  ;; This works because the computed return-type function receives whatever
  ;; is at the first child's :type position — if the target-type is a type
  ;; constructor like (expr-Int), its :type is Type(0). So we need a custom
  ;; propagator instead.
  ;; KEPT AS #f: handled by custom case in install-typing-network below.
  (register-typing-rule! expr-generic-from-int? 2
                         (list expr-generic-from-int-target-type expr-generic-from-int-arg)
                         #f 'generic-from-int)
  (register-typing-rule! expr-generic-from-rat? 2
                         (list expr-generic-from-rat-target-type expr-generic-from-rat-arg)
                         #f 'generic-from-rat)

  ;; ===== STRUCTURAL/COMPLEX: return-type #f =====
  ;; These need special handling: dependent types, eliminators, pattern matching, etc.
  (register-typing-rule! expr-panic? 1 (list expr-panic-msg) #f 'panic)
  (register-typing-rule! expr-ann? 2 (list expr-ann-term expr-ann-type) #f 'ann)
  (register-typing-rule! expr-reduce? 2 (list expr-reduce-scrutinee expr-reduce-arms) #f 'reduce)
  (register-typing-rule! expr-union? 2 (list expr-union-left expr-union-right) #f 'union)
  (register-typing-rule! expr-pair? 2 (list expr-pair-fst expr-pair-snd) #f 'pair)
  (register-typing-rule! expr-tycon? 0 '() #f 'tycon)
  )

;; Install default domain at module load time
(install-default-typing-domain!)


;; --- install-typing-network: the core Phase 2 deliverable ---
;;
;; Takes a prop-network, a form cell id, and a core expr (from elaborate-top-level).
;; Structurally decomposes the expr into sub-expression positions.
;; For each position:
;;   1. Writes type-bot to the type-map (initial ⊥)
;;   2. Installs a typing propagator via net-add-propagator
;;
;; Returns: (values updated-network root-position)
;;
;; The network then runs to quiescence. The result type is at root-position
;; in the type-map.
;;
;; Network Reality Check:
;;   - net-add-propagator: called once per sub-expression
;;   - net-cell-write: each fire-fn writes to type-map
;;   - Trace: type-map[pos] = ⊥ → propagator fires → writes type → cascade → read


(define (install-typing-network net tm-cid expr ctx-val)
  ;; Write initial context to root context position via :context facet
  (define root-ctx-pos (gensym 'ctx-root))
  (define net-with-ctx (that-write net tm-cid root-ctx-pos ':context ctx-val))
  ;; Track 4B Phase 2: read registered trait constraints ONCE at setup.
  ;; This is an off-network read during propagator installation, not during
  ;; firing. The constraints were registered by the imperative elaborator.
  ;; The resulting propagators are on-network.
  (define trait-constraints (read-trait-constraints))  ;; hasheq: meta-id → trait-constraint-info
  ;; Track 4B Phase 6: meta-bridge propagators write to output cell (parameter).
  ;; No more constraint-meta collection — bridging is through propagator output cell.
  ;; Recursive structural decomposition.
  ;; For each sub-expression, assign it as its own position key (eq? identity).
  ;; ctx-pos is the POSITION of the current scope's context in the type-map.
  (let install ([net net-with-ctx] [e expr] [ctx-pos root-ctx-pos])
    (match e
      ;; --- Literals: P1 initial writes (no propagators needed) ---
      ;; Type and usage are constants — write directly during installation.
      ;; Zero propagator overhead: no dependents entry, no scheduling, no cleanup.
      [(expr-int _)    (type-map-write net tm-cid e (expr-Int))]
      [(expr-nat-val _)(type-map-write net tm-cid e (expr-Nat))]
      ;; N4: numeric literal — on-network runs only in INFER position (no check-on-network),
      ;; so write its DEFAULT type (Int if integral else Rat); annotated/context positions are
      ;; typed function-level by the check arm (which solves alpha, collapsed at zonk).
      [(expr-num-lit _ integral? _) (type-map-write net tm-cid e (if integral? (expr-Int) (expr-Rat)))]
      [(expr-true)     (type-map-write net tm-cid e (expr-Bool))]
      [(expr-false)    (type-map-write net tm-cid e (expr-Bool))]

      ;; --- Type constructors: P1 initial writes ---
      [(expr-Int)      (type-map-write net tm-cid e (expr-Type (lzero)))]
      [(expr-Nat)      (type-map-write net tm-cid e (expr-Type (lzero)))]
      [(expr-Bool)     (type-map-write net tm-cid e (expr-Type (lzero)))]
      [(expr-String)   (type-map-write net tm-cid e (expr-Type (lzero)))]

      ;; --- Universe: P1 initial write ---
      [(expr-Type l)   (type-map-write net tm-cid e (expr-Type (lsuc l)))]

      ;; --- Meta expression: leave :type at ⊥ (metas resolve through typing).
      ;; Track 4B: install usage + meta-bridge + optional constraint propagators.
      [(expr-meta id _)
       ;; Usage: zero-usage — P2 fire-once
       (define-values (net-u _u-pid)
         (net-add-fire-once-propagator net (list tm-cid) (list tm-cid)
                             (make-usage-zero-fire-fn tm-cid e ctx-pos) tm-cid
                             #:component-paths (list (cons tm-cid (cons ctx-pos ':context)))))
       ;; Phase 6: meta-bridge propagator — P2 fire-once
       (define output-cid (current-meta-solution-output-cell-id))
       (define net-b
         (if output-cid
             (let-values ([(n _) (net-add-fire-once-propagator net-u (list tm-cid) (list output-cid)
                                   (make-meta-solution-output-fire-fn tm-cid e id output-cid) tm-cid
                                   ;; PPN 4C Phase 3c-ii: watch :type facet (which stores both
                                   ;; CLASSIFIER and INHABITANT layers as classify-inhabit-value
                                   ;; per §4.2/§6.15.8). Fire function reads :term (inhabitant
                                   ;; layer) for the meta's solution.
                                   #:component-paths
                                   (list (cons tm-cid (cons e ':type))))])
               n)
             net-u))
       ;; PPN 4C Phase 3c-iii: cross-tag residuation propagator per §6.15.8 Q2.
       ;; Watches the meta's :type facet (both tag layers in one classify-inhabit-value).
       ;; Fires when both CLASSIFIER and INHABITANT populated (threshold) and checks
       ;; compatibility via subtype-lattice-merge. Contradictions are written inline;
       ;; narrowings emit stratum requests (Phase 9 TMS-tagged propagation adds later).
       ;; Not fire-once: the meta's classifier or inhabitant may refine over rounds;
       ;; idempotent by construction (subtype-lattice-merge stabilizes).
       (define net-r
         (let-values ([(n _) (net-add-propagator net-b (list tm-cid) (list tm-cid classify-inhabit-request-cell-id)
                               (make-classify-inhabit-residuation-fire-fn tm-cid e)
                               #:component-paths
                               (list (cons tm-cid (cons e ':type))))])
           n))
       ;; Phase 2+3: constraint propagators
       (define tc-info (hash-ref trait-constraints id #f))
       (cond
         [(not tc-info) net-r]
         [else
          (define trait-name (trait-constraint-info-trait-name tc-info))
          (define type-arg-exprs (trait-constraint-info-type-arg-exprs tc-info))
          ;; 1. Constraint-creation — P2 fire-once.
          ;; PPN 4C Phase 3e/follow-up (2026-04-20): fire-fn actually reads
          ;; :constraints at dict-meta-pos to check if still bot before writing
          ;; (typing-propagators.rkt:687) — NOT a pure write as the prior
          ;; comment suggested. The whole-cell (cons tm-cid #f) declaration was
          ;; an over-declaration. Corrected: specific path on :constraints facet
          ;; at e (dict-meta-pos). Fire-once semantics still preserved via
          ;; net-add-fire-once-propagator; the path declaration is the accurate
          ;; propagator-watches-what statement per Phase 1f discipline.
          (define-values (net1 _cc-pid)
            (net-add-fire-once-propagator net-r (list tm-cid) (list tm-cid)
                                (make-constraint-creation-fire-fn tm-cid e trait-name) tm-cid
                                #:component-paths
                                (list (cons tm-cid (cons e ':constraints)))))
          ;; 2. Type-narrows-constraints bridge (NOT fire-once — may fire multiple times)
          (define net2
            (for/fold ([n net1]) ([ta (in-list type-arg-exprs)])
              (cond
                [(or (expr-meta? ta) (expr-bvar? ta) (expr-fvar? ta)
                     (expr-app? ta) (expr-lam? ta) (expr-Pi? ta))
                 (define-values (n2 _bridge-pid)
                   (net-add-propagator n (list tm-cid) (list tm-cid)
                                       (make-type-narrows-constraints-fire-fn tm-cid e ta)
                                       #:component-paths
                                       (list (cons tm-cid (cons ta ':type)))))
                 n2]
                [else n])))
          ;; 3. S1 trait-resolution — P2 fire-once
          (define-values (net3 _res-pid)
            (net-add-fire-once-propagator net2 (list tm-cid) (list tm-cid)
                                (make-trait-resolution-fire-fn tm-cid e) tm-cid
                                #:component-paths
                                (list (cons tm-cid (cons e ':constraints)))))
          net3])]

      ;; --- Bound variable: type + usage — both P2 fire-once ---
      [(expr-bvar k)
       (define-values (net1 _t) (net-add-fire-once-propagator net (list tm-cid) (list tm-cid)
                                  (make-bvar-fire-fn/ctx-pos tm-cid e k ctx-pos) tm-cid
                                  #:component-paths (list (cons tm-cid (cons ctx-pos ':context)))))
       (define-values (net2 _u) (net-add-fire-once-propagator net1 (list tm-cid) (list tm-cid)
                                  (make-usage-bvar-fire-fn tm-cid e k ctx-pos) tm-cid
                                  #:component-paths (list (cons tm-cid (cons ctx-pos ':context)))))
       net2]

      ;; --- Free variable: P1 initial write (type from env, zero-usage) ---
      [(expr-fvar name)
       (define ty (global-env-lookup-type name))
       (if ty
           (type-map-write net tm-cid e ty)
           net)]  ;; not found — leave at ⊥

      ;; --- Application (tensor) with bidirectional writes ---
      ;; Pattern 1: the app propagator writes domain DOWNWARD to arg position.
      ;; The merge at arg-pos is unification (type-lattice-merge). This solves
      ;; metas: if arg is a meta at ⊥, the domain write fills it.
      [(expr-app func arg)
       (define net1 (install net func ctx-pos))
       (define net2 (install net1 arg ctx-pos))
       ;; Typing: bidirectional app propagator
       (define-values (net3 _t) (net-add-propagator net2 (list tm-cid) (list tm-cid)
                                  (make-app-fire-fn tm-cid e func arg)
                                  #:component-paths
                                  (list (cons tm-cid (cons func ':type))
                                        (cons tm-cid (cons arg ':type)))))
       ;; Usage: add-usage(func, scale(m, arg))
       (define-values (net4 _u) (net-add-propagator net3 (list tm-cid) (list tm-cid)
                                  (make-usage-app-fire-fn tm-cid e func arg)
                                  #:component-paths
                                  (list (cons tm-cid (cons func ':usage))
                                        (cons tm-cid (cons arg ':usage))
                                        (cons tm-cid (cons func ':type)))))
       net4]

      ;; --- Lambda: context-extension (P2) + typing + usage (P2) ---
      [(expr-lam m dom body)
       (define net1 (install net dom ctx-pos))
       (define child-ctx-pos (gensym 'ctx-lam))
       (define-values (net2 _ctx) (net-add-fire-once-propagator net1 (list tm-cid) (list tm-cid)
                                    (make-context-extension-fire-fn tm-cid ctx-pos dom child-ctx-pos m) tm-cid
                                    #:component-paths (list (cons tm-cid (cons ctx-pos ':context)))))
       (define net3 (install net2 body child-ctx-pos))
       ;; Typing: lam propagator (NOT fire-once)
       (define-values (net4 _t) (net-add-propagator net3 (list tm-cid) (list tm-cid)
                                  (make-lam-fire-fn tm-cid e dom body m)
                                  #:component-paths
                                  (list (cons tm-cid (cons dom ':type))
                                        (cons tm-cid (cons body ':type)))))
       ;; Usage: utail — P2 fire-once
       (define-values (net5 _u) (net-add-fire-once-propagator net4 (list tm-cid) (list tm-cid)
                                  (make-usage-lam-fire-fn tm-cid e body) tm-cid
                                  #:component-paths
                                  (list (cons tm-cid (cons body ':usage)))))
       net5]

      ;; --- Pi formation: context-extension (P2) + typing + usage (P2) ---
      [(expr-Pi m dom cod)
       (define child-ctx-pos (gensym 'ctx-pi))
       (define-values (net0 _ctx) (net-add-fire-once-propagator net (list tm-cid) (list tm-cid)
                                    (make-context-extension-fire-fn tm-cid ctx-pos dom child-ctx-pos m) tm-cid
                                    #:component-paths (list (cons tm-cid (cons ctx-pos ':context)))))
       (define net1 (install net0 dom ctx-pos))
       (define net2 (install net1 cod child-ctx-pos))
       ;; Typing: pi propagator
       (define-values (net3 _t) (net-add-propagator net2 (list tm-cid) (list tm-cid)
                                  (make-pi-fire-fn tm-cid e dom cod)
                                  #:component-paths
                                  (list (cons tm-cid (cons dom ':type))
                                        (cons tm-cid (cons cod ':type)))))
       ;; Usage: utail — P2 fire-once
       (define-values (net4 _u) (net-add-fire-once-propagator net3 (list tm-cid) (list tm-cid)
                                  (make-usage-pi-fire-fn tm-cid e cod) tm-cid
                                  #:component-paths
                                  (list (cons tm-cid (cons cod ':usage)))))
       net4]

      ;; --- Union type: type of `<A | B>` IS [Type (lmax level(A) level(B))] ---
      ;; PPN 4C Path T-3 (Commit A.2-a, 2026-04-22): architectural fix.
      ;; Previously this case installed branching via worldview-bitmask
      ;; (Phase 8 Option D) and wrote COMPONENT types (A, B) to position e's
      ;; :type facet, which was (a) architecturally wrong — components are
      ;; not the type of the union expression, they're its components — and
      ;; (b) accidentally load-bearing under pre-T-3 merge semantics via
      ;; contradiction-detection-as-fallback (merge(A,B)=type-top → sexp
      ;; typing-core.rkt:459 infer fallback returned correct [Type lv]).
      ;;
      ;; Fix: mirror make-pi-fire-fn's pattern. A union expression IS a type
      ;; former; its type is the universe at level max(level(components)).
      ;; Check-time branching against a union type (e.g., check expr : A | B)
      ;; is a distinct code path in typing-errors.rkt:check/err; no branching
      ;; needed here at infer time.
      [(expr-union left right)
       (define net1 (install net left ctx-pos))
       (define net2 (install net1 right ctx-pos))
       (define-values (net3 _pid)
         (net-add-propagator net2 (list tm-cid) (list tm-cid)
           (make-union-fire-fn tm-cid e left right)
           #:component-paths (list (cons tm-cid (cons left ':type))
                                   (cons tm-cid (cons right ':type)))))
       net3]

      ;; --- Type annotation: return type IS the annotation + check term ---
      ;; Phase 9 prep: ann(term, T) → T, with T written downward to term
      ;; as a check constraint. Merge at term position IS unification.
      [(expr-ann term type-expr)
       ;; Install sub-expression propagators for term and type-expr
       (define net1 (install net term ctx-pos))
       (define net2 (install net1 type-expr ctx-pos))
       ;; Write T as this expression's type (the annotation IS the type)
       (define net3 (type-map-write net2 tm-cid e type-expr))
       ;; Write T downward to term position (CHECK: term must have type T).
       ;; PPN 4C Path T-3 Commit A.2-b (2026-04-22): Role B migration.
       ;; This is explicit equality enforcement — term MUST have type type-expr.
       ;; type-map-write-unified preserves type-top on structural mismatch so
       ;; the contradiction-detection propagator below reliably fires under
       ;; post-T-3 Commit B set-union merge semantics.
       (define net4 (type-map-write-unified net3 tm-cid term type-expr))
       ;; Quick shape check: if annotation is non-Pi and term is lambda, → contradiction.
       ;; Lambda requires Pi annotation. Non-Pi annotations on lambdas are always errors.
       (if (and (expr-lam? term) (not (expr-Pi? type-expr)))
           (type-map-write net4 tm-cid e type-top)
           ;; Contradiction detection propagator: watches term for type-top
           (let-values ([(net5 _check-pid)
                         (net-add-fire-once-propagator net4 (list tm-cid) (list tm-cid)
                           (lambda (net)
                             (define term-type (type-map-read net tm-cid term))
                             (if (type-top? term-type)
                                 (type-map-write net tm-cid e type-top)
                                 net))
                           tm-cid
                           #:component-paths (list (cons tm-cid (cons term ':type))))])
             net5))]

      ;; --- Type constructor: kind from arity ---
      ;; Phase 9 prep: tycon(name) → curried Pi type from arity table.
      [(expr-tycon name)
       (define arity (tycon-arity name))
       (if arity
           ;; Build curried Pi: Type → Type → ... → Type (arity arrows)
           (let ([kind (let loop ([n arity])
                         (if (= n 0)
                             (expr-Type (lzero))
                             (expr-Pi 'm0 (expr-Type (lzero)) (loop (- n 1)))))])
             (type-map-write net tm-cid e kind))
           net)]  ;; unknown tycon — leave at ⊥

      ;; --- Pattern matching: structural unification across branches ---
      ;; Phase 9 prep: each arm decomposes the constructor's Pi chain into
      ;; pattern variable bindings (context extension), installs body propagators
      ;; in the child context, and body types merge at the result position.
      ;; All arms are independent — concurrent evaluation during quiescence.
      [(expr-reduce scrutinee arms _structural?)
       ;; Install scrutinee propagators
       (define net1 (install net scrutinee ctx-pos))
       ;; For each arm: decompose constructor, extend context, install body
       (for/fold ([n net1]) ([arm (in-list arms)])
         (define ctor-name (expr-reduce-arm-ctor-name arm))
         (define bc (expr-reduce-arm-binding-count arm))
         (define body (expr-reduce-arm-body arm))
         (cond
           [(= bc 0)
            ;; No bindings — install body in same context
            (define n2 (install n body ctx-pos))
            ;; Body type writes to result position via merge (join)
            (define-values (n3 _pid)
              (net-add-fire-once-propagator n2 (list tm-cid) (list tm-cid)
                (lambda (net)
                  (define body-type (type-map-read net tm-cid body))
                  (if (type-bot? body-type) net
                      (type-map-write net tm-cid e body-type)))
                tm-cid
                #:component-paths (list (cons tm-cid (cons body ':type)))))
            n3]
           [else
            ;; bc > 0: create child context with pattern variable bindings.
            ;; Constructor type from env gives the Pi chain for binding types.
            (define ctor-type (global-env-lookup-type ctor-name))
            (if (not ctor-type)
                ;; Unknown constructor — skip this arm
                n
                ;; Walk the Pi chain: each domain = one pattern variable type
                (let ([child-ctx-pos (gensym 'ctx-match)])
                  ;; Install context-extension propagators for each binding.
                  ;; Walk ctor-type Pi chain, extract domain types.
                  (define-values (ext-net ext-type)
                    (let loop ([net-acc n] [ty ctor-type] [remaining bc]
                               [current-ctx-pos ctx-pos])
                      (if (= remaining 0)
                          (values net-acc ty)
                          (match ty
                            [(expr-Pi m dom cod)
                             (define next-ctx-pos (gensym 'ctx-match-bind))
                             ;; Context extension: bind pattern var with type dom
                             (define-values (n2 _) (net-add-fire-once-propagator net-acc
                               (list tm-cid) (list tm-cid)
                               (make-context-extension-fire-fn tm-cid current-ctx-pos dom next-ctx-pos m)
                               tm-cid
                               #:component-paths (list (cons tm-cid (cons current-ctx-pos ':context)))))
                             (loop n2 cod (- remaining 1) next-ctx-pos)]
                            ;; Not a Pi — can't decompose further
                            [_ (values net-acc ty)]))))
                  ;; Install body in the innermost child context
                  (define innermost-ctx
                    (let find-innermost ([p ctx-pos] [ty ctor-type] [rem bc])
                      (if (= rem 0) p
                          (match ty
                            [(expr-Pi _ _ cod) (find-innermost (gensym 'skip) cod (- rem 1))]
                            [_ p]))))
                  ;; Actually, the loop above already created the context positions.
                  ;; The innermost is the last next-ctx-pos created. Let me track it.
                  ;; SIMPLIFIED: use a single context extension that adds all bindings at once.
                  ;; Walk the Pi chain, collect domain types, create one child context with all bindings.
                  (define binding-types
                    (let loop ([ty ctor-type] [remaining bc] [acc '()])
                      (if (= remaining 0) (reverse acc)
                          (match ty
                            [(expr-Pi m dom cod)
                             (loop cod (- remaining 1) (cons (cons dom m) acc))]
                            [_ (reverse acc)]))))
                  ;; Create child context by extending with all bindings
                  (define child-ctx-pos2 (gensym 'ctx-match-all))
                  (define-values (ext-net2 _ctx-pid)
                    (net-add-fire-once-propagator ext-net (list tm-cid) (list tm-cid)
                      (lambda (net)
                        (define parent-ctx (that-read (net-cell-read net tm-cid) ctx-pos ':context))
                        (cond
                          [(not (context-cell-value? parent-ctx)) net]
                          [else
                           (define extended
                             (for/fold ([ctx parent-ctx]) ([bt (in-list binding-types)])
                               (context-extend-value ctx (car bt) (cdr bt))))
                           (that-write net tm-cid child-ctx-pos2 ':context extended)]))
                      tm-cid
                      #:component-paths (list (cons tm-cid (cons ctx-pos ':context)))))
                  ;; Install body in child context
                  (define body-net (install ext-net2 body child-ctx-pos2))
                  ;; Body type merges at result position
                  (define-values (result-net _pid)
                    (net-add-fire-once-propagator body-net (list tm-cid) (list tm-cid)
                      (lambda (net)
                        (define body-type (type-map-read net tm-cid body))
                        (if (type-bot? body-type) net
                            (type-map-write net tm-cid e body-type)))
                      tm-cid
                      #:component-paths (list (cons tm-cid (cons body ':type)))))
                  result-net))]))]

      ;; --- Generic from-int/from-rat: return type = target-type EXPRESSION ---
      ;; The target-type field is the first child. Its VALUE (the expression itself,
      ;; e.g., (expr-Int)) is the return type. P1 initial write.
      [(expr-generic-from-int target-type arg)
       (define net1 (install net target-type ctx-pos))
       (define net2 (install net1 arg ctx-pos))
       (type-map-write net2 tm-cid e target-type)]

      [(expr-generic-from-rat target-type arg)
       (define net1 (install net target-type ctx-pos))
       (define net2 (install net1 arg ctx-pos))
       (type-map-write net2 tm-cid e target-type)]

      ;; --- Pair: type = Sigma(type-of-fst, type-of-snd) ---
      [(expr-pair fst-expr snd-expr)
       (define net1 (install net fst-expr ctx-pos))
       (define net2 (install net1 snd-expr ctx-pos))
       ;; Propagator reads both component types, writes Sigma
       (define-values (net3 _pid)
         (net-add-fire-once-propagator net2 (list tm-cid) (list tm-cid)
           (lambda (net)
             (define fst-type (type-map-read net tm-cid fst-expr))
             (define snd-type (type-map-read net tm-cid snd-expr))
             (cond
               [(or (type-bot? fst-type) (type-bot? snd-type)) net]
               [else (type-map-write net tm-cid e (expr-Sigma fst-type snd-type))]))
           tm-cid
           #:component-paths
           (list (cons tm-cid (cons fst-expr ':type))
                 (cons tm-cid (cons snd-expr ':type)))))
       net3]

      ;; --- Domain lookup: SRE typing domain handles remaining expr kinds ---
      [_
       (define rule (lookup-typing-rule e))
       (if rule
           ;; Install typing + usage propagators from the rule
           ;; PLUS coercion detection for binary generic ops (S2, P2)
           (let* ([net1 (install-from-rule net tm-cid e ctx-pos rule)]
                  [net2 (install-usage-from-rule net1 tm-cid e ctx-pos rule)]
                  ;; Coercion detection: for binary generic ops, install S2 propagator
                  [net3 (if (and (= (typing-domain-rule-arity rule) 2)
                                (let ([name (typing-domain-rule-name rule)])
                                  (memq name '(generic-add generic-sub generic-mul generic-div
                                               generic-mod generic-lt generic-le generic-gt
                                               generic-ge generic-eq))))
                            (let ([children (typing-domain-rule-children rule)])
                              (define child1 ((car children) e))
                              (define child2 ((cadr children) e))
                              (define-values (n _pid)
                                (net-add-fire-once-propagator net2
                                  (list tm-cid) (list tm-cid)
                                  (make-coercion-detection-fire-fn tm-cid e child1 child2)
                                  tm-cid
                                  #:component-paths
                                  (list (cons tm-cid (cons child1 ':type))
                                        (cons tm-cid (cons child2 ':type)))))
                              n)
                            net2)])
             net3)
           ;; Truly unhandled — leave at ⊥, log for coverage tracking
           (begin
             (when (struct? e)
               (define v (struct->vector e))
               (define tag (vector-ref v 0))
               (hash-update! unhandled-expr-counts tag add1 0))
             net))])))

;; Track 4B Phase 3b: expose collected constraint-meta positions.
;; install-typing-network returns only the network (backward compat).
;; The constraint positions are captured in the box and accessed by
;; Track 4B Phase 6: install-typing-network/with-constraints REMOVED.
;; Meta-bridge propagators now write to the output cell during quiescence.
;; No collection, no wrapper. install-typing-network is called directly.


;; ============================================================
;; Phase 3 (D.4): Production Integration — infer-on-network
;; ============================================================
;;
;; Creates a typing cell on the prop-network, installs typing propagators
;; for the given core expr, runs to quiescence, and reads the root type
;; from the cell. This is the propagator-native replacement for infer/err.
;;
;; Network Reality Check:
;;   1. net-new-cell: creates the typing cell with type-map-merge-fn
;;   2. net-add-propagator: via install-typing-network (per sub-expression)
;;   3. run-to-quiescence: propagators fire, types flow through cell
;;   4. net-cell-read: reads the root type from the type-map
;;   Result comes from cell read after quiescence. Not a function return.

;; ============================================================
;; Track 4B Phase 6+6b: On-Main-Network Typing with Global Cell
;; ============================================================
;;
;; Architecture:
;;   ONE persistent attribute-map cell on the main elab-network (§9).
;;   Created on first command, reused across all commands.
;;   CHAMP structural sharing: positions from earlier commands persist,
;;   new commands add deltas. Cross-command type visibility is free.
;;
;;   Per-command output cell for meta-solution bridging.
;;   Meta-bridge propagators write to output cell during quiescence.
;;
;;   P3 cleanup: after quiescence, clear dependents from BOTH cells.
;;   Values persist (computed types stay in the attribute-map CHAMP),
;;   propagators are removed (zero scheduling overhead for next command).
;;
;; Network Reality Check:
;;   1. net-new-cell: creates cells on MAIN network (once for attr-map, per-command for output)
;;   2. net-add-propagator: installs per-command propagators
;;   3. run-to-quiescence-bsp: BSP on the main network
;;   4. net-clear-dependents: P3 cleanup — values persist, propagators removed
;;   Result flows through cells on the main network. No ephemeral PU.

(define TYPING-FUEL-LIMIT 200)

;; Parameters for the persistent global attribute-map cell and per-command output cell.
(define current-attribute-map-cell-id (make-parameter #f))
(define current-meta-solution-output-cell-id (make-parameter #f))
;; Note (PPN 4C Path T-3 Commit A.2-a, 2026-04-22): union-assumption-counter
;; removed — was only used by the pre-T-3 expr-union install case for
;; worldview-bitmask branching at infer time, which was both architecturally
;; incorrect and accidentally load-bearing. See typing-propagators.rkt:1878+.

;; Phase 0c: Initialize the global attribute-map cell on the persistent
;; registry network. Called once per file alongside init-macros-cells!,
;; init-warning-cells!, init-narrow-cells!. The cell is a MODULE-LEVEL
;; attribute store — the typing facet of the module environment.
;; §9: CHAMP structural sharing across commands. .pnet cache populates it.
(define (init-attribute-map-cell! prn-box)
  (when prn-box
    (define pnet (unbox prn-box))
    (define-values (pnet* cid)
      (net-new-cell pnet (hasheq) attribute-map-merge-fn))
    (current-attribute-map-cell-id cid)
    (set-box! prn-box pnet*)))

(define (infer-on-network pnet expr ctx-val)
  ;; 1. Get the GLOBAL attribute-map cell from the persistent registry network.
  ;; If not initialized (e.g., test context), create per-command.
  (define prn-box (current-persistent-registry-net-box))
  (define-values (net0 tm-cid use-persistent?)
    (cond
      ;; Persistent network available + global cell initialized → use it
      [(and prn-box (current-attribute-map-cell-id))
       (values (unbox prn-box) (current-attribute-map-cell-id) #t)]
      ;; Fallback: per-command cell on the provided network (test context)
      [else
       (define-values (n c) (net-new-cell pnet (hasheq) attribute-map-merge-fn))
       (values n c #f)]))
  ;; 2. Create per-command output cell (meta solutions).
  ;; N6a (warning-accumulation fix): the per-command warning-output cell +
  ;; its whole-map fire-once collection propagator are RETIRED. The old
  ;; collection fire folded over EVERY position in the attribute map — on
  ;; the PERSISTENT attr-map this harvested :warnings facets deposited by
  ;; ALL prior commands (facet values persist by design; P3 clears
  ;; dependents only), re-attaching stale warnings to every later result.
  ;; Its firing round was also expression-shape-dependent (own-facet
  ;; harvest sometimes landed one command late). Warnings are now read
  ;; directly post-quiescence, scoped to the current command's expr tree
  ;; (step 5 below). make-warning-collection-fire-fn stays exported (tests).
  (define-values (net1 output-cid)
    (net-new-cell net0 '() meta-solution-merge))
  ;; 3. Install ALL attribute propagators (typing + constraints + usage + meta-bridge)
  (parameterize ([current-meta-solution-output-cell-id output-cid])
    (define net2w (install-typing-network net1 tm-cid expr ctx-val))
    ;; 4. Run to quiescence with fuel limit (save/restore for main network)
    ;; D.4 1C-iv-a (§10.0.6 D-1C-iii-5 retirement obligation; D-1C-iv-2 mitigation):
    ;; migrated from struct-copy substitution to cell-API. Pre-migration: writes
    ;; STRUCT-FIELD via struct-copy [fuel TYPING-FUEL-LIMIT] WITHOUT cell-write
    ;; → β1 lockstep VIOLATED mid-bounded-run → BSP sites 2+3 needed transitional
    ;; struct-field check (D-1C-iii-5). Post-migration: writes cell directly via
    ;; net-cell-reset (bypasses merge; same semantic as fork-prop-network init);
    ;; β1 lockstep preserved at boundary (cell IS the live state).
    ;;
    ;; net-cell-reset is the correct primitive: under tropical-fuel-merge (=min),
    ;; net-cell-write would (min current TYPING-FUEL-LIMIT) and the smaller wins —
    ;; if current < TYPING-FUEL-LIMIT, we'd inherit a smaller budget than intended.
    ;; net-cell-reset bypasses merge: the bounded run gets exactly TYPING-FUEL-LIMIT
    ;; budget regardless of current.
    (define saved-fuel (net-cell-read net2w fuel-cell-id))
    (define net2-limited (net-cell-reset net2w fuel-cell-id TYPING-FUEL-LIMIT))
    (define net3 (run-to-quiescence-bsp net2-limited))
    ;; Restore fuel (cell-API; bypass merge to write saved-fuel directly).
    (define net3-restored (net-cell-reset net3 fuel-cell-id saved-fuel))
    ;; 5. Read results
    (define root-type (type-map-read net3-restored tm-cid expr))
    (define meta-solutions (net-cell-read net3-restored output-cid))
    ;; N6a: scoped post-quiescence warning harvest — read the attr-map ONCE
    ;; and extract :warnings facets ONLY at positions belonging to the
    ;; current command's expr tree. Deterministic (post-fixpoint cell read),
    ;; immune to stale facets from prior commands / module loads.
    (define warnings
      (let ([tm (net-cell-read net3-restored tm-cid)])
        (if (not (hash? tm))
            '()
            (let ([scope (expr-subterm-seteq expr)])
              (for/fold ([acc '()])
                        ([(pos record) (in-hash tm)])
                (if (and (set-member? scope pos) (hash? record))
                    (let ([ws (hash-ref record ':warnings '())])
                      (if (null? ws) acc (append acc ws)))
                    acc))))))
    ;; 6. P3 cleanup: clear dependents from all cells.
    (define net4 (net-clear-dependents net3-restored tm-cid))
    (define net5 (net-clear-dependents net4 output-cid))
    ;; 7. Rebox the persistent network if we used it.
    (when use-persistent?
      (set-box! prn-box net5))
    ;; Return: cleaned network, root type, meta solutions, warnings
    (values (if use-persistent? pnet net5) root-type meta-solutions warnings)))

;; ============================================================
;; Production Entry Point: infer-on-network/err
;; ============================================================
;;
;; Drop-in replacement for infer/err in process-command.
;; Same contract: takes ctx and expr, returns type or prologos-error.
;;
;; Track 4B Phase 6: operates on the MAIN elab-network, not an ephemeral PU.
;; Unboxes the elab-network, runs typing on its prop-net, reads results,
;; bridges meta solutions to the imperative meta-store (scaffolding),
;; reboxes the updated elab-network.
(define on-network-success-count (box 0))
(define on-network-fallback-count (box 0))

(define (infer-on-network/err ctx expr [loc srcloc-unknown] [names '()])
  (define net-box (current-prop-net-box))
  (cond
    [(not net-box) type-bot]  ;; no network → signal fallback
    [else
     ;; Unbox the main elab-network, extract its prop-net
     (define enet (unbox net-box))
     (define pnet (elab-network-prop-net enet))
     (define ctx-val (context-cell-value ctx (length ctx)))
     ;; Run typing on the MAIN network (returns 4 values since Phase 7)
     (define-values (pnet* root-type meta-solutions warnings)
       (infer-on-network pnet expr ctx-val))
     ;; Rebox the updated elab-network (attribute-map cell now on main network)
     (set-box! net-box (elab-network-rewrap enet pnet*))
     ;; Bridge meta solutions to imperative meta-store (SCAFFOLDING until Phase 9)
     ;; This is ONE cell read (the output cell), not a scan. The solutions were
     ;; collected by meta-bridge propagators during quiescence.
     (for ([pair (in-list meta-solutions)])
       (define meta-id (car pair))
       (define solution (cdr pair))
       (unless (meta-solved? meta-id)
         (solve-meta! meta-id solution)))
     ;; Parametric trait resolution bridge (SCAFFOLDING)
     ;; Resolves parametric constraints (Seqable, Foldable, Reducible) where
     ;; monomorphic on-network resolution succeeded for type-args but the
     ;; dict-meta needs parametric pattern matching.
     (resolve-trait-constraints!)
     ;; Check for remaining unsolved dict-metas (parametric constraints
     ;; that couldn't be resolved on-network because erased type-arg
     ;; metas have no on-network path to their solutions).
     (define has-unsolved-dict?
       (let ([constraints (read-trait-constraints)])
         (for/or ([(mid _) (in-hash constraints)])
           (not (meta-solved? mid)))))
     ;; Return type (with fallback checks)
     (cond
       [(type-bot? root-type)
        (set-box! on-network-fallback-count (add1 (unbox on-network-fallback-count)))
        (inference-failed-error loc "on-network: bot" (pp-expr expr names))]
       [(type-top? root-type)
        (set-box! on-network-fallback-count (add1 (unbox on-network-fallback-count)))
        (inference-failed-error loc "on-network: top" (pp-expr expr names))]
       [(has-unsolved-meta? root-type)
        (set-box! on-network-fallback-count (add1 (unbox on-network-fallback-count)))
        (inference-failed-error loc "on-network: unsolved meta" (pp-expr expr names))]
       ;; Unsolved dict-metas → trigger fallback to imperative path
       ;; which has CHECK mode for resolving erased type-arg metas
       [has-unsolved-dict?
        (set-box! on-network-fallback-count (add1 (unbox on-network-fallback-count)))
        (inference-failed-error loc "on-network: unsolved dict" (pp-expr expr names))]
       [else
        ;; N6a (double-emission guard): bridge on-network warnings to the
        ;; imperative warning parameters (SCAFFOLDING) ONLY on success — on
        ;; any fallback branch above, the driver re-runs the imperative
        ;; infer/err, whose numeric-join/warn! emits its own coercion
        ;; warnings; bridging here too would emit the same coercion twice.
        (for ([w (in-list warnings)])
          (when (and (list? w) (pair? w) (eq? (car w) 'coercion-warning))
            (emit-coercion-warning! (cadr w) (caddr w))))
        (set-box! on-network-success-count (add1 (unbox on-network-success-count)))
        root-type])]))


;; ============================================================
;; Phase 4b-i: Fan-In Meta-Readiness Infrastructure
;; ============================================================
;;
;; A meta-readiness cell per form tracks which metas are solved
;; via a set-based monotone value. At S2 commit time, a single
;; threshold propagator reads the unsolved set and writes defaults
;; (lzero for levels, mw for multiplicities, sess-end for sessions).
;;
;; This replaces the tree-walking `default-metas` function in
;; freeze (zonk.rkt:939-1352). Instead of walking a tree, the
;; S2 handler reads a cell.
;;
;; The merge is set-union (monotone: solved set only grows).
;; When all registered metas are in the solved set, all-solved? = #t.

(struct meta-readiness-value
  (registered  ;; hasheq: meta-id → meta-class
   solved)     ;; seteq: solved meta-ids
  #:transparent)

(define meta-readiness-empty
  (meta-readiness-value (hasheq) (seteq)))

(define (meta-readiness-register rv meta-id meta-class)
  (meta-readiness-value
   (hash-set (meta-readiness-value-registered rv) meta-id meta-class)
   (meta-readiness-value-solved rv)))

(define (meta-readiness-solve rv meta-id)
  (meta-readiness-value
   (meta-readiness-value-registered rv)
   (set-add (meta-readiness-value-solved rv) meta-id)))

(define (meta-readiness-unsolved rv)
  (define registered (meta-readiness-value-registered rv))
  (define solved (meta-readiness-value-solved rv))
  (for/list ([(id cls) (in-hash registered)]
             #:unless (set-member? solved id))
    (cons id cls)))

(define (meta-readiness-all-solved? rv)
  (= (hash-count (meta-readiness-value-registered rv))
     (set-count (meta-readiness-value-solved rv))))

(define (meta-readiness-merge old new)
  (meta-readiness-value
   (for/fold ([result (meta-readiness-value-registered old)])
             ([(id cls) (in-hash (meta-readiness-value-registered new))])
     (hash-set result id cls))
   (set-union (meta-readiness-value-solved old)
              (meta-readiness-value-solved new))))

(define (meta-readiness-contradicts? v) #f)


;; ============================================================
;; Phase 6: Constraint SRE Domain
;; ============================================================
;;
;; Trait constraints as a lattice: pending (⊥) → resolved(instance) → contradicted (⊤).

(struct constraint-cell-value
  (status    ;; 'pending | 'resolved | 'contradicted
   instance) ;; resolved instance value, or #f
  #:transparent)

(define constraint-pending (constraint-cell-value 'pending #f))
(define (constraint-resolved instance) (constraint-cell-value 'resolved instance))
(define constraint-contradicted (constraint-cell-value 'contradicted #f))

(define (constraint-pending? v)
  (and (constraint-cell-value? v) (eq? (constraint-cell-value-status v) 'pending)))
(define (constraint-resolved? v)
  (and (constraint-cell-value? v) (eq? (constraint-cell-value-status v) 'resolved)))
(define (constraint-contradicted? v)
  (and (constraint-cell-value? v) (eq? (constraint-cell-value-status v) 'contradicted)))

(define (constraint-cell-merge old new)
  (cond
    [(constraint-contradicted? old) old]
    [(constraint-contradicted? new) new]
    [(constraint-pending? old) new]
    [(constraint-pending? new) old]
    [(and (constraint-resolved? old) (constraint-resolved? new))
     (if (equal? (constraint-cell-value-instance old)
                 (constraint-cell-value-instance new))
         old
         constraint-contradicted)]
    [else constraint-contradicted]))

(define (constraint-cell-meet a b)
  (cond
    [(constraint-contradicted? a) b]
    [(constraint-contradicted? b) a]
    [(constraint-pending? a) a]
    [(constraint-pending? b) b]
    [(and (constraint-resolved? a) (constraint-resolved? b))
     (if (equal? (constraint-cell-value-instance a)
                 (constraint-cell-value-instance b))
         a
         constraint-pending)]
    [else constraint-pending]))

(define (constraint-cell-contradicts? v)
  (constraint-contradicted? v))
