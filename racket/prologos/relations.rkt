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
         "tabling.rkt"
         "union-find.rkt"
         "solver.rkt"
         "provenance.rkt"
         "syntax.rkt")

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
 expr->goal-desc
 ;; Execution
 solve-goal
 explain-goal)

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

;; Convert an AST goal expression to a goal-desc struct.
;; All logic variables are normalized to plain symbols for the runtime solver.
(define (expr->goal-desc g)
  (cond
    [(expr-goal-app? g)
     (goal-desc 'app (list (expr-goal-app-name g)
                           (map normalize-term (expr-goal-app-args g))))]
    [(expr-unify-goal? g)
     (goal-desc 'unify (list (normalize-term (expr-unify-goal-lhs g))
                             (normalize-term (expr-unify-goal-rhs g))))]
    [(expr-is-goal? g)
     (goal-desc 'is (list (normalize-term (expr-is-goal-var g))
                          (expr-is-goal-expr g)))]
    [(expr-not-goal? g)
     (goal-desc 'not (list (expr-not-goal-goal g)))]
    [(expr-cut? g)
     (goal-desc 'cut '())]
    [(expr-guard? g)
     (goal-desc 'guard (list (expr-guard-condition g) (expr-guard-goal g)))]
    [else
     ;; Fallback: wrap as-is
     (goal-desc 'app (list 'unknown (list g)))]))

;; ========================================
;; Runtime Unification + DFS Solver (Sub-phase F)
;; ========================================

;; Default depth limit for DFS search
(define DEFAULT-DEPTH-LIMIT 100)

;; Walk a substitution to fully resolve a term.
;; subst: hasheq mapping variable names (symbols) to values or other var names
(define (walk subst term)
  (cond
    [(symbol? term)
     (define val (hash-ref subst term #f))
     (if val
         (if (eq? val term) term (walk subst val))
         term)]
    [else term]))

;; Deeply walk a term, resolving all variables transitively.
(define (walk* subst term)
  (define resolved (walk subst term))
  (cond
    [(list? resolved)
     (map (lambda (t) (walk* subst t)) resolved)]
    [else resolved]))

;; Unify two terms under a substitution.
;; Returns updated substitution or #f on failure.
(define (unify-terms t1 t2 subst)
  (define v1 (walk subst t1))
  (define v2 (walk subst t2))
  (cond
    [(equal? v1 v2) subst]
    [(symbol? v1) (hash-set subst v1 v2)]
    [(symbol? v2) (hash-set subst v2 v1)]
    [(and (list? v1) (list? v2) (= (length v1) (length v2)))
     (let loop ([ts1 v1] [ts2 v2] [s subst])
       (cond
         [(null? ts1) s]
         [else
          (define s* (unify-terms (car ts1) (car ts2) s))
          (if s* (loop (cdr ts1) (cdr ts2) s*) #f)]))]
    [else #f]))

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
     ;; Stub: is-goals evaluate functional expressions
     ;; For now, just unify the var with the expr (both as ground)
     (define var (car args))
     (define expr (cadr args))
     (define result (unify-terms (walk subst var) (walk subst expr) subst))
     (if result (list result) '())]
    [(not)
     ;; Negation-as-failure: succeed if inner goal fails
     (define inner-goal-expr (car args))
     (define inner-goal (expr->goal-desc inner-goal-expr))
     (define results (solve-single-goal config store inner-goal subst depth))
     (if (null? results)
         (list subst)  ;; inner failed → not succeeds
         '())]         ;; inner succeeded → not fails
    [(cut)
     ;; Cut: return current substitution (cut semantics need special handling)
     (list subst)]
    [(guard)
     ;; Guard: evaluate condition, if truthy proceed with inner goal
     (define condition (car args))
     (define inner-goal-expr (cadr args))
     (define inner-goal (expr->goal-desc inner-goal-expr))
     (define cond-resolved (walk subst condition))
     ;; For now, guard passes through to inner goal if condition is not #f
     (if cond-resolved
         (solve-single-goal config store inner-goal subst depth)
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
       (when (symbol? a) (hash-set! vars a #t)))]
    [(is)
     (when (symbol? (car args)) (hash-set! vars (car args) #t))]
    [(not)
     ;; inner goal is an AST expr — would need deep walking
     ;; For now, skip (inner vars won't be freshened)
     (void)]
    [else (void)]))

;; Solve an app goal: look up relation, try facts then clauses.
(define (solve-app-goal config store goal-name goal-args subst depth)
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
     (goal-desc 'is (map rename-term args))]
    [(not)
     ;; not args is a list with one element (the inner goal AST expr)
     ;; Renaming inside AST exprs would require deep walking — pass through for now
     goal]
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
  ;; with proper unification of ground args
  (let* ([top-goal (goal-desc 'app (list goal-name effective-args))]
         [solutions (solve-goals config store (list top-goal) (hasheq) 0)])
    ;; Project query variables from each solution
    (for/list ([subst (in-list solutions)])
      (for/hasheq ([qv (in-list query-vars)])
        (values qv (walk* subst qv))))))

;; ========================================
;; Execution: explain-goal
;; ========================================

;; Like solve-goal but returns answer-records with provenance.
;; prov-level: 'none | 'summary | 'full | 'atms
;;
;; Returns: (listof answer-record)
(define (explain-goal config store goal-name goal-args query-vars prov-level)
  ;; For now, delegate to solve-goal and wrap results
  ;; Full provenance tracking will be wired in reduction.rkt
  (define effective-level
    (if (eq? prov-level 'none) 'full prov-level))

  (define binding-maps
    (solve-goal config store goal-name goal-args query-vars))

  ;; Wrap each binding map in an answer-record
  (for/list ([bm (in-list binding-maps)])
    (make-answer
     #:bindings bm
     #:clause-id #f
     #:depth 0
     #:derivation #f
     #:support #f)))
