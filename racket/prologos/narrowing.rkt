#lang racket/base

;;;
;;; narrowing.rkt — Narrowing Propagator for FL Narrowing
;;;
;;; Installs propagators into a propagator network that implement needed
;;; narrowing guided by definitional trees.  Given a function's definitional
;;; tree, argument cells, and a result cell, this module installs propagators
;;; that:
;;;
;;;   - Branch nodes: watch the scrutinized arg cell; when it receives a
;;;     constructor, deterministically follow the matching child.  When the
;;;     cell is bot, residuate (don't fire).
;;;
;;;   - Rule nodes: when all pattern variables are bound, build the result
;;;     term and write it to the result cell.
;;;
;;;   - Exempt nodes: write term-top (contradiction) to the result cell —
;;;     the function is undefined for this pattern.
;;;
;;;   - Or nodes: create ATMS amb choices over alternative branches.
;;;
;;; The narrowing propagator is additive: calling a function with ground
;;; arguments produces the same result as the reducer (deterministic path
;;; through the tree, no amb needed).
;;;
;;; DEPENDENCIES: propagator.rkt, term-lattice.rkt, definitional-tree.rkt,
;;;               macros.rkt (for ctor registry)
;;;
;;; Phase 1c of FL Narrowing implementation.
;;;

(require racket/match
         racket/list
         "propagator.rkt"
         "term-lattice.rkt"
         "definitional-tree.rkt"
         "confluence-analysis.rkt"
         "termination-analysis.rkt"
         "interval-domain.rkt"
         "narrowing-abstract.rkt"
         "search-heuristics.rkt"
         "global-constraints.rkt"
         "bb-optimization.rkt"
         "cfa-analysis.rkt"
         "macros.rkt"
         "global-env.rkt")

(provide
 ;; Core API
 install-narrowing-propagators
 narrow-function
 ;; Demand analysis
 narrowing-demands
 ;; Phase 1d: Narrowing search
 run-narrowing-search
 ;; Phase 2c: Confluence classification
 get-confluence-class
 ;; Phase 2b: Termination classification
 get-termination-class
 get-function-fuel
 ;; Phase 2a: Interval domain
 current-narrow-intervals
 ;; Helpers (for testing)
 term-from-ground-expr
 nat->term
 bindings-to-read-fn)

;; ========================================
;; Term construction from ground expressions
;; ========================================

;; term-from-ground-expr : expr × prop-network × (expr → val) → (values prop-network term-value)
;;
;; Converts a ground (fully known) core expression into a term-lattice value,
;; creating sub-cells in the network for constructor arguments.
;;
;; The `eval-fn` parameter evaluates sub-expressions that aren't simple
;; constructors (e.g., function calls).  For Phase 1c, we handle the common
;; cases: nullary ctors (zero, true, false, nil), unary ctors (suc),
;; binary ctors (cons), and nat literals.
(define (term-from-ground-expr expr net)
  (match expr
    ;; Nullary constructors
    [(? (lambda (e) (and (struct? e)
                        (let ([name (ground-expr->ctor-name e)])
                          (and name
                               (let ([meta (lookup-ctor name)])
                                 (and meta (null? (ctor-meta-field-types meta)))))))))
     (values net (term-ctor (ground-expr->ctor-name expr) '()))]
    ;; Suc with sub-expression
    [(? (lambda (e) (expr-suc? e)))
     (define-values (net1 sub-term) (term-from-ground-expr (expr-suc-pred expr) net))
     (define-values (net2 sub-cid) (net-new-cell net1 sub-term term-merge term-contradiction?))
     (values net2 (term-ctor 'suc (list sub-cid)))]
    ;; Nat literal → unary Nat chain
    [(? (lambda (e) (expr-nat-val? e)))
     (nat->term (expr-nat-val-n expr) net)]
    ;; Application of a constructor (generic case)
    ;; For now, treat as opaque — will be extended in Phase 1d
    [_
     (values net term-bot)]))

;; ground-expr->ctor-name : expr → symbol | #f
;; Maps known ground expression types to their constructor symbol.
(define (ground-expr->ctor-name expr)
  (cond
    [(expr-zero? expr)  'zero]
    [(expr-true? expr)  'true]
    [(expr-false? expr) 'false]
    [else #f]))

;; We need the syntax struct predicates.  Import them via a lazy approach:
;; since macros.rkt already re-exports from syntax.rkt, we get them transitively.
;; But let's be explicit about what we need:
(require "syntax.rkt")

;; nat->term : Nat × prop-network → (values prop-network term-value)
;; Convert a natural number to a term-lattice Nat chain:  0 → zero, n → suc(suc(...zero))
(define (nat->term n net)
  (if (zero? n)
      (values net (term-ctor 'zero '()))
      (let-values ([(net1 pred-term) (nat->term (sub1 n) net)])
        (let-values ([(net2 pred-cid) (net-new-cell net1 pred-term term-merge term-contradiction?)])
          (values net2 (term-ctor 'suc (list pred-cid)))))))

;; ========================================
;; Binding environment for pattern variables
;; ========================================

;; A binding environment maps de Bruijn indices (from the definitional tree
;; path) to cell-ids in the propagator network.  As we descend through a
;; dt-branch, we bind the sub-cells of the matched constructor.
;;
;; Representation: (listof cell-id), indexed by position.
;; Index 0 is the most recently bound variable.

;; bindings-to-read-fn : (listof cell-id) × prop-network → (cell-id → term-value)
;; Create a read function for term-walk from a binding environment and network.
(define (bindings-to-read-fn bindings net)
  (lambda (cid)
    (net-cell-read net cid)))

;; ========================================
;; Core: install narrowing propagators
;; ========================================

;; install-narrowing-propagators :
;;   prop-network × def-tree × (listof cell-id) × cell-id × (listof cell-id)
;;   → prop-network
;;
;; Walks the definitional tree and installs propagators that implement
;; needed narrowing.
;;
;; Parameters:
;;   net        — current propagator network
;;   tree       — definitional tree node (dt-branch, dt-rule, dt-or, dt-exempt)
;;   arg-cells  — cell-ids for the function's arguments (positional)
;;   result-cell — cell-id for the function's return value
;;   bindings   — accumulated pattern variable bindings (cell-ids, de Bruijn order)
;;
;; Returns: updated prop-network with new propagators installed.
(define (install-narrowing-propagators net tree arg-cells result-cell bindings)
  (match tree
    ;; ---- Branch: case analysis on an argument ----
    [(dt-branch pos type-name children)
     (define watched-cell (list-ref arg-cells pos))
     (define-values (net* _pid)
       (net-add-propagator
        net
        (list watched-cell)   ;; watch the scrutinized arg
        (list result-cell)    ;; may eventually write to result
        (make-branch-fire-fn watched-cell pos type-name children
                             arg-cells result-cell bindings)))
     net*]

    ;; ---- Rule: leaf with RHS expression ----
    [(dt-rule rhs)
     ;; Install a propagator that watches all bound cells.
     ;; When all bindings are determined (non-bot), evaluate the RHS
     ;; and write to result-cell.
     (if (null? bindings)
         ;; No bindings (constant function) — write immediately
         (let-values ([(net1 result-term) (term-from-ground-expr rhs net)])
           (net-cell-write net1 result-cell result-term))
         ;; Watch all binding cells; fire when any changes
         (let-values ([(net* _pid)
                       (net-add-propagator
                        net
                        bindings           ;; watch all bound cells
                        (list result-cell)  ;; write to result
                        (make-rule-fire-fn rhs bindings result-cell))])
           net*))]

    ;; ---- Or: non-deterministic (overlapping patterns) ----
    [(dt-or branches)
     ;; For now, try each branch sequentially (deterministic fallthrough).
     ;; Full ATMS amb support will come with solver integration (Phase 1d).
     ;; For Phase 1c: install propagators for ALL branches.  The first one
     ;; that fires and writes a non-bot value to result-cell wins (lattice
     ;; merge handles this correctly).
     (for/fold ([n net])
               ([branch (in-list branches)])
       (install-narrowing-propagators n branch arg-cells result-cell bindings))]

    ;; ---- Exempt: function undefined for this pattern ----
    [(dt-exempt)
     ;; Write contradiction to result cell
     (net-cell-write net result-cell term-top)]

    ;; ---- Unknown/fallback ----
    [_ net]))

;; ========================================
;; Branch propagator: case analysis
;; ========================================

;; make-branch-fire-fn : creates the fire-fn for a dt-branch propagator.
;;
;; When the watched cell receives a constructor, we determine which child
;; branch to follow and recursively install propagators for that child.
;;
;; Key behaviors:
;;   - bot → residuate (return net unchanged, don't fire)
;;   - term-ctor(tag, sub-cells) → look up tag in children, install child propagators
;;   - term-var → residuate (demand-driven: wait for more info)
;;   - term-top → contradiction already recorded, do nothing
(define (make-branch-fire-fn watched-cell pos type-name children
                             arg-cells result-cell bindings)
  (lambda (net)
    (define val (net-cell-read net watched-cell))
    (define walked (term-walk val (lambda (cid) (net-cell-read net cid))))
    (match walked
      ;; Bot: residuate — wait for information
      [(? term-bot?) net]

      ;; Constructor: deterministic case analysis
      [(term-ctor tag sub-cells)
       (define child-entry (assq tag children))
       (if child-entry
           ;; Found matching branch — extend bindings with sub-cells
           ;; and recursively install propagators for the child subtree.
           ;; Sub-cells are prepended to bindings (de Bruijn: newest first).
           (let ([child-tree (cdr child-entry)]
                 [new-bindings (append (reverse sub-cells) bindings)])
             (install-narrowing-propagators net child-tree arg-cells result-cell new-bindings))
           ;; No matching constructor in the tree — exempt (partial function)
           (net-cell-write net result-cell term-top))]

      ;; Variable: residuate (wait for binding)
      [(term-var _) net]

      ;; Top: contradiction already present, nothing to do
      [(? term-top?) net]

      ;; Anything else: residuate
      [_ net])))

;; ========================================
;; Rule propagator: evaluate RHS
;; ========================================

;; make-rule-fire-fn : creates the fire-fn for a dt-rule propagator.
;;
;; When all binding cells have non-bot values, attempt to evaluate the RHS
;; and write the result to the result cell.
;;
;; For Phase 1c, we handle simple cases:
;;   - Bound variable references (de Bruijn indices into bindings)
;;   - Constructor applications (zero, suc, cons, etc.)
;;   - Simple expressions
;;
;; Complex RHS expressions (function calls, recursion) are deferred to
;; Phase 1d where solver integration provides the full evaluation context.
(define (make-rule-fire-fn rhs bindings result-cell)
  (lambda (net)
    ;; Check if all bindings are determined
    (define binding-vals
      (for/list ([cid (in-list bindings)])
        (term-walk (net-cell-read net cid)
                   (lambda (c) (net-cell-read net c)))))
    ;; If any binding is still bot, residuate
    (if (ormap term-bot? binding-vals)
        net
        ;; All bindings determined — evaluate RHS
        (let-values ([(net1 result-term) (eval-rhs rhs bindings net)])
          (if (term-bot? result-term)
              net1  ;; couldn't evaluate — residuate
              (net-cell-write net1 result-cell result-term))))))

;; eval-rhs : expr × (listof cell-id) × prop-network → (values prop-network term-value)
;;
;; Evaluate a definitional tree RHS expression in the context of pattern bindings.
;; Each de Bruijn index maps to a cell-id in `bindings`.
;;
;; Handles:
;;   - expr-bvar: look up binding → read cell value
;;   - expr-zero, expr-true, expr-false: nullary constructors
;;   - expr-suc: unary constructor with recursive eval
;;   - expr-nat-val: literal natural
;;   - expr-app of constructor: constructor application
;;   - expr-fvar + expr-app: function calls → create narrowing sub-problem (recursive)
;;   - expr-reduce: nested match → treat as new narrowing sub-problem
(define (eval-rhs expr bindings net)
  (match expr
    ;; Bound variable — read its cell value
    [(expr-bvar idx)
     (if (< idx (length bindings))
         (let ([cid (list-ref bindings idx)])
           (values net (net-cell-read net cid)))
         (values net term-bot))]

    ;; Nullary constructors
    [(expr-zero)  (values net (term-ctor 'zero '()))]
    [(expr-true)  (values net (term-ctor 'true '()))]
    [(expr-false) (values net (term-ctor 'false '()))]

    ;; Suc — recursive
    [(expr-suc sub)
     (define-values (net1 sub-term) (eval-rhs sub bindings net))
     (if (term-bot? sub-term)
         (values net1 term-bot)
         (let-values ([(net2 sub-cid) (net-new-cell net1 sub-term term-merge term-contradiction?)])
           (values net2 (term-ctor 'suc (list sub-cid)))))]

    ;; Nat literal
    [(expr-nat-val n)
     (nat->term n net)]

    ;; Application: check if it's a constructor application
    [(expr-app func arg)
     (define ctor-name (expr->ctor-name func))
     (if ctor-name
         ;; Constructor application — build term
         (let-values ([(net1 arg-term) (eval-rhs arg bindings net)])
           (if (term-bot? arg-term)
               (values net1 term-bot)
               (let-values ([(net2 arg-cid) (net-new-cell net1 arg-term term-merge term-contradiction?)])
                 ;; Check if we're building up a multi-arg constructor
                 ;; by seeing if func is itself an application
                 (define existing-sub-cells (expr->ctor-sub-cells func bindings net2))
                 (if existing-sub-cells
                     (let ([all-cells (append (cdr existing-sub-cells) (list arg-cid))])
                       (values net2 (term-ctor (car existing-sub-cells) all-cells)))
                     (values net2 (term-ctor ctor-name (list arg-cid)))))))
         ;; Not a constructor — can't evaluate in narrowing context yet
         ;; For function calls, we'd need to install recursive narrowing (Phase 1d)
         (values net term-bot))]

    ;; Free variable (function reference) — can't evaluate standalone
    [(expr-fvar _) (values net term-bot)]

    ;; Lambda — can't narrow through higher-order yet
    [(expr-lam _ _ _) (values net term-bot)]

    ;; Anything else — opaque
    [_ (values net term-bot)]))

;; expr->ctor-name : expr → symbol | #f
;; Extract constructor name from an expression (function position).
(define (expr->ctor-name expr)
  (match expr
    [(expr-fvar name)
     (if (lookup-ctor name) name #f)]
    [(expr-zero)  'zero]
    [(expr-true)  'true]
    [(expr-false) 'false]
    ;; Partially applied constructor: (cons a) is (app (fvar cons) a)
    ;; The outermost ctor name is in the leftmost fvar
    [(expr-app func _)
     (expr->ctor-name func)]
    [_ #f]))

;; expr->ctor-sub-cells : expr × bindings × net → (cons ctor-name (listof cell-id)) | #f
;; For curried constructor applications like ((cons a) b), extract the ctor name
;; and already-built sub-cells from the function position.
(define (expr->ctor-sub-cells expr bindings net)
  (match expr
    [(expr-app inner-func inner-arg)
     (define ctor-name (expr->ctor-name inner-func))
     (when ctor-name
       (define-values (_net arg-term) (eval-rhs inner-arg bindings net))
       (unless (term-bot? arg-term)
         ;; This is getting complex for deeply curried constructors.
         ;; For Phase 1c, handle the common 2-arg case:
         (define-values (net2 arg-cid) (net-new-cell net arg-term term-merge term-contradiction?))
         (cons ctor-name (list arg-cid))))
     #f]
    [_ #f]))

;; ========================================
;; Top-level: narrow a function
;; ========================================

;; narrow-function : prop-network × symbol × def-tree × Nat → (values prop-network (listof cell-id) cell-id)
;;
;; Creates argument cells and a result cell for a function, then installs
;; narrowing propagators from its definitional tree.
;;
;; Parameters:
;;   net   — current propagator network
;;   name  — function name (for diagnostics)
;;   tree  — definitional tree
;;   arity — number of function arguments
;;
;; Returns:
;;   net'        — updated network with propagators installed
;;   arg-cells   — list of cell-ids for function arguments
;;   result-cell — cell-id for function result
(define (narrow-function net name tree arity)
  ;; Create argument cells (initially bot — unknown)
  (define-values (net1 arg-cells)
    (for/fold ([n net] [cells '()])
              ([i (in-range arity)])
      (let-values ([(n* cid) (net-new-cell n term-bot term-merge term-contradiction?)])
        (values n* (append cells (list cid))))))
  ;; Create result cell (initially bot)
  (define-values (net2 result-cell)
    (net-new-cell net1 term-bot term-merge term-contradiction?))
  ;; Install narrowing propagators from the definitional tree
  (define net3
    (install-narrowing-propagators net2 tree arg-cells result-cell '()))
  (values net3 arg-cells result-cell))

;; ========================================
;; Demand analysis
;; ========================================

;; narrowing-demands : prop-network × (listof cell-id) → (listof cell-id)
;;
;; Returns the list of argument cells that are still at bot (unresolved).
;; These represent demands — the narrowing propagator is waiting for
;; information on these cells before it can fire.
;;
;; Used by the search phase to decide which cell to narrow next.
(define (narrowing-demands net arg-cells)
  (for/list ([cid (in-list arg-cells)]
             #:when (term-bot? (term-walk (net-cell-read net cid)
                                          (lambda (c) (net-cell-read net c)))))
    cid))

;; ========================================
;; Phase 1d: DT-Guided Narrowing Search
;; ========================================
;;
;; Given [f ?x ?y ...] = target, find all substitutions for the ?-variables
;; such that f(x, y, ...) = target.  Walks the definitional tree to enumerate
;; argument instantiations (needed narrowing), substitutes into the rule RHS,
;; and matches structurally against the target.  Function calls in the RHS
;; trigger recursive narrowing.

(define NARROW-DEPTH-LIMIT 50)

;; ----------------------------------------
;; Phase 2a: Interval domain for bounded enumeration
;; ----------------------------------------

;; Maps logic-var name (symbol) → interval.
;; Threaded via parameterize for proper backtracking in search.
(define current-narrow-intervals (make-parameter (hasheq)))

;; ----------------------------------------
;; Confluence classification (Phase 2c)
;; ----------------------------------------

;; Lazily analyze and cache confluence for a function's definitional tree.
;; Returns 'confluent, 'non-confluent, or 'unknown.
;; Tries DT registry first, then extracts from function body if needed.
(define (get-confluence-class func-name)
  (define cached (lookup-confluence func-name))
  (cond
    [cached (confluence-result-class cached)]
    [else
     (define tree
       (or (lookup-def-tree func-name)
           ;; Fallback: extract DT from function body in global env
           (let ([body (global-env-lookup-value func-name)])
             (and body (extract-definitional-tree body)))))
     (cond
       [tree
        (define result (analyze-confluence tree))
        (register-confluence! func-name result)
        (confluence-result-class result)]
       [else 'unknown])]))

;; ----------------------------------------
;; Termination classification (Phase 2b)
;; ----------------------------------------

;; Lazily analyze and cache termination for a function.
;; Returns 'terminating, 'bounded, or 'non-narrowable.
(define (get-termination-class func-name)
  (define cached (lookup-termination func-name))
  (cond
    [cached (termination-result-class cached)]
    [else
     (define body (global-env-lookup-value func-name))
     (cond
       [body
        (define tree (or (lookup-def-tree func-name)
                         (extract-definitional-tree body)))
        (define-values (arity _inner) (peel-lambdas body))
        (define result (analyze-termination func-name tree arity))
        (register-termination! func-name result)
        (termination-result-class result)]
       [else 'non-narrowable])]))

;; Get the fuel bound for a function (per-function or default).
(define (get-function-fuel func-name)
  (define cached (lookup-termination func-name))
  (cond
    [cached
     (define class (termination-result-class cached))
     (cond
       [(eq? class 'terminating) NARROW-DEPTH-LIMIT]
       [(eq? class 'bounded)
        (or (termination-result-fuel-bound cached) NARROW-DEPTH-LIMIT)]
       [else 0])]  ;; non-narrowable: no fuel
    [else
     ;; Not yet analyzed — trigger analysis
     (get-termination-class func-name)
     (get-function-fuel func-name)]))

;; run-narrowing-search :
;;   symbol × (listof expr) × expr × (listof symbol) → (listof hasheq)
;;
;; Entry point for narrowing.  Returns a list of answer maps (hasheq),
;; each mapping variable names (from var-names) to ground Prologos values.
(define (run-narrowing-search func-name arg-exprs target-expr var-names)
  (define func-body (global-env-lookup-value func-name))
  (when (not func-body) (set! func-body #f))
  (cond
    [(not func-body) '()]
    [else
     (define dt (extract-definitional-tree func-body))
     (cond
       [(not dt) '()]
       [else
        ;; Phase 2b: check termination class before searching
        (define term-class (get-termination-class func-name))
        (cond
          [(eq? term-class 'non-narrowable) '()]
          [else
           (define-values (arity _inner) (peel-lambdas func-body))
           ;; Build initial binding stack.
           ;; After peeling n lambdas: bvar 0 = last param, bvar (n-1) = first param.
           ;; So initial-bindings = (reverse arg-exprs).
           ;; Normalize ground args to Peano form (nat-val/int → suc/zero chains)
           ;; so they match structurally when substituted into RHS bodies.
           (define initial-bindings
             (reverse (map normalize-narrow-target arg-exprs)))
           ;; Normalize target for matching (convert nat-val to Peano suc/zero)
           (define target-norm (normalize-narrow-target target-expr))
           ;; Per-function fuel from termination analysis
           (define fuel (get-function-fuel func-name))
           ;; Phase 2a: Compute initial intervals for argument variables
           (define initial-intervals
             (let ([arg-ivs (compute-arg-intervals func-name arg-exprs target-norm)])
               (cond
                 [arg-ivs
                  (for/fold ([store (hasheq)])
                            ([arg (in-list arg-exprs)]
                             [iv (in-list arg-ivs)])
                    (if (expr-logic-var? arg)
                        (hash-set store (expr-logic-var-name arg) iv)
                        store))]
                 [else (hasheq)])))
           ;; Phase 3b: Search heuristics
           (define search-cfg (current-narrow-search-config))
           (define counter (make-solution-counter
                            (narrow-search-config-search-mode search-cfg)))
           ;; Phase 3c: Global constraints and BB optimization
           ;; Inject type-guard constraints from ?x:Nat:Even constraint chains
           (define base-constraints (current-narrow-constraints))
           (define var-constraint-map (current-narrow-var-constraints))
           (define type-guard-constraints
             (if (hash-empty? var-constraint-map)
                 '()
                 (for*/list ([(vn type-names) (in-hash var-constraint-map)]
                             [tn (in-list type-names)])
                   (narrow-constraint 'type-guard (list vn) tn))))
           (define constraints (append type-guard-constraints base-constraints))
           (define bb (current-bb-state))
           ;; Build the core search function (takes fuel, returns solutions)
           (define (do-search f)
             (parameterize ([current-narrow-intervals initial-intervals]
                            [current-narrow-constraints constraints]
                            [current-bb-state bb])
               (narrow-dt-search dt initial-bindings func-name
                                target-norm (hasheq) 0 f counter)))
           ;; Run search: iterative deepening or fixed fuel
           (define raw-solutions
             (if (narrow-search-config-iterative? search-cfg)
                 (iterative-deepening-search do-search fuel)
                 (do-search fuel)))
           ;; Phase 3c: update BB bound for each solution found
           (when bb
             (for ([sol (in-list raw-solutions)])
               (bb-update-bound! bb sol)))
           ;; Phase 3c: filter to optimal solutions if BB active
           (define filtered-solutions
             (if bb
                 (bb-filter-optimal raw-solutions bb)
                 raw-solutions))
           ;; Project and resolve variable names from solutions
           (for/list ([sol (in-list filtered-solutions)])
             (for/hasheq ([vn (in-list var-names)])
               (values vn (narrow-resolve-val sol vn))))])])]))

;; ----------------------------------------
;; Target normalization
;; ----------------------------------------

;; Convert numeric literals to Peano suc/zero chains for structural matching.
;; Function bodies use suc/zero, so the target must match that representation.
;; Handles both expr-nat-val (natural numbers) and expr-int (integer literals,
;; which are used for bare numeric literals like 5 in the parser).
(define (normalize-narrow-target expr)
  (match expr
    [(expr-nat-val n) (nat-val->peano n)]
    [(expr-int n) (if (>= n 0) (nat-val->peano n) expr)]
    [(expr-suc sub) (expr-suc (normalize-narrow-target sub))]
    [(expr-app f a)
     (expr-app (normalize-narrow-target f) (normalize-narrow-target a))]
    [_ expr]))

(define (nat-val->peano n)
  (if (zero? n) (expr-zero) (expr-suc (nat-val->peano (- n 1)))))

;; ----------------------------------------
;; DT-guided search
;; ----------------------------------------

;; narrow-dt-search : dt × bindings × func-name × target × subst × depth × fuel
;;                    → (listof hasheq)
;;
;; bindings: (listof expr) indexed by bvar position (newest first).
;;   Contains expr-logic-var for unbound variables, concrete exprs for ground.
;; subst: hasheq mapping logic-var names (symbols) to values.
;; fuel: per-function depth limit (from termination analysis or NARROW-DEPTH-LIMIT).
(define (narrow-dt-search tree bindings func-name target subst depth
                          [fuel NARROW-DEPTH-LIMIT]
                          [counter 'unlimited])
  (cond
    [(> depth fuel) '()]
    [(solution-counter-exhausted? counter) '()]
    [else
     (match tree
       [(dt-branch pos type-name children)
        ;; Map DT position to binding stack index.
        ;; Position was computed as (arity - 1 - bvar_index) during extraction.
        ;; Our binding stack has the same structure, so:
        ;;   binding-index = (length bindings) - 1 - pos
        (define binding-idx (- (length bindings) 1 pos))
        (cond
          [(or (< binding-idx 0) (>= binding-idx (length bindings))) '()]
          [else
           (define current-val (list-ref bindings binding-idx))
           (cond
             ;; Unbound logic variable — enumerate constructors
             [(expr-logic-var? current-val)
              (define var-name (expr-logic-var-name current-val))
              ;; Phase 2a: interval lookup for numeric types
              (define var-iv
                (and (nat-type-name? type-name)
                     (hash-ref (current-narrow-intervals) var-name
                               (type-initial-interval type-name))))
              (cond
                ;; Interval contradiction — no solutions
                [(and var-iv (interval-contradiction? var-iv)) '()]
                ;; Enumerate constructors (with interval pruning when var-iv available)
                [else
                 ;; Phase 3b: apply value ordering
                 (define search-cfg (current-narrow-search-config))
                 (define ordered-children
                   (reorder-dt-children children
                                        (narrow-search-config-value-order search-cfg)
                                        dt-exempt?))
                 ;; Phase 3b: use bounded-append-map for early exit
                 (bounded-append-map
                  (lambda (child-entry)
                    (define ctor-name (car child-entry))
                    (define child-tree (cdr child-entry))
                    (define short (ctor-short-name ctor-name))
                    (cond
                      [(dt-exempt? child-tree) '()]
                      ;; Phase 2a: skip zero when interval lo > 0
                      [(and var-iv (eq? short 'zero)
                            (> (interval-lo var-iv) 0))
                       '()]
                      ;; Phase 2a: skip suc when interval hi = 0
                      [(and var-iv (eq? short 'suc)
                            (eqv? (interval-hi var-iv) 0))
                       '()]
                      [else
                       (define ctor-meta-info (lookup-ctor-flexible ctor-name))
                       (define field-count
                         (if ctor-meta-info
                             (length (ctor-meta-field-types ctor-meta-info))
                             0))
                       ;; Fresh logic vars for sub-fields
                       (define sub-vars
                         (for/list ([i (in-range field-count)])
                           (expr-logic-var
                            (gensym (format "~a~a_" ctor-name i))
                            'free)))
                       ;; Build constructor expression
                       (define ctor-val (make-narrow-ctor-expr ctor-name sub-vars))
                       ;; Update bindings at the narrowed position
                       (define updated-bindings
                         (for/list ([b (in-list bindings)]
                                    [i (in-naturals)])
                           (if (= i binding-idx) ctor-val b)))
                       ;; Prepend sub-field bindings (reversed, per de Bruijn)
                       (define new-bindings
                         (append (reverse sub-vars) updated-bindings))
                       ;; Record in substitution
                       (define new-subst (hash-set subst var-name ctor-val))
                       ;; Phase 2a: propagate sub-interval for suc
                       (define new-intervals
                         (if (and var-iv (eq? short 'suc) (= field-count 1))
                             (let* ([sub-name (expr-logic-var-name (car sub-vars))]
                                    [sub-iv (interval
                                             (max 0 (- (interval-lo var-iv) 1))
                                             (if (eqv? (interval-hi var-iv) +inf.0)
                                                 +inf.0
                                                 (- (interval-hi var-iv) 1)))])
                               (hash-set (current-narrow-intervals) sub-name sub-iv))
                             (current-narrow-intervals)))
                       ;; Phase 3c: forward-check constraints
                       (define active-constraints (current-narrow-constraints))
                       (define fc-result
                         (if (null? active-constraints)
                             (list new-subst active-constraints new-intervals)
                             (forward-check new-subst active-constraints new-intervals)))
                       (cond
                         [(not fc-result) '()]  ;; constraint violation → prune
                         [else
                          (define fc-subst (car fc-result))
                          (define fc-constraints (cadr fc-result))
                          (define fc-intervals (caddr fc-result))
                          ;; Phase 3c: BB pruning
                          (define bb (current-bb-state))
                          (cond
                            [(and bb (bb-should-prune? bb fc-intervals)) '()]
                            [else
                             (parameterize ([current-narrow-intervals fc-intervals]
                                            [current-narrow-constraints fc-constraints]
                                            [current-bb-state bb])
                               (narrow-dt-search child-tree new-bindings func-name
                                                target fc-subst depth fuel counter))])])]))
                  ordered-children
                  counter)])]

             ;; Ground value — extract constructor and follow matching child
             [else
              (define tag (narrow-extract-ctor-tag current-val))
              (define child-entry (and tag (assq tag children)))
              (cond
                [(not child-entry) '()]
                [(dt-exempt? (cdr child-entry)) '()]
                [else
                 (define child-tree (cdr child-entry))
                 (define sub-vals (narrow-extract-ctor-subfields current-val))
                 (define new-bindings
                   (append (reverse sub-vals) bindings))
                 (narrow-dt-search child-tree new-bindings func-name
                                  target subst depth fuel counter)])])])]

       [(dt-rule rhs)
        ;; Substitute bvar references in RHS with binding values
        (define result (narrow-subst-bvars rhs bindings 0))
        ;; Match result against target
        (define raw-solutions (narrow-match result target subst func-name depth))
        ;; Phase 3c: post-match constraint checking
        ;; Variables may be bound during matching (not just enumeration),
        ;; so we must verify constraints on the complete solutions.
        (define active-constraints (current-narrow-constraints))
        (if (null? active-constraints)
            raw-solutions
            (filter-map
             (lambda (sol)
               ;; Fully resolve all variable values through the substitution
               ;; chain before constraint checking.  The raw subst may map
               ;; 'x -> (expr-suc (expr-logic-var 'suc0_123 'free)) with
               ;; 'suc0_123 -> ... elsewhere; resolve-var in global-constraints
               ;; only follows top-level logic-var chains, missing nested ones.
               (define resolved-sol
                 (for/hasheq ([(k v) (in-hash sol)])
                   (values k (narrow-resolve-expr sol v))))
               (define fc-result
                 (forward-check resolved-sol active-constraints (current-narrow-intervals)))
               (and fc-result (car fc-result)))
             raw-solutions))]

       [(dt-or branches)
        ;; Phase 2c: confluence classification determines search optimality.
        ;; Both confluent and non-confluent use the same search (try all branches);
        ;; needed narrowing for confluent functions is optimal, basic narrowing for
        ;; non-confluent ensures completeness.
        (get-confluence-class func-name) ;; lazy analyze + cache
        (bounded-append-map
         (lambda (b)
           (narrow-dt-search b bindings func-name target subst depth fuel counter))
         branches
         counter)]

       [(dt-exempt) '()])]))

;; ----------------------------------------
;; BVar substitution (one-pass, all indices)
;; ----------------------------------------

;; Substitute all bvar references in expr with values from bindings.
;; depth: current binder depth offset (increases inside lam/reduce).
(define (narrow-subst-bvars expr bindings depth)
  (match expr
    [(expr-bvar idx)
     (define adjusted (- idx depth))
     (if (and (>= adjusted 0) (< adjusted (length bindings)))
         (list-ref bindings adjusted)
         expr)]
    [(expr-app f a)
     (expr-app (narrow-subst-bvars f bindings depth)
               (narrow-subst-bvars a bindings depth))]
    [(expr-suc e)
     (expr-suc (narrow-subst-bvars e bindings depth))]
    [(expr-lam m t body)
     (expr-lam m t (narrow-subst-bvars body bindings (+ depth 1)))]
    [(expr-reduce scrut arms structural?)
     (expr-reduce
      (narrow-subst-bvars scrut bindings depth)
      (for/list ([arm (in-list arms)])
        (define bc (expr-reduce-arm-binding-count arm))
        (expr-reduce-arm
         (expr-reduce-arm-ctor-name arm)
         bc
         (narrow-subst-bvars (expr-reduce-arm-body arm)
                             bindings (+ depth bc))))
      structural?)]
    [(expr-pair a b)
     (expr-pair (narrow-subst-bvars a bindings depth)
                (narrow-subst-bvars b bindings depth))]
    [(expr-boolrec mot tc fc scrut)
     (expr-boolrec (narrow-subst-bvars mot bindings depth)
                   (narrow-subst-bvars tc bindings depth)
                   (narrow-subst-bvars fc bindings depth)
                   (narrow-subst-bvars scrut bindings depth))]
    ;; Ground/atomic — no bvars inside
    [(expr-zero) expr] [(expr-true) expr] [(expr-false) expr]
    [(expr-nat-val _) expr] [(expr-int _) expr] [(expr-string _) expr]
    [(expr-fvar _) expr] [(expr-keyword _) expr] [(expr-logic-var _ _) expr]
    [(expr-unit) expr] [(expr-nil) expr]
    [_ expr]))

;; ----------------------------------------
;; Structural matching (result vs target)
;; ----------------------------------------

;; narrow-match : expr × expr × subst × func-name × depth → (listof hasheq)
;;
;; Match a (possibly partially evaluated) result against a target.
;; The result may contain:
;;   - expr-logic-var nodes (unbound variables) → bind to corresponding target part
;;   - constructor applications → structural decomposition
;;   - function calls (expr-app with non-constructor fvar) → recursive narrowing
(define (narrow-match result target subst func-name depth)
  (cond
    ;; Logic variable in result → check existing binding or bind to target
    [(expr-logic-var? result)
     (define var-name (expr-logic-var-name result))
     (define existing (hash-ref subst var-name #f))
     (cond
       ;; Already bound → resolve and verify consistency
       [existing
        (narrow-match (narrow-resolve-expr subst existing) target subst func-name depth)]
       ;; Unbound → bind to target
       [else
        (list (hash-set subst var-name target))])]

    ;; Logic variable in target → resolve or bind
    [(expr-logic-var? target)
     (define var-name (expr-logic-var-name target))
     (define existing (hash-ref subst var-name #f))
     (cond
       ;; Already bound → resolve and re-match
       [existing
        (narrow-match result (narrow-resolve-expr subst existing) subst func-name depth)]
       ;; Unbound → bind target var to result
       [else
        (list (hash-set subst var-name result))])]

    ;; Both zero → match
    [(and (expr-zero? result) (expr-zero? target))
     (list subst)]

    ;; Both true → match
    [(and (expr-true? result) (expr-true? target))
     (list subst)]

    ;; Both false → match
    [(and (expr-false? result) (expr-false? target))
     (list subst)]

    ;; Both suc → recurse on predecessor
    [(and (expr-suc? result) (expr-suc? target))
     (narrow-match (expr-suc-pred result) (expr-suc-pred target)
                   subst func-name depth)]

    ;; suc result vs nat-val target (shouldn't happen after normalization, but handle)
    [(and (expr-suc? result) (expr-nat-val? target) (> (expr-nat-val-n target) 0))
     (narrow-match (expr-suc-pred result)
                   (expr-suc (nat-val->peano (- (expr-nat-val-n target) 1)))
                   subst func-name depth)]

    ;; Both nil → match
    [(and (or (expr-nil? result) (and (expr-fvar? result) (eq? (expr-fvar-name result) 'nil)))
          (or (expr-nil? target) (and (expr-fvar? target) (eq? (expr-fvar-name target) 'nil))))
     (list subst)]

    ;; Both unit → match
    [(and (expr-unit? result) (expr-unit? target))
     (list subst)]

    ;; Both nat-val with same value → match
    [(and (expr-nat-val? result) (expr-nat-val? target)
          (= (expr-nat-val-n result) (expr-nat-val-n target)))
     (list subst)]

    ;; Phase 3a: logic var in function position → CFA defunctionalization
    ;; Result is an application whose head is an unbound logic variable.
    ;; Use 0-CFA to determine candidate functions, try each one.
    ;; Must come before general app cases, which assume fvar heads.
    [(and (expr-app? result)
          (let-values ([(fn _args) (narrow-extract-call-ho result)])
            (expr-logic-var? fn)))
     (define-values (fn-var all-args) (narrow-extract-call-ho result))
     (define var-name (expr-logic-var-name fn-var))
     ;; Check if already bound in subst
     (define existing (hash-ref subst var-name #f))
     (cond
       [existing
        ;; Already bound — reconstruct the application with the bound value
        ;; and re-match
        (define resolved (narrow-resolve-expr subst existing))
        (define rebuilt (foldl (lambda (a f) (expr-app f a)) resolved all-args))
        (narrow-match rebuilt target subst func-name depth)]
       [else
        ;; Unbound — use CFA to find candidate functions
        (define arity (length all-args))
        (define cfa (cfa-ensure-analyzed!))
        (define flow-list (cfa-flow-set-for-param cfa func-name 0))
        ;; Use flow set if non-empty, otherwise fall back to arity enumeration
        (define candidates
          (if (null? flow-list)
              (cfa-get-candidates-for-arity arity)
              flow-list))
        ;; Try each candidate function
        (append-map
         (lambda (cand-name)
           ;; Verify candidate has a definitional tree (is narrowable)
           (define cand-body (global-env-lookup-value cand-name))
           (cond
             [(not cand-body) '()]
             [else
              (define cand-dt (extract-definitional-tree cand-body))
              (cond
                [(not cand-dt) '()]
                [else
                 (define call-vars (collect-narrow-logic-vars all-args))
                 (define inner-solutions
                   (run-narrowing-search cand-name all-args target call-vars))
                 ;; Merge inner solutions with current subst,
                 ;; binding fn-var to the candidate function
                 (for/list ([inner-sol (in-list inner-solutions)])
                   (define merged
                     (for/fold ([s subst])
                               ([(k v) (in-hash inner-sol)])
                       (hash-set s k v)))
                   (hash-set merged var-name (expr-fvar cand-name)))])]))
         candidates)])]

    ;; Constructor application (fvar apps) — decompose
    ;; Match if same constructor name and same number of args
    [(and (expr-app? result) (expr-app? target))
     (define-values (r-func r-args) (narrow-extract-call result))
     (define-values (t-func t-args) (narrow-extract-call target))
     (cond
       ;; Same constructor → match sub-fields
       [(and r-func t-func (eq? r-func t-func)
             (lookup-ctor-flexible r-func)
             (= (length r-args) (length t-args)))
        (narrow-match-list r-args t-args subst func-name depth)]
       ;; Result is a function call (non-constructor) → recursive narrowing
       ;; Even with all ground args, we must recurse: the function body needs
       ;; to be "evaluated" via DT traversal to check if the result matches.
       ;; Resolve args through current subst to propagate known bindings.
       [(and r-func (not (lookup-ctor-flexible r-func)))
        (define resolved-args
          (map (lambda (a) (narrow-resolve-expr subst a)) r-args))
        (define call-vars (collect-narrow-logic-vars resolved-args))
        (define inner-solutions
          (run-narrowing-search r-func resolved-args target call-vars))
        ;; Merge inner solutions with current subst
        (for/list ([inner-sol (in-list inner-solutions)])
          (for/fold ([s subst])
                    ([(k v) (in-hash inner-sol)])
            (hash-set s k v)))]
       [else '()])]

    ;; Result is an fvar application, target is not → function call
    [(and (expr-app? result) (not (expr-app? target)))
     (define-values (r-func r-args) (narrow-extract-call result))
     (cond
       [(and r-func (not (lookup-ctor-flexible r-func)))
        ;; Resolve args through current subst
        (define resolved-args
          (map (lambda (a) (narrow-resolve-expr subst a)) r-args))
        (define call-vars (collect-narrow-logic-vars resolved-args))
        (define inner-solutions
          (run-narrowing-search r-func resolved-args target call-vars))
        (for/list ([inner-sol (in-list inner-solutions)])
          (for/fold ([s subst])
                    ([(k v) (in-hash inner-sol)])
            (hash-set s k v)))]
       [else '()])]

    ;; Boolrec (if/then/else): reduce when scrutinee is known, enumerate when logic var
    [(expr-boolrec? result)
     (define scrut (expr-boolrec-target result))
     (define resolved-scrut (narrow-resolve-expr subst scrut))
     (cond
       ;; Scrutinee is true → match then-case against target
       [(expr-true? resolved-scrut)
        (narrow-match (expr-boolrec-true-case result) target subst func-name depth)]
       ;; Scrutinee is false → match else-case against target
       [(expr-false? resolved-scrut)
        (narrow-match (expr-boolrec-false-case result) target subst func-name depth)]
       ;; Scrutinee is a logic var → enumerate both Bool values
       [(expr-logic-var? resolved-scrut)
        (define var-name (expr-logic-var-name resolved-scrut))
        (append
         ;; Try true: bind var to true, match then-case
         (narrow-match (expr-boolrec-true-case result) target
                       (hash-set subst var-name (expr-true)) func-name depth)
         ;; Try false: bind var to false, match else-case
         (narrow-match (expr-boolrec-false-case result) target
                       (hash-set subst var-name (expr-false)) func-name depth))]
       ;; Unknown scrutinee — cannot narrow
       [else '()])]

    ;; Structural equality fallback (handles expr-string, expr-int, etc.)
    [(equal? result target) (list subst)]

    ;; No match
    [else '()]))

;; Match a list of result sub-fields against target sub-fields.
(define (narrow-match-list results targets subst func-name depth)
  (cond
    [(and (null? results) (null? targets)) (list subst)]
    [(or (null? results) (null? targets)) '()]
    [else
     (define first-matches
       (narrow-match (car results) (car targets) subst func-name depth))
     (append-map
      (lambda (s)
        (narrow-match-list (cdr results) (cdr targets) s func-name depth))
      first-matches)]))

;; ----------------------------------------
;; Helpers: constructor building & extraction
;; ----------------------------------------

;; Build a constructor expression from a name and sub-field expressions.
(define (make-narrow-ctor-expr ctor-name sub-vars)
  (cond
    [(eq? ctor-name 'zero) (expr-zero)]
    [(eq? ctor-name 'true) (expr-true)]
    [(eq? ctor-name 'false) (expr-false)]
    [(eq? ctor-name 'nil) (expr-fvar 'nil)]
    [(eq? ctor-name 'unit) (expr-unit)]
    [(and (eq? ctor-name 'suc) (= (length sub-vars) 1))
     (expr-suc (car sub-vars))]
    ;; General: curried application
    [(null? sub-vars) (expr-fvar ctor-name)]
    [else
     (foldl (lambda (arg acc) (expr-app acc arg))
            (expr-fvar ctor-name)
            sub-vars)]))

;; Extract constructor tag from a ground expression.
(define (narrow-extract-ctor-tag expr)
  (match expr
    [(expr-zero) 'zero]
    [(expr-true) 'true]
    [(expr-false) 'false]
    [(expr-unit) 'unit]
    [(expr-suc _) 'suc]
    [(expr-nat-val n) (if (zero? n) 'zero 'suc)]
    [(expr-fvar name)
     (if (or (lookup-ctor name) (lookup-ctor (ctor-short-name name)))
         (ctor-short-name name) #f)]
    [(expr-app func _) (narrow-extract-ctor-tag func)]
    [_ #f]))

;; Extract sub-field values from a constructor expression.
(define (narrow-extract-ctor-subfields expr)
  (match expr
    [(expr-zero) '()]
    [(expr-true) '()]
    [(expr-false) '()]
    [(expr-unit) '()]
    [(expr-nil) '()]
    [(expr-suc sub) (list sub)]
    [(expr-nat-val n)
     (if (zero? n) '() (list (nat-val->peano (- n 1))))]
    [(expr-fvar _) '()]   ;; nullary constructor
    [(expr-app _ _)
     ;; Curried ctor app: collect args
     (let loop ([e expr] [args '()])
       (match e
         [(expr-app f a) (loop f (cons a args))]
         [_ args]))]
    [_ '()]))

;; Extract function name and args from an application chain.
;; (app (app (fvar f) a1) a2) → (values 'f (list a1 a2))
(define (narrow-extract-call expr)
  (let loop ([e expr] [args '()])
    (match e
      [(expr-app f a) (loop f (cons a args))]
      [(expr-fvar name) (values name args)]
      [_ (values #f '())])))

;; Phase 3a: Extract head expression and args from an application chain.
;; Like narrow-extract-call but returns the head expression even if it's
;; not an fvar (e.g., a logic var or lambda).
;; (app (app (logic-var 'f) a1) a2) → (values (logic-var 'f) (list a1 a2))
(define (narrow-extract-call-ho expr)
  (let loop ([e expr] [args '()])
    (match e
      [(expr-app f a) (loop f (cons a args))]
      [_ (values e args)])))

;; Collect logic variable names from a list of expressions.
(define (collect-narrow-logic-vars exprs)
  (define seen (make-hasheq))
  (define result '())
  (define (walk e)
    (match e
      [(expr-logic-var name _)
       (unless (hash-ref seen name #f)
         (hash-set! seen name #t)
         (set! result (cons name result)))]
      [(expr-app f a) (walk f) (walk a)]
      [(expr-suc sub) (walk sub)]
      [(expr-pair a b) (walk a) (walk b)]
      [_ (void)]))
  (for-each walk exprs)
  (reverse result))

;; ----------------------------------------
;; Solution resolution
;; ----------------------------------------

;; Resolve a variable name through the substitution to a ground value.
(define (narrow-resolve-val subst name)
  (define val (hash-ref subst name #f))
  (cond
    [(not val) (expr-logic-var name 'free)]  ;; unresolved — leave as logic var
    [else (narrow-resolve-expr subst val)]))

;; Walk an expression, resolving all embedded logic vars through the substitution.
(define (narrow-resolve-expr subst expr)
  (match expr
    [(expr-logic-var name _)
     (narrow-resolve-val subst name)]
    [(expr-suc sub)
     (expr-suc (narrow-resolve-expr subst sub))]
    [(expr-app f a)
     (expr-app (narrow-resolve-expr subst f)
               (narrow-resolve-expr subst a))]
    [(expr-pair a b)
     (expr-pair (narrow-resolve-expr subst a)
                (narrow-resolve-expr subst b))]
    [_ expr]))
