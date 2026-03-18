#lang racket/base

;;;
;;; CFA-ANALYSIS — 0-CFA (Zeroth-Order Control Flow Analysis)
;;; Phase 3a of FL Narrowing: auto-defunctionalization for higher-order
;;; narrowing arguments.
;;;
;;; When narrowing encounters a logic variable in function position
;;; (e.g., [apply-op ?f 3N 7N] = 10N), 0-CFA determines which named
;;; functions could flow to that position, enabling automatic
;;; defunctionalization: the flow set becomes the "constructor universe"
;;; for the function variable.
;;;
;;; The analysis is demand-driven and per-module:
;;;   1. Collect flow constraints from all definitions in global-env
;;;   2. Solve via fixpoint iteration (flow sets grow monotonically)
;;;   3. Query: for a given (func, param-pos), return the set of
;;;      function names that could flow there
;;;   4. Fallback: if flow set is empty, enumerate all functions with
;;;      matching arity (completeness guarantee for query variables)
;;;
;;; Dependencies: syntax.rkt, global-env.rkt, definitional-tree.rkt, macros.rkt
;;;

(require racket/match
         racket/list
         racket/set
         "syntax.rkt"
         "global-env.rkt"
         "definitional-tree.rkt"
         "macros.rkt")

(provide
 ;; Structs
 (struct-out cfa-result)
 (struct-out cfa-constraint)
 (struct-out cfa-src-fn)
 (struct-out cfa-src-param)
 (struct-out cfa-tgt-param)
 (struct-out cfa-tgt-return)
 ;; Analysis
 cfa-analyze
 cfa-collect-constraints
 cfa-solve
 ;; Queries
 cfa-flow-set-for-param
 cfa-get-candidates-for-arity
 ;; Cache
 current-cfa-result
 cfa-ensure-analyzed!)

;; ========================================
;; Data structures
;; ========================================

