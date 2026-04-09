#lang racket/base

;;;
;;; relations.rkt — Relation Registry and Execution
;;;
;;; Manages the relation store: registration of `defr` relations, clause
;;; instantiation into propagator networks, and the solve/explain dispatch.
;;;
;;; Key concepts:
;;;   - relation-info: registered by defr elaboration, holds variants + schema
;;;   - relation-store: hasheq mapping names to relation-info
;;;   - solve-goal: creates fresh network, instantiates clauses, runs to quiescence
;;;   - explain-goal: like solve but with provenance recording
;;;
;;; Design reference: docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org §7.4
;;;

(require racket/list
         "propagator.rkt"
         "atms.rkt"            ;; Phase 6+7: solver-state operations
         "decision-cell.rkt"   ;; Phase 6+7: compound cells, tagged-cell-value
         "tabling.rkt"
         "union-find.rkt"
         "solver.rkt"
         "provenance.rkt"
         "syntax.rkt"
         "performance-counters.rkt"
         "ctor-registry.rkt")

(provide
 ;; Core structs
 (struct-out relation-info)
 (struct-out variant-info)
 (struct-out clause-info)
 (struct-out fact-row)
 (struct-out param-info)
 (struct-out goal-desc)
 ;; Relation store (parameter + operations)
 current-relation-store
 make-relation-store
 relation-register
 relation-lookup
 relation-store-names
 ;; AST → runtime conversion
 expr-defr->relation-info
 expr-rel->relation-info
 expr->goal-desc
 ;; Variable renaming helpers (for negation)
 rename-ast-vars
 collect-ast-vars
 ;; Evaluation callback (set by reduction.rkt to break circular dep)
 current-is-eval-fn
 ;; NAF oracle (set by wf-engine.rkt for well-founded semantics)
 current-naf-oracle
 ;; Solver internals (for run-solve-goal in reduction.rkt + benchmarks)
 solve-single-goal
 solve-goals
 walk
 walk*
 unify-terms
 normalize-term-deep
 ;; Execution
 solve-goal
 explain-goal
 ;; D4 Provenance: parallel explain solver internals (for wf-engine.rkt)
 explain-goals
 explain-app-goal
 ;; Phase 6+7: Propagator-native solver (D.11)
 install-goal-propagator
 install-conjunction
 install-clause-propagators
 solve-goal-propagator)

;; ========================================
;; Evaluation callback
;; ========================================

