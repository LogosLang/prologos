#lang racket/base

;;;
;;; DEFINITIONAL TREE EXTRACTION
;;; Phase 1a of FL Narrowing: extract hierarchical case-analysis structures
;;; from defn definitions to guide needed narrowing.
;;;
;;; A definitional tree encodes how a function's pattern matching decomposes
;;; its arguments. The narrowing propagator (Phase 1c) walks this tree to
;;; determine which argument to narrow and which constructors to try.
;;;

(require racket/match
         racket/list
         racket/string
         "syntax.rkt"
         "macros.rkt")

(provide
 ;; Tree node structs
 (struct-out dt-rule)
 (struct-out dt-branch)
 (struct-out dt-or)
 (struct-out dt-exempt)
 ;; Extraction
 extract-definitional-tree
 peel-lambdas
 ;; Registry
 current-def-tree-registry
 register-def-tree!
 lookup-def-tree
 ;; Utilities
 def-tree-has-exempt?
 def-tree-has-or?
 def-tree-depth
 def-tree-leaves
 ;; FQN helpers
 lookup-ctor-flexible
 ctor-short-name)

;; ========================================
;; Tree node structs
;; ========================================

;; Leaf: a rewrite rule. rhs is the body expression (core expr).
;; The pattern is implicit — encoded by the path through the tree.
(struct dt-rule (rhs) #:transparent)

;; Interior: case analysis at an argument position.
;; position: 0-based integer (argument index being case-analyzed)
;; type-name: symbol (ADT type, e.g., 'Nat, 'Bool, 'List) or #f if unknown
;; children: alist [(ctor-name . subtree) ...] where subtree is dt-rule/dt-branch/dt-or/dt-exempt
(struct dt-branch (position type-name children) #:transparent)

;; Non-deterministic: overlapping patterns (same constructor in multiple arms).
;; branches: list of subtrees, all tried.
(struct dt-or (branches) #:transparent)

;; Leaf: no rule applies (partial function — missing constructor).
(struct dt-exempt () #:transparent)

;; ========================================
;; Registry (for later phases to look up trees by function name)
;; ========================================

(define current-def-tree-registry (make-parameter (hasheq)))

(define (register-def-tree! name tree)
  (current-def-tree-registry
   (hash-set (current-def-tree-registry) name tree)))

(define (lookup-def-tree name)
  (hash-ref (current-def-tree-registry) name #f))

;; ========================================
;; Lambda peeling
;; ========================================

;; peel-lambdas : expr -> (values nat expr)
;; Strip outer lambda layers, returning the count (arity) and inner body.
(define (peel-lambdas e)
  (let loop ([e e] [n 0])
    (match e
      [(expr-lam _ _ body) (loop body (+ n 1))]
      [_ (values n e)])))

;; ========================================
;; FQN helper
;; ========================================

;; Extract the short (bare) name from a potentially FQN symbol.
;; 'prologos::data::list::cons -> 'cons, 'cons -> 'cons
(define (ctor-short-name fqn)
  (define parts (string-split (symbol->string fqn) "::"))
  (string->symbol (last parts)))

;; Look up constructor metadata, trying both the given name and its short form.
(define (lookup-ctor-flexible name)
  (or (lookup-ctor name)
      (let ([short (ctor-short-name name)])
        (and (not (eq? short name))
             (lookup-ctor short)))))

;; ========================================
;; Core extraction
;; ========================================

;; extract-definitional-tree : expr -> (or/c dt-branch? dt-or? dt-rule? #f)
;; Top-level entry point. Takes an elaborated function body (from global-env).
;; Returns a definitional tree, or #f if the function has no pattern matching.
;; For functions without pattern matching (straight-through), returns a single
;; dt-rule whose RHS is the inner body — enabling narrowing through higher-order
;; applications (Phase 3a: 0-CFA auto-defunctionalization).
(define (extract-definitional-tree body)
  (define-values (arity inner) (peel-lambdas body))
  (cond
    [(expr-reduce? inner)
     (extract-from-reduce inner arity)]
    ;; Phase 3a: non-matching functions get a trivial dt-rule
    ;; This allows narrowing to proceed through function applications
    ;; in the RHS (e.g., [f x y] where f is a logic var).
    [(> arity 0)
     (dt-rule inner)]
    [else #f]))

;; extract-from-reduce : expr-reduce nat -> dt-branch or dt-or
;; Core extraction from an expr-reduce node.
;; arity: the number of lambda layers peeled so far (used for bvar->position mapping).
(define (extract-from-reduce reduce-expr arity)
  (define scrutinee (expr-reduce-scrutinee reduce-expr))
  (define arms (expr-reduce-arms reduce-expr))

  ;; 1. Determine argument position from scrutinee
  (define position (scrutinee->position scrutinee arity))

  ;; 2. Get type name from first arm's constructor
  (define first-ctor-name (expr-reduce-arm-ctor-name (car arms)))
  (define ctor-info (lookup-ctor-flexible first-ctor-name))
  (define type-name (and ctor-info (ctor-meta-type-name ctor-info)))

  ;; 3. Check for overlapping constructors (same ctor in multiple arms)
  (define ctor-names (map expr-reduce-arm-ctor-name arms))
  (define has-overlap?
    (not (= (length ctor-names)
            (length (remove-duplicates ctor-names eq?)))))

  (cond
    [has-overlap?
     ;; Group arms by constructor and build Or for duplicates
     (build-or-tree arms position type-name arity)]
    [else
     ;; 4. Build children for each arm
     (define children
       (for/list ([arm (in-list arms)])
         (define ctor-name (expr-reduce-arm-ctor-name arm))
         (define binding-count (expr-reduce-arm-binding-count arm))
         (define body (expr-reduce-arm-body arm))
         ;; If the body is another expr-reduce, recurse.
         ;; The new arity accounts for bindings introduced by this arm.
         (cons ctor-name
               (if (expr-reduce? body)
                   (extract-from-reduce body (+ arity binding-count))
                   (dt-rule body)))))

     ;; 5. Detect missing constructors -> Exempt nodes
     (define all-ctors (and type-name (lookup-type-ctors type-name)))
     (define present (map car children))
     (define missing
       (if all-ctors
           (filter (lambda (c) (not (memq c present))) all-ctors)
           '()))

     (define full-children
       (append children
               (for/list ([c (in-list missing)])
                 (cons c (dt-exempt)))))

     (dt-branch position type-name full-children)]))

;; build-or-tree : (listof expr-reduce-arm) nat (or/c symbol #f) nat -> dt-or
;; Handle overlapping patterns by wrapping in dt-or.
;; Groups by constructor; for each unique constructor, if only one arm -> normal child,
;; if multiple arms for same constructor -> dt-or wrapping those arms.
(define (build-or-tree arms position type-name arity)
  ;; Group arms by constructor name
  (define groups (make-hasheq))
  (for ([arm (in-list arms)])
    (define name (expr-reduce-arm-ctor-name arm))
    (hash-update! groups name (lambda (lst) (append lst (list arm))) '()))

  ;; Build branches: for constructors with multiple arms, wrap in dt-or
  (define branches
    (for/list ([arm (in-list arms)])
      (define ctor-name (expr-reduce-arm-ctor-name arm))
      (define binding-count (expr-reduce-arm-binding-count arm))
      (define body (expr-reduce-arm-body arm))
      (if (expr-reduce? body)
          (extract-from-reduce body (+ arity binding-count))
          (dt-rule body))))

  (dt-or branches))

;; ========================================
;; Scrutinee position mapping
;; ========================================

;; scrutinee->position : expr nat -> integer
;; Maps a scrutinee expression to a 0-based argument position.
;; Inside n nested lambdas:
;;   bvar(n-1) = first param (arg 0)
;;   bvar(n-2) = second param (arg 1)
;;   ...
;;   bvar(0)   = last param (arg n-1)
;; So: position = arity - 1 - index
(define (scrutinee->position scrutinee arity)
  (match scrutinee
    [(expr-bvar index)
     (- arity 1 index)]
    [_
     ;; Non-bvar scrutinee (computed expression) — return -1 to signal
     ;; that this is not a simple argument position. Phase 1c can handle this.
     -1]))

;; ========================================
;; Utility functions
;; ========================================

;; def-tree-has-exempt? : def-tree -> boolean
;; Does the tree contain any Exempt nodes?
(define (def-tree-has-exempt? tree)
  (match tree
    [(dt-exempt) #t]
    [(dt-rule _) #f]
    [(dt-branch _ _ children)
     (ormap (lambda (pair) (def-tree-has-exempt? (cdr pair))) children)]
    [(dt-or branches)
     (ormap def-tree-has-exempt? branches)]))

;; def-tree-has-or? : def-tree -> boolean
;; Does the tree contain any Or nodes?
(define (def-tree-has-or? tree)
  (match tree
    [(dt-or _) #t]
    [(dt-exempt) #f]
    [(dt-rule _) #f]
    [(dt-branch _ _ children)
     (ormap (lambda (pair) (def-tree-has-or? (cdr pair))) children)]))

;; def-tree-depth : def-tree -> nat
;; Maximum depth of the tree.
(define (def-tree-depth tree)
  (match tree
    [(dt-exempt) 0]
    [(dt-rule _) 0]
    [(dt-branch _ _ children)
     (+ 1 (apply max 0 (map (lambda (pair) (def-tree-depth (cdr pair))) children)))]
    [(dt-or branches)
     (apply max 0 (map def-tree-depth branches))]))

;; def-tree-leaves : def-tree -> (listof (or/c dt-rule? dt-exempt?))
;; Collect all leaf nodes.
(define (def-tree-leaves tree)
  (match tree
    [(dt-exempt) (list tree)]
    [(dt-rule _) (list tree)]
    [(dt-branch _ _ children)
     (append-map (lambda (pair) (def-tree-leaves (cdr pair))) children)]
    [(dt-or branches)
     (append-map def-tree-leaves branches)]))