;; A flow constraint: source → target
;; "The function named by source may flow to the target position."
(struct cfa-constraint (source target) #:transparent)

;; Sources: where a function value comes from
(struct cfa-src-fn (name) #:transparent)              ;; A named function definition
(struct cfa-src-param (func-name pos) #:transparent)  ;; Parameter of a function

;; Targets: where a function value flows to
(struct cfa-tgt-param (func-name pos) #:transparent)  ;; Parameter of a called function
(struct cfa-tgt-return (func-name) #:transparent)     ;; Return value of a function

;; Analysis result (cached per module)
;; flow-sets: hash of target-key → (setof symbol)
(struct cfa-result (flow-sets) #:transparent)

;; Cache: parameter holding current CFA result (or #f for unanalyzed)
(define current-cfa-result (make-parameter #f))

;; ========================================
;; Helpers
;; ========================================

;; Convert bvar index to parameter position.
;; bvar index 0 = innermost lambda = last parameter.
;; For arity=3, depth=3: bvar 0 → param 2, bvar 1 → param 1, bvar 2 → param 0.
;; Returns #f if the bvar doesn't correspond to a function parameter
;; (e.g., it's a match/let binding at a deeper depth).
(define (bvar->param-pos bvar-idx arity depth)
  (define adjusted (- bvar-idx (- depth arity)))
  (and (>= adjusted 0) (< adjusted arity)
       (- arity 1 adjusted)))

;; Extract function name and args from a curried application chain.
;; (app (app (fvar f) a1) a2) → (values 'f (list a1 a2))
;; If function part is not an fvar, returns (values non-fvar-expr args).
(define (extract-call-chain expr)
  (let loop ([e expr] [args '()])
    (match e
      [(expr-app f a) (loop f (cons a args))]
      [(expr-fvar name) (values name args)]
      [_ (values #f args)])))

;; target-key : cfa-tgt → any (hashable via equal?)
(define (target-key tgt)
  (match tgt
    [(cfa-tgt-param func-name pos) (list 'param func-name pos)]
    [(cfa-tgt-return func-name) (list 'return func-name)]))

;; ========================================
;; Constraint collection
;; ========================================

;; cfa-collect-constraints : → (listof cfa-constraint)
;; Walk all definitions in current-prelude-env and collect flow constraints.
(define (cfa-collect-constraints)
  (define env (current-prelude-env))
  (define constraints '())

  (define (emit! c) (set! constraints (cons c constraints)))

  ;; Walk a body expression, collecting constraints.
  ;; func-name: the function whose body we're walking
  ;; arity: number of lambda binders (for bvar → param-pos mapping)
  ;; depth: current binder depth (increases inside nested lambdas/reduce)
  (define (walk expr func-name arity depth)
    (match expr
      ;; Application chain: [g arg0 arg1 ...]
      [(expr-app _ _)
       (define-values (fn args) (extract-call-chain expr))
       (cond
         ;; Known function call: check args for function flows
         [(and fn (symbol? fn))
          ;; Walk arg sub-expressions for nested calls
          (for ([a (in-list args)])
            (walk a func-name arity depth))
          ;; Check each arg for function-typed flows
          (for ([arg (in-list args)]
                [pos (in-naturals)])
            (cond
              ;; Named function passed as argument
              [(and (expr-fvar? arg)
                    (not (lookup-ctor-flexible (expr-fvar-name arg))))
               (emit! (cfa-constraint
                       (cfa-src-fn (expr-fvar-name arg))
                       (cfa-tgt-param fn pos)))]
              ;; Parameter forwarded to another function
              [(expr-bvar? arg)
               (define pp (bvar->param-pos (expr-bvar-index arg) arity depth))
               (when pp
                 (emit! (cfa-constraint
                         (cfa-src-param func-name pp)
                         (cfa-tgt-param fn pos))))]
              ;; Otherwise: no direct function flow
              [else (void)]))]
         ;; Unknown function: just walk sub-exprs
         [else
          (for ([a (in-list args)])
            (walk a func-name arity depth))])]

      ;; Lambda: walk body at increased depth
      [(expr-lam _ _ body)
       (walk body func-name arity (+ depth 1))]

      ;; Reduce/match: walk all branches
      [(expr-reduce scrut arms _structural?)
       (walk scrut func-name arity depth)
       (for ([arm (in-list arms)])
         (define bc (expr-reduce-arm-binding-count arm))
         (walk (expr-reduce-arm-body arm) func-name arity (+ depth bc)))]

      ;; Suc
      [(expr-suc sub)
       (walk sub func-name arity depth)]

      ;; Pair
      [(expr-pair a b)
       (walk a func-name arity depth)
       (walk b func-name arity depth)]

      ;; Leaves (fvar, bvar, zero, true, false, etc.): no sub-expressions
      [_ (void)]))

  ;; Walk the inner body after peeling lambdas
  (define (walk-inner expr func-name arity depth)
    (match expr
      [(expr-lam _ _ body)
       (walk-inner body func-name arity (+ depth 1))]
      [_
       ;; All lambdas peeled; depth should equal arity.
       (walk expr func-name arity depth)]))

  ;; Process each definition in the global environment
  (for ([(name entry) (in-hash env)])
    (define val (cdr entry))
    (when val  ;; skip type-only entries
      (define-values (ar _inner) (peel-lambdas val))
      (when (> ar 0)  ;; only process function definitions (not constants)
        (walk-inner val name ar 0))))

  (reverse constraints))

;; ========================================
;; Fixpoint solver
;; ========================================

;; cfa-solve : (listof cfa-constraint) → cfa-result
;; Compute flow sets by fixpoint iteration.
;; Each target gets a set of function names.
;; Sources are resolved through the current flow sets.
(define (cfa-solve constraints)
  ;; flow-sets: mutable hash of target-key → (mutable-setof symbol)
  (define flow-sets (make-hash))

  ;; Get or create the mutable set for a target
  (define (get-set! tgt)
    (define key (target-key tgt))
    (hash-ref! flow-sets key (lambda () (mutable-set))))

  ;; Resolve a source to a set of function names
  (define (resolve-source src)
    (match src
      [(cfa-src-fn name) (set name)]
      [(cfa-src-param func-name pos)
       (define key (target-key (cfa-tgt-param func-name pos)))
       (define s (hash-ref flow-sets key #f))
       (if s (for/set ([x (in-mutable-set s)]) x) (set))]))

  ;; Iterate until fixpoint
  (define changed? #t)
  (let loop ()
    (when changed?
      (set! changed? #f)
      (for ([c (in-list constraints)])
        (define src-set (resolve-source (cfa-constraint-source c)))
        (define tgt-mset (get-set! (cfa-constraint-target c)))
        (for ([fn-name (in-set src-set)])
          (unless (set-member? tgt-mset fn-name)
            (set-add! tgt-mset fn-name)
            (set! changed? #t))))
      (loop)))

  ;; Convert mutable sets to immutable for the result
  (define result-sets
    (for/hash ([(key mset) (in-hash flow-sets)])
      (values key (for/set ([x (in-mutable-set mset)]) x))))

  (cfa-result result-sets))

;; ========================================
;; Query API
;; ========================================

;; cfa-flow-set-for-param : cfa-result × symbol × nat → (listof symbol)
;; Get the list of function names that can flow to func-name's param at pos.
(define (cfa-flow-set-for-param result func-name pos)
  (define s (hash-ref (cfa-result-flow-sets result)
                      (list 'param func-name pos)
                      #f))
  (if s (set->list s) '()))

;; cfa-get-candidates-for-arity : nat → (listof symbol)
;; Arity-based fallback: enumerate all function definitions with matching arity.
;; Excludes constructors and non-function entries.
(define (cfa-get-candidates-for-arity target-arity)
  (define env (current-prelude-env))
  (for/list ([(name entry) (in-hash env)]
             #:when (cdr entry)  ;; has a value (not type-only)
             #:when (not (lookup-ctor-flexible name))  ;; not a constructor
             #:when (let-values ([(ar _) (peel-lambdas (cdr entry))])
                      (= ar target-arity)))
    name))

;; ========================================
;; High-level API
;; ========================================

;; cfa-analyze : → cfa-result
;; Collect constraints from current-prelude-env and solve via fixpoint.
(define (cfa-analyze)
  (define constraints (cfa-collect-constraints))
  (cfa-solve constraints))

;; cfa-ensure-analyzed! : → cfa-result
;; Demand-driven: analyze if not cached, cache and return result.
(define (cfa-ensure-analyzed!)
  (or (current-cfa-result)
      (let ([result (cfa-analyze)])
        (current-cfa-result result)
        result)))
