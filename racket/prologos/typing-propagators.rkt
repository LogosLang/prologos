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
         (only-in "metavar-store.rkt" meta-solution/cell-id current-prop-net-box)
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


;; --- Typing cell: a plain hasheq mapping positions to types ---
;;
;; The typing cell's value IS the type-map: (hasheq expr → type-value).
;; Each position starts at type-bot (absent from map = ⊥).
;; The merge function is pointwise: for shared keys, keep the non-⊥ value.
;; This is monotone: positions only gain information.

(define (type-map-merge-fn old new)
  (cond
    [(not (hash? old)) new]
    [(not (hash? new)) old]
    [else
     (for/fold ([result old]) ([(k v) (in-hash new)])
       (define old-v (hash-ref result k type-bot))
       (cond
         [(type-bot? old-v) (hash-set result k v)]  ;; ⊥ + X = X
         [(type-bot? v) result]                       ;; X + ⊥ = X
         [(equal? old-v v) result]                    ;; idempotent
         ;; Both non-⊥ and different: use type-lattice-merge for shared keys.
         ;; This makes the type-map merge INTO unification — two writes to the
         ;; same position (infer upward + check downward) merge via the type
         ;; lattice, handling metas, structural equality, and subtype comparison.
         ;; Context-cell-values are not types — pass through unchanged.
         [(context-cell-value? old-v) (hash-set result k v)]
         [(context-cell-value? v) result]
         [else (hash-set result k (type-lattice-merge old-v v))]))]))  ;; lattice merge

;; Read a type-map position. Returns type-bot if not present (= ⊥).
(define (type-map-read net tm-cid position)
  (define tm (net-cell-read net tm-cid))
  (if (hash? tm)
      (hash-ref tm position type-bot)
      type-bot))

;; Write a type to a type-map position via net-cell-write.
;; The cell merge (type-map-merge-fn) handles pointwise combination.
;; Component-indexed firing selectively schedules propagators.
(define (type-map-write net tm-cid position type-val)
  (net-cell-write net tm-cid (hasheq position type-val)))

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
(define (make-context-extension-fire-fn tm-cid parent-ctx-pos domain-expr child-ctx-pos mult)
  (lambda (net)
    (define parent-ctx (type-map-read net tm-cid parent-ctx-pos))
    (cond
      [(not (context-cell-value? parent-ctx)) net]
      [else
       ;; Extend context with the domain EXPRESSION (the type annotation)
       (define child-ctx (context-extend-value parent-ctx domain-expr mult))
       (type-map-write net tm-cid child-ctx-pos child-ctx)])))

;; Updated bvar fire-fn: reads from a context POSITION in the type-map
;; (not a captured context value)
(define (make-bvar-fire-fn/ctx-pos tm-cid position k ctx-pos)
  (lambda (net)
    (define ctx-val (type-map-read net tm-cid ctx-pos))
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
    [else
     ;; Recurse on children
     (define net-with-children
       (for/fold ([n net]) ([child-fn (in-list children)])
         (install-typing-network n tm-cid (child-fn e) ctx-pos)))
     ;; Install literal propagator for the return type
     (define-values (net* _pid)
       (net-add-propagator net-with-children (list tm-cid) (list tm-cid)
                           (make-literal-fire-fn tm-cid e ret-type)))
     net*]))

