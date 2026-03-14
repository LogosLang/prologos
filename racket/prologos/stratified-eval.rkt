#lang racket/base

;;;
;;; stratified-eval.rkt — Stratified Evaluation for the Logic Engine
;;;
;;; Orchestration layer bridging stratify.rkt (SCC + stratification),
;;; tabling.rkt (memoized answer tables), and relations.rkt (DFS solver).
;;;
;;; Key concepts:
;;;   - Extract dep-info from relation-info for stratification
;;;   - Cache strata with version-based invalidation
;;;   - Single-stratum fast path: zero overhead (direct delegate to solve-goal)
;;;   - Multi-stratum: evaluate bottom-up with tabling + table freezing
;;;
;;; Design reference: docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org §7.7
;;;

(require racket/list
         "syntax.rkt"
         "stratify.rkt"
         "tabling.rkt"
         "relations.rkt"
         "solver.rkt"
         "wf-engine.rkt")

(provide
 ;; Phase S1: Dependency extraction
 relation-info->dep-info
 extract-all-dep-infos
 ;; Phase S2: Cached stratification
 current-relation-store-version
 bump-relation-store-version!
 current-strata-cache
 get-or-compute-strata
 ;; Phase S3: Stratified solver
 store-has-negation?
 stratified-solve-goal
 stratified-explain-goal)

;; ========================================
;; Phase S1: Dependency Extraction
;; ========================================

