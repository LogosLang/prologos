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
         racket/set          ;; Track 2B Phase 1a: set-intersect, seteq for viable-indices
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
 ;; Track 2B Phase 1a+1b: on-network discrimination
 build-discrimination-data
 discrimination-data-merge
 discrimination-data-bot
 position-discriminates?
 install-discrimination-propagators
 ;; Phase 1b: discrimination tree
 (struct-out discrim-node)
 (struct-out discrim-leaf)
 build-discrimination-tree
 variant-discrimination-tree
 tree-all-indices
 ;; AST → runtime conversion
 expr-defr->relation-info
 expr-rel->relation-info
 expr->goal-desc
 ;; Variable renaming helpers (for negation)
 rename-ast-vars
 collect-ast-vars
 ;; Evaluation callback (set by reduction.rkt to break circular dep)
 current-is-eval-fn
 ;; Track 2B Phase 2a: NAF infrastructure (stratified)
 current-naf-completions
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
 solve-goal-propagator
 ;; Phase 6+7: Variable environment helpers (for tests + consumers)
 logic-var-bot
 build-var-env
 resolve-term
 gray-code-order
 ;; Phase 8: Scope cell variable access
 scope-ref?
 logic-var-read
 logic-var-write)

;; ========================================
;; Evaluation callback
;; ========================================