;; Register ALL known expression kinds.
;; Called once at module load time.
(define (install-default-typing-domain!)
  ;; --- Int arithmetic: binary → Int ---
  (for ([info (list (list expr-int-add? expr-int-add-a expr-int-add-b 'int-add)
                    (list expr-int-sub? expr-int-sub-a expr-int-sub-b 'int-sub)
                    (list expr-int-mul? expr-int-mul-a expr-int-mul-b 'int-mul)
                    (list expr-int-div? expr-int-div-a expr-int-div-b 'int-div)
                    (list expr-int-mod? expr-int-mod-a expr-int-mod-b 'int-mod))])
    (register-typing-rule! (car info) 2
                           (list (cadr info) (caddr info))
                           (expr-Int) (cadddr info)))

  ;; --- Int arithmetic: unary → Int ---
  (register-typing-rule! expr-int-neg? 1 (list expr-int-neg-a) (expr-Int) 'int-neg)
  (register-typing-rule! expr-int-abs? 1 (list expr-int-abs-a) (expr-Int) 'int-abs)

  ;; --- Int comparison: binary → Bool ---
  (for ([info (list (list expr-int-lt? expr-int-lt-a expr-int-lt-b 'int-lt)
                    (list expr-int-le? expr-int-le-a expr-int-le-b 'int-le)
                    (list expr-int-eq? expr-int-eq-a expr-int-eq-b 'int-eq))])
    (register-typing-rule! (car info) 2
                           (list (cadr info) (caddr info))
                           (expr-Bool) (cadddr info)))

  ;; --- Literals ---
  (register-typing-rule! expr-string? 0 '() (expr-String) 'string-literal)

  ;; --- Type constructors not yet in explicit match ---
  (register-typing-rule! expr-Char? 0 '() (expr-Type (lzero)) 'Char-type)
  (register-typing-rule! expr-Symbol? 0 '() (expr-Type (lzero)) 'Symbol-type)
  (register-typing-rule! expr-Keyword? 0 '() (expr-Type (lzero)) 'Keyword-type)

  ;; --- Map operations: structural (return type depends on map type) ---
  (register-typing-rule! expr-map-get? 2
                         (list expr-map-get-m expr-map-get-k)
                         #f 'map-get)

  ;; --- Generic arithmetic: return-type #f (Pattern 4 scope) ---
  (register-typing-rule! expr-generic-add? 2
                         (list expr-generic-add-a expr-generic-add-b)
                         #f 'generic-add)
  (register-typing-rule! expr-generic-sub? 2
                         (list expr-generic-sub-a expr-generic-sub-b)
                         #f 'generic-sub)
  (register-typing-rule! expr-generic-mul? 2
                         (list expr-generic-mul-a expr-generic-mul-b)
                         #f 'generic-mul))

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
  ;; Write initial context to a root context position
  (define root-ctx-pos (gensym 'ctx-root))
  (define net-with-ctx (type-map-write net tm-cid root-ctx-pos ctx-val))
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

      ;; --- Meta expression: leave at ⊥ (metas resolve through imperative path) ---
      [(expr-meta _ _) net]

      ;; --- Bound variable: reads from context POSITION ---
      [(expr-bvar k)
       (define-values (net1 _pid)
         (net-add-propagator net (list tm-cid) (list tm-cid)
                             (make-bvar-fire-fn/ctx-pos tm-cid e k ctx-pos)
                             #:component-paths (list (cons tm-cid ctx-pos))))
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
       ;; Watch entire cell (multiple positions on same cell-id)
       (define-values (net3 _pid)
         (net-add-propagator net2 (list tm-cid) (list tm-cid)
                             (make-app-fire-fn tm-cid e func arg)))
       net3]

      ;; --- Lambda: creates child scope via context-extension propagator ---
      [(expr-lam m dom body)
       ;; Install domain propagator
       (define net1 (install net dom ctx-pos))
       ;; Create child context position for body scope
       (define child-ctx-pos (gensym 'ctx-lam))
       ;; Install context-extension propagator: watches parent ctx position
       (define-values (net2 _ctx-pid)
         (net-add-propagator net1 (list tm-cid) (list tm-cid)
                             (make-context-extension-fire-fn tm-cid ctx-pos dom child-ctx-pos m)
                             #:component-paths
                             (list (cons tm-cid ctx-pos))))
       ;; Install body propagator in child scope
       (define net3 (install net2 body child-ctx-pos))
       ;; Install lambda propagator — watches entire cell (multiple positions
       ;; on same cell-id can't use component-paths due to assoc first-match)
       (define-values (net4 _pid)
         (net-add-propagator net3 (list tm-cid) (list tm-cid)
                             (make-lam-fire-fn tm-cid e dom body m)))
       net4]

      ;; --- Pi formation ---
      [(expr-Pi m dom cod)
       ;; Create child context for codomain (Pi binds a variable)
       (define child-ctx-pos (gensym 'ctx-pi))
       (define-values (net0 _ctx-pid)
         (net-add-propagator net (list tm-cid) (list tm-cid)
                             (make-context-extension-fire-fn tm-cid ctx-pos dom child-ctx-pos m)
                             #:component-paths
                             (list (cons tm-cid ctx-pos))))
       (define net1 (install net0 dom ctx-pos))
       (define net2 (install net1 cod child-ctx-pos))
       ;; Watch entire cell (multiple positions on same cell-id)
       (define-values (net3 _pid)
         (net-add-propagator net2 (list tm-cid) (list tm-cid)
                             (make-pi-fire-fn tm-cid e dom cod)))
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
  ;; 1. Create a fresh typing cell (hasheq value, type-map-merge-fn)
  (define-values (net1 tm-cid)
    (net-new-cell net (hasheq) type-map-merge-fn))
  ;; 2. Install typing propagators for the expr tree
  (define net2 (install-typing-network net1 tm-cid expr ctx-val))
  ;; 3. Run to quiescence with fuel limit
  (define original-fuel (prop-network-fuel net2))
  (define net2-limited
    (struct-copy prop-network net2
      [hot (struct-copy prop-net-hot (prop-network-hot net2)
             [fuel TYPING-FUEL-LIMIT])]))
  (define net3 (run-to-quiescence net2-limited))
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