;; Callback for evaluating functional expressions inside relational goals.
;; Set by reduction.rkt to `whnf` to break circular dependency.
;; When #f, is-goals fall back to raw unification (no evaluation).
(define current-is-eval-fn (make-parameter #f))

;; NAF oracle callback for well-founded semantics.
;; When #f (default), standard NAF is used (try to prove inner goal;
;; if no proof found, negation succeeds).
;; When set, must be a function: (symbol → 'succeed | 'fail | 'defer)
;;   'succeed — treat `not p` as true
;;   'fail — treat `not p` as false (backtrack)
;;   'defer — treat `not p` as unknown (skip this clause)
(define current-naf-oracle (make-parameter #f))

;; ========================================
;; PUnify Phase 5a: Solver Cell Infrastructure
;; ========================================

;; Solver environment: replaces hasheq substitution when punify is enabled.
;; pnet: prop-network (persistent, immutable — threaded functionally like subst)
;; var-cells: hasheq(symbol → cell-id) — maps logic var names to their cells
(struct solver-env (pnet var-cells) #:transparent)

;; Sentinel value for unbound solver cells.
(define SOLVER-TERM-BOT (gensym 'solver-term-bot))

;; Merge function for solver cells: a simple flat lattice.
;; ⊥ + x = x, x + ⊥ = x, x + x = x, x + y = contradiction.
(define (solver-term-merge old new)
  (cond
    [(eq? old SOLVER-TERM-BOT) new]
    [(eq? new SOLVER-TERM-BOT) old]
    [(equal? old new) old]
    [else 'solver-contradiction]))

;; Contradiction detector for solver cells.
(define (solver-contradiction? val)
  (eq? val 'solver-contradiction))

;; Create an empty solver environment.
(define (make-solver-env)
  (solver-env (make-prop-network) (hasheq)))

;; Ensure a variable has a cell, creating one at SOLVER-TERM-BOT if needed.
(define (solver-ensure-var env name)
  (if (hash-has-key? (solver-env-var-cells env) name)
      env
      (let-values ([(pnet cid) (net-new-cell (solver-env-pnet env)
                                              SOLVER-TERM-BOT
                                              solver-term-merge
                                              solver-contradiction?)])
        (solver-env pnet (hash-set (solver-env-var-cells env) name cid)))))

;; Walk a term in a solver-env: read cell value, follow variable chains.
(define (solver-walk env term)
  (cond
    [(symbol? term)
     (define cid (hash-ref (solver-env-var-cells env) term #f))
     (if cid
         (let ([val (net-cell-read (solver-env-pnet env) cid)])
           (if (eq? val SOLVER-TERM-BOT)
               term  ;; unbound
               (if (eq? val term) term (solver-walk env val))))
         term)]  ;; not a known var — ground atom
    [else term]))

;; Deep-walk: resolve all variables transitively in a solver-env.
(define (solver-walk* env term)
  (define resolved (solver-walk env term))
  (cond
    [(list? resolved)
     (map (lambda (t) (solver-walk* env t)) resolved)]
    [else resolved]))

;; Unify two terms using solver cells.
;; Returns updated solver-env or #f on failure.
(define (solver-unify-terms t1 t2 env)
  ;; Auto-create cells for any symbol arguments
  (define env1 (if (symbol? t1) (solver-ensure-var env t1) env))
  (define env2 (if (symbol? t2) (solver-ensure-var env1 t2) env1))
  (define v1 (solver-walk env2 t1))
  (define v2 (solver-walk env2 t2))
  (cond
    [(equal? v1 v2) env2]
    [(symbol? v1)
     ;; v1 is an unbound var — occurs check then write
     (if (solver-term-occurs? env2 v1 v2) #f
         (let ()
           (define env3 (solver-ensure-var env2 v1))
           (define cid (hash-ref (solver-env-var-cells env3) v1))
           (define new-pnet (net-cell-write (solver-env-pnet env3) cid v2))
           (if (net-contradiction? new-pnet)
               #f
               (solver-env new-pnet (solver-env-var-cells env3)))))]
    [(symbol? v2)
     (if (solver-term-occurs? env2 v2 v1) #f
         (let ()
           (define env3 (solver-ensure-var env2 v2))
           (define cid (hash-ref (solver-env-var-cells env3) v2))
           (define new-pnet (net-cell-write (solver-env-pnet env3) cid v1))
           (if (net-contradiction? new-pnet)
               #f
               (solver-env new-pnet (solver-env-var-cells env3)))))]
    [(and (list? v1) (list? v2))
     ;; PUnify Phase 5b: descriptor-aware decomposition for compound terms.
     ;; If both have a recognized constructor tag, decompose via descriptor.
     ;; Otherwise fall back to pairwise list unification.
     (define tag1 (and (pair? v1) (let ([h (car v1)]) (and (symbol? h) h))))
     (define tag2 (and (pair? v2) (let ([h (car v2)]) (and (symbol? h) h))))
     (define desc1 (and tag1 (lookup-ctor-desc tag1 #:domain 'data)))
     (define desc2 (and tag2 (lookup-ctor-desc tag2 #:domain 'data)))
     (cond
       [(and desc1 desc2 (eq? tag1 tag2))
        ;; Same constructor — decompose sub-components via descriptor
        (define cs1 ((ctor-desc-extract-fn desc1) v1))
        (define cs2 ((ctor-desc-extract-fn desc2) v2))
        (let loop ([c1s cs1] [c2s cs2] [e env2])
          (cond
            [(null? c1s) e]
            [else
             (define e* (solver-unify-terms (car c1s) (car c2s) e))
             (if e* (loop (cdr c1s) (cdr c2s) e*) #f)]))]
       [(and desc1 desc2)
        ;; Different constructors — structural mismatch
        #f]
       [else
        ;; Fallback: pairwise list unification for non-descriptor terms
        (if (= (length v1) (length v2))
            (let loop ([ts1 v1] [ts2 v2] [e env2])
              (cond
                [(null? ts1) e]
                [else
                 (define e* (solver-unify-terms (car ts1) (car ts2) e))
                 (if e* (loop (cdr ts1) (cdr ts2) e*) #f)]))
            #f)])]
    [else #f]))

;; ========================================
;; Core structs
;; ========================================

;; Parameter info: name + mode
;; name: symbol
;; mode: 'free | 'in | 'out
(struct param-info (name mode) #:transparent)

;; A goal descriptor (runtime representation of a relational goal)
;; kind: 'app | 'unify | 'is | 'not | 'cut | 'guard
;; args: depends on kind
(struct goal-desc (kind args) #:transparent)

;; A clause: a rule body (list of goal descriptors)
(struct clause-info (goals) #:transparent)

;; A fact row: ground data (list of values)
(struct fact-row (terms) #:transparent)

;; A variant: one arity/pattern case of a relation
;; params: (listof param-info)
;; clauses: (listof clause-info) — rule clauses (&>)
;; facts: (listof fact-row) — ground facts (||)
(struct variant-info (params clauses facts) #:transparent)

;; A registered relation
;; name: symbol
;; arity: nat (for single-arity; #f for multi-arity)
;; variants: (listof variant-info)
;; schema: #f or symbol (schema name)
;; tabled?: boolean
(struct relation-info (name arity variants schema tabled?) #:transparent)

;; ========================================
;; Relation store
;; ========================================

;; Create an empty relation store.
(define (make-relation-store)
  (hasheq))

;; Register a relation in the store.
;; Returns updated store.
(define (relation-register store rel)
  (hash-set store (relation-info-name rel) rel))

;; Look up a relation by name.
;; Returns relation-info or #f.
(define (relation-lookup store name)
  (hash-ref store name #f))

;; List all registered relation names.
(define (relation-store-names store)
  (hash-keys store))

;; Global relation store parameter (initialized to empty store).
;; Updated by driver.rkt when processing defr commands.
(define current-relation-store (make-parameter (make-relation-store)))

;; ========================================
;; AST → Runtime Conversion
;; ========================================

;; Convert an expr-defr AST node to a relation-info struct.
;; Called by the driver after type-checking and zonking a defr.
(define (expr-defr->relation-info defr-expr)
  (define name (expr-defr-name defr-expr))
  (define schema (expr-defr-schema defr-expr))
  (define variants (expr-defr-variants defr-expr))
  (define converted-variants
    (for/list ([v (in-list variants)])
      (expr-variant->variant-info v)))
  ;; Determine arity from first variant (or #f if no variants)
  (define arity
    (if (pair? converted-variants)
        (length (variant-info-params (car converted-variants)))
        #f))
  ;; Extract schema name if present
  (define schema-name
    (cond
      [(symbol? schema) schema]
      [(expr-fvar? schema) (expr-fvar-name schema)]
      [else #f]))
  (relation-info name arity converted-variants schema-name #f))

;; Convert an anonymous expr-rel to a relation-info with a given name.
;; expr-rel has params (list of (name . mode) pairs) and clauses (list of expr-clause/expr-fact-block).
(define (expr-rel->relation-info rel-expr temp-name)
  (define params (expr-rel-params rel-expr))
  (define clauses (expr-rel-clauses rel-expr))
  (define converted-params
    (for/list ([p (in-list params)])
      (cond
        [(expr-logic-var? p)
         (param-info (expr-logic-var-name p)
                     (or (expr-logic-var-mode p) 'free))]
        [(and (pair? p) (symbol? (car p)))
         (param-info (car p) (or (cdr p) 'free))]
        [(symbol? p) (param-info p 'free)]
        [else (param-info (gensym 'p) 'free)])))
  (define arity (length converted-params))
  ;; Each clause becomes a variant-info body
  (define converted-variants
    (for/list ([c (in-list clauses)])
      (define-values (facts clause-goals)
        (extract-facts-and-clauses c))
      (variant-info converted-params clause-goals facts)))
  (relation-info temp-name arity converted-variants #f #f))

;; Convert an expr-defr-variant to a variant-info.
(define (expr-variant->variant-info v)
  (define params (expr-defr-variant-params v))
  (define body (expr-defr-variant-body v))
  (define converted-params
    (for/list ([p (in-list params)])
      (cond
        [(expr-logic-var? p)
         (param-info (expr-logic-var-name p)
                     (or (expr-logic-var-mode p) 'free))]
        [(symbol? p)
         (param-info p 'free)]
        ;; From parser: params are (name . mode) pairs
        [(and (pair? p) (symbol? (car p)))
         (param-info (car p) (or (cdr p) 'free))]
        [else
         (param-info (gensym 'p) 'free)])))
  (define-values (facts clauses)
    (extract-facts-and-clauses body))
  (variant-info converted-params clauses facts))

;; Extract facts and clauses from a variant body.
;; Returns (values facts clauses).
(define (extract-facts-and-clauses body)
  (cond
    [(expr-fact-block? body)
     (define rows
       (for/list ([row (in-list (expr-fact-block-rows body))])
         (fact-row (expr-fact-row-terms row))))
     (values rows '())]
    [(expr-clause? body)
     (define goals
       (for/list ([g (in-list (expr-clause-goals body))])
         (expr->goal-desc g)))
     (values '() (list (clause-info goals)))]
    [(list? body)
     ;; Body is a list of clause/fact-block forms
     (define all-facts '())
     (define all-clauses '())
     (for ([item (in-list body)])
       (cond
         [(expr-fact-block? item)
          (for ([row (in-list (expr-fact-block-rows item))])
            (set! all-facts (cons (fact-row (expr-fact-row-terms row)) all-facts)))]
         [(expr-clause? item)
          (define goals
            (for/list ([g (in-list (expr-clause-goals item))])
              (expr->goal-desc g)))
          (set! all-clauses (cons (clause-info goals) all-clauses))]))
     (values (reverse all-facts) (reverse all-clauses))]
    [else (values '() '())]))

;; Normalize an AST term for the runtime solver.
;; expr-logic-var → symbol (the var name), all other AST nodes stay as-is.
(define (normalize-term t)
  (cond
    [(expr-logic-var? t) (expr-logic-var-name t)]
    [else t]))

;; Deep-normalize an AST term for the runtime solver.
;; Recursively converts constructor applications to lists so unify-terms can decompose them.
;; Logic vars → symbols, (expr-app f a) chains → flat lists, everything else ground.
(define (normalize-term-deep t)
  (cond
    [(expr-logic-var? t)
     ;; Strip mode prefix (?/+/-) if present — mode is metadata, not identity
     (let* ([name (expr-logic-var-name t)]
            [s (symbol->string name)])
       (if (and (> (string-length s) 1)
                (memv (string-ref s 0) '(#\? #\+ #\-)))
           (string->symbol (substring s 1))
           name))]
    [(expr-app? t)
     (define-values (head args) (uncurry-app-rel t))
     (cons (normalize-term-deep head)
           (map normalize-term-deep args))]
    [(expr-goal-app? t)
     ;; goal-app name: use keyword to distinguish from variable symbols.
     ;; Keywords are not symbols, so unify-terms treats them as ground.
     (cons (string->keyword (symbol->string (expr-goal-app-name t)))
           (map normalize-term-deep (expr-goal-app-args t)))]
    [else t]))

;; Uncurry a chain of expr-app: (app (app f a1) a2) → (values f (list a1 a2))
(define (uncurry-app-rel e)
  (let loop ([e e] [acc '()])
    (cond
      [(expr-app? e) (loop (expr-app-func e) (cons (expr-app-arg e) acc))]
      [else (values e acc)])))

;; Convert an AST goal expression to a goal-desc struct.
;; All logic variables are normalized to plain symbols for the runtime solver.
(define (expr->goal-desc g)
  (cond
    [(expr-goal-app? g)
     (goal-desc 'app (list (expr-goal-app-name g)
                           (map normalize-term (expr-goal-app-args g))))]
    [(expr-unify-goal? g)
     ;; Deep-normalize unify terms so constructor applications become lists
     ;; that unify-terms can structurally decompose.
     (goal-desc 'unify (list (normalize-term-deep (expr-unify-goal-lhs g))
                             (normalize-term-deep (expr-unify-goal-rhs g))))]
    [(expr-is-goal? g)
     (goal-desc 'is (list (normalize-term (expr-is-goal-var g))
                          (expr-is-goal-expr g)))]
    [(expr-not-goal? g)
     (goal-desc 'not (list (expr-not-goal-goal g)))]
    [(expr-cut? g)
     (goal-desc 'cut '())]
    [(expr-guard? g)
     (if (expr-guard-goal g)
         (goal-desc 'guard (list (expr-guard-condition g) (expr-guard-goal g)))
         (goal-desc 'guard (list (expr-guard-condition g))))]
    [else
     ;; Fallback: wrap as-is
     (goal-desc 'app (list 'unknown (list g)))]))

;; ========================================
;; AST Expression Substitution
;; ========================================

;; Collect logic variable names from a general AST expression.
;; Walks into expr-app, pairs, and any transparent struct (e.g. expr-int-add,
;; expr-guard, etc.) to find all expr-logic-var nodes.
(define (collect-logic-vars-in-expr expr vars)
  (cond
    [(expr-logic-var? expr)
     (hash-set! vars (expr-logic-var-name expr) #t)]
    [(expr-app? expr)
     (collect-logic-vars-in-expr (expr-app-func expr) vars)
     (collect-logic-vars-in-expr (expr-app-arg expr) vars)]
    [(pair? expr)
     (collect-logic-vars-in-expr (car expr) vars)
     (collect-logic-vars-in-expr (cdr expr) vars)]
    ;; Generic: walk transparent struct fields (covers expr-int-add, expr-suc, etc.)
    [(struct? expr)
     (define v (struct->vector expr))
     (for ([i (in-range 1 (vector-length v))])
       (collect-logic-vars-in-expr (vector-ref v i) vars))]
    [else (void)]))

;; Rename logic variable names inside an AST expression using a fresh-map.
;; Used by rename-goal-vars for `is`-goal expressions.
;; Walks into expr-app, pairs, and any transparent struct to reach nested logic vars.
(define (rename-logic-vars-in-expr expr fresh-map)
  (cond
    [(expr-logic-var? expr)
     (define fresh-name (hash-ref fresh-map (expr-logic-var-name expr)
                                  (expr-logic-var-name expr)))
     (expr-logic-var fresh-name (expr-logic-var-mode expr))]
    [(expr-app? expr)
     (expr-app (rename-logic-vars-in-expr (expr-app-func expr) fresh-map)
               (rename-logic-vars-in-expr (expr-app-arg expr) fresh-map))]
    [(pair? expr)
     (cons (rename-logic-vars-in-expr (car expr) fresh-map)
           (rename-logic-vars-in-expr (cdr expr) fresh-map))]
    ;; Generic: walk transparent struct fields (covers expr-int-add, expr-suc, etc.)
    [(struct? expr)
     (define v (struct->vector expr))
     (define len (vector-length v))
     (define new-fields
       (for/list ([i (in-range 1 len)])
         (rename-logic-vars-in-expr (vector-ref v i) fresh-map)))
     ;; Only reconstruct if something changed
     (define changed?
       (for/or ([i (in-range (- len 1))]
                [nf (in-list new-fields)])
         (not (eq? (vector-ref v (+ i 1)) nf))))
     (if changed?
         (let-values ([(st _) (struct-info expr)])
           (apply (struct-type-make-constructor st) new-fields))
         expr)]
    [else expr]))

;; Substitute logic variable values from a substitution into an AST expression.
;; Walks the AST tree, replacing expr-logic-var nodes with their resolved values.
;; This is needed for `is`-goals and `guard` conditions where functional
;; expressions reference logic variables that may be bound.
;; Walks into expr-app, pairs, and any transparent struct (e.g. expr-int-add,
;; expr-suc, expr-guard, etc.) to reach nested logic vars.
(define (subst-logic-vars-in-expr expr subst)
  (cond
    [(expr-logic-var? expr)
     (define val (walk subst (expr-logic-var-name expr)))
     ;; If still a symbol (unbound var), keep as logic-var for whnf
     (if (symbol? val)
         (expr-logic-var val (expr-logic-var-mode expr))
         val)]
    [(expr-app? expr)
     (expr-app (subst-logic-vars-in-expr (expr-app-func expr) subst)
               (subst-logic-vars-in-expr (expr-app-arg expr) subst))]
    [(pair? expr)
     (cons (subst-logic-vars-in-expr (car expr) subst)
           (subst-logic-vars-in-expr (cdr expr) subst))]
    ;; Generic: walk transparent struct fields (covers expr-int-add, expr-suc, etc.)
    [(struct? expr)
     (define v (struct->vector expr))
     (define len (vector-length v))
     (define new-fields
       (for/list ([i (in-range 1 len)])
         (subst-logic-vars-in-expr (vector-ref v i) subst)))
     ;; Only reconstruct if something changed
     (define changed?
       (for/or ([i (in-range (- len 1))]
                [nf (in-list new-fields)])
         (not (eq? (vector-ref v (+ i 1)) nf))))
     (if changed?
         (let-values ([(st _) (struct-info expr)])
           (apply (struct-type-make-constructor st) new-fields))
         expr)]
    [else expr]))

;; ========================================
;; Runtime Unification + DFS Solver (Sub-phase F)
;; ========================================

;; Default depth limit for DFS search
(define DEFAULT-DEPTH-LIMIT 100)

;; PUnify Phase 8: Occurs check for the DFS solver (System 2).
;; Prevents infinite terms from unify(X, f(X)).
;; Works with both hasheq and solver-env via polymorphic `walk`.
(define (solver-term-occurs? subst var term)
  (let check ([t (walk subst term)])
    (cond
      [(eq? t var) #t]
      [(list? t) (for/or ([elem (in-list t)]) (check (walk subst elem)))]
      [else #f])))

;; Walk a substitution to fully resolve a term.
;; subst: hasheq or solver-env (PUnify Phase 5a dispatches on type)
(define (walk subst term)
  (cond
    [(solver-env? subst) (solver-walk subst term)]
    [(symbol? term)
     (define val (hash-ref subst term #f))
     (if val
         (if (eq? val term) term (walk subst val))
         term)]
    [else term]))

;; Deeply walk a term, resolving all variables transitively.
(define (walk* subst term)
  (cond
    [(solver-env? subst) (solver-walk* subst term)]
    [else
     (define resolved (walk subst term))
     (cond
       [(list? resolved)
        (map (lambda (t) (walk* subst t)) resolved)]
       [else resolved])]))

;; Unify two terms under a substitution.
;; Returns updated substitution (hasheq or solver-env) or #f on failure.
(define (unify-terms t1 t2 subst)
  (perf-inc-solver-unify!)
  (if (solver-env? subst)
      (solver-unify-terms t1 t2 subst)
      (let ([v1 (walk subst t1)]
            [v2 (walk subst t2)])
        (cond
          [(equal? v1 v2) subst]
          [(symbol? v1)
           (if (solver-term-occurs? subst v1 v2) #f (hash-set subst v1 v2))]
          [(symbol? v2)
           (if (solver-term-occurs? subst v2 v1) #f (hash-set subst v2 v1))]
          [(and (list? v1) (list? v2) (= (length v1) (length v2)))
           (let loop ([ts1 v1] [ts2 v2] [s subst])
             (cond
               [(null? ts1) s]
               [else
                (define s* (unify-terms (car ts1) (car ts2) s))
                (if s* (loop (cdr ts1) (cdr ts2) s*) #f)]))]
          [else #f]))))

;; Solve a list of goals under a substitution, returning all solutions.
;; config: solver-config
;; store: relation store
;; goals: (listof goal-desc)
;; subst: current substitution (hasheq)
;; depth: current depth
;; Returns: (listof hasheq) — each is a complete substitution
(define (solve-goals config store goals subst depth)
  (cond
    [(null? goals) (list subst)]
    [else
     (define first-goal (car goals))
     (define rest-goals (cdr goals))
     (define sub-results (solve-single-goal config store first-goal subst depth))
     (append-map
      (lambda (s) (solve-goals config store rest-goals s depth))
      sub-results)]))

;; Dispatch a single goal, returning a list of substitutions.
(define (solve-single-goal config store goal subst depth)
  (when (> depth DEFAULT-DEPTH-LIMIT)
    (error 'solve "Depth limit exceeded (~a)" DEFAULT-DEPTH-LIMIT))
  (define kind (goal-desc-kind goal))
  (define args (goal-desc-args goal))
  (case kind
    [(app)
     (define goal-name (car args))
     (define goal-args (cadr args))
     (solve-app-goal config store goal-name goal-args subst (add1 depth))]
    [(unify)
     (define lhs (car args))
     (define rhs (cadr args))
     (define lhs-resolved (walk subst lhs))
     (define rhs-resolved (walk subst rhs))
     (define result (unify-terms lhs-resolved rhs-resolved subst))
     (if result (list result) '())]
    [(is)
     ;; is-goal: evaluate a functional expression and unify result with var.
     ;; var is a symbol (logic variable name), expr is an AST node.
     (define var (car args))
     (define expr (cadr args))
     (define eval-fn (current-is-eval-fn))
     (define val
       (if eval-fn
           ;; Substitute bound logic vars into the expression, then evaluate
           (let ([substituted (subst-logic-vars-in-expr expr subst)])
             (eval-fn substituted))
           ;; No eval function available — use raw expression
           expr))
     (define result (unify-terms (walk subst var) val subst))
     (if result (list result) '())]
    [(not)
     ;; Negation-as-failure: succeed if inner goal fails.
     ;; Apply current substitution to inner goal's variables before evaluating,
     ;; so negation checks the ground instantiation (not unbound vars).
     (define inner-goal-expr (car args))
     (define inner-goal (expr->goal-desc inner-goal-expr))
     (define naf-oracle (current-naf-oracle))
     (cond
       ;; Well-founded NAF oracle path: consult bilattice instead of DFS
       [(and naf-oracle (eq? (goal-desc-kind inner-goal) 'app))
        (define pred-name (car (goal-desc-args inner-goal)))
        (define oracle-result (naf-oracle pred-name))
        (case oracle-result
          [(succeed) (list subst)]  ;; definitely false → NAF succeeds
          [(fail) '()]              ;; definitely true → NAF fails
          [(defer) '()]             ;; unknown → skip (conservative)
          [else
           ;; Oracle returned 'standard — fall through to standard DFS NAF
           (define resolved-inner-goal (apply-subst-to-goal inner-goal subst))
           (define results (solve-single-goal config store resolved-inner-goal subst depth))
           (if (null? results)
               (list subst)
               '())])]
       ;; Standard NAF path: try to prove inner goal
       [else
        (define resolved-inner-goal (apply-subst-to-goal inner-goal subst))
        (define results (solve-single-goal config store resolved-inner-goal subst depth))
        (if (null? results)
            (list subst)  ;; inner failed → not succeeds
            '())])]       ;; inner succeeded → not fails
    [(cut)
     ;; Cut: return current substitution (cut semantics need special handling)
     (list subst)]
    [(guard)
     ;; Guard: evaluate condition, if truthy proceed with inner goal (or succeed).
     ;; Condition is an AST expression (functional); goal is an AST goal node or #f.
     (define condition (car args))
     (define inner-goal-expr (and (pair? (cdr args)) (cadr args)))
     (define eval-fn (current-is-eval-fn))
     (define cond-val
       (if eval-fn
           (let ([substituted (subst-logic-vars-in-expr condition subst)])
             (eval-fn substituted))
           (walk subst condition)))
     ;; Check if condition evaluated to true.
     (define truthy?
       (cond
         [(expr-true? cond-val) #t]
         [(expr-false? cond-val) #f]
         [(boolean? cond-val) cond-val]
         [(eq? cond-val #f) #f]
         [else #t]))  ;; non-#f, non-false values are truthy
     (if truthy?
         (if (and inner-goal-expr (not (eq? inner-goal-expr #f)))
             (let ([inner-goal (expr->goal-desc inner-goal-expr)])
               (solve-single-goal config store inner-goal subst depth))
             (list subst))  ;; 1-arg guard: condition passed, succeed
         '())]
    [else
     (error 'solve "Unknown goal kind: ~a" kind)]))

;; Collect all variable names referenced in a clause (params + body goals).
;; Returns a list of unique symbols.
(define (collect-clause-vars ci param-names)
  (define vars (make-hasheq))
  ;; Add params
  (for ([pn (in-list param-names)])
    (hash-set! vars pn #t))
  ;; Walk all goals and collect symbol references
  (for ([g (in-list (clause-info-goals ci))])
    (collect-goal-vars g vars))
  (hash-keys vars))

(define (collect-goal-vars goal vars)
  (define args (goal-desc-args goal))
  (case (goal-desc-kind goal)
    [(app)
     (define goal-args (cadr args))
     (for ([a (in-list goal-args)])
       (when (symbol? a) (hash-set! vars a #t)))]
    [(unify)
     (for ([a (in-list args)])
       (collect-solver-term-vars a vars))]
    [(is)
     (when (symbol? (car args)) (hash-set! vars (car args) #t))
     ;; Also collect logic vars from the expression AST
     (collect-logic-vars-in-expr (cadr args) vars)]
    [(not)
     ;; Deep-walk the inner AST expr to collect variable names
     (define inner (car args))
     (collect-ast-vars inner vars)]
    [(guard)
     ;; Collect vars from condition expr and optionally inner goal
     (collect-logic-vars-in-expr (car args) vars)
     (when (pair? (cdr args))
       (collect-ast-vars (cadr args) vars))]
    [else (void)]))

;; Recursively collect variable symbols from a solver term (symbol or list tree).
(define (collect-solver-term-vars term vars)
  (cond
    [(symbol? term) (hash-set! vars term #t)]
    [(list? term) (for ([t (in-list term)]) (collect-solver-term-vars t vars))]
    [else (void)]))

;; Apply a substitution to a goal-desc, resolving variables to their bindings.
;; Used before negation evaluation to ensure ground instantiation.
(define (apply-subst-to-goal goal subst)
  (define kind (goal-desc-kind goal))
  (define args (goal-desc-args goal))
  (define (resolve-term t)
    (cond
      [(symbol? t) (walk subst t)]
      [(list? t) (map resolve-term t)]
      [else t]))
  (case kind
    [(app)
     (define goal-name (car args))
     (define goal-args (cadr args))
     (goal-desc 'app (list goal-name (map resolve-term goal-args)))]
    [(unify)
     (goal-desc 'unify (map resolve-term args))]
    [(is)
     (goal-desc 'is (map resolve-term args))]
    [(not)
     ;; Recurse into nested not
     (define inner-goal-expr (car args))
     (define inner-goal (expr->goal-desc inner-goal-expr))
     (define resolved (apply-subst-to-goal inner-goal subst))
     ;; Return as goal-desc directly (already converted)
     resolved]
    [else goal]))

;; Deep-walk an AST expression to collect variable names (symbols).
;; Used for `not` goals where the inner goal is an AST expr, not a goal-desc.
(define (collect-ast-vars expr vars)
  (cond
    [(expr-goal-app? expr)
     (for ([a (in-list (expr-goal-app-args expr))])
       (cond
         [(expr-logic-var? a) (hash-set! vars (expr-logic-var-name a) #t)]
         [(symbol? a) (hash-set! vars a #t)]))]
    [(expr-unify-goal? expr)
     (let ([lhs (expr-unify-goal-lhs expr)]
           [rhs (expr-unify-goal-rhs expr)])
       (when (expr-logic-var? lhs) (hash-set! vars (expr-logic-var-name lhs) #t))
       (when (symbol? lhs) (hash-set! vars lhs #t))
       (when (expr-logic-var? rhs) (hash-set! vars (expr-logic-var-name rhs) #t))
       (when (symbol? rhs) (hash-set! vars rhs #t)))]
    [(expr-not-goal? expr)
     (collect-ast-vars (expr-not-goal-goal expr) vars)]
    [else (void)]))

;; Deep-walk an AST expression to rename logic variables using a fresh-map.
;; Returns a new AST expression with renamed variables.
(define (rename-ast-vars expr fresh-map)
  (cond
    [(expr-goal-app? expr)
     (expr-goal-app (expr-goal-app-name expr)
                    (for/list ([a (in-list (expr-goal-app-args expr))])
                      (cond
                        [(expr-logic-var? a)
                         (define fresh-name (hash-ref fresh-map (expr-logic-var-name a)
                                                      (expr-logic-var-name a)))
                         (expr-logic-var fresh-name (expr-logic-var-mode a))]
                        [else a])))]
    [(expr-unify-goal? expr)
     (define (rename-unify-term t)
       (cond
         [(expr-logic-var? t)
          (define fresh-name (hash-ref fresh-map (expr-logic-var-name t)
                                       (expr-logic-var-name t)))
          (expr-logic-var fresh-name (expr-logic-var-mode t))]
         [else t]))
     (expr-unify-goal (rename-unify-term (expr-unify-goal-lhs expr))
                      (rename-unify-term (expr-unify-goal-rhs expr)))]
    [(expr-not-goal? expr)
     (expr-not-goal (rename-ast-vars (expr-not-goal-goal expr) fresh-map))]
    [else expr]))

;; Solve an app goal: look up relation, try facts then clauses.
(define (solve-app-goal config store goal-name goal-args subst depth)
  (perf-inc-solver-backtrack!)
  (define rel (relation-lookup store goal-name))
  (unless rel
    (error 'solve "Unknown relation: ~a" goal-name))
  ;; Resolve goal-args through current substitution
  (define resolved-args
    (for/list ([a (in-list goal-args)])
      (walk subst a)))
  ;; Try each variant
  (append-map
   (lambda (variant)
     (define params (variant-info-params variant))
     (define facts (variant-info-facts variant))
     (define clauses (variant-info-clauses variant))
     (define param-names (map param-info-name params))
     ;; Try facts
     (define fact-results
       (append-map
        (lambda (fr)
          (define terms (fact-row-terms fr))
          ;; Unify resolved args with fact terms
          (define result
            (let loop ([as resolved-args] [ts terms] [s subst])
              (cond
                [(and (null? as) (null? ts)) s]
                [(or (null? as) (null? ts)) #f]
                [else
                 (define s* (unify-terms (car as) (car ts) s))
                 (if s* (loop (cdr as) (cdr ts) s*) #f)])))
          (if result (list result) '()))
        facts))
     ;; Try clauses
     (define clause-results
       (append-map
        (lambda (ci)
          ;; Fresh variables for this clause — ALL variables, not just params
          (define fresh-map (make-hasheq))
          (define (freshen name)
            (define key (string->symbol
                         (format "~a_~a" name (gensym))))
            (hash-set! fresh-map name key)
            key)
          ;; Collect ALL variable names from clause goals + params
          (define all-vars (collect-clause-vars ci param-names))
          ;; Create fresh variable names for all vars
          (for ([v (in-list all-vars)])
            (freshen v))
          ;; Extract fresh param names for unification
          (define fresh-params
            (for/list ([pn (in-list param-names)])
              (hash-ref fresh-map pn)))
          ;; Unify goal args with fresh params
          (define initial-subst
            (let loop ([as resolved-args] [fps fresh-params] [s subst])
              (cond
                [(and (null? as) (null? fps)) s]
                [(or (null? as) (null? fps)) #f]
                [else
                 (define s* (unify-terms (car as) (car fps) s))
                 (if s* (loop (cdr as) (cdr fps) s*) #f)])))
          (if initial-subst
              ;; Rename variables in clause goals using fresh-map
              (let ([renamed-goals (map (lambda (g) (rename-goal-vars g fresh-map)) (clause-info-goals ci))])
                (solve-goals config store renamed-goals initial-subst depth))
              '()))
        clauses))
     (append fact-results clause-results))
   (relation-info-variants rel)))

;; Rename variables in a goal descriptor using a fresh-map.
(define (rename-goal-vars goal fresh-map)
  (define kind (goal-desc-kind goal))
  (define args (goal-desc-args goal))
  (define (rename-term t)
    (cond
      [(symbol? t) (hash-ref fresh-map t t)]
      [(list? t) (map rename-term t)]
      [else t]))
  (case kind
    [(app)
     (define goal-name (car args))
     (define goal-args (cadr args))
     (goal-desc 'app (list goal-name (map rename-term goal-args)))]
    [(unify)
     (goal-desc 'unify (map rename-term args))]
    [(is)
     ;; var is a symbol (rename it), expr is an AST node (rename logic vars inside)
     (define var (rename-term (car args)))
     (define expr (rename-logic-vars-in-expr (cadr args) fresh-map))
     (goal-desc 'is (list var expr))]
    [(not)
     ;; Deep-walk the inner AST expression to rename logic variables
     (define inner-expr (car args))
     (goal-desc 'not (list (rename-ast-vars inner-expr fresh-map)))]
    [(guard)
     ;; condition is an AST expr (rename logic vars), goal is an AST goal node or absent
     (define cond-expr (rename-logic-vars-in-expr (car args) fresh-map))
     (if (pair? (cdr args))
         (let ([inner-goal (rename-ast-vars (cadr args) fresh-map)])
           (goal-desc 'guard (list cond-expr inner-goal)))
         (goal-desc 'guard (list cond-expr)))]
    [(cut) goal]
    [else goal]))

;; ========================================
;; Execution: solve-goal
;; ========================================

;; Solve a relational goal, returning a list of answer maps.
;; Each answer is a hasheq mapping query variable names to their values.
;;
;; config: solver-config
;; store: relation store (hasheq of name → relation-info)
;; goal-name: symbol — the relation to query
;; goal-args: (listof any) — arguments (ground values or #f for query vars)
;; query-vars: (listof symbol) — names of unbound variables to project
;;
;; Returns: (listof hasheq) — each hasheq maps query var names to values
(define (solve-goal config store goal-name goal-args query-vars)
  (define rel (relation-lookup store goal-name))
  (unless rel
    (error 'solve "Unknown relation: ~a" goal-name))

  ;; Reconstruct proper goal-args for the DFS solver.
  ;; If goal-args is empty, the caller wants all params as query variables.
  ;; Use the relation's param names as goal args (the DFS solver treats
  ;; symbols as unification variables). The query-vars may be a subset
  ;; of all params — projection happens later.
  (define effective-args
    (if (null? goal-args)
        ;; Use all param names from the first variant as goal args
        (let ([params (if (pair? (relation-info-variants rel))
                          (variant-info-params (car (relation-info-variants rel)))
                          '())])
          (map param-info-name params))
        ;; Mix of ground and query args — already correct from reduction layer
        goal-args))

  ;; Use DFS solver for all queries — handles both facts and clauses
  ;; with proper unification of ground args.
  ;; PUnify Phase 5a: use solver-env (cell-based) when punify enabled.
  (let* ([initial-subst (if (current-punify-enabled?)
                            (make-solver-env)
                            (hasheq))]
         [top-goal (goal-desc 'app (list goal-name effective-args))]
         [solutions (solve-goals config store (list top-goal) initial-subst 0)])
    ;; Project query variables from each solution
    (for/list ([subst (in-list solutions)])
      (for/hasheq ([qv (in-list query-vars)])
        (values qv (walk* subst qv))))))

;; ========================================
;; Execution: explain-goal (D4 Provenance — parallel explain solver)
;; ========================================

;; Like solve-goal but returns answer-result structs with provenance.
;; prov-level: 'none | 'summary | 'full | 'atms
;; explain forces :full when :none (calling explain implies you want the why).
;;
;; Returns: (listof answer-result)
(define (explain-goal config store goal-name goal-args query-vars prov-level)
  (define effective-level
    (if (eq? prov-level 'none) 'full prov-level))
  (define max-depth (solver-config-max-derivation-depth config))

  (define rel (relation-lookup store goal-name))
  (unless rel
    (error 'explain "Unknown relation: ~a" goal-name))

  ;; Same effective-args logic as solve-goal
  (define effective-args
    (if (null? goal-args)
        (let ([params (if (pair? (relation-info-variants rel))
                          (variant-info-params (car (relation-info-variants rel)))
                          '())])
          (map param-info-name params))
        goal-args))

  ;; Run explain-app-goal which returns (listof (cons subst provenance-data))
  (define results
    (explain-app-goal config store goal-name effective-args (hasheq) 0 max-depth effective-level))

  ;; Project query variables from each result and build answer-result
  (for/list ([r (in-list results)])
    (define subst (car r))
    (define prov (cdr r))
    (define bindings
      (for/hasheq ([qv (in-list query-vars)])
        (values qv (walk* subst qv))))
    (make-answer-result #:bindings bindings #:provenance prov)))

;; ----------------------------------------
;; Parallel explain DFS solver
;; Mirrors solve-goals/solve-single-goal/solve-app-goal
;; but returns (cons subst provenance-data) pairs alongside the substitution.
;; ----------------------------------------

;; explain-goals: solve a conjunction of goals, threading the substitution
;; and collecting child derivation trees.
;; Returns: (listof (cons subst (listof derivation-tree)))
;;   Each result is (subst . children) where children are derivation nodes
;;   from all sub-goals in the conjunction.
(define (explain-goals config store goals subst depth max-depth prov-level)
  (cond
    [(null? goals) (list (cons subst '()))]
    [else
     (define first-goal (car goals))
     (define rest-goals (cdr goals))
     (define sub-results
       (explain-single-goal config store first-goal subst depth max-depth prov-level))
     ;; sub-results: (listof (cons subst (listof derivation-tree)))
     (append-map
      (lambda (r)
        (define s (car r))
        (define children-so-far (cdr r))
        (define rest-results
          (explain-goals config store rest-goals s depth max-depth prov-level))
        (for/list ([rr (in-list rest-results)])
          (cons (car rr) (append children-so-far (cdr rr)))))
      sub-results)]))

;; explain-single-goal: dispatch a single goal with provenance.
;; Returns: (listof (cons subst (listof derivation-tree)))
;;   For app goals, produces derivation-tree nodes.
;;   For unify/is/guard/not/cut, produces empty children (no derivation to record).
(define (explain-single-goal config store goal subst depth max-depth prov-level)
  (when (> depth DEFAULT-DEPTH-LIMIT)
    (error 'explain "Depth limit exceeded (~a)" DEFAULT-DEPTH-LIMIT))
  (define kind (goal-desc-kind goal))
  (define args (goal-desc-args goal))
  (case kind
    [(app)
     (define goal-name (car args))
     (define goal-args (cadr args))
     ;; explain-app-goal returns (listof (cons subst provenance-data))
     ;; Convert to (cons subst (list derivation-tree-or-#f))
     (define results
       (explain-app-goal config store goal-name goal-args subst (add1 depth) max-depth prov-level))
     (for/list ([r (in-list results)])
       (define s (car r))
       (define prov (cdr r))
       (define dtree (and prov (provenance-data-derivation prov)))
       (cons s (if dtree (list dtree) '())))]
    [(unify)
     (define lhs (car args))
     (define rhs (cadr args))
     (define lhs-resolved (walk subst lhs))
     (define rhs-resolved (walk subst rhs))
     (define result (unify-terms lhs-resolved rhs-resolved subst))
     (if result (list (cons result '())) '())]
    [(is)
     (define var (car args))
     (define expr (cadr args))
     (define eval-fn (current-is-eval-fn))
     (define val
       (if eval-fn
           (let ([substituted (subst-logic-vars-in-expr expr subst)])
             (eval-fn substituted))
           expr))
     (define result (unify-terms (walk subst var) val subst))
     (if result (list (cons result '())) '())]
    [(not)
     ;; Negation-as-failure: succeed if inner goal fails. No derivation children.
     (define inner-goal-expr (car args))
     (define inner-goal (expr->goal-desc inner-goal-expr))
     (define naf-oracle (current-naf-oracle))
     (cond
       [(and naf-oracle (eq? (goal-desc-kind inner-goal) 'app))
        (define pred-name (car (goal-desc-args inner-goal)))
        (define oracle-result (naf-oracle pred-name))
        (case oracle-result
          [(succeed) (list (cons subst '()))]
          [(fail) '()]
          [(defer) '()]
          [else
           (define resolved-inner-goal (apply-subst-to-goal inner-goal subst))
           (define results (explain-single-goal config store resolved-inner-goal subst depth max-depth prov-level))
           (if (null? results) (list (cons subst '())) '())])]
       [else
        (define resolved-inner-goal (apply-subst-to-goal inner-goal subst))
        (define results (explain-single-goal config store resolved-inner-goal subst depth max-depth prov-level))
        (if (null? results)
            (list (cons subst '()))
            '())])]
    [(cut) (list (cons subst '()))]
    [(guard)
     (define condition (car args))
     (define inner-goal-expr (and (pair? (cdr args)) (cadr args)))
     (define eval-fn (current-is-eval-fn))
     (define cond-val
       (if eval-fn
           (let ([substituted (subst-logic-vars-in-expr condition subst)])
             (eval-fn substituted))
           (walk subst condition)))
     (define truthy?
       (cond
         [(expr-true? cond-val) #t]
         [(expr-false? cond-val) #f]
         [(boolean? cond-val) cond-val]
         [(eq? cond-val #f) #f]
         [else #t]))
     (if truthy?
         (if (and inner-goal-expr (not (eq? inner-goal-expr #f)))
             (let ([inner-goal (expr->goal-desc inner-goal-expr)])
               (explain-single-goal config store inner-goal subst depth max-depth prov-level))
             (list (cons subst '())))
         '())]
    [else
     (error 'explain "Unknown goal kind: ~a" kind)]))

;; explain-app-goal: look up relation, try facts then clauses, building provenance.
;; Returns: (listof (cons subst provenance-data))
(define (explain-app-goal config store goal-name goal-args subst depth max-depth prov-level)
  (perf-inc-solver-backtrack!)
  (define rel (relation-lookup store goal-name))
  (unless rel
    (error 'explain "Unknown relation: ~a" goal-name))

  ;; Resolve goal-args through current substitution
  (define resolved-args
    (for/list ([a (in-list goal-args)])
      (walk subst a)))

  ;; Compute clause-id convention: count total facts+clauses across all variants
  ;; to decide if index suffix is needed
  (define total-entries
    (for/sum ([v (in-list (relation-info-variants rel))])
      (+ (length (variant-info-facts v))
         (length (variant-info-clauses v)))))

  ;; Build clause-id from name, arity, and index
  (define (make-clause-id arity idx)
    (if (= total-entries 1)
        (string->symbol (format "~a/~a" goal-name arity))
        (string->symbol (format "~a/~a-~a" goal-name arity idx))))

  ;; Depth limit check: truncate if at max depth
  (when (> depth max-depth)
    ;; Return empty — we've exceeded the derivation depth limit
    ;; (the solver depth limit DEFAULT-DEPTH-LIMIT still applies for correctness)
    (void))

  ;; Try each variant
  (append-map
   (lambda (variant)
     (define params (variant-info-params variant))
     (define facts (variant-info-facts variant))
     (define clauses (variant-info-clauses variant))
     (define param-names (map param-info-name params))
     (define arity (length param-names))

     ;; Try facts
     (define fact-results
       (let loop ([frs facts] [fact-idx 0] [acc '()])
         (cond
           [(null? frs) (reverse acc)]
           [else
            (define fr (car frs))
            (define terms (fact-row-terms fr))
            (define result
              (let inner ([as resolved-args] [ts terms] [s subst])
                (cond
                  [(and (null? as) (null? ts)) s]
                  [(or (null? as) (null? ts)) #f]
                  [else
                   (define s* (unify-terms (car as) (car ts) s))
                   (if s* (inner (cdr as) (cdr ts) s*) #f)])))
            (if result
                (let* ([cid (make-clause-id arity fact-idx)]
                       [dtree (if (memq prov-level '(full atms))
                                  (make-derivation goal-name
                                                   (for/list ([a (in-list goal-args)])
                                                     (walk* result a))
                                                   cid '())
                                  #f)]
                       [prov (make-provenance-data
                              #:clause-id cid
                              #:depth depth
                              #:derivation dtree)])
                  (loop (cdr frs) (add1 fact-idx) (cons (cons result prov) acc)))
                (loop (cdr frs) (add1 fact-idx) acc))])))

     ;; Try clauses
     (define clause-results
       (let loop ([cis clauses] [clause-idx (length facts)] [acc '()])
         (cond
           [(null? cis) (reverse acc)]
           [else
            (define ci (car cis))
            ;; Fresh variables for this clause
            (define fresh-map (make-hasheq))
            (define (freshen name)
              (define key (string->symbol (format "~a_~a" name (gensym))))
              (hash-set! fresh-map name key)
              key)
            (define all-vars (collect-clause-vars ci param-names))
            (for ([v (in-list all-vars)]) (freshen v))
            (define fresh-params
              (for/list ([pn (in-list param-names)])
                (hash-ref fresh-map pn)))
            ;; Unify goal args with fresh params
            (define initial-subst
              (let inner ([as resolved-args] [fps fresh-params] [s subst])
                (cond
                  [(and (null? as) (null? fps)) s]
                  [(or (null? as) (null? fps)) #f]
                  [else
                   (define s* (unify-terms (car as) (car fps) s))
                   (if s* (inner (cdr as) (cdr fps) s*) #f)])))
            (if initial-subst
                ;; Rename variables in clause goals and recurse
                (let* ([renamed-goals (map (lambda (g) (rename-goal-vars g fresh-map))
                                          (clause-info-goals ci))]
                       [body-results
                        (if (> depth max-depth)
                            ;; At depth limit: truncate — don't recurse into body
                            (list (cons initial-subst '()))
                            (explain-goals config store renamed-goals initial-subst
                                           depth max-depth prov-level))]
                       [cid (make-clause-id arity clause-idx)])
                  (define new-results
                    (for/list ([br (in-list body-results)])
                      (define final-subst (car br))
                      (define children (cdr br))
                      (define dtree
                        (if (memq prov-level '(full atms))
                            (make-derivation goal-name
                                             (for/list ([a (in-list goal-args)])
                                               (walk* final-subst a))
                                             cid children)
                            #f))
                      (define prov (make-provenance-data
                                   #:clause-id cid
                                   #:depth depth
                                   #:derivation dtree))
                      (cons final-subst prov)))
                  (loop (cdr cis) (add1 clause-idx) (append acc new-results)))
                (loop (cdr cis) (add1 clause-idx) acc))])))

     (append fact-results clause-results))
   (relation-info-variants rel)))


;; ========================================
;; Phase 6+7: Propagator-Native Solver (D.11)
;; ========================================
;;
;; Logic variables = cells on the prop-network.
;; Goals = propagator installations (not function calls).
;; Conjunction = sequential installation (broadcast in Phase 7b).
;; Results = answer accumulator cell (set-union merge).
;;
;; Coexists with the DFS solver above. Selected by :strategy config.

;; Sentinel for unbound logic variables.
(define logic-var-bot 'logic-var-bot)

;; Logic variable cell merge: last binding wins.
(define (logic-var-merge old new)
  (if (eq? old logic-var-bot) new
      (if (eq? new logic-var-bot) old
          new)))

;; Allocate a fresh logic variable cell on the network.
;; Returns: (values new-network cell-id)
(define (alloc-logic-var net)
  (net-new-cell net logic-var-bot logic-var-merge))

;; Build a variable environment: hasheq var-name → cell-id.
;; Allocates a fresh cell for each variable name.
;; Returns: (values new-network env)
(define (build-var-env net var-names)
  (for/fold ([n net] [env (hasheq)])
            ([name (in-list var-names)])
    (define-values (n* cid) (alloc-logic-var n))
    (values n* (hash-set env name cid))))

;; Resolve a term against a variable environment.
;; If the term is a symbol in env, return its cell-id.
;; Otherwise return the term as-is (ground value).
(define (resolve-term env term)
  (if (and (symbol? term) (hash-has-key? env term))
      (hash-ref env term)
      term))

;; ----------------------------------------
;; install-goal-propagator (7a)
;; ----------------------------------------
;; Dispatches on goal kind, installs propagator(s) on the network.
;; Returns: new-network
(define (install-goal-propagator net goal env store config answer-cid)
  (define kind (goal-desc-kind goal))
  (define args (goal-desc-args goal))
  (case kind
    [(unify)
     (define lhs (resolve-term env (car args)))
     (define rhs (resolve-term env (cadr args)))
     (cond
       ;; Both cells: bidirectional unification propagator
       [(and (cell-id? lhs) (cell-id? rhs))
        (define (unify-fire net)
          (define v1 (net-cell-read net lhs))
          (define v2 (net-cell-read net rhs))
          (cond
            [(eq? v1 logic-var-bot)
             (if (eq? v2 logic-var-bot) net (net-cell-write net lhs v2))]
            [(eq? v2 logic-var-bot) (net-cell-write net rhs v1)]
            [(equal? v1 v2) net]
            [else net]))
        (define-values (net* _pid)
          (net-add-propagator net (list lhs rhs) (list lhs rhs) unify-fire))
        net*]
       ;; One cell, one ground: write ground to cell
       [(cell-id? lhs) (net-cell-write net lhs rhs)]
       [(cell-id? rhs) (net-cell-write net rhs lhs)]
       ;; Both ground: no network change
       [else net])]

    [(is)
     (define var (resolve-term env (car args)))
     (define expr (cadr args))
     (define eval-fn (current-is-eval-fn))
     (if (and (cell-id? var) eval-fn)
         (net-cell-write net var (eval-fn expr))
         net)]

    [(app)
     (define goal-name (car args))
     (define goal-args (cadr args))
     (install-clause-propagators net goal-name goal-args env store config answer-cid)]

    [(not) net]   ;; Phase 7c: NAF S1 propagator (deferred)
    [(guard) net] ;; Phase 7c: guard S1 propagator (deferred)
    [(cut) net]   ;; Out of scope (P2)
    [else net]))

;; ----------------------------------------
;; install-conjunction (7b)
;; ----------------------------------------
;; Install all goals in a clause body. Order-irrelevant.
;; Returns: new-network
(define (install-conjunction net goals env store config answer-cid)
  (for/fold ([n net])
            ([goal (in-list goals)])
    (install-goal-propagator n goal env store config answer-cid)))

;; ----------------------------------------
;; install-clause-propagators (6c)
;; ----------------------------------------
;; Three paths: facts, single clause, multi-clause.
;; Returns: new-network
(define (install-clause-propagators net goal-name goal-args env store config answer-cid)
  (define rel (relation-lookup store goal-name))
  (cond
    [(not rel) net]
    [else
     (define resolved-args
       (for/list ([a (in-list goal-args)])
         (resolve-term env a)))
     (for/fold ([n net])
               ([variant (in-list (relation-info-variants rel))])
       (define params (variant-info-params variant))
       (define facts (variant-info-facts variant))
       (define clauses (variant-info-clauses variant))
       (define param-names (map param-info-name params))

       ;; Facts: write each fact row's values to the corresponding arg cells
       (define n-facts
         (for/fold ([n n])
                   ([fr (in-list facts)])
           (define row (fact-row-terms fr))
           (if (= (length row) (length resolved-args))
               (for/fold ([n n])
                         ([arg (in-list resolved-args)]
                          [val (in-list row)])
                 (if (cell-id? arg)
                     (net-cell-write n arg val)
                     n))
               n)))

       ;; Clauses
       (cond
         [(null? clauses) n-facts]
         [else
          ;; For each clause: build fresh var env, unify args with params,
          ;; install clause body goals.
          ;; TODO Phase 6d: multi-clause → PU-per-clause with Gray code.
          ;; For now: sequential installation (no branching isolation).
          (for/fold ([n n-facts])
                    ([ci (in-list clauses)])
            (define clause-goals (clause-info-goals ci))
            ;; Fresh variable scope for this clause
            (define-values (n2 clause-env) (build-var-env n param-names))
            ;; Unify resolved args with clause param cells
            (define n3
              (for/fold ([n n2])
                        ([arg (in-list resolved-args)]
                         [pname (in-list param-names)])
                (define pcid (hash-ref clause-env pname))
                (if (cell-id? arg)
                    (let-values ([(n* _pid)
                                  (net-add-propagator n (list arg) (list pcid)
                                    (lambda (net)
                                      (define v (net-cell-read net arg))
                                      (if (eq? v logic-var-bot) net
                                          (net-cell-write net pcid v))))])
                      n*)
                    (net-cell-write n pcid arg))))
            (install-conjunction n3 clause-goals clause-env store config answer-cid))]))]))

;; ----------------------------------------
;; solve-goal-propagator (entry point)
;; ----------------------------------------
;; The propagator-native alternative to solve-goal.
;; Returns: (listof hasheq) — projected query variable bindings.
(define (solve-goal-propagator config store goal-name goal-args query-vars)
  (define rel (relation-lookup store goal-name))
  (unless rel
    (error 'solve-goal-propagator "Unknown relation: ~a" goal-name))

  (define effective-args
    (if (null? goal-args)
        (let ([params (if (pair? (relation-info-variants rel))
                          (variant-info-params (car (relation-info-variants rel)))
                          '())])
          (map param-info-name params))
        goal-args))

  ;; Create network + allocate query variable cells
  (define net0 (make-prop-network))
  (define-values (net1 query-env) (build-var-env net0 query-vars))

  ;; Answer accumulator cell
  (define (answer-merge old new)
    (cond [(null? old) new] [(null? new) old] [else (append old new)]))
  (define-values (net2 answer-cid) (net-new-cell net1 '() answer-merge))

  ;; Install the top-level goal
  (define top-goal (goal-desc 'app (list goal-name effective-args)))
  (define net3 (install-goal-propagator net2 top-goal query-env store config answer-cid))

  ;; Run to quiescence
  (define net4 (run-to-quiescence net3))

  ;; Project query variables
  (define result-subst
    (for/hasheq ([qv (in-list query-vars)])
      (define cid (hash-ref query-env qv))
      (define val (net-cell-read net4 cid))
      (values qv (if (eq? val logic-var-bot) qv val))))

  (if (for/and ([qv (in-list query-vars)])
        (eq? (hash-ref result-subst qv) qv))
      '()
      (list result-subst)))
