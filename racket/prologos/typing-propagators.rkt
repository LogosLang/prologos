#lang racket/base

;;;
;;; typing-propagators.rkt — PPN Track 4: Elaboration as Attribute Evaluation
;;;
;;; Infrastructure for propagator-based type inference. Typing rules are
;;; DPO rewrite rules (Engelfriet-Heyker: HR grammars = attribute grammars).
;;; Types live in form cells' type-maps (PU values). Context is a cell.
;;;
;;; Phase 1c: Context lattice — typing context as cells.
;;; Phase 2+: DPO typing rules, tensor propagator, etc.
;;;

(require racket/match
         racket/set
         "syntax.rkt"
         "prelude.rkt"
         "substitution.rkt"
         "global-env.rkt"
         (only-in "subtype-predicate.rkt" type-tensor-core)
         (only-in "type-lattice.rkt" type-bot type-bot? type-top type-top?)
         (only-in "metavar-store.rkt" meta-solution/cell-id))

(provide
 ;; Phase 1c: Context lattice
 (struct-out context-cell-value)
 context-empty-value
 context-extend-value
 context-lookup-type
 context-lookup-mult
 context-cell-merge
 context-cell-contradicts?
 ;; Phase 2a: Typing rule infrastructure
 (struct-out typing-rule)
 make-typing-rule-registry
 typing-rule-registry-add!
 typing-rule-registry-lookup
 typing-rule-registry-rules
 dispatch-typing-rule
 expr-typing-tag
 ;; Phase 2b: Concrete typing rules
 register-literal-typing-rules!
 register-universe-typing-rules!
 ;; Phase 2c: Variable lookup rules
 register-variable-typing-rules!
 ;; Phase 2d: Lambda + Pi formation rules
 register-binder-typing-rules!
 ;; Phase 2e: Application (tensor) rule
 register-application-typing-rules!
 ;; Phase 3: Integration — typing-rule-aware infer
 make-typing-rule-infer
 make-default-typing-registry
 ;; Phase 4b deployment: parameter for production pipeline wiring
 current-typing-rule-infer
 ;; Phase 4a: Meta-solving — typing rule for expr-meta
 register-meta-typing-rules!
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

;; Merge function for context cells. Pointwise merge on bindings:
;; - Same length: merge each (type . mult) pair
;; - Different length: take the LONGER (more information = deeper scope)
;; - Type merge: equal? check (Phase 2 will wire in type-lattice-merge)
;; - Mult merge: keep the more informative (max in QTT ordering)
;;
;; Context cells form TREES (parent→child via extension), and under ATMS
;; branching, each branch has its own worldview (TMS layer handles this).
;; There is no cross-branch context merging — the merge below handles
;; the case where two propagators write to the same context cell within
;; a single worldview.
(define (context-cell-merge old new)
  (cond
    ;; If either is the empty/bot value, take the other
    [(null? (context-cell-value-bindings old)) new]
    [(null? (context-cell-value-bindings new)) old]
    ;; Same depth: pointwise merge
    [(= (context-cell-value-depth old) (context-cell-value-depth new))
     (context-cell-value
      (map (lambda (ob nb)
             (cons
              ;; Type: if equal keep, otherwise keep newer (Phase 2: lattice merge)
              (if (equal? (car ob) (car nb)) (car ob) (car nb))
              ;; Mult: if equal keep, otherwise keep newer
              (if (equal? (cdr ob) (cdr nb)) (cdr ob) (cdr nb))))
           (context-cell-value-bindings old)
           (context-cell-value-bindings new))
      (context-cell-value-depth old))]
    ;; Different depth: take the deeper (more information)
    [(> (context-cell-value-depth new) (context-cell-value-depth old)) new]
    [else old]))

;; Context cells don't have a contradiction state (no type-top equivalent).
;; A contradicted binding will show up as type-top IN the type lattice,
;; not in the context lattice.
(define (context-cell-contradicts? v) #f)


;; ============================================================
;; Phase 2a: Typing Rule Infrastructure
;; ============================================================
;;
;; A typing-rule is first-class data: inspectable, registry-indexed,
;; and analyzable (critical pairs for confluence). Parallels sre-rewrite-rule
;; from Track 2D but specific to the typing domain.
;;
;; Each rule matches an AST node tag and computes a type from sub-expression
;; types (read from the type-map) and context (read from a context cell).
;; Rules operate bidirectionally: infer (join, upward) when computing a
;; type from sub-expressions, check (meet, downward) when validating
;; against an expected type.

;; typing-rule: a declarative typing rule for one AST node kind.
;;
;; tag: symbol — the expr struct tag this rule matches (e.g., 'expr-app, 'expr-lam)
;; name: symbol — human-readable name for the rule
;; arity: Nat — number of sub-expression children (for structural matching)
;; infer-fn: (context-cell-value, expr, (position → type-or-#f)) → type-or-#f
;;   Computes the type from the expression and sub-expression types.
;;   The third argument reads the type-map at sub-expression positions.
;;   Returns the computed type, or #f if the rule cannot fire (inputs not ready).
;; check-fn: (context-cell-value, expr, type, (position → type-or-#f)) → boolean
;;   Validates the expression against an expected type.
;;   Returns #t if valid, #f if not. #f when inputs not ready.
;;   Can be #f if this rule only infers (no check mode).
;; stratum: Nat — scheduling stratum (0 = S0 monotone, default)
(struct typing-rule
  (tag        ;; symbol: expr tag this rule matches
   name       ;; symbol: human-readable rule name
   arity      ;; Nat: number of sub-expression children
   infer-fn   ;; (ctx-val, expr, type-map-reader) → type-or-#f
   check-fn   ;; (ctx-val, expr, expected-type, type-map-reader) → boolean | #f for infer-only
   stratum)   ;; Nat: scheduling stratum
  #:transparent)

;; Registry: mutable hash mapping expr tag → typing-rule.
;; The registry is the typing rule index — lookup by AST tag is O(1).
(define (make-typing-rule-registry)
  (make-hasheq))

;; Register a typing rule. If a rule already exists for this tag,
;; it is replaced (later registration wins — for migration batches).
(define (typing-rule-registry-add! registry rule)
  (hash-set! registry (typing-rule-tag rule) rule))

;; Look up a typing rule by AST tag. Returns the rule or #f.
(define (typing-rule-registry-lookup registry tag)
  (hash-ref registry tag #f))

;; List all registered rules (for inspection, critical pair analysis).
(define (typing-rule-registry-rules registry)
  (hash-values registry))

;; Dispatch: given an expression and a registry, find and fire the
;; appropriate typing rule. Returns the computed type, or #f if no rule
;; exists for this expression's tag (fall back to imperative infer/check).
;;
;; This is the DPO-first + imperative-fallback entry point from §4b.
;; When a rule exists, it fires. When no rule exists, the caller falls
;; back to the imperative infer/check arm.
;;
;; expr-tag-fn: (expr → symbol) — extracts the AST tag from an expression
;;   (provided by the caller to avoid dependency on syntax.rkt's tag dispatch)
;; ctx-val: context-cell-value — the current typing context
;; e: Expr — the expression to type
;; type-map-reader: (position → type-or-#f) — reads sub-expression types
;;
;; Returns: (cons 'ok type) if a rule fired successfully,
;;          (cons 'check ok?) if a check rule fired,
;;          #f if no rule exists for this tag (fall back to imperative).
(define (dispatch-typing-rule registry expr-tag-fn ctx-val e type-map-reader
                              #:expected-type [expected-type #f])
  (define tag (expr-tag-fn e))
  (define rule (typing-rule-registry-lookup registry tag))
  (cond
    [(not rule) #f]  ;; no rule for this tag → imperative fallback
    ;; Check mode: expected type provided, rule has check-fn
    [(and expected-type (typing-rule-check-fn rule))
     (define result ((typing-rule-check-fn rule) ctx-val e expected-type type-map-reader))
     ;; check-fn returns #t/#f for pass/fail, or 'not-ready if inputs missing.
     ;; #t/#f are valid results; 'not-ready means the rule can't fire yet.
     (if (eq? result 'not-ready)
         #f
         (cons 'check result))]
    ;; Infer mode
    [else
     (define result ((typing-rule-infer-fn rule) ctx-val e type-map-reader))
     ;; infer-fn returns a type, or 'not-ready if inputs missing.
     (if (or (not result) (eq? result 'not-ready))
         #f
         (cons 'ok result))]))


;; ============================================================
;; expr-typing-tag: extract AST tag symbol from an expression
;; ============================================================
;;
;; Maps expression structs to tag symbols used for registry lookup.
;; This is the bridge between Racket struct predicates and the
;; typing-rule registry's symbol-based indexing.

(define (expr-typing-tag e)
  (cond
    ;; Literals (value-carrying)
    [(expr-int? e)      'expr-int]
    [(expr-nat-val? e)  'expr-nat-val]
    [(expr-true? e)     'expr-true]
    [(expr-false? e)    'expr-false]
    ;; Type constructors (nullary)
    [(expr-Int? e)      'expr-Int]
    [(expr-Nat? e)      'expr-Nat]
    [(expr-Bool? e)     'expr-Bool]
    [(expr-String? e)   'expr-String]
    [(expr-Char? e)     'expr-Char]
    [(expr-Keyword? e)  'expr-Keyword]
    [(expr-Symbol? e)   'expr-Symbol]
    ;; Universe
    [(expr-Type? e)     'expr-Type]
    ;; Variables
    [(expr-bvar? e)     'expr-bvar]
    [(expr-fvar? e)     'expr-fvar]
    ;; Structural
    [(expr-app? e)      'expr-app]
    [(expr-lam? e)      'expr-lam]
    [(expr-Pi? e)       'expr-Pi]
    [(expr-Sigma? e)    'expr-Sigma]
    [(expr-fst? e)      'expr-fst]
    [(expr-snd? e)      'expr-snd]
    [(expr-meta? e)     'expr-meta]
    ;; Eliminators
    [(expr-natrec? e)   'expr-natrec]
    [(expr-boolrec? e)  'expr-boolrec]
    ;; Fallback
    [else               #f]))


;; ============================================================
;; Phase 2b: Literal + Universe Typing Rules
;; ============================================================
;;
;; The simplest rules: no context, no recursion, fixed types.
;; These validate the typing-rule framework with real expr types.

;; Helper: make a constant infer rule (returns a fixed type regardless of inputs).
(define (make-constant-infer-rule tag name result-type)
  (typing-rule
   tag name 0
   (lambda (_ctx _e _reader) result-type)
   ;; check-fn: type equality check against the constant type
   (lambda (_ctx _e expected _reader) (equal? expected result-type))
   0))

;; Register all literal typing rules into a registry.
;; Literals: expr-int → Int, expr-nat-val → Nat, expr-true/false → Bool
(define (register-literal-typing-rules! registry)
  ;; Integer literal: (expr-int v) → Int when v is exact-integer?
  (typing-rule-registry-add! registry
    (typing-rule
     'expr-int 'int-literal 0
     (lambda (_ctx e _reader)
       (if (exact-integer? (expr-int-val e)) (expr-Int) #f))
     (lambda (_ctx e expected _reader)
       (and (exact-integer? (expr-int-val e))
            (equal? expected (expr-Int))))
     0))
  ;; Nat value literal: (expr-nat-val _) → Nat
  (typing-rule-registry-add! registry
    (make-constant-infer-rule 'expr-nat-val 'nat-literal (expr-Nat)))
  ;; Boolean literals
  (typing-rule-registry-add! registry
    (make-constant-infer-rule 'expr-true 'true-literal (expr-Bool)))
  (typing-rule-registry-add! registry
    (make-constant-infer-rule 'expr-false 'false-literal (expr-Bool)))
  ;; Type constructors: each type IS a Type at universe level 0
  ;; Int : Type 0, Nat : Type 0, Bool : Type 0, etc.
  (for ([tag+name (list (cons 'expr-Int 'Int-type)
                        (cons 'expr-Nat 'Nat-type)
                        (cons 'expr-Bool 'Bool-type)
                        (cons 'expr-String 'String-type)
                        (cons 'expr-Char 'Char-type)
                        (cons 'expr-Keyword 'Keyword-type)
                        (cons 'expr-Symbol 'Symbol-type))])
    (typing-rule-registry-add! registry
      (make-constant-infer-rule (car tag+name) (cdr tag+name)
                                (expr-Type (lzero))))))

;; Universe rule: Type(l) : Type(l+1)
(define (register-universe-typing-rules! registry)
  (typing-rule-registry-add! registry
    (typing-rule
     'expr-Type 'universe 0
     (lambda (_ctx e _reader)
       (expr-Type (lsuc (expr-Type-level e))))
     ;; check: Type(l) checks against Type(l') when l < l' (cumulativity)
     ;; For now: exact level match (Phase 5 may refine with level solving)
     (lambda (_ctx e expected _reader)
       (and (expr-Type? expected)
            (equal? (lsuc (expr-Type-level e))
                    (expr-Type-level expected))))
     0)))


;; ============================================================
;; Phase 2c: Variable Lookup Typing Rules
;; ============================================================
;;
;; bvar: reads from context cell at de Bruijn position k, shifts by (k+1).
;; fvar: reads from global environment (off-network bridge, deferred to Track 7).

(define (register-variable-typing-rules! registry)
  ;; Bound variable: (expr-bvar k) → lookup-type(k, ctx), shifted by (k+1)
  (typing-rule-registry-add! registry
    (typing-rule
     'expr-bvar 'bound-variable-lookup 0
     (lambda (ctx-val e _reader)
       (define k (expr-bvar-index e))
       (define raw-type (context-lookup-type ctx-val k))
       (if (expr-error? raw-type)
           #f  ;; out of bounds — can't fire (or error in imperative path)
           (shift (+ k 1) 0 raw-type)))
     ;; check: bvar checks if its inferred type is consistent with expected
     (lambda (ctx-val e expected _reader)
       (define k (expr-bvar-index e))
       (define raw-type (context-lookup-type ctx-val k))
       (if (expr-error? raw-type)
           #f
           (equal? (shift (+ k 1) 0 raw-type) expected)))
     0))

  ;; Free variable: (expr-fvar name) → global-env-lookup-type(name)
  ;; Uses the off-network global environment bridge (§1c, deferred to Track 7).
  ;; Deprecation warnings are side effects — preserved here for parity with
  ;; the imperative arm, but will migrate to separate concern in Track 7.
  (typing-rule-registry-add! registry
    (typing-rule
     'expr-fvar 'free-variable-lookup 0
     (lambda (_ctx-val e _reader)
       (define name (expr-fvar-name e))
       (define ty (global-env-lookup-type name))
       (or ty #f))  ;; #f if not found (imperative path returns expr-error)
     ;; check: fvar checks if its type matches expected
     (lambda (_ctx-val e expected _reader)
       (define name (expr-fvar-name e))
       (define ty (global-env-lookup-type name))
       (and ty (equal? ty expected)))
     0)))


;; ============================================================
;; Phase 2d: Lambda + Pi + Sigma Formation Rules
;; ============================================================
;;
;; These rules use context extension (tensor) and read sub-expression
;; types from the type-map reader.
;;
;; In the propagator model:
;; - "is this a type?" = read the sub-expression's type from type-map;
;;   if it's Type(l), the sub-expression is a type at level l.
;; - "infer body under extended context" = extend context cell, read
;;   body's type from type-map (body's typing rule fires with extended ctx).
;;
;; The type-map reader receives AST sub-expression objects as position keys.
;; Phase 3 formalizes the position scheme when wiring to actual type-maps.

(define (register-binder-typing-rules! registry)
  ;; Lambda: (expr-lam m dom body) → Pi(m, dom, body-type)
  ;; Reads dom's type (must be Type(l)) and body's type from type-map.
  ;; Extends context with dom:m for body's typing.
  (typing-rule-registry-add! registry
    (typing-rule
     'expr-lam 'lambda-formation 2  ;; 2 sub-expressions: dom, body
     (lambda (ctx-val e reader)
       (define dom (expr-lam-type e))
       (define body (expr-lam-body e))
       (define m (expr-lam-mult e))
       (cond
         ;; Hole domain: can't infer without expected type (need check mode)
         [(expr-hole? dom) #f]
         [else
          ;; Read domain's type from type-map (must be Type(l) for dom to be a type)
          (define dom-type (reader dom))
          (cond
            [(not dom-type) 'not-ready]  ;; dom not typed yet
            [(not (expr-Type? dom-type)) #f]  ;; dom is not a type → error
            [else
             ;; Read body's type from type-map
             ;; The body's type was computed in an extended context (ctx + dom:m).
             ;; This is handled by the propagator wiring: body's typing rule
             ;; reads from a child context cell. Here we just read the result.
             (define body-type (reader body))
             (cond
               [(not body-type) 'not-ready]  ;; body not typed yet
               [(expr-error? body-type) #f]   ;; body typing failed
               [else (expr-Pi m dom body-type)])])]))
     ;; check: lambda against Pi — the bidirectional (meet, downward) case.
     ;; Uses expected Pi domain to fill hole domains.
     (lambda (ctx-val e expected reader)
       (cond
         [(not (expr-Pi? expected)) #f]  ;; can only check lambda against Pi
         [else
          (define m (expr-lam-mult e))
          (define dom (expr-lam-type e))
          (define body (expr-lam-body e))
          (define expected-dom (expr-Pi-domain expected))
          (define expected-cod (expr-Pi-codomain expected))
          (cond
            ;; Hole domain: accept expected domain (the key bidirectional case)
            [(expr-hole? dom)
             (define body-type (reader body))
             (cond
               [(not body-type) 'not-ready]
               [else (equal? body-type expected-cod)])]
            ;; Concrete domain: must match expected
            [else
             (and (equal? dom expected-dom)
                  (let ([body-type (reader body)])
                    (cond
                      [(not body-type) 'not-ready]
                      [else (equal? body-type expected-cod)])))])]))
     0))

  ;; Pi formation: (expr-Pi m dom cod) → Type(max(level(dom), level(cod)))
  ;; Both dom and cod must be types (their types must be Type(l)).
  (typing-rule-registry-add! registry
    (typing-rule
     'expr-Pi 'pi-formation 2
     (lambda (ctx-val e reader)
       (define dom (expr-Pi-domain e))
       (define cod (expr-Pi-codomain e))
       ;; Read types of domain and codomain
       (define dom-type (reader dom))
       (define cod-type (reader cod))
       (cond
         [(or (not dom-type) (not cod-type)) 'not-ready]
         [(not (expr-Type? dom-type)) #f]  ;; domain not a type
         [(not (expr-Type? cod-type)) #f]  ;; codomain not a type
         [else
          ;; Level = max(dom-level, cod-level)
          ;; For simplicity: use lmax (defined in prelude)
          (expr-Type (lmax (expr-Type-level dom-type)
                           (expr-Type-level cod-type)))]))
     ;; check: Pi checks against Type(l)
     (lambda (ctx-val e expected reader)
       (and (expr-Type? expected)
            (let ([result ((typing-rule-infer-fn
                            (typing-rule-registry-lookup registry 'expr-Pi))
                           ctx-val e reader)])
              (cond
                [(eq? result 'not-ready) 'not-ready]
                [(not result) #f]
                [else (equal? result expected)]))))
     0))

  ;; Sigma formation: (expr-Sigma A B) → Type(max(level(A), level(B)))
  (typing-rule-registry-add! registry
    (typing-rule
     'expr-Sigma 'sigma-formation 2
     (lambda (ctx-val e reader)
       (define a (expr-Sigma-fst-type e))
       (define b (expr-Sigma-snd-type e))
       (define a-type (reader a))
       (define b-type (reader b))
       (cond
         [(or (not a-type) (not b-type)) 'not-ready]
         [(not (expr-Type? a-type)) #f]
         [(not (expr-Type? b-type)) #f]
         [else (expr-Type (lmax (expr-Type-level a-type)
                                (expr-Type-level b-type)))]))
     #f  ;; no check-fn (Sigma checks via infer+compare)
     0)))


;; ============================================================
;; Phase 2e: Application (Tensor) Typing Rule
;; ============================================================
;;
;; The core application rule: (expr-app func arg) → result-type
;; Uses type-tensor-core from Track 2H (the quantale tensor).
;;
;; In the propagator model:
;; - func-type is read from the type-map at the func position
;; - arg-type is read from the type-map at the arg position
;; - type-tensor-core(func-type, arg-type) computes the result type
;; - Union distribution is EMERGENT: tensor returns type-bot for
;;   inapplicable components; the cell merge produces the union of
;;   valid results.
;;
;; The beta case (func is a lambda) is handled by the lambda rule's
;; check mode: when we know the expected arg type, the lambda rule
;; fires in check direction. The general application rule handles
;; the remaining case: infer func type, tensor with arg type.

(define (register-application-typing-rules! registry)
  ;; Application: (expr-app func arg) → type-tensor-core(func-type, arg-type)
  (typing-rule-registry-add! registry
    (typing-rule
     'expr-app 'application-tensor 2
     (lambda (ctx-val e reader)
       (define func (expr-app-func e))
       (define arg (expr-app-arg e))
       (define func-type (reader func))
       (define arg-type (reader arg))
       (cond
         [(or (not func-type) (not arg-type)) 'not-ready]
         [else
          (define result (type-tensor-core func-type arg-type))
          (cond
            [(type-bot? result) #f]  ;; inapplicable → error
            [(type-top? result) #f]  ;; contradiction → error
            [else result])]))
     ;; check: application against expected type.
     ;; Validates that tensor result is consistent with expected.
     (lambda (ctx-val e expected reader)
       (define func (expr-app-func e))
       (define arg (expr-app-arg e))
       (define func-type (reader func))
       (define arg-type (reader arg))
       (cond
         [(or (not func-type) (not arg-type)) 'not-ready]
         [else
          (define result (type-tensor-core func-type arg-type))
          (cond
            [(type-bot? result) #f]
            [(type-top? result) #f]
            [else (equal? result expected)])]))
     0))

  ;; Projection: (expr-fst e) → first component of Sigma type
  (typing-rule-registry-add! registry
    (typing-rule
     'expr-fst 'fst-projection 1
     (lambda (ctx-val e reader)
       (define inner (expr-fst-expr e))
       (define inner-type (reader inner))
       (cond
         [(not inner-type) 'not-ready]
         [(expr-Sigma? inner-type) (expr-Sigma-fst-type inner-type)]
         [else #f]))  ;; not a Sigma → error
     #f 0))

  ;; Projection: (expr-snd e) → second component of Sigma type
  (typing-rule-registry-add! registry
    (typing-rule
     'expr-snd 'snd-projection 1
     (lambda (ctx-val e reader)
       (define inner (expr-snd-expr e))
       (define inner-type (reader inner))
       (cond
         [(not inner-type) 'not-ready]
         [(expr-Sigma? inner-type) (expr-Sigma-snd-type inner-type)]
         [else #f]))
     #f 0)))


;; ============================================================
;; Phase 3: Integration — Typing-Rule-Aware Infer
;; ============================================================
;;
;; DPO-first + imperative-fallback (design §4b).
;;
;; `make-typing-rule-infer` creates a function that wraps an existing
;; `infer` function with typing-rule dispatch. For each expression:
;;   1. Check the registry for a typing rule matching this expr tag.
;;   2. If found, build a type-map-reader that recursively calls
;;      the WRAPPED infer on sub-expressions (mixed state: rules for
;;      this node, imperative/rule mix for children).
;;   3. If the rule fires, use its result.
;;   4. If no rule or not-ready, fall back to the original infer.
;;
;; This is the incremental migration path: as more rules are added
;; to the registry, more expressions are typed via rules, fewer via
;; imperative match arms. When all expressions have rules, the
;; fallback is never reached.

;; Create a registry with all currently-implemented typing rules.
;; Phase 4b deployment: only LEAF rules are safe for production dispatch.
;; Non-leaf rules (binder, application, variable, meta) have side effects
;; in the imperative path (constraint creation, meta solving, trait resolution)
;; that the pure typing rules don't reproduce. Enabling them causes constraint
;; resolution failures. Non-leaf rules remain for testing/parity validation.
;; They will be safe when constraint creation is also on-network (Phase 6+).
(define (make-default-typing-registry)
  (define reg (make-typing-rule-registry))
  (register-literal-typing-rules! reg)
  (register-universe-typing-rules! reg)
  ;; Phase 6+ will enable these as constraint creation moves on-network:
  ;; (register-variable-typing-rules! reg)
  ;; (register-binder-typing-rules! reg)
  ;; (register-application-typing-rules! reg)
  ;; (register-meta-typing-rules! reg)
  reg)

;; Create a typing-rule-aware infer function.
;; infer-fallback: (ctx expr → type-or-error) — the imperative infer
;; registry: typing-rule registry (or #f to use default)
;; Returns: (ctx expr → type-or-error) — same signature as infer
(define (make-typing-rule-infer infer-fallback
                                #:registry [registry #f])
  (define reg (or registry (make-default-typing-registry)))

  (define (rule-infer ctx e)
    ;; Build context-cell-value from the imperative ctx (list of (type . mult))
    (define ctx-val
      (context-cell-value ctx (length ctx)))

    ;; Build type-map-reader: reads sub-expression types by recursively
    ;; calling rule-infer on the sub-expression. This is the mixed-state
    ;; bridge: the reader itself may use rules or fall back for each sub.
    (define (type-map-reader sub-expr)
      (define result (rule-infer ctx sub-expr))
      (if (expr-error? result) #f result))

    ;; Try dispatch
    (define tag (expr-typing-tag e))
    (cond
      [(not tag)
       ;; Unknown tag → straight to fallback
       (infer-fallback ctx e)]
      [else
       (define dispatch-result
         (dispatch-typing-rule reg expr-typing-tag ctx-val e type-map-reader))
       (cond
         [(and dispatch-result (eq? (car dispatch-result) 'ok))
          (cdr dispatch-result)]
         [else
          ;; No rule, not-ready, or rule returned #f → fallback
          (infer-fallback ctx e)])]))

  rule-infer)

;; Phase 4b deployment: parameter for production pipeline wiring.
;; When set, infer/err uses this instead of raw (infer ctx e).
;; Installed by driver.rkt at startup via make-typing-rule-infer.
;; Default #f = not installed (use imperative infer directly).
(define current-typing-rule-infer (make-parameter #f))


;; ============================================================
;; Phase 4a: Meta-Variable Typing Rule
;; ============================================================
;;
;; Meta-variables ARE cells. When a meta appears in an expression,
;; its type is read directly from its cell (via cell-id fast path).
;; If the meta is solved, return the solution type. If unsolved,
;; return 'not-ready (propagator re-fires when the cell is written).
;;
;; This makes cells the SOLE AUTHORITY for meta solutions.
;; The CHAMP meta-info is kept for debugging/constraint tracking
;; but is NOT consulted for solution lookup.

(define (register-meta-typing-rules! registry)
  (typing-rule-registry-add! registry
    (typing-rule
     'expr-meta 'meta-follow 0
     (lambda (_ctx-val e _reader)
       ;; Read solution directly from cell (fast path)
       (define cell-id (expr-meta-cell-id e))
       (define id (expr-meta-id e))
       (define sol (meta-solution/cell-id cell-id id))
       (cond
         [sol sol]          ;; solved → return solution type
         [else 'not-ready])) ;; unsolved → wait for cell write
     ;; check: meta in check position — optimistically succeed
     ;; (matches current imperative behavior: [(expr-meta _ _) _) #t])
     (lambda (_ctx-val _e _expected _reader) #t)
     0)))


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

;; meta-readiness-value: tracks meta solve states for one form.
;;   registered: (hasheq meta-id → meta-class) — all metas in this form
;;     meta-class: 'type | 'level | 'mult | 'session
;;   solved: (seteq meta-id) — which metas have been solved
(struct meta-readiness-value
  (registered  ;; hasheq: meta-id → meta-class
   solved)     ;; seteq: solved meta-ids
  #:transparent)

;; Empty readiness (no metas registered, none solved)
(define meta-readiness-empty
  (meta-readiness-value (hasheq) (seteq)))

;; Register a new meta in this form's readiness tracking.
;; Returns updated readiness value.
(define (meta-readiness-register rv meta-id meta-class)
  (meta-readiness-value
   (hash-set (meta-readiness-value-registered rv) meta-id meta-class)
   (meta-readiness-value-solved rv)))

;; Mark a meta as solved. Returns updated readiness value.
(define (meta-readiness-solve rv meta-id)
  (meta-readiness-value
   (meta-readiness-value-registered rv)
   (set-add (meta-readiness-value-solved rv) meta-id)))

;; Get the set of unsolved metas (registered but not solved).
;; Returns: (listof (cons meta-id meta-class))
(define (meta-readiness-unsolved rv)
  (define registered (meta-readiness-value-registered rv))
  (define solved (meta-readiness-value-solved rv))
  (for/list ([(id cls) (in-hash registered)]
             #:unless (set-member? solved id))
    (cons id cls)))

;; Are all registered metas solved?
(define (meta-readiness-all-solved? rv)
  (= (hash-count (meta-readiness-value-registered rv))
     (set-count (meta-readiness-value-solved rv))))

;; Merge: set-union on both registered and solved (monotone).
(define (meta-readiness-merge old new)
  (meta-readiness-value
   ;; Registered: union of all registered metas
   (for/fold ([result (meta-readiness-value-registered old)])
             ([(id cls) (in-hash (meta-readiness-value-registered new))])
     (hash-set result id cls))
   ;; Solved: union of solved sets
   (set-union (meta-readiness-value-solved old)
              (meta-readiness-value-solved new))))

;; Meta-readiness cells don't contradict.
(define (meta-readiness-contradicts? v) #f)


;; ============================================================
;; Phase 6: Constraint SRE Domain
;; ============================================================
;;
;; Trait constraints as a lattice: pending (⊥) → resolved(instance) → contradicted (⊤).
;; Each constraint cell tracks one trait constraint (e.g., "Eq ?A").
;; The constraint fires as a propagator when its argument type is refined.
;;
;; Lattice (from design §1b):
;;   pending ⊔ pending = pending
;;   pending ⊔ resolved(A) = resolved(A)
;;   resolved(A) ⊔ resolved(A) = resolved(A)  (idempotent)
;;   resolved(A) ⊔ resolved(B) = contradicted  (A ≠ B, coherence violation)
;;   contradicted ⊔ X = contradicted
;;
;; Meet (GLB, dual of join):
;;   meet(contradicted, X) = X              (⊤ is identity for meet)
;;   meet(pending, X) = pending             (⊥ is annihilator)
;;   meet(resolved(A), resolved(A)) = resolved(A)
;;   meet(resolved(A), resolved(B)) = pending  (different → ⊥)

;; constraint-cell-value: the state of one trait constraint.
;;   status: 'pending | 'resolved | 'contradicted
;;   instance: the resolved instance (when status = 'resolved), #f otherwise
(struct constraint-cell-value
  (status    ;; 'pending | 'resolved | 'contradicted
   instance) ;; resolved instance value, or #f
  #:transparent)

;; Constructors
(define constraint-pending (constraint-cell-value 'pending #f))
(define (constraint-resolved instance) (constraint-cell-value 'resolved instance))
(define constraint-contradicted (constraint-cell-value 'contradicted #f))

;; Predicates
(define (constraint-pending? v)
  (and (constraint-cell-value? v) (eq? (constraint-cell-value-status v) 'pending)))
(define (constraint-resolved? v)
  (and (constraint-cell-value? v) (eq? (constraint-cell-value-status v) 'resolved)))
(define (constraint-contradicted? v)
  (and (constraint-cell-value? v) (eq? (constraint-cell-value-status v) 'contradicted)))

;; Join (⊔): accumulate constraint information monotonically.
(define (constraint-cell-merge old new)
  (cond
    ;; contradicted absorbs everything
    [(constraint-contradicted? old) old]
    [(constraint-contradicted? new) new]
    ;; pending + X = X (pending is ⊥)
    [(constraint-pending? old) new]
    [(constraint-pending? new) old]
    ;; resolved + resolved: same instance → idempotent, different → contradicted
    [(and (constraint-resolved? old) (constraint-resolved? new))
     (if (equal? (constraint-cell-value-instance old)
                 (constraint-cell-value-instance new))
         old  ;; idempotent
         constraint-contradicted)]  ;; coherence violation
    ;; fallback (shouldn't happen)
    [else constraint-contradicted]))

;; Meet (⊓): dual of join.
(define (constraint-cell-meet a b)
  (cond
    ;; contradicted is identity for meet
    [(constraint-contradicted? a) b]
    [(constraint-contradicted? b) a]
    ;; pending is annihilator for meet
    [(constraint-pending? a) a]
    [(constraint-pending? b) b]
    ;; resolved + resolved: same → keep, different → pending (no common lower bound)
    [(and (constraint-resolved? a) (constraint-resolved? b))
     (if (equal? (constraint-cell-value-instance a)
                 (constraint-cell-value-instance b))
         a
         constraint-pending)]
    [else constraint-pending]))

;; Contradiction check: is this cell value at ⊤?
(define (constraint-cell-contradicts? v)
  (constraint-contradicted? v))