;; Callback for evaluating functional expressions inside relational goals.
;; Set by reduction.rkt to `whnf` to break circular dependency.
;; When #f, is-goals fall back to raw unification (no evaluation).
(define current-is-eval-fn (make-parameter #f))

;; Track 2B Phase 2a: NAF completion registrations.
;; Mutable hasheq: completion-cid → info-hasheq.
;; Written during install-goal-propagator ('not case).
;; Read by solve-goal-propagator after BSP quiescence to write 'completed.
;; Scaffolding — Phase 2b replaces with BSP completion stratum.
(define current-naf-completions (make-parameter #f))


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
;; Track 2B Phase 1a: computes discrimination map at registration time.
(define (relation-register store rel)
  (hash-set store (relation-info-name rel) rel))

;; ========================================
;; Track 2B Phase 1a: Discrimination Infrastructure
;; ========================================
;;
;; On-network clause discrimination via broadcast propagators.
;;
;; Each discriminating argument position gets ONE compound discrimination
;; cell (Pocket Universe pattern: one cell, components indexed by clause/
;; fact-row index). The cell value is a hasheq mapping clause-idx to the
;; expected ground value at that position. Wildcard clauses (no discriminator)
;; are omitted — they match any value.
;;
;; At query time, ONE broadcast propagator per discriminating position reads
;; the query argument cell + discrimination cell, compares each clause's
;; expected value with the query arg using `equal?` (same semantics as
;; solver-unify-terms line 175), and writes the viable set to the clause-
;; viability cell.
;;
;; Alternatives ordering: fact rows first (indices 0..F-1), then
;; clauses (indices F..F+C-1). Stable; matches assumption-id allocation.
;;
;; Lattice: compound cell with hash-union merge (monotone — new clause
;; registrations add components). Self-hosting: derivation propagator
;; watches relation registry cell.

;; A discrimination-data value: hasheq clause-idx → expected-value.
;; Stored as the value of a discrimination cell at position k.
;; Clauses not in the map are wildcards (match any value).
(define discrimination-data-bot (hasheq))

(define (discrimination-data-merge old new)
  (if (eq? old discrimination-data-bot) new
      (if (eq? new discrimination-data-bot) old
          ;; hash-union: new clauses add to existing
          (for/fold ([acc old]) ([(k v) (in-hash new)])
            (hash-set acc k v)))))

;; Build discrimination data for each position from a variant's facts + clauses.
;; Returns: (hasheq position → discrimination-data)
;; where discrimination-data = (hasheq clause-idx → expected-ground-value)
(define (build-discrimination-data variant)
  (define params (variant-info-params variant))
  (define facts (variant-info-facts variant))
  (define clauses (variant-info-clauses variant))
  (define param-names (map param-info-name params))
  (define n-facts (length facts))

  ;; Fact rows: each row contributes its ground value at each position
  (define from-facts
    (for/fold ([dm (hasheq)])
              ([fr (in-list facts)]
               [fact-idx (in-naturals)])
      (for/fold ([dm dm])
                ([val (in-list (fact-row-terms fr))]
                 [pos (in-naturals)])
        (define pos-data (hash-ref dm pos discrimination-data-bot))
        (hash-set dm pos (hash-set pos-data fact-idx val)))))

  ;; Clauses: peek at first unify goal for discriminating value
  (for/fold ([dm from-facts])
            ([ci (in-list clauses)]
             [clause-idx (in-naturals n-facts)])
    (define goals (clause-info-goals ci))
    (if (null? goals)
        dm  ;; no goals = wildcard (not added to discrimination data)
        (let ([first-goal (car goals)])
          (if (eq? (goal-desc-kind first-goal) 'unify)
              (let* ([args (goal-desc-args first-goal)]
                     [lhs (car args)]
                     [rhs (cadr args)])
                (define param-pos
                  (for/or ([pname (in-list param-names)]
                           [pos (in-naturals)])
                    (and (equal? pname lhs) pos)))
                (if (and param-pos (not (symbol? rhs)))
                    (let ([pos-data (hash-ref dm param-pos discrimination-data-bot)])
                      (hash-set dm param-pos (hash-set pos-data clause-idx rhs)))
                    dm))
              dm)))))

;; Check if position k has discrimination power.
(define (position-discriminates? discrim-data pos n-alternatives)
  (define pos-data (hash-ref discrim-data pos discrimination-data-bot))
  (and (not (hash-empty? pos-data))
       ;; Discriminates if not ALL alternatives are in the map
       ;; (some are wildcards) or if values are not all identical
       (or (< (hash-count pos-data) n-alternatives)
           (let ([vals (hash-values pos-data)])
             (not (for/and ([v (in-list (cdr vals))])
                    (equal? v (car vals))))))))

;; ========================================
;; Track 2B Phase 1b: Discrimination Tree (Needed-Narrowing-Inspired)
;; ========================================
;;
;; Hierarchical clause discrimination. Each level of the tree represents
;; a Q_1 decomposition of the clause space at one argument position.
;; The tree IS the Hasse diagram of the clause decomposition.
;;
;; At solve time, the tree guides propagator installation: only install
;; discrimination propagators for positions that add narrowing power
;; within the current viable group. Avoids redundant propagators.
;;
;; SRE: each tree level is a decision cell. The recursive decomposition
;; Q_N = Q_{N-1} × Q_1 matches the tree's recursive structure.

;; Tree node: discriminate at `position` using value → subtree mapping.
;; `wildcard-indices`: clause indices with no discriminator at this position
;; (always viable regardless of value).
(struct discrim-node (position children wildcard-indices) #:transparent)
;; Leaf: no further discrimination needed. `indices` = viable clause set.
(struct discrim-leaf (indices) #:transparent)

;; Score a position's discrimination power for a given set of clause indices.
;; Returns the number of distinct GROUPS the position creates.
;; Higher = more discriminating. 0 = no discrimination.
(define (position-score discrim-data pos indices)
  (define pos-data (hash-ref discrim-data pos discrimination-data-bot))
  (if (hash-empty? pos-data) 0
      (let ()
        ;; Group indices by their expected value at this position
        (define groups (make-hash))  ;; value → (listof index)
        (define wildcards '())
        (for ([idx (in-set indices)])
          (define val (hash-ref pos-data idx #f))
          (if val
              (hash-update! groups val (lambda (lst) (cons idx lst)) '())
              (set! wildcards (cons idx wildcards))))
        ;; Score = number of distinct groups (excluding wildcards)
        ;; A position that creates N groups from M indices is more discriminating
        (hash-count groups))))

;; Build a discrimination tree for a set of clause indices.
;; `discrim-data`: (hasheq position → (hasheq clause-idx → expected-value))
;; `indices`: seteq of clause indices to discriminate among
;; `positions`: list of argument positions still available for discrimination
;; Returns: discrim-node or discrim-leaf
(define (build-discrimination-tree discrim-data indices positions)
  (cond
    ;; Base case: 0-1 indices — no further discrimination needed
    [(<= (set-count indices) 1)
     (discrim-leaf indices)]

    ;; No more positions to discriminate on
    [(null? positions)
     (discrim-leaf indices)]

    [else
     ;; Score each remaining position
     (define scored
       (for/list ([pos (in-list positions)])
         (cons (position-score discrim-data pos indices) pos)))
     ;; Best position = highest score
     (define best-pair
       (for/fold ([best (car scored)])
                 ([pair (in-list (cdr scored))])
         (if (> (car pair) (car best)) pair best)))

     (if (zero? (car best-pair))
         ;; No position discriminates further — leaf
         (discrim-leaf indices)
         ;; Build tree node at best position
         (let ()
           (define best-pos (cdr best-pair))
           (define pos-data (hash-ref discrim-data best-pos discrimination-data-bot))
           (define remaining-positions (remove best-pos positions))

           ;; Group indices by value at best-pos
           (define groups (make-hash))
           (define wildcard-indices (seteq))
           (for ([idx (in-set indices)])
             (define val (hash-ref pos-data idx #f))
             (if val
                 (hash-update! groups val
                               (lambda (s) (set-add s idx))
                               (seteq))
                 (set! wildcard-indices (set-add wildcard-indices idx))))

           ;; Recursively build subtrees for each group
           ;; Wildcards are added to EVERY group (they match any value)
           (define children
             (for/hasheq ([(val group-indices) (in-hash groups)])
               (define full-group (set-union group-indices wildcard-indices))
               (values val (build-discrimination-tree discrim-data full-group remaining-positions))))

           (discrim-node best-pos children wildcard-indices)))]))

;; Collect all clause indices reachable from a tree node.
(define (tree-all-indices tree-node)
  (cond
    [(discrim-leaf? tree-node) (discrim-leaf-indices tree-node)]
    [(discrim-node? tree-node)
     (define wildcards (discrim-node-wildcard-indices tree-node))
     (for/fold ([acc wildcards])
               ([(val subtree) (in-hash (discrim-node-children tree-node))])
       (set-union acc (tree-all-indices subtree)))]
    [else (seteq)]))

;; Build a discrimination tree for a variant.
;; Returns: discrim-node or discrim-leaf (or #f if no discrimination possible)
(define (variant-discrimination-tree variant)
  (define discrim-data (build-discrimination-data variant))
  (define n-facts (length (variant-info-facts variant)))
  (define n-clauses (length (variant-info-clauses variant)))
  (define n-total (+ n-facts n-clauses))
  (if (<= n-total 1) #f  ;; no discrimination needed for 0-1 alternatives
      (let ()
        (define all-indices (for/seteq ([i (in-range n-total)]) i))
        (define all-positions
          (for/list ([i (in-range (length (variant-info-params variant)))])
            i))
        (define tree (build-discrimination-tree discrim-data all-indices all-positions))
        ;; Only return tree if it actually discriminates (not just a leaf of everything)
        (if (discrim-leaf? tree) #f tree))))

;; Install discrimination broadcast propagators on the network.
;; For each discriminating position k:
;;   - Allocate a discrimination cell (compound: clause-idx → expected-value)
;;   - Write the discrimination data to the cell
;;   - Install a broadcast propagator that reads query-arg + discrim cell,
;;     compares using equal?, writes viable set to viability cell
;;
;; Returns: (values new-network viability-cid)
(define (install-discrimination-propagators net variant resolved-args n-alternatives)
  (define discrim-data (build-discrimination-data variant))

  ;; Allocate viability cell: starts with all alternatives viable
  (define all-viable (for/seteq ([i (in-range n-alternatives)]) i))
  (define (viability-merge old new)
    (if (equal? old all-viable) new
        (if (equal? new all-viable) old
            (set-intersect old new))))
  (define-values (net1 viability-cid)
    (net-new-cell net all-viable viability-merge))

  ;; Flat propagator installation: one fire-once propagator per discriminating
  ;; position. ALL positions install propagators — ordering EMERGES from BSP
  ;; dataflow (which arg cells resolve first). Distributivity guarantees
  ;; same result regardless of narrowing order. The discrimination tree (Phase 1b)
  ;; is a data value for analysis/self-hosting, not an imperative installation guide.
  (define net-final
    (for/fold ([n net1])
              ([pos (in-naturals)]
               [arg (in-list resolved-args)])
      (define pos-data (hash-ref discrim-data pos discrimination-data-bot))
      (cond
        [(hash-empty? pos-data) n]  ;; no discriminators at this position
        [(or (scope-ref? arg) (cell-id? arg))
         ;; Free argument: install fire-once propagator that fires when arg resolves
         (define arg-cid (if (scope-ref? arg) (scope-ref-cid arg) arg))
         (define discrim-pairs
           (for/list ([(clause-idx expected) (in-hash pos-data)])
             (cons clause-idx expected)))
         (define (discrim-fire net)
           (define arg-val
             (let ([raw (net-cell-read net arg-cid)])
               (if (scope-cell? raw)
                   (let ([var-name (and (scope-ref? arg) (scope-ref-var arg))])
                     (if var-name (scope-cell-ref raw var-name) raw))
                   raw)))
           (if (or (eq? arg-val scope-cell-bot) (not arg-val))
               net  ;; arg not yet resolved — residuate (no write)
               (let ([viable
                      (for/seteq ([pair (in-list discrim-pairs)]
                                  #:when (equal? (cdr pair) arg-val))
                        (car pair))])
                 (define wildcards
                   (for/seteq ([i (in-range n-alternatives)]
                               #:when (not (hash-has-key? pos-data i)))
                     i))
                 (define full-viable (set-union viable wildcards))
                 (net-cell-write net viability-cid full-viable))))
         (define-values (n2 _pid)
           (net-add-fire-once-propagator n (list arg-cid) (list viability-cid)
                                         discrim-fire))
         n2]
        [else
         ;; Ground argument: narrow immediately via cell write
         (define viable
           (for/seteq ([pair (in-list (hash->list pos-data))]
                       #:when (equal? (cdr pair) arg))
             (car pair)))
         (define wildcards
           (for/seteq ([i (in-range n-alternatives)]
                       #:when (not (hash-has-key? pos-data i)))
             i))
         (define full-viable (set-union viable wildcards))
         (net-cell-write n viability-cid full-viable)])))

  (values net-final viability-cid))

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
;; DEPRECATED in favor of build-var-env with scope cells.
;; Kept for NAF inner-result cell allocation.
(define (alloc-logic-var net)
  (net-new-cell net logic-var-bot logic-var-merge))

;; Phase 8.2: Build a variable environment using ONE compound scope cell.
;; Allocates a single cell holding a scope-cell value (hasheq var-name → value).
;; Returns: (values new-network scope-cell-id env)
;;   scope-cell-id: the single cell-id for the compound scope
;;   env: hasheq var-name → (cons scope-cell-id var-name) for caller convenience
;; The env preserves the same interface as the old build-var-env —
;; callers use resolve-term to look up variables. The difference:
;; resolve-term now returns a scope-ref (cons cell-id var-name) for variables.
(define (build-var-env net var-names)
  (define initial-scope
    (scope-cell (for/hasheq ([v (in-list var-names)])
                  (values v scope-cell-bot))))
  (define-values (n scope-cid) (net-new-cell net initial-scope scope-cell-merge))
  (define env
    (for/hasheq ([v (in-list var-names)])
      (values v (cons scope-cid v))))
  (values n env))

;; A scope-ref: (cons scope-cell-id var-name). Returned by build-var-env.
(define (scope-ref? x) (and (pair? x) (cell-id? (car x)) (symbol? (cdr x))))
(define (scope-ref-cid x) (car x))
(define (scope-ref-var x) (cdr x))

;; Read a logic variable from the network.
;; Handles both old-style cell-ids and new scope-refs.
(define (logic-var-read net ref)
  (cond
    [(scope-ref? ref)
     (define sc (net-cell-read net (scope-ref-cid ref)))
     (if (scope-cell? sc)
         (scope-cell-ref sc (scope-ref-var ref))
         scope-cell-bot)]
    [(cell-id? ref) (net-cell-read net ref)]
    [else ref]))

;; Write a logic variable on the network.
;; Handles both old-style cell-ids and new scope-refs.
;; For scope-refs: writes a delta scope-cell (one variable set) →
;; scope-cell-merge handles per-key join.
(define (logic-var-write net ref value)
  (cond
    [(scope-ref? ref)
     (net-cell-write net (scope-ref-cid ref)
                     (scope-cell (hasheq (scope-ref-var ref) value)))]
    [(cell-id? ref) (net-cell-write net ref value)]
    [else net]))

;; Resolve a term against a variable environment.
;; If the term is a symbol in env, return the scope-ref (or cell-id for old-style).
;; Otherwise return the term as-is (ground value).
(define (resolve-term env term)
  (if (and (symbol? term) (hash-has-key? env term))
      (hash-ref env term)
      term))

;; Gray code: i → i XOR (i >> 1).
;; Generates a Hamiltonian path on Q_n that changes one bit per step.
;; Used to order branch PU creation for maximal CHAMP structural sharing.
(define (gray-code i)
  (bitwise-xor i (arithmetic-shift i -1)))

;; Generate Gray code ordering for M items. Returns a permutation of 0..M-1
;; where successive elements differ by one bit (Hamming distance 1).
;; For M that isn't a power of 2, walks the Gray code sequence and collects
;; indices < M in encounter order.
;; Examples: M=2 → (0 1), M=3 → (0 1 3→skip 2), M=4 → (0 1 3 2)
(define (gray-code-order m)
  (cond
    [(<= m 1) (list 0)]
    [else
     ;; Walk gray codes for enough bits, collect indices < m
     (define bits (let loop ([b 1]) (if (>= (arithmetic-shift 1 b) m) b (loop (add1 b)))))
     (define total (arithmetic-shift 1 bits))
     (for/list ([i (in-range total)]
                #:when (< (gray-code i) m))
       (gray-code i))]))

;; Auto-wrap a fire function with the current worldview bitmask if set.
;; Ensures propagators installed during a clause's installation inherit
;; that clause's worldview for their fire-time reads and writes.
(define (maybe-wrap-worldview fire-fn)
  (define bm (current-worldview-bitmask))
  (if (zero? bm)
      fire-fn
      (lambda (net)
        (parameterize ([current-worldview-bitmask bm])
          (fire-fn net)))))

;; ----------------------------------------
;; install-goal-propagator (7a)
;; ----------------------------------------
;; Dispatches on goal kind, installs propagator(s) on the network.
;; ctx: solver-context or #f (needed for multi-clause branching)
;; Returns: new-network
(define (install-goal-propagator net goal env store config answer-cid [ctx #f])
  (define kind (goal-desc-kind goal))
  (define args (goal-desc-args goal))
  (case kind
    [(unify)
     (define lhs (resolve-term env (car args)))
     (define rhs (resolve-term env (cadr args)))
     ;; Helper: is this a variable ref (scope-ref or cell-id)?
     (define (var-ref? x) (or (scope-ref? x) (cell-id? x)))
     ;; Helper: get the cell-id(s) a ref watches
     (define (ref->input-cids x)
       (if (scope-ref? x) (list (scope-ref-cid x)) (list x)))
     (cond
       ;; Both variable refs: bidirectional unification propagator
       [(and (var-ref? lhs) (var-ref? rhs))
        (define (unify-fire net)
          (define v1 (logic-var-read net lhs))
          (define v2 (logic-var-read net rhs))
          (cond
            [(eq? v1 scope-cell-bot)
             (if (eq? v2 scope-cell-bot) net (logic-var-write net lhs v2))]
            [(eq? v2 scope-cell-bot) (logic-var-write net rhs v1)]
            [(equal? v1 v2) net]
            [else net]))
        (define input-cids (append (ref->input-cids lhs) (ref->input-cids rhs)))
        (define output-cids input-cids)
        ;; Component-paths: tell the scheduler which scope components to watch
        (define cpaths
          (append (if (scope-ref? lhs)
                      (list (cons (scope-ref-cid lhs) (scope-ref-var lhs)))
                      '())
                  (if (scope-ref? rhs)
                      (list (cons (scope-ref-cid rhs) (scope-ref-var rhs)))
                      '())))
        (define-values (net* _pid)
          (net-add-propagator net input-cids output-cids (maybe-wrap-worldview unify-fire)
                              #:component-paths cpaths))
        net*]
       ;; One variable, one ground: write ground to variable
       [(var-ref? lhs) (logic-var-write net lhs rhs)]
       [(var-ref? rhs) (logic-var-write net rhs lhs)]
       ;; Both ground: no network change
       [else net])]

    [(is)
     (define var (resolve-term env (car args)))
     (define expr (cadr args))
     (define eval-fn (current-is-eval-fn))
     (if (and (or (scope-ref? var) (cell-id? var)) eval-fn)
         (logic-var-write net var (eval-fn expr))
         net)]

    [(app)
     (define goal-name (car args))
     (define goal-args (cadr args))
     (install-clause-propagators net goal-name goal-args env store config answer-cid ctx)]

    [(not)
     ;; Track 2B D.12: NAF as worldview assumption.
     ;; NAF gets an assumption h_naf via solver-assume. The assumption means
     ;; "this NAF succeeded." S1 validates it; if inner goal is provable,
     ;; h_naf becomes a nogood (eliminated). Tagged writes under h_naf become
     ;; invisible via worldview filtering.
     ;;
     ;; At S0: allocate assumption, register for S1. The NAF goal itself does
     ;; NOT install inner goal propagators. Subsequent goals in the conjunction
     ;; are tagged with h_naf by install-conjunction (which wraps them with
     ;; the NAF bitmask after encountering a 'not goal).
     (define inner-goal-expr (car args))
     (define inner-goal (expr->goal-desc inner-goal-expr))

     (if (not ctx)
         net  ;; no solver context — NAF is a no-op (test scaffolding)
         (let ()
           ;; Allocate NAF assumption
           (define-values (net1 naf-aid)
             (solver-assume ctx net (gensym 'naf) 'naf-probe))
           (define naf-bit-pos (assumption-id-n naf-aid))

           ;; Promote outer scope cells to tagged-cell-value
           ;; (required for worldview-tagged writes by subsequent goals)
           (define outer-scope-cids
             (remove-duplicates
              (for/list ([ref (in-hash-values env)]
                         #:when (scope-ref? ref))
                (scope-ref-cid ref))))
           (define net2
             (for/fold ([n net1])
                       ([cid (in-list outer-scope-cids)])
               (promote-cell-to-tagged n cid)))

           ;; Register for S1 evaluation
           (when (current-naf-completions)
             (hash-set! (current-naf-completions) naf-aid
                        (hasheq 'inner-goal inner-goal
                                'env env
                                'store store
                                'config config
                                'naf-bit-pos naf-bit-pos)))

           ;; Return: network with assumption allocated + cells promoted.
           ;; install-conjunction handles wrapping subsequent goals with h_naf bitmask.
           ;; Store the NAF bit position in the network for install-conjunction to read.
           ;; We use a convention: return a tagged value (net . naf-bit-pos) that
           ;; install-conjunction recognizes. (Alternatively, use a parameter.)
           ;; Simplest: use current-worldview-bitmask to signal the NAF bitmask.
           ;; After this goal returns, install-conjunction ORs the NAF bit into
           ;; current-worldview-bitmask for subsequent goals.

           ;; Actually — use a separate return channel. We'll modify install-conjunction
           ;; to accumulate NAF bits. For now: store in the naf-completions registry
           ;; and have install-conjunction check it.
           net2))]

    [(guard)
     ;; Guard: evaluate condition, proceed if truthy.
     (define condition (car args))
     (define inner-goal-expr (and (pair? (cdr args)) (cadr args)))
     (define eval-fn (current-is-eval-fn))
     (define cond-val
       (if eval-fn
           (eval-fn condition)
           condition))
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
               (install-goal-propagator net inner-goal env store config answer-cid ctx))
             net)  ;; 1-arg guard: condition passed, succeed
         net)]  ;; guard failed — return unchanged network

    [(cut) net]   ;; Out of scope (P2)
    [else net]))

;; ----------------------------------------
;; install-conjunction (7b, revised D.12)
;; ----------------------------------------
;; Install all goals in a clause body.
;; NAF-aware: when a 'not goal is encountered, its h_naf assumption bit
;; is ORed into the worldview bitmask for ALL subsequent goals. This means
;; subsequent goals' writes are tagged with h_naf — if S1 eliminates h_naf
;; (NAF failed), those writes become invisible via worldview filtering.
;; Returns: new-network
(define (install-conjunction net goals env store config answer-cid [ctx #f])
  (define-values (net-final _accumulated-naf-bm)
    (for/fold ([n net]
               [naf-bm 0])  ;; accumulated NAF bitmask
              ([goal (in-list goals)])
      (cond
        [(eq? (goal-desc-kind goal) 'not)
         ;; NAF goal: install it (allocates assumption + registers for S1).
         ;; Then add its bit to the accumulated NAF bitmask.
         (define n2 (install-goal-propagator n goal env store config answer-cid ctx))
         ;; Read the NAF bit from the registry (last registered NAF)
         (define naf-bit-pos
           (if (current-naf-completions)
               (let ([entries (hash-values (current-naf-completions))])
                 (if (pair? entries)
                     (hash-ref (last entries) 'naf-bit-pos 0)
                     0))
               0))
         (define new-naf-bm (bitwise-ior naf-bm (arithmetic-shift 1 naf-bit-pos)))
         (values n2 new-naf-bm)]
        [else
         ;; Non-NAF goal: install with accumulated NAF bitmask
         ;; (subsequent goals' writes tagged with all prior NAF assumptions)
         (define outer-bm (current-worldview-bitmask))
         (define combined-bm (bitwise-ior outer-bm naf-bm))
         (define n2
           (if (zero? naf-bm)
               ;; No NAF context — install normally
               (install-goal-propagator n goal env store config answer-cid ctx)
               ;; NAF context — wrap with combined bitmask
               (parameterize ([current-worldview-bitmask combined-bm])
                 (install-goal-propagator n goal env store config answer-cid ctx))))
         (values n2 naf-bm)])))
  net-final)

;; ----------------------------------------
;; install-one-clause (helper)
;; ----------------------------------------
;; Install a single clause's bindings + body goals on a network.
;; resolved-args: (listof (cell-id | ground-value))
;; Returns: new-network
(define (install-one-clause net ci resolved-args param-names env store config answer-cid ctx)
  (define clause-goals (clause-info-goals ci))
  ;; Fresh variable scope for this clause
  (define-values (n2 clause-env) (build-var-env net param-names))
  ;; Unify resolved args with clause param refs
  (define n3
    (for/fold ([n n2])
              ([arg (in-list resolved-args)]
               [pname (in-list param-names)])
      (define pref (hash-ref clause-env pname))
      (define (var-ref? x) (or (scope-ref? x) (cell-id? x)))
      (if (var-ref? arg)
          ;; Both variable refs: bidirectional propagator (arg ↔ param)
          (let ([unify-fire
                 (lambda (net)
                   (define va (logic-var-read net arg))
                   (define vp (logic-var-read net pref))
                   (cond
                     [(eq? va scope-cell-bot)
                      (if (eq? vp scope-cell-bot) net
                          (logic-var-write net arg vp))]
                     [(eq? vp scope-cell-bot)
                      (logic-var-write net pref va)]
                     [else net]))]
                [input-cids (append (if (scope-ref? arg) (list (scope-ref-cid arg)) (list arg))
                                    (if (scope-ref? pref) (list (scope-ref-cid pref)) (list pref)))]
                [cpaths (append (if (scope-ref? arg)
                                    (list (cons (scope-ref-cid arg) (scope-ref-var arg)))
                                    '())
                                (if (scope-ref? pref)
                                    (list (cons (scope-ref-cid pref) (scope-ref-var pref)))
                                    '()))])
            (let-values ([(n* _pid)
                          (net-add-propagator n
                            (remove-duplicates input-cids) (remove-duplicates input-cids)
                            (maybe-wrap-worldview unify-fire)
                            #:component-paths cpaths)])
              n*))
          ;; Ground arg: write directly to param variable
          (logic-var-write n pref arg))))
  (install-conjunction n3 clause-goals clause-env store config answer-cid ctx))

;; ----------------------------------------
;; install-one-clause-concurrent (Phase 6+7 concurrent)
;; ----------------------------------------
;; Like install-one-clause, but ALL propagators are wrapped with
;; wrap-with-worldview so their writes are tagged with this clause's
;; bitmask. For concurrent multi-clause execution on the SAME network.
;; bit-position: integer — this clause's assumption bit position.
;; aid: assumption-id — for #:assumption tagging on propagators.
(define (install-one-clause-concurrent net ci resolved-args param-names
                                       env store config answer-cid ctx
                                       bit-position aid)
  (define clause-goals (clause-info-goals ci))
  (define bitmask (arithmetic-shift 1 bit-position))
  ;; Fresh variable scope for this clause (clause-local cells)
  (define-values (n2 clause-env) (build-var-env net param-names))
  ;; Unify resolved args with clause param refs.
  ;; Arg↔param propagators are WRAPPED with the clause's worldview bitmask.
  (define n3
    (for/fold ([n n2])
              ([arg (in-list resolved-args)]
               [pname (in-list param-names)])
      (define pref (hash-ref clause-env pname))
      (define (var-ref? x) (or (scope-ref? x) (cell-id? x)))
      (if (var-ref? arg)
          ;; Bidirectional propagator wrapped with worldview
          (let ([unify-fire
                 (wrap-with-worldview
                  (lambda (net)
                    (define va (logic-var-read net arg))
                    (define vp (logic-var-read net pref))
                    (cond
                      [(eq? va scope-cell-bot)
                       (if (eq? vp scope-cell-bot) net
                           (logic-var-write net arg vp))]
                      [(eq? vp scope-cell-bot)
                       (logic-var-write net pref va)]
                      [else net]))
                  bit-position)]
                [input-cids (remove-duplicates
                             (append (if (scope-ref? arg) (list (scope-ref-cid arg)) (list arg))
                                     (if (scope-ref? pref) (list (scope-ref-cid pref)) (list pref))))]
                [cpaths (append (if (scope-ref? arg)
                                    (list (cons (scope-ref-cid arg) (scope-ref-var arg)))
                                    '())
                                (if (scope-ref? pref)
                                    (list (cons (scope-ref-cid pref) (scope-ref-var pref)))
                                    '()))])
            (let-values ([(n* _pid)
                          (net-add-propagator n input-cids input-cids unify-fire
                                              #:assumption aid
                                              #:component-paths cpaths)])
              n*))
          ;; Ground arg: write under this clause's worldview
          (parameterize ([current-worldview-bitmask bitmask])
            (logic-var-write n pref arg)))))
  ;; Install clause body goals under this clause's worldview.
  ;; Goal propagators will also use current-worldview-bitmask when they fire.
  ;; For now: install-conjunction installs propagators directly.
  ;; Each goal's propagator fire-fn should be wrapped — but install-goal-propagator
  ;; creates the fire functions inline. The simplest approach: set
  ;; current-worldview-bitmask during installation for direct writes,
  ;; and the propagators pick up the bitmask at fire time via wrap-with-worldview.
  ;; TODO: wrap all goal propagators with worldview. For now, direct writes
  ;; during installation use the bitmask; propagator fires need wrapping.
  (parameterize ([current-worldview-bitmask bitmask])
    (install-conjunction n3 clause-goals clause-env store config answer-cid ctx)))

;; ----------------------------------------
;; install-clause-propagators (6c + 6d)
;; ----------------------------------------
;; Three paths: facts, single clause, multi-clause (PU-per-clause).
;; ctx: solver-context or #f (needed for multi-clause branching)
;; Returns: new-network
(define (install-clause-propagators net goal-name goal-args env store config answer-cid [ctx #f])
  (define rel (relation-lookup store goal-name))
  (cond
    [(not rel) net]
    [else
     (define resolved-args
       (for/list ([a (in-list goal-args)])
         (resolve-term env a)))

     ;; Phase 8.5-8.7: Tabling check.
     ;; Phase 10b: :tabling :off skips tabling entirely.
     ;; :by-default (default): all relations tabled when ctx available.
     (define tabling-enabled?
       (not (eq? (solver-config-tabling config) 'off)))
     (define table-cid
       (and ctx tabling-enabled? (solver-table-lookup ctx net goal-name)))

     (cond
       ;; Consumer path: table exists, read from it
       [table-cid
        (install-table-consumer net table-cid resolved-args env)]

       ;; Producer path: register table + install clauses normally + write to table
       [(and ctx tabling-enabled?)
        (define-values (net-reg new-table-cid) (solver-table-register ctx net goal-name))
        (define net-with-clauses
          (install-clause-propagators-inner net-reg goal-name resolved-args rel store config answer-cid ctx))
        ;; Install a producer propagator: when query vars have values,
        ;; project results to the table cell
        (install-table-producer net-with-clauses new-table-cid resolved-args env)]

       ;; No ctx: install normally (no tabling)
       [else
        (install-clause-propagators-inner net goal-name resolved-args rel store config answer-cid ctx)])]))

;; Inner clause installation (the actual variant loop, extracted for tabling).
;; Track 2B Phase 1a: uses discrimination map to narrow which facts/clauses
;; are viable based on bound (ground) arguments. This is the clause-viability
;; lattice narrowing — same lattice as Track 2 decision cells (P(N) under ⊇,
;; set-intersection merge), with bound arguments as the narrowing source.
(define (install-clause-propagators-inner net goal-name resolved-args rel store config answer-cid ctx [env (hasheq)])
     (for/fold ([n net])
               ([variant (in-list (relation-info-variants rel))])
       (define params (variant-info-params variant))
       (define facts (variant-info-facts variant))
       (define clauses (variant-info-clauses variant))
       (define param-names (map param-info-name params))

       ;; Track 2B Phase 1a: on-network discrimination via broadcast propagators.
       ;; Install discrimination propagators that narrow the viable set based
       ;; on bound arguments. Returns viability cell that gates clause/fact
       ;; installation.
       (define n-alternatives (+ (length facts) (length clauses)))
       (define-values (n-discrim viability-cid)
         (install-discrimination-propagators n variant resolved-args n-alternatives))

       ;; For ground args, discrimination propagators write to viability cell
       ;; immediately (construction-time narrowing via cell write). For free args,
       ;; fire-once propagators will narrow when args resolve during BSP.
       ;; Read the viability cell to get the current viable set.
       (define viable-indices (net-cell-read n-discrim viability-cid))

       ;; Track 2B D.11: NAF success detection moved to S1 stratum.
       ;; No NAF-success cell write at S0 — S1 reads viability directly.
       (define n-naf-signal n-discrim)

       ;; Track 2B Phase 1a Step 5: Per-fact-row PU branching.
       ;; Viable fact rows get worldview bitmask bits (same as multi-clause).
       ;; Each row writes under its own bitmask → tagged-cell-value entries
       ;; keep results separate. Coordinated with clause assumptions via
       ;; solver-assume (shared namespace, critique R3).
       (define viable-facts
         (for/list ([fr (in-list facts)]
                    [fact-idx (in-naturals)]
                    #:when (set-member? viable-indices fact-idx))
           fr))

       (define n-facts
         (cond
           ;; No viable facts: skip
           [(null? viable-facts) n-naf-signal]

           ;; Single viable fact: write directly (no PU overhead)
           [(null? (cdr viable-facts))
            (let ([row (fact-row-terms (car viable-facts))])
              (if (= (length row) (length resolved-args))
                  (for/fold ([n n-naf-signal])
                            ([arg (in-list resolved-args)]
                             [val (in-list row)])
                    (if (or (scope-ref? arg) (cell-id? arg))
                        (logic-var-write n arg val)
                        n))
                  n-naf-signal))]

           ;; Multiple viable facts: PU branching with worldview bitmasks.
           ;; Same pattern as multi-clause concurrent execution.
           [else
            (let ()
              ;; Create assumptions per viable fact row
              (define-values (n-assumed fact-aids-rev)
                (if ctx
                    (for/fold ([net n-naf-signal] [aids '()])
                              ([fr (in-list viable-facts)]
                               [i (in-naturals)])
                      (define-values (net* aid)
                        (solver-assume ctx net
                                      (string->symbol (format "fact-~a-~a" goal-name i))
                                      fr))
                      (values net* (cons aid aids)))
                    ;; No solver-context: local counter
                    (for/fold ([net n-naf-signal] [aids '()])
                              ([fr (in-list viable-facts)]
                               [i (in-naturals)])
                      (values net (cons (assumption-id i) aids)))))
              (define fact-aids (reverse fact-aids-rev))

              ;; Promote shared scope cells to tagged-cell-value
              (define promoted-cids (remove-duplicates
                (for/list ([arg (in-list resolved-args)]
                           #:when (or (scope-ref? arg) (cell-id? arg)))
                  (if (scope-ref? arg) (scope-ref-cid arg) arg))))
              (define n-promoted
                (for/fold ([net n-assumed])
                          ([cid (in-list promoted-cids)])
                  (promote-cell-to-tagged net cid)))

              ;; Write each fact row under its worldview bitmask
              (for/fold ([net n-promoted])
                        ([fr (in-list viable-facts)]
                         [aid (in-list fact-aids)])
                (define row (fact-row-terms fr))
                (define bitmask (arithmetic-shift 1 (assumption-id-n aid)))
                (if (= (length row) (length resolved-args))
                    (parameterize ([current-worldview-bitmask bitmask])
                      (for/fold ([net net])
                                ([arg (in-list resolved-args)]
                                 [val (in-list row)])
                        (if (or (scope-ref? arg) (cell-id? arg))
                            (logic-var-write net arg val)
                            net)))
                    net)))]))

       ;; Track 2B Phase 1a: filter clauses to only viable ones
       (define n-facts-count (length facts))
       (define viable-clauses
         (for/list ([ci (in-list clauses)]
                    [i (in-naturals n-facts-count)]
                    #:when (set-member? viable-indices i))
           ci))

       ;; Clauses (viable only — narrowed by discrimination map)
       (cond
         [(null? viable-clauses) n-facts]

         ;; Single viable clause: install directly, no PU (Tier 1 behavior)
         [(null? (cdr viable-clauses))
          (install-one-clause n-facts (car viable-clauses) resolved-args param-names
                              env store config answer-cid ctx)]

         ;; Multi-clause: CONCURRENT propagators on SAME network.
         ;; All M viable clauses' propagators installed on ONE network, each wrapped
         ;; with wrap-with-worldview for per-clause bitmask tagging.
         ;; ONE run-to-quiescence fires all concurrently via BSP.
         ;; Tagged-cell-value entries keep clause results separate.
         ;; Clause ordering is IRRELEVANT — dataflow determines execution.
         [else
          (let ()
            ;; Create assumptions for each viable clause (integer IDs for bitmask)
            (define-values (n-assumed aids-rev)
              (if ctx
                  (for/fold ([n n-facts] [aids '()])
                            ([ci (in-list viable-clauses)]
                             [i (in-naturals)])
                    (define-values (n* aid)
                      (solver-assume ctx n
                                    (string->symbol (format "clause-~a-~a" goal-name i))
                                    ci))
                    (values n* (cons aid aids)))
                  ;; No solver-context: use local counter for assumption IDs
                  (for/fold ([n n-facts] [aids '()])
                            ([ci (in-list viable-clauses)]
                             [i (in-naturals)])
                    (values n (cons (assumption-id i) aids)))))
            (define aids (reverse aids-rev))

            ;; Promote shared scope cells to tagged-cell-value
            (define promoted-cids (remove-duplicates
              (for/list ([arg (in-list resolved-args)]
                         #:when (or (scope-ref? arg) (cell-id? arg)))
                (if (scope-ref? arg) (scope-ref-cid arg) arg))))
            (define n-promoted
              (for/fold ([n n-assumed])
                        ([cid (in-list promoted-cids)])
                (promote-cell-to-tagged n cid)))

            ;; Install ALL clauses' propagators on the SAME network.
            ;; Each clause's body goals are installed with propagators wrapped
            ;; via current-worldview-bitmask (set per-fire by wrap-with-worldview
            ;; in install-one-clause-concurrent). Bidirectional arg↔param
            ;; propagators are ALSO wrapped so their writes are tagged.
            ;; BSP fires all clauses' propagators concurrently.
            (define n-installed
              (for/fold ([n n-promoted])
                        ([ci (in-list viable-clauses)]
                         [aid (in-list aids)])
                (define bit-pos (assumption-id-n aid))
                (install-one-clause-concurrent n ci resolved-args param-names
                                               env store config answer-cid ctx
                                               bit-pos aid)))

            ;; ONE run-to-quiescence: all clauses' propagators fire concurrently.
            ;; Results accumulate in the answer accumulator via set-union.
            ;; NOTE: run-to-quiescence happens in solve-goal-propagator (the caller).
            ;; Here we just return the network with all propagators installed.
            n-installed)])))


;; ----------------------------------------
;; Table consumer: install a propagator that reads the table cell and
;; writes matching answers to the query's arg variables.
;; table-cid: cell-id of the table cell (list of answer scope-cells)
;; resolved-args: (listof scope-ref | ground-value)
;; env: the query's variable environment
;; Returns: new-network
(define (install-table-consumer net table-cid resolved-args env)
  ;; Consumer propagator: reads table cell, filters by ground args,
  ;; writes matching values to free arg variables.
  ;; NOT fire-once: must re-fire as new answers arrive.
  (define consumer-fire
    (maybe-wrap-worldview
     (lambda (net)
       (define answers (net-cell-read net table-cid))
       (if (or (not (list? answers)) (null? answers))
           net
           ;; For each answer (a scope-cell bindings hasheq),
           ;; check if ground args match, write free args
           (for/fold ([n net])
                     ([answer (in-list answers)])
             (if (not (hash? answer))
                 n
                 ;; Check ground args match
                 (let ([matches?
                        (for/and ([arg (in-list resolved-args)]
                                  [i (in-naturals)])
                          (if (or (scope-ref? arg) (cell-id? arg))
                              #t  ;; free arg — always matches
                              (equal? arg (hash-ref answer i #f))))])
                   (if matches?
                       ;; Write free arg values from answer
                       (for/fold ([n n])
                                 ([arg (in-list resolved-args)]
                                  [i (in-naturals)])
                         (if (and (or (scope-ref? arg) (cell-id? arg))
                                  (hash-has-key? answer i))
                             (logic-var-write n arg (hash-ref answer i))
                             n))
                       n))))))))
  (define-values (net* _pid)
    (net-add-propagator net (list table-cid) '() consumer-fire))
  net*)

;; Table producer: after clause propagators are installed, add a propagator
;; that projects resolved-args to the table cell when they have values.
;; Returns: new-network
(define (install-table-producer net table-cid resolved-args env)
  ;; Producer propagator: reads query arg values, writes binding tuple to table cell.
  ;; Fires when any arg changes. Projects current bindings.
  (define input-cids
    (remove-duplicates
     (for/list ([arg (in-list resolved-args)]
                #:when (or (scope-ref? arg) (cell-id? arg)))
       (if (scope-ref? arg) (scope-ref-cid arg) arg))))
  (define producer-fire
    (maybe-wrap-worldview
     (lambda (net)
       ;; Read all args, build binding tuple
       (define bindings
         (for/hasheq ([arg (in-list resolved-args)]
                       [i (in-naturals)])
           (define val (if (or (scope-ref? arg) (cell-id? arg))
                           (logic-var-read net arg)
                           arg))
           (values i val)))
       ;; Only write if at least one variable is bound (non-bot)
       (define has-binding?
         (for/or ([(_k v) (in-hash bindings)])
           (and (not (eq? v scope-cell-bot)) (not (eq? v 'logic-var-bot)))))
       (if has-binding?
           (net-cell-write net table-cid (list bindings))
           net))))
  (if (null? input-cids)
      net  ;; no input cells — nothing to watch
      (let-values ([(net* _pid)
                    (net-add-propagator net input-cids (list table-cid) producer-fire)])
        net*)))

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

  ;; Phase 10c: Create network with fuel from :timeout config.
  ;; :timeout is milliseconds; approximate as fuel (1ms ≈ 1000 firings).
  ;; #f = no timeout → default fuel (1000000).
  (define timeout-ms (solver-config-timeout config))
  (define fuel (if timeout-ms (* timeout-ms 1000) 1000000))
  (define net0 (make-prop-network fuel))
  (define-values (net-ctx ctx) (make-solver-context net0))
  (define-values (net1 query-env) (build-var-env net-ctx query-vars))

  ;; Answer accumulator cell
  (define (answer-merge old new)
    (cond [(null? old) new] [(null? new) old] [else (append old new)]))
  (define-values (net2 answer-cid) (net-new-cell net1 '() answer-merge))

  ;; Track 2B Phase 2a: NAF completion registry (scaffolding)
  (define naf-completions (make-hasheq))

  ;; Install the top-level goal (pass ctx for PU branching)
  (define top-goal (goal-desc 'app (list goal-name effective-args)))
  (define net3
    (parameterize ([current-naf-completions naf-completions])
      (install-goal-propagator net2 top-goal query-env store config answer-cid ctx)))

  ;; Run to quiescence (inner + outer propagators converge)
  (define net4 (run-to-quiescence net3))

  ;; D.12: S1 NAF evaluation at S0 fixpoint.
  ;; For each registered NAF, check inner goal provability using discrimination.
  ;; If provable: h_naf is a nogood → solver-add-nogood eliminates it.
  ;; Worldview narrowing makes tagged writes under h_naf invisible.
  ;; Phase 2b moves this to a BSP stratum in run-to-quiescence-bsp.
  (define net5
    (if (hash-empty? naf-completions)
        net4  ;; no NAFs → skip
        (let ()
          ;; S1: evaluate each pending NAF by checking inner goal provability
          (define net-with-nogoods
            (for/fold ([n net4])
                      ([(naf-aid info) (in-hash naf-completions)])
              (define inner-goal (hash-ref info 'inner-goal))
              (define naf-env (hash-ref info 'env))
              (define naf-store (hash-ref info 'store))
              (define naf-config (hash-ref info 'config))
              (define naf-bit-pos (hash-ref info 'naf-bit-pos))
              ;; S1 provability check at S0 fixpoint
              (define inner-provable?
                (cond
                  [(eq? (goal-desc-kind inner-goal) 'app)
                   (define goal-name (car (goal-desc-args inner-goal)))
                   (define goal-args (cadr (goal-desc-args inner-goal)))
                   (define rel (relation-lookup naf-store goal-name))
                   (if (not rel) #f
                       (for/or ([variant (in-list (relation-info-variants rel))])
                         (define discrim-data (build-discrimination-data variant))
                         (define n-facts (length (variant-info-facts variant)))
                         (define n-clauses (length (variant-info-clauses variant)))
                         (define n-alts (+ n-facts n-clauses))
                         (define resolved
                           (for/list ([a (in-list goal-args)])
                             (define r (resolve-term naf-env a))
                             (if (scope-ref? r)
                                 (let ([v (logic-var-read n r)])
                                   (if (eq? v scope-cell-bot) r v))
                                 r)))
                         (define viable
                           (for/fold ([v (for/seteq ([i (in-range n-alts)]) i)])
                                     ([arg (in-list resolved)]
                                      [pos (in-naturals)])
                             (define pos-data (hash-ref discrim-data pos discrimination-data-bot))
                             (cond
                               [(hash-empty? pos-data) v]
                               [(or (scope-ref? arg) (cell-id? arg)) v]
                               [else
                                (define compatible
                                  (for/seteq ([pair (in-list (hash->list pos-data))]
                                              #:when (equal? (cdr pair) arg))
                                    (car pair)))
                                (define wildcards
                                  (for/seteq ([i (in-range n-alts)]
                                              #:when (not (hash-has-key? pos-data i)))
                                    i))
                                (set-intersect v (set-union compatible wildcards))])))
                         (not (set-empty? viable))))]
                  [(eq? (goal-desc-kind inner-goal) 'unify)
                   (define lhs (resolve-term naf-env (car (goal-desc-args inner-goal))))
                   (define rhs (resolve-term naf-env (cadr (goal-desc-args inner-goal))))
                   (define lv (if (scope-ref? lhs) (logic-var-read n lhs) lhs))
                   (define rv (if (scope-ref? rhs) (logic-var-read n rhs) rhs))
                   (or (eq? lv scope-cell-bot) (eq? rv scope-cell-bot) (equal? lv rv))]
                  [else #t]))
              ;; If inner is provable: h_naf is invalid → write nogood
              (if inner-provable?
                  (solver-add-nogood ctx n (hasheq naf-aid #t))
                  n)))  ;; inner not provable → h_naf remains valid
          ;; Run S0 again — nogoods may trigger worldview narrowing + new propagation
          (run-to-quiescence net-with-nogoods))))

  ;; D.12: no NAF-result filtering needed — worldview narrowing handles it.
  ;; Eliminated NAF assumptions make tagged writes invisible via tagged-cell-read.
  (define naf-failed-bitmasks (seteq))  ;; unused — kept for result reading compat

  ;; Read results from scope cells.
  ;; Phase 8.2: query-env maps var-name → scope-ref.
  ;; All query vars are in ONE scope cell. Read the scope cell and
  ;; extract each variable's binding.
  (define first-qv-ref (and (pair? query-vars) (hash-ref query-env (car query-vars) #f)))
  (define scope-cid (and (scope-ref? first-qv-ref) (scope-ref-cid first-qv-ref)))
  (define scope-raw (and scope-cid (net-cell-read-raw net5 scope-cid)))

  (cond
    ;; Multi-clause concurrent: scope cell is tagged-cell-value.
    ;; Read each clause's result via its bitmask.
    [(and scope-raw (tagged-cell-value? scope-raw)
          (pair? (tagged-cell-value-entries scope-raw)))
     (define bitmasks
       (remove-duplicates
        (for/list ([entry (in-list (tagged-cell-value-entries scope-raw))])
          (car entry))))
     ;; Domain-merge for same-bitmask entry merging.
     ;; Multiple writes at same bitmask (e.g., c1 and c2 written separately)
     ;; must be merged via scope-cell-merge to produce a complete binding.
     ;; We use make-tagged-merge(scope-cell-merge) because tagged-cell-read's
     ;; domain-merge receives the tagged merge wrapper (same as net-cell-read uses).
     (define domain-merge (make-tagged-merge scope-cell-merge))
     ;; Phase 2a: filter out NAF-failed bitmasks + clauses with all-unresolved vars
     (define raw-results
       (for/list ([bm (in-list bitmasks)]
                  #:unless (set-member? naf-failed-bitmasks bm))  ;; NAF filter
         (for/hasheq ([qv (in-list query-vars)])
           (define ref (hash-ref query-env qv))
           (define sc-val
             (if (tagged-cell-value? scope-raw)
                 (tagged-cell-read scope-raw bm domain-merge)
                 scope-raw))
           (define val (if (scope-cell? sc-val)
                           (scope-cell-ref sc-val qv)
                           scope-cell-bot))
           (values qv (if (eq? val scope-cell-bot) qv val)))))
     ;; Filter: skip results where ALL query vars are unresolved
     (filter (lambda (result-subst)
               (not (for/and ([qv (in-list query-vars)])
                      (eq? (hash-ref result-subst qv) qv))))
             raw-results)]

    ;; Single-clause/facts: read scope cell directly
    [else
     ;; Phase 2a: check if NAF failed for the single-clause path (outer-bm = 0)
     (if (set-member? naf-failed-bitmasks 0)
         '()  ;; NAF failed in single-clause context → no results
         (let ()
           (define sc-val
             (if scope-cid (net-cell-read net5 scope-cid) #f))
           (define result-subst
             (for/hasheq ([qv (in-list query-vars)])
               (define val (if (scope-cell? sc-val)
                               (scope-cell-ref sc-val qv)
                               scope-cell-bot))
               (values qv (if (eq? val scope-cell-bot) qv val))))
           (if (for/and ([qv (in-list query-vars)])
                 (eq? (hash-ref result-subst qv) qv))
               '()
               (list result-subst))))]))
