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
         "syntax.rkt"
         "prelude.rkt"
         "substitution.rkt"
         "global-env.rkt"
         "propagator.rkt"
         "surface-rewrite.rkt"
         (only-in "subtype-predicate.rkt" type-tensor-core)
         (only-in "type-lattice.rkt" type-bot type-bot? type-top type-top? type-lattice-merge has-unsolved-meta?)
         (only-in "metavar-store.rkt" meta-solution/cell-id current-prop-net-box
                  trait-constraint-info trait-constraint-info?
                  trait-constraint-info-trait-name trait-constraint-info-type-arg-exprs
                  read-trait-constraints)
         "constraint-cell.rkt"  ;; Track 4B Phase 2: reuse existing constraint lattice
         "constraint-propagators.rkt"  ;; Track 4B Phase 2: build-trait-constraint, refine-constraint-by-type-tag
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
 context-cell-contradicts?
 ;; Track 4B Phase 1: Attribute Record PU
 attribute-map-merge-fn
 ;; Track 4B Phase 2: Constraint Attribute Propagators
 make-constraint-creation-fire-fn
 make-type-narrows-constraints-fire-fn
 type-expr->tag
 that-read
 that-write
 facet-bot
 facet-bot?
 facet-merge
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

(define (facet-merge facet old-v new-v)
  (case facet
    [(:type)
     (cond
       [(type-bot? old-v) new-v]
       [(type-bot? new-v) old-v]
       [(equal? old-v new-v) old-v]
       [else (type-lattice-merge old-v new-v)])]
    [(:context)
     (cond
       [(equal? old-v context-empty-value) new-v]
       [(equal? new-v context-empty-value) old-v]
       [(equal? old-v new-v) old-v]
       [else (context-cell-merge old-v new-v)])]
    ;; Track 4B Phase 2: constraint domain uses existing constraint-cell lattice
    [(:constraints) (constraint-merge old-v new-v)]
    ;; Future facets (Phases 4, 7) — identity merge until implemented
    [(:usage) new-v]
    [(:warnings) new-v]
    [else new-v]))

