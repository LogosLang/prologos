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
         "syntax.rkt")

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
 dispatch-typing-rule)

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
