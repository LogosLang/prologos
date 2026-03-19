#lang racket/base

;; bench-solver-unify.rkt — Micro-benchmarks for solver-level unification
;;
;; Targets the flat solver representation (symbols = logic vars, keyword-headed
;; lists = constructors) and the DFS unification machinery in relations.rkt.
;; This is the unification that PUnify replaces — these benchmarks establish
;; the baseline against which propagator-based unification is compared.
;;
;; Stresses: walk chains, unify-terms decomposition, walk* deep substitution,
;; normalize-ast-to-solver-term, variable-heavy substitutions, wide/deep terms,
;; failure-heavy workloads.

(require "../../tools/bench-micro.rkt"
         "../../relations.rkt"
         "../../syntax.rkt"
         "../../reduction.rkt"
         "../../performance-counters.rkt"
         "../../metavar-store.rkt")

;; ============================================================
;; Helpers: term generators
;; ============================================================

;; Build a deeply nested constructor term: (:suc (:suc ... (:zero)))
;; Depth N → N+1 nodes. Stresses recursive decomposition in unify-terms.
(define (deep-ctor-term depth)
  (if (zero? depth)
      (list '#:zero)
      (list '#:suc (deep-ctor-term (sub1 depth)))))

;; Build a wide constructor term: (:node a1 a2 ... aN)
;; Width N → N+1 list elements. Stresses element-wise unification.
(define (wide-ctor-term width [leaf-fn (lambda (i) i)])
  (cons '#:node (for/list ([i (in-range width)]) (leaf-fn i))))

;; Build a long variable chain in a substitution: x0→x1→x2→...→xN→val
;; Stresses walk's transitive resolution.
(define (chain-subst length val)
  (define vars (for/list ([i (in-range (add1 length))])
                 (string->symbol (format "x~a" i))))
  (define subst
    (for/fold ([s (hasheq)])
              ([i (in-range length)])
      (hash-set s (list-ref vars i) (list-ref vars (add1 i)))))
  ;; Terminal variable → ground value
  (hash-set subst (list-ref vars length) val))

;; Build a substitution with N independent variables
(define (wide-subst n)
  (for/fold ([s (hasheq)])
            ([i (in-range n)])
    (hash-set s (string->symbol (format "v~a" i)) i)))

;; Build a term with N variables that need resolution
(define (vars-term n)
  (cons '#:tuple (for/list ([i (in-range n)])
                   (string->symbol (format "v~a" i)))))

;; Build an AST term for normalize-ast-to-solver-term: deeply nested expr-app
(define (deep-app-ast depth)
  (if (zero? depth)
      (expr-fvar 'leaf)
      (expr-app (expr-fvar 'f) (deep-app-ast (sub1 depth)))))

;; Build a wide goal-app AST for normalize
(define (wide-goal-app-ast width)
  (expr-goal-app 'ctor
    (for/list ([i (in-range width)])
      (expr-nat-val i))))

;; ============================================================
;; Section 1: unify-terms — structural decomposition
;; ============================================================

;; 1a. Identical deep terms — fast path (equal? check)
(define b-unify-identical-deep
  (let ([t (deep-ctor-term 50)])
    (bench "unify-terms: identical deep ctor (depth=50) x500"
      (for ([_ (in-range 500)])
        (unify-terms t t (hasheq))))))

;; 1b. Structurally equal but distinct deep terms — full decomposition
(define b-unify-equal-deep
  (bench "unify-terms: equal deep ctor (depth=50) x500"
    ;; Build fresh each iteration so equal? fails, forces element-wise
    (for ([_ (in-range 500)])
      (define t1 (deep-ctor-term 50))
      (define t2 (deep-ctor-term 50))
      (unify-terms t1 t2 (hasheq)))))

;; 1c. Deep terms with variable at the bottom — unification + binding
(define b-unify-deep-with-var
  (let ([ground (deep-ctor-term 49)])
    (bench "unify-terms: deep ctor vs var-at-leaf (depth=50) x500"
      (for ([_ (in-range 500)])
        ;; One side has a variable at position 50
        (define t-var
          (let loop ([d 49])
            (if (zero? d) 'x (list '#:suc (loop (sub1 d))))))
        (unify-terms (list '#:suc ground) (list '#:suc t-var) (hasheq))))))

;; 1d. Wide terms — fan-out decomposition
(define b-unify-wide
  (let ([t1 (wide-ctor-term 100)]
        [t2 (wide-ctor-term 100)])
    (bench "unify-terms: wide ctor (width=100) x500"
      (for ([_ (in-range 500)])
        (unify-terms t1 t2 (hasheq))))))

;; 1e. Wide terms with all-variable RHS — N bindings created
(define b-unify-wide-vars
  (let ([ground (wide-ctor-term 100)]
        [with-vars (cons '#:node
                     (for/list ([i (in-range 100)])
                       (string->symbol (format "v~a" i))))])
    (bench "unify-terms: wide ctor vs 100 vars x500"
      (for ([_ (in-range 500)])
        (unify-terms ground with-vars (hasheq))))))

;; 1f. Failure: mismatched constructor — should fail fast
(define b-unify-fail-ctor
  (bench "unify-terms: ctor mismatch (fail) x2000"
    (for ([_ (in-range 2000)])
      (unify-terms (list '#:suc '#:zero) (list '#:zero) (hasheq)))))

;; 1g. Failure deep into structure — worst case for failure
(define b-unify-fail-deep
  (let ([t1 (let loop ([d 49])
              (if (zero? d) (list '#:zero) (list '#:suc (loop (sub1 d)))))]
        [t2 (let loop ([d 49])
              (if (zero? d) (list '#:one) (list '#:suc (loop (sub1 d)))))])  ; differs only at leaf
    (bench "unify-terms: fail at depth=50 (late failure) x500"
      (for ([_ (in-range 500)])
        (unify-terms t1 t2 (hasheq))))))

;; ============================================================
;; Section 2: walk / walk* — substitution traversal
;; ============================================================

;; 2a. Walk through a chain of length 100
(define b-walk-chain-100
  (let ([subst (chain-subst 100 42)])
    (bench "walk: chain length=100 x2000"
      (for ([_ (in-range 2000)])
        (walk subst 'x0)))))

;; 2b. Walk through a chain of length 500
(define b-walk-chain-500
  (let ([subst (chain-subst 500 42)])
    (bench "walk: chain length=500 x500"
      (for ([_ (in-range 500)])
        (walk subst 'x0)))))

;; 2c. walk* on a term with 100 variables, each bound
(define b-walkstar-wide
  (let ([subst (wide-subst 100)]
        [term (vars-term 100)])
    (bench "walk*: 100 vars in flat term x500"
      (for ([_ (in-range 500)])
        (walk* subst term)))))

;; 2d. walk* on a deeply nested term with chains
(define b-walkstar-deep-chains
  (let* ([n 20]
         ;; Build a deep ctor term where each leaf is a chained variable
         [subst (for/fold ([s (hasheq)])
                          ([i (in-range n)])
                  (define chain (chain-subst 10 i))
                  (for/fold ([s2 s])
                            ([(k v) (in-hash chain)])
                    ;; Namespace variables to avoid collision
                    (hash-set s2
                              (string->symbol (format "~a_~a" k i))
                              (if (symbol? v)
                                  (string->symbol (format "~a_~a" v i))
                                  v))))]
         [term (cons '#:tuple
                     (for/list ([i (in-range n)])
                       (string->symbol (format "x0_~a" i))))])
    (bench "walk*: 20 vars with chain=10 each x500"
      (for ([_ (in-range 500)])
        (walk* subst term)))))

;; ============================================================
;; Section 3: normalize-ast-to-solver-term — AST → flat term
;; ============================================================

;; 3a. Flat expression (no nesting)
(define b-normalize-flat
  (let ([e (expr-nat-val 42)])
    (bench "normalize-ast: flat atom x5000"
      (with-fresh-meta-env
        (parameterize ([current-reduction-fuel (box 10000)])
          (for ([_ (in-range 5000)])
            (normalize-ast-to-solver-term e)))))))

;; 3b. Deep app chain — uncurrying cost
(define b-normalize-deep-app
  (let ([e (deep-app-ast 30)])
    (bench "normalize-ast: deep app chain (depth=30) x500"
      (with-fresh-meta-env
        (parameterize ([current-reduction-fuel (box 10000)])
          (for ([_ (in-range 500)])
            (normalize-ast-to-solver-term e)))))))

;; 3c. Wide goal-app — many arguments
(define b-normalize-wide-goal-app
  (let ([e (wide-goal-app-ast 50)])
    (bench "normalize-ast: wide goal-app (width=50) x1000"
      (with-fresh-meta-env
        (parameterize ([current-reduction-fuel (box 10000)])
          (for ([_ (in-range 1000)])
            (normalize-ast-to-solver-term e)))))))

;; 3d. Nested expr-app with goal-app — mixed structure
(define b-normalize-mixed
  (let ([e (expr-app
            (expr-app (expr-fvar 'f)
                      (expr-goal-app 'pair (list (expr-nat-val 1) (expr-nat-val 2))))
            (expr-goal-app 'triple (list (expr-fvar 'x)
                                          (expr-fvar 'y)
                                          (expr-fvar 'z))))])
    (bench "normalize-ast: mixed app+goal-app x1000"
      (with-fresh-meta-env
        (parameterize ([current-reduction-fuel (box 10000)])
          (for ([_ (in-range 1000)])
            (normalize-ast-to-solver-term e)))))))

;; ============================================================
;; Section 4: Combined unification patterns
;; ============================================================

;; 4a. Chain of unifications: x1=t, x2=t, ..., x100=t (growing substitution)
(define b-unify-growing-subst
  (let ([ground-term (list '#:pair 1 2)])
    (bench "unify-terms: 100 sequential bindings (growing subst) x200"
      (for ([_ (in-range 200)])
        (for/fold ([s (hasheq)])
                  ([i (in-range 100)])
          (define var (string->symbol (format "v~a" i)))
          (or (unify-terms var ground-term s) (hasheq)))))))

;; 4b. Transitive unification chain: x0=x1, x1=x2, ..., x99=val
(define b-unify-transitive-chain
  (bench "unify-terms: transitive chain (100 vars) x200"
    (for ([_ (in-range 200)])
      (for/fold ([s (hasheq)])
                ([i (in-range 100)])
        (define v1 (string->symbol (format "c~a" i)))
        (define v2 (if (= i 99)
                       42  ;; terminal ground value
                       (string->symbol (format "c~a" (add1 i)))))
        (or (unify-terms v1 v2 s) (hasheq))))))

;; 4c. Unify-then-walk*: unify N terms, then walk* to fully resolve
(define b-unify-then-walkstar
  (bench "unify-terms + walk*: 50 bindings then resolve x200"
    (for ([_ (in-range 200)])
      (define subst
        (for/fold ([s (hasheq)])
                  ([i (in-range 50)])
          (define var (string->symbol (format "r~a" i)))
          (or (unify-terms var (list '#:val i) s) (hasheq))))
      ;; Now walk* a term referencing all 50 variables
      (define term (cons '#:result
                     (for/list ([i (in-range 50)])
                       (string->symbol (format "r~a" i)))))
      (walk* subst term))))

;; 4d. Nested constructor unification — tree-shaped terms
;; Perfect binary tree, depth 8 = 255 internal + 256 leaves = 511 nodes
(define (make-tree depth leaf-fn)
  (if (zero? depth)
      (leaf-fn)
      (list '#:branch (make-tree (sub1 depth) leaf-fn)
                      (make-tree (sub1 depth) leaf-fn))))

(define b-unify-tree-terms
  (bench "unify-terms: binary tree (depth=8, 511 nodes) x100"
    (for ([_ (in-range 100)])
      (define t1 (make-tree 8 (lambda () '#:leaf)))
      (define t2 (make-tree 8 (lambda () '#:leaf)))
      (unify-terms t1 t2 (hasheq)))))

;; 4e. Partially-overlapping tree terms with variables — realistic pattern
(define b-unify-partial-overlap
  (bench "unify-terms: partial overlap tree (depth=6) x200"
    (for ([_ (in-range 200)])
      ;; t1: concrete binary tree, depth 6
      (define t1
        (let loop ([d 6] [path '()])
          (if (zero? d)
              (length path)  ;; unique leaf values
              (list '#:branch (loop (sub1 d) (cons 'l path))
                              (loop (sub1 d) (cons 'r path))))))
      ;; t2: same structure but some leaves replaced with variables
      (define counter 0)
      (define t2
        (let loop ([d 6] [path '()])
          (if (zero? d)
              (begin
                (set! counter (add1 counter))
                (if (even? counter)
                    (string->symbol (format "v~a" counter))  ;; variable
                    (length path)))  ;; ground
              (list '#:branch (loop (sub1 d) (cons 'l path))
                              (loop (sub1 d) (cons 'r path))))))
      (unify-terms t1 t2 (hasheq)))))

;; ============================================================
;; Run all
;; ============================================================

(define section-1
  (list b-unify-identical-deep b-unify-equal-deep b-unify-deep-with-var
        b-unify-wide b-unify-wide-vars b-unify-fail-ctor b-unify-fail-deep))

(define section-2
  (list b-walk-chain-100 b-walk-chain-500 b-walkstar-wide b-walkstar-deep-chains))

(define section-3
  (list b-normalize-flat b-normalize-deep-app b-normalize-wide-goal-app b-normalize-mixed))

(define section-4
  (list b-unify-growing-subst b-unify-transitive-chain b-unify-then-walkstar
        b-unify-tree-terms b-unify-partial-overlap))

(newline)
(displayln "=== Section 1: unify-terms structural decomposition ===")
(print-bench-summary section-1)

(newline)
(displayln "=== Section 2: walk / walk* traversal ===")
(print-bench-summary section-2)

(newline)
(displayln "=== Section 3: normalize-ast-to-solver-term ===")
(print-bench-summary section-3)

(newline)
(displayln "=== Section 4: combined patterns ===")
(print-bench-summary section-4)