(define (facet-bot facet)
  (case facet
    [(:type) type-bot]
    [(:context) context-empty-value]
    [(:constraints) constraint-bot]  ;; constraint-cell.rkt: all candidates possible
    [(:usage) '()]               ;; empty usage vector
    [(:warnings) '()]            ;; no warnings
    [else #f]))

(define (facet-bot? facet v)
  (case facet
    [(:type) (type-bot? v)]
    [(:context) (equal? v context-empty-value)]
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

(define (that-read attribute-map position facet)
  (if (hash? attribute-map)
      (let ([record (hash-ref attribute-map position (hasheq))])
        (if (hash? record)
            (hash-ref record facet (facet-bot facet))
            (facet-bot facet)))
      (facet-bot facet)))

(define (that-write net cell-id position facet value)
  (net-cell-write net cell-id
    (hasheq position (hasheq facet value))))

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

(define (type-map-write net tm-cid position type-val)
  (that-write net tm-cid position ':type type-val))

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
       ;; DOWNWARD: write expected domain to arg position.
       (define net1 (type-map-write net tm-cid arg-pos dom))
       ;; UPWARD: subst uses arg-pos (expression key) — handles ALL codomains.
       (define result-type (subst 0 arg-pos cod))
       (type-map-write net1 tm-cid position result-type)]
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
     ;; COMPUTED return type: function from first child's type → result type.
     ;; Install children first, then a propagator that watches the first child's
     ;; type-map position and applies the function.
     (define child-exprs (map (lambda (fn) (fn e)) children))
     (define net-with-children
       (for/fold ([n net]) ([child-fn (in-list children)])
         (install-typing-network n tm-cid (child-fn e) ctx-pos)))
     (define first-child (car child-exprs))
     (define-values (net* _pid)
       (net-add-propagator net-with-children (list tm-cid) (list tm-cid)
         (lambda (net)
           (define child-type (type-map-read net tm-cid first-child))
           (cond
             [(type-bot? child-type) net]  ;; wait for child type
             [else
              (define result (ret-type child-type))
              (if result
                  (type-map-write net tm-cid e result)
                  net)]))))  ;; function returned #f — can't compute
     net*]
    [else
     ;; Constant return type
     (define net-with-children
       (for/fold ([n net]) ([child-fn (in-list children)])
         (install-typing-network n tm-cid (child-fn e) ctx-pos)))
     (define-values (net* _pid)
       (net-add-propagator net-with-children (list tm-cid) (list tm-cid)
                           (make-literal-fire-fn tm-cid e ret-type)))
     net*]))

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

  ;; ===== GENERIC ARITHMETIC: return-type #f (Pattern 4: full trait dispatch) =====
  ;; F2 Option C attempted but REVERTED: computed return types (same-as-arg-type)
  ;; produce correct types for same-type ops but bypass coercion warnings for
  ;; cross-family ops (Int + Posit32). The imperative path handles coercion
  ;; detection and warning emission. Until coercion logic moves on-network,
  ;; generic ops must fall back to imperative for correct warning behavior.
  (for ([info (list (list expr-generic-add? expr-generic-add-a expr-generic-add-b 'generic-add)
                    (list expr-generic-sub? expr-generic-sub-a expr-generic-sub-b 'generic-sub)
                    (list expr-generic-mul? expr-generic-mul-a expr-generic-mul-b 'generic-mul)
                    (list expr-generic-div? expr-generic-div-a expr-generic-div-b 'generic-div)
                    (list expr-generic-mod? expr-generic-mod-a expr-generic-mod-b 'generic-mod)
                    (list expr-generic-lt? expr-generic-lt-a expr-generic-lt-b 'generic-lt)
                    (list expr-generic-le? expr-generic-le-a expr-generic-le-b 'generic-le)
                    (list expr-generic-gt? expr-generic-gt-a expr-generic-gt-b 'generic-gt)
                    (list expr-generic-ge? expr-generic-ge-a expr-generic-ge-b 'generic-ge)
                    (list expr-generic-eq? expr-generic-eq-a expr-generic-eq-b 'generic-eq))])
    (register-typing-rule! (car info) 2 (list (cadr info) (caddr info)) #f (cadddr info)))
  (register-typing-rule! expr-generic-negate? 1 (list expr-generic-negate-a) #f 'generic-negate)
  (register-typing-rule! expr-generic-abs? 1 (list expr-generic-abs-a) #f 'generic-abs)

  ;; Conversion: return type = target-type field (first field, not arg)
  ;; generic-from-int(target-type, arg) → target-type
  ;; generic-from-rat(target-type, arg) → target-type
  ;; The target-type is an EXPRESSION (like (expr-Int)), and its type-map value is Type(0).
  ;; But we want the expression itself as the return type. Use a computed function that
  ;; reads the target-type expression from the type-map and returns it if it's a type constructor.
  ;; Conversion: target-type field is an EXPRESSION (e.g., (expr-Rat)), not a type.
  ;; The return type IS the expression, not its type-map value (Type(0)).
  ;; Registered as #f for now — needs expression-value access in computed types.
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
  ;; Recursive structural decomposition.
  ;; For each sub-expression, assign it as its own position key (eq? identity).
  ;; ctx-pos is the POSITION of the current scope's context in the type-map.
  (let install ([net net-with-ctx] [e expr] [ctx-pos root-ctx-pos])
    (match e
      ;; --- Literals: immediate type, no inputs ---
      [(expr-int v)
       (define-values (net1 _pid)
         (net-add-propagator net (list tm-cid) (list tm-cid)
                             (make-literal-fire-fn tm-cid e (expr-Int))
                             #:component-paths (list)))
       net1]

      [(expr-nat-val _)
       (define-values (net1 _pid)
         (net-add-propagator net (list tm-cid) (list tm-cid)
                             (make-literal-fire-fn tm-cid e (expr-Nat))))
       net1]

      [(expr-true)
       (define-values (net1 _pid)
         (net-add-propagator net (list tm-cid) (list tm-cid)
                             (make-literal-fire-fn tm-cid e (expr-Bool))))
       net1]

      [(expr-false)
       (define-values (net1 _pid)
         (net-add-propagator net (list tm-cid) (list tm-cid)
                             (make-literal-fire-fn tm-cid e (expr-Bool))))
       net1]

      ;; --- Type constructors: Type(lzero) ---
      [(expr-Int)
       (define-values (net1 _pid)
         (net-add-propagator net (list tm-cid) (list tm-cid)
                             (make-literal-fire-fn tm-cid e (expr-Type (lzero)))))
       net1]

      [(expr-Nat)
       (define-values (net1 _pid)
         (net-add-propagator net (list tm-cid) (list tm-cid)
                             (make-literal-fire-fn tm-cid e (expr-Type (lzero)))))
       net1]

      [(expr-Bool)
       (define-values (net1 _pid)
         (net-add-propagator net (list tm-cid) (list tm-cid)
                             (make-literal-fire-fn tm-cid e (expr-Type (lzero)))))
       net1]

      [(expr-String)
       (define-values (net1 _pid)
         (net-add-propagator net (list tm-cid) (list tm-cid)
                             (make-literal-fire-fn tm-cid e (expr-Type (lzero)))))
       net1]

      ;; --- Universe ---
      [(expr-Type l)
       (define-values (net1 _pid)
         (net-add-propagator net (list tm-cid) (list tm-cid)
                             (make-universe-fire-fn tm-cid e l)))
       net1]

      ;; --- Meta expression: leave :type at ⊥ (metas resolve through typing).
      ;; Track 4B Phase 2: if this meta has a registered trait constraint,
      ;; install constraint-creation and type-narrows-constraints propagators.
      [(expr-meta id _)
       (define tc-info (hash-ref trait-constraints id #f))
       (cond
         [(not tc-info) net]  ;; no trait constraint → nothing to install
         [else
          (define trait-name (trait-constraint-info-trait-name tc-info))
          (define type-arg-exprs (trait-constraint-info-type-arg-exprs tc-info))
          ;; 1. Constraint-creation propagator: builds initial domain from registry
          (define-values (net1 _cc-pid)
            (net-add-propagator net (list tm-cid) (list tm-cid)
                                (make-constraint-creation-fire-fn tm-cid e trait-name)
                                #:component-paths (list)))  ;; fires once (no watched paths)
          ;; 2. Type-narrows-constraints bridge: one per type-arg expression.
          ;; Watches the :type facet of each type-arg position.
          ;; When the type-arg becomes concrete, narrows the constraint domain.
          (for/fold ([n net1]) ([ta (in-list type-arg-exprs)])
            (cond
              ;; Only install bridge for type-args that are positions in the
              ;; attribute map (expr nodes). Concrete types don't need bridges.
              [(or (expr-meta? ta) (expr-bvar? ta) (expr-fvar? ta)
                   (expr-app? ta) (expr-lam? ta) (expr-Pi? ta))
               (define-values (n2 _bridge-pid)
                 (net-add-propagator n (list tm-cid) (list tm-cid)
                                     (make-type-narrows-constraints-fire-fn tm-cid e ta)
                                     #:component-paths
                                     (list (cons tm-cid (cons ta ':type)))))
               n2]
              ;; Concrete type-arg (e.g., (expr-Int)) — narrow immediately
              ;; by writing a refined domain in the creation propagator.
              ;; This is handled by the creation propagator's initial domain
              ;; already being filtered when type args are known.
              [else n]))])]

      ;; --- Bound variable: reads from :context facet at ctx-pos ---
      [(expr-bvar k)
       (define-values (net1 _pid)
         (net-add-propagator net (list tm-cid) (list tm-cid)
                             (make-bvar-fire-fn/ctx-pos tm-cid e k ctx-pos)
                             #:component-paths (list (cons tm-cid (cons ctx-pos ':context)))))
       net1]

      ;; --- Free variable: reads from global env ---
      [(expr-fvar name)
       (define-values (net1 _pid)
         (net-add-propagator net (list tm-cid) (list tm-cid)
                             (make-fvar-fire-fn tm-cid e name)))
       net1]

      ;; --- Application (tensor) with bidirectional writes ---
      ;; Pattern 1: the app propagator writes domain DOWNWARD to arg position.
      ;; The merge at arg-pos is unification (type-lattice-merge). This solves
      ;; metas: if arg is a meta at ⊥, the domain write fills it.
      [(expr-app func arg)
       (define net1 (install net func ctx-pos))
       (define net2 (install net1 arg ctx-pos))
       ;; Track 4B Phase 1: multi-path on :type facet — watches func AND arg types
       (define-values (net3 _pid)
         (net-add-propagator net2 (list tm-cid) (list tm-cid)
                             (make-app-fire-fn tm-cid e func arg)
                             #:component-paths
                             (list (cons tm-cid (cons func ':type))
                                   (cons tm-cid (cons arg ':type)))))
       net3]

      ;; --- Lambda: creates child scope via context-extension propagator ---
      [(expr-lam m dom body)
       ;; Install domain propagator
       (define net1 (install net dom ctx-pos))
       ;; Create child context position for body scope
       (define child-ctx-pos (gensym 'ctx-lam))
       ;; Install context-extension propagator: watches parent :context facet
       (define-values (net2 _ctx-pid)
         (net-add-propagator net1 (list tm-cid) (list tm-cid)
                             (make-context-extension-fire-fn tm-cid ctx-pos dom child-ctx-pos m)
                             #:component-paths
                             (list (cons tm-cid (cons ctx-pos ':context)))))
       ;; Install body propagator in child scope
       (define net3 (install net2 body child-ctx-pos))
       ;; Track 4B Phase 1: multi-path on :type facet — watches dom AND body types
       (define-values (net4 _pid)
         (net-add-propagator net3 (list tm-cid) (list tm-cid)
                             (make-lam-fire-fn tm-cid e dom body m)
                             #:component-paths
                             (list (cons tm-cid (cons dom ':type))
                                   (cons tm-cid (cons body ':type)))))
       net4]

      ;; --- Pi formation ---
      [(expr-Pi m dom cod)
       ;; Create child context for codomain (Pi binds a variable)
       (define child-ctx-pos (gensym 'ctx-pi))
       (define-values (net0 _ctx-pid)
         (net-add-propagator net (list tm-cid) (list tm-cid)
                             (make-context-extension-fire-fn tm-cid ctx-pos dom child-ctx-pos m)
                             #:component-paths
                             (list (cons tm-cid (cons ctx-pos ':context)))))
       (define net1 (install net0 dom ctx-pos))
       (define net2 (install net1 cod child-ctx-pos))
       ;; Track 4B Phase 1: multi-path on :type facet — watches dom AND cod types
       (define-values (net3 _pid)
         (net-add-propagator net2 (list tm-cid) (list tm-cid)
                             (make-pi-fire-fn tm-cid e dom cod)
                             #:component-paths
                             (list (cons tm-cid (cons dom ':type))
                                   (cons tm-cid (cons cod ':type)))))
       net3]

      ;; --- Domain lookup: SRE typing domain handles remaining expr kinds ---
      [_
       (define rule (lookup-typing-rule e))
       (if rule
           (install-from-rule net tm-cid e ctx-pos rule)
           ;; Truly unhandled — leave at ⊥, log for coverage tracking
           (begin
             (when (struct? e)
               (define v (struct->vector e))
               (define tag (vector-ref v 0))
               (hash-update! unhandled-expr-counts tag add1 0))
             net))])))


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

;; infer-on-network: the production entry point for propagator-native typing.
;; Takes a prop-network, a core expr, and a context cell value.
;; Returns: (values updated-network inferred-type)
;;   inferred-type is the type at the root position (the expr itself),
;;   or type-bot if the propagators couldn't compute it.
;; §15 Typing PU: fuel limit for the internal prop-network.
;; Simple expressions: 2-10 firings. Complex: up to ~100.
;; If exceeded, the network is cycling — bail out (type-bot → fallback).
(define TYPING-FUEL-LIMIT 200)

(define (infer-on-network net expr ctx-val)
  ;; 1. Create a fresh attribute cell (nested hasheq, attribute-map-merge-fn)
  (define-values (net1 tm-cid)
    (net-new-cell net (hasheq) attribute-map-merge-fn))
  ;; 2. Install typing propagators for the expr tree
  (define net2 (install-typing-network net1 tm-cid expr ctx-val))
  ;; 3. Run to quiescence with fuel limit
  (define original-fuel (prop-network-fuel net2))
  (define net2-limited
    (struct-copy prop-network net2
      [hot (struct-copy prop-net-hot (prop-network-hot net2)
             [fuel TYPING-FUEL-LIMIT])]))
  ;; Track 4B Phase 0d: explicit BSP for stratified attribute evaluation.
  ;; Ephemeral PUs MUST use BSP for CALM-invariant enforcement.
  (define net3 (run-to-quiescence-bsp net2-limited))
  ;; 4. Read the root type from the type-map
  (define root-type (type-map-read net3 tm-cid expr))
  ;; If fuel exhausted (cycling), return type-bot → fallback
  (if (<= (prop-network-fuel net3) 0)
      (values net3 type-bot)
      (values net3 root-type)))


;; ============================================================
;; Phase 7 (D.4): Surface→Type Bridge — Production Entry Point
;; ============================================================
;;
;; infer-on-network/err: drop-in replacement for infer/err in process-command.
;; Same contract: takes ctx and expr, returns type or prologos-error.
;; Internally: extracts prop-network from elab-network box, runs
;; infer-on-network, writes updated network back, returns type.

;; §15 Typing PU Architecture: ephemeral network as Pocket Universe.
;; Creates a FRESH prop-network for typing (not the main elab-network).
;; The typing network is created, run, read, and discarded (GC'd).
;; This prevents accumulation of typing propagators across commands.
(define on-network-success-count (box 0))
(define on-network-fallback-count (box 0))

(define (infer-on-network/err ctx expr [loc srcloc-unknown] [names '()])
  (define net-box (current-prop-net-box))
  (cond
    [(not net-box) type-bot]  ;; no network → signal fallback
    [else
     ;; Ephemeral typing network — isolated from main elab-network
     (define pnet (make-prop-network))
     (define ctx-val (context-cell-value ctx (length ctx)))
     (define-values (_pnet* root-type) (infer-on-network pnet expr ctx-val))
     ;; Main elab-network UNCHANGED — typing PU is ephemeral
     ;; Convert result: fall back for incomplete/partial results
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
       [else
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