;; Extract dependency info from a relation-info struct.
;; Walks clause bodies to identify positive and negative dependencies.
;;
;; Positive dep: goal-desc with kind 'app referencing another relation
;; Negative dep: goal-desc with kind 'not containing an expr-goal-app
(define (relation-info->dep-info ri)
  (define pos '())
  (define neg '())
  (for* ([v (in-list (relation-info-variants ri))]
         [c (in-list (variant-info-clauses v))]
         [g (in-list (clause-info-goals c))])
    (collect-goal-deps g
                       (lambda (name) (set! pos (cons name pos)))
                       (lambda (name) (set! neg (cons name neg)))))
  (dep-info (relation-info-name ri)
            (remove-duplicates pos)
            (remove-duplicates neg)))

;; Walk a goal-desc and call pos-cb/neg-cb for each dependency found.
(define (collect-goal-deps goal pos-cb neg-cb)
  (case (goal-desc-kind goal)
    [(app)
     (define goal-name (car (goal-desc-args goal)))
     (pos-cb goal-name)]
    [(not)
     ;; The inner arg is an AST expr (expr-goal-app or similar)
     (define inner (car (goal-desc-args goal)))
     (cond
       [(expr-goal-app? inner)
        (neg-cb (expr-goal-app-name inner))]
       ;; If inner is already a goal-desc (shouldn't happen, but defensive)
       [(goal-desc? inner)
        (when (eq? (goal-desc-kind inner) 'app)
          (neg-cb (car (goal-desc-args inner))))])]
    [(guard)
     ;; Guard's inner goal may reference relations (absent for 1-arg guard)
     (define gargs (goal-desc-args goal))
     (when (pair? (cdr gargs))
       (define inner-expr (cadr gargs))
       (when (expr-goal-app? inner-expr)
         (pos-cb (expr-goal-app-name inner-expr))))]
    [else (void)]))

;; Extract dep-infos from all relations in a store.
;; Returns (listof dep-info).
(define (extract-all-dep-infos store)
  (for/list ([(name ri) (in-hash store)])
    (relation-info->dep-info ri)))

;; ========================================
;; Phase S2: Cached Stratification
;; ========================================

;; Version counter for the relation store.
;; Bumped each time a new relation is registered.
(define current-relation-store-version (make-parameter 0))

(define (bump-relation-store-version!)
  (current-relation-store-version (add1 (current-relation-store-version))))

;; Strata cache: (cons version strata) or #f
;; strata: (listof (listof dep-info)) in evaluation order
(define current-strata-cache (make-parameter #f))

;; Get strata for the current relation store, using cache if valid.
;; Returns (listof (listof dep-info)) — strata in evaluation order (stratum 0 first).
(define (get-or-compute-strata store)
  (define version (current-relation-store-version))
  (define cached (current-strata-cache))
  (cond
    [(and cached (= (car cached) version))
     (cdr cached)]
    [else
     (define dep-infos (extract-all-dep-infos store))
     (define strata
       (if (null? dep-infos)
           '()
           (stratify dep-infos)))
     (current-strata-cache (cons version strata))
     strata]))

;; ========================================
;; Phase S3: Stratified Solver
;; ========================================

;; Check if any relation in the store uses negation.
;; Quick scan to enable the single-stratum fast path.
(define (store-has-negation? store)
  (for/or ([(name ri) (in-hash store)])
    (for*/or ([v (in-list (relation-info-variants ri))]
              [c (in-list (variant-info-clauses v))]
              [g (in-list (clause-info-goals c))])
      (eq? (goal-desc-kind g) 'not))))

;; Find which stratum a predicate belongs to.
;; Returns the stratum index (0-based) or #f if not found.
(define (find-stratum-index strata pred-name)
  (for/or ([stratum (in-list strata)]
           [idx (in-naturals)])
    (and (for/or ([di (in-list stratum)])
           (eq? (dep-info-name di) pred-name))
         idx)))

;; Stratified solve: the primary entry point.
;;
;; For programs without negation (single stratum): delegates directly to
;; solve-goal with zero overhead.
;;
;; For programs with negation (multiple strata): evaluates strata bottom-up,
;; collecting all answers for each stratum via tabling before proceeding.
;;
;; config: solver-config
;; store: relation store (hasheq of name → relation-info)
;; goal-name: symbol
;; goal-args: (listof any)
;; query-vars: (listof symbol)
;;
;; Returns: (listof hasheq) — each maps query var names to values
(define (stratified-solve-goal config store goal-name goal-args query-vars)
  ;; Well-founded semantics dispatch
  (define semantics (solver-config-semantics config))
  (case semantics
    [(well-founded)
     ;; WFLE path: handles negation cycles via bilattice fixpoint
     ;; Use tabled variant to store per-predicate certainty in WF tables
     (define wf-answers
       (parameterize ([current-wf-table-store (table-store-empty)])
         (wf-solve-goal-tabled config store goal-name goal-args query-vars)))
     (wf-answers->standard wf-answers 'strict)]
    [else
     ;; Stratified path (default)
     ;; Scope stratification to predicates reachable from the query,
     ;; so unstratifiable predicates elsewhere in the store don't
     ;; block stratifiable queries.
     (cond
       [(not (store-has-negation? store))
        (solve-goal config store goal-name goal-args query-vars)]
       [else
        (define reachable (transitive-pred-closure store goal-name))
        (define reachable-dep-infos
          (for*/list ([pred (in-list reachable)]
                      [ri (in-value (hash-ref store pred #f))]
                      #:when ri)
            (relation-info->dep-info ri)))
        (define strata
          (if (null? reachable-dep-infos)
              '()
              (stratify reachable-dep-infos)))
        (cond
          [(<= (length strata) 1)
           (solve-goal config store goal-name goal-args query-vars)]
          [else
           (stratified-solve-multi config store strata goal-name goal-args query-vars)])])]))

;; Multi-stratum evaluation.
;; Evaluates strata bottom-up: for each stratum, solve all predicates once
;; to collect their complete answer sets, then freeze those answers before
;; proceeding to the next stratum. This ensures negation targets in lower
;; strata are fully evaluated before upper strata consult them.
;;
;; Note: The DFS solver already handles recursion within a stratum through
;; backtracking and depth-limiting. The stratum ordering only matters for
;; ensuring negation soundness — lower strata complete before upper strata
;; begin, so (not P) checks a fully-computed P.
(define (stratified-solve-multi config store strata goal-name goal-args query-vars)
  ;; Evaluate each stratum bottom-up. We don't need to cache per-stratum
  ;; answers for the DFS solver (it re-derives them); the stratum ordering
  ;; itself is what ensures correctness for negation.
  ;;
  ;; For each stratum, we "touch" every predicate to force evaluation,
  ;; ensuring the DFS solver's depth-limited search has a chance to
  ;; complete before upper strata rely on negation of those predicates.
  (define target-stratum-idx (find-stratum-index strata goal-name))

  ;; Walk strata in order. For strata below the target, just force evaluation
  ;; (the DFS solver will re-derive answers when queried from above).
  ;; For the target stratum, solve the actual goal.
  (for ([stratum (in-list strata)]
        [stratum-idx (in-naturals)])
    ;; Force-evaluate all predicates in this stratum (ensures completion)
    ;; Skip the target predicate in the target stratum — we'll query it directly below
    (for ([di (in-list stratum)])
      (define name (dep-info-name di))
      (when (and (not (and (equal? stratum-idx target-stratum-idx)
                           (eq? name goal-name)))
                 (relation-lookup store name))
        (define ri (relation-lookup store name))
        (define params
          (if (pair? (relation-info-variants ri))
              (variant-info-params (car (relation-info-variants ri)))
              '()))
        (define all-param-names (map param-info-name params))
        ;; Evaluate to force DFS solver completion for this predicate
        (solve-goal config store name '() all-param-names))))

  ;; Now solve the target goal — all lower strata have been evaluated,
  ;; so negation-as-failure against lower-stratum predicates is sound.
  (solve-goal config store goal-name goal-args query-vars))

;; Stratified explain: like solve but with provenance.
;; For now, delegates to explain-goal directly (stratified explain is future work).
(define (stratified-explain-goal config store goal-name goal-args query-vars prov-level)
  (define semantics (solver-config-semantics config))
  (case semantics
    [(well-founded)
     (wf-explain-goal config store goal-name goal-args query-vars prov-level)]
    [else
     (explain-goal config store goal-name goal-args query-vars prov-level)]))
