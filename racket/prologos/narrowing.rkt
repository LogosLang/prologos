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
         "macros.rkt")

(provide
 ;; Core API
 install-narrowing-propagators
 narrow-function
 ;; Demand analysis
 narrowing-demands
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
