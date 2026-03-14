#lang racket/base

;;;
;;; wf-engine.rkt — Well-Founded Engine Orchestration
;;;
;;; Solver-level entry point that orchestrates the existing DFS solver
;;; with bilattice cell pairs to compute well-founded semantics.
;;; Parallel to stratified-eval.rkt for the well-founded path.
;;;
;;; Architecture: Hybrid DFS + Bilattice
;;;   - DFS solver (relations.rkt) does proof search (unification, backtracking)
;;;   - Bilattice cells track three-valued status of predicates
;;;   - NAF oracle bridges the two: consults bilattice instead of stratification
;;;   - Iterative fixpoint loop until bilattice stabilizes
;;;
;;; Phase 4a: predicate-level granularity (one bilattice-var per predicate name)
;;;
;;; Design reference: docs/tracking/2026-03-14_WFLE_IMPLEMENTATION.md Phase 4
;;;

(require racket/list
         "propagator.rkt"
         "bilattice.rkt"
         "solver.rkt"
         "relations.rkt"
         "stratify.rkt"
         "syntax.rkt")

(provide
 ;; Core engine
 wf-solve-goal
 wf-explain-goal
 ;; Answer types
 (struct-out wf-answer)
 (struct-out wf-explained-answer)
 (struct-out wf-undeterminacy-explanation)
 ;; Answer conversion
 wf-answers->standard
 ;; Internals (exported for testing)
 make-wf-naf-oracle
 transitive-pred-closure
 preds-with-negation
 bilattice-stable?)

;; ========================================
;; Answer Types
;; ========================================

;; A well-founded answer: variable bindings with certainty.
;; bindings: hasheq : symbol → value
;; certainty: 'definite | 'unknown
(struct wf-answer (bindings certainty) #:transparent)

;; Explanation structs
(struct wf-explained-answer (bindings certainty explanation) #:transparent)
(struct wf-undeterminacy-explanation (atom cycle-predicates) #:transparent)

;; ========================================
;; Dependency Analysis
;; ========================================

;; Compute the transitive closure of predicates reachable from a goal.
;; Walks positive and negative dependencies from the relation store.
;; Returns: (listof symbol)
(define (transitive-pred-closure store start-pred)
  (let loop ([worklist (list start-pred)]
             [visited '()])
    (cond
      [(null? worklist) visited]
      [else
       (define pred (car worklist))
       (define rest (cdr worklist))
       (cond
         [(member pred visited) (loop rest visited)]
         [else
          (define ri (hash-ref store pred #f))
          (define new-deps
            (if ri
                (let ([di (wf-relation-info->dep-info ri)])
                  (append (dep-info-pos-deps di) (dep-info-neg-deps di)))
                '()))
          (loop (append rest new-deps) (cons pred visited))])])))

;; Identify which predicates participate in negation (appear as targets of `not`).
;; Returns: (listof symbol) — subset of all-preds that are negated somewhere
(define (preds-with-negation store all-preds)
  (define neg-targets
    (for*/list ([pred (in-list all-preds)]
                [ri (in-value (hash-ref store pred #f))]
                #:when ri
                [v (in-list (relation-info-variants ri))]
                [c (in-list (variant-info-clauses v))]
                [g (in-list (clause-info-goals c))]
                #:when (eq? (goal-desc-kind g) 'not)
                [inner (in-value (car (goal-desc-args g)))]
                #:when (expr-goal-app? inner))
      (expr-goal-app-name inner)))
  ;; Include all predicates that are negation targets OR that negate others,
  ;; since both need bilattice tracking for the iterative fixpoint.
  (define negating-preds
    (for*/list ([pred (in-list all-preds)]
                [ri (in-value (hash-ref store pred #f))]
                #:when ri
                [v (in-list (relation-info-variants ri))]
                [c (in-list (variant-info-clauses v))]
                [g (in-list (clause-info-goals c))]
                #:when (eq? (goal-desc-kind g) 'not))
      pred))
  (remove-duplicates (append neg-targets negating-preds)))

;; ========================================
;; NAF Oracle
;; ========================================

;; Tracks whether any NAF call returned 'defer during a probe.
;; When #t after a probe, "no proofs found" is inconclusive.
(define current-naf-deferred? (make-parameter #f))

;; Create a NAF oracle that consults the bilattice.
;; Returns a function: (symbol → 'succeed | 'fail | 'defer)
;; Side effect: sets current-naf-deferred? to #t when returning 'defer
(define (make-wf-naf-oracle net pred-bvar-map)
  (lambda (pred-name)
    (define bvar (hash-ref pred-bvar-map pred-name #f))
    (cond
      [(not bvar) 'succeed]  ;; no bilattice entry → closed-world: not provable
      [else
       (define result (bilattice-read-bool net bvar))
       (case result
         [(false) 'succeed]      ;; definitely false → NAF succeeds
         [(true) 'fail]          ;; definitely true → NAF fails
         [(unknown)
          (current-naf-deferred? #t)
          'defer]
         [(contradiction) 'fail])])))

;; ========================================
;; Bilattice Update
;; ========================================

;; Update bilattice from DFS solver results.
;; For each predicate that produced answers, set lower := #t.
;; For each predicate that produced NO answers, set upper := #f.
;; Returns: updated network
(define (update-bilattice-from-results net pred-bvar-map store answers all-preds)
  ;; Collect predicates that were proven (appeared in any answer's goals)
  ;; For predicate-level granularity: if the DFS solver found any proof
  ;; for a predicate, that predicate's lower is #t.
  ;;
  ;; We probe each predicate individually by running solve-goal on it.
  ;; This is the predicate-level approach: for each negation-participating
  ;; predicate, check if it has any proofs under the current NAF oracle.
  net)

;; Probe a single predicate to determine its proof status under current oracle.
;; Returns: (values updated-network probed?) where probed? indicates if DFS was run
(define (probe-single-predicate config store n pred-name bvar)
  (define ri (hash-ref store pred-name #f))
  (cond
    [(not ri)
     ;; predicate not defined → definitely false
     (bilattice-upper-write n bvar #f)]
    [else
     ;; Check if predicate has any facts (fast path)
     (define has-facts?
       (for/or ([v (in-list (relation-info-variants ri))])
         (not (null? (variant-info-facts v)))))
     (define has-clauses?
       (for/or ([v (in-list (relation-info-variants ri))])
         (not (null? (variant-info-clauses v)))))
     (cond
       [has-facts?
        ;; Facts exist → definitely true
        (bilattice-lower-write n bvar #t)]
       [(not has-clauses?)
        ;; No facts and no clauses → definitely false
        (bilattice-upper-write n bvar #f)]
       [else
        ;; Has clauses — try to prove via DFS solver with current oracle
        (define params (variant-info-params (car (relation-info-variants ri))))
        (define query-vars
          (for/list ([p (in-list params)] [i (in-naturals)])
            (string->symbol (format "_wf_~a_~a" pred-name i))))
        (define goal-args
          (for/list ([qv (in-list query-vars)])
            (expr-logic-var qv 'free)))
        ;; Track whether any NAF deferred during this probe
        (current-naf-deferred? #f)
        (define actual-results
          (with-handlers ([exn:fail? (lambda (e) '())])
            (solve-goal config store pred-name goal-args query-vars)))
        (define deferred? (current-naf-deferred?))
        (cond
          [(not (null? actual-results))
           ;; Proofs found → lower := #t
           (bilattice-lower-write n bvar #t)]
          [(not deferred?)
           ;; No proofs AND no NAF deferred → conclusively false
           (bilattice-upper-write n bvar #f)]
          [else
           ;; No proofs BUT some NAF deferred → inconclusive
           n])])]))

;; Probe each predicate to determine its proof status under current oracle.
;; Returns: updated network with bilattice cells reflecting proof status.
(define (probe-predicates config store net pred-bvar-map)
  (for/fold ([n net])
            ([(pred-name bvar) (in-hash pred-bvar-map)])
    (probe-single-predicate config store n pred-name bvar)))

;; ========================================
;; Bilattice Stability Check
;; ========================================

;; Check if the bilattice is stable (no changes between two networks).
(define (bilattice-stable? net1 net2 pred-bvar-map)
  (for/and ([(pred-name bvar) (in-hash pred-bvar-map)])
    (and (equal? (bilattice-read-bool net1 bvar)
                 (bilattice-read-bool net2 bvar)))))

;; ========================================
;; Iterative Fixpoint
;; ========================================

;; Iterate DFS solving + bilattice update until stable.
(define (wf-iterate config store net pred-bvar-map
                     goal-name goal-args query-vars)
  (define max-iterations (max 10 (* 2 (hash-count pred-bvar-map))))
  (let loop ([net net] [iteration 0] [last-answers '()])
    (cond
      [(>= iteration max-iterations)
       ;; iteration limit — return last results (sound but conservative)
       (values net last-answers)]
      [else
       ;; Phase A: Create NAF oracle from current bilattice state
       (define naf-oracle (make-wf-naf-oracle net pred-bvar-map))
       ;; Phase B: Probe all negation-participating predicates
       (define net2
         (parameterize ([current-naf-oracle naf-oracle])
           (probe-predicates config store net pred-bvar-map)))
       ;; Phase C: Run the actual query with the oracle
       (define answers
         (parameterize ([current-naf-oracle naf-oracle])
           (with-handlers ([exn:fail? (lambda (e) '())])
             (solve-goal config store goal-name goal-args query-vars))))
       ;; Phase D: Check for fixpoint
       (if (bilattice-stable? net net2 pred-bvar-map)
           (values net2 answers)
           (loop net2 (add1 iteration) answers))])))

;; ========================================
;; Top-Level Entry Point
;; ========================================

;; Solve a relational goal using the well-founded engine.
;; Returns: (listof wf-answer)
(define (wf-solve-goal config store goal-name goal-args query-vars)
  ;; Step 1: Identify all predicates reachable from the goal
  (define all-preds (transitive-pred-closure store goal-name))
  ;; Step 2: Identify which predicates participate in negation
  (define neg-preds (preds-with-negation store all-preds))
  (cond
    ;; Fast path: no negation → delegate to standard solver
    [(null? neg-preds)
     (define answers
       (with-handlers ([exn:fail? (lambda (e) '())])
         (solve-goal config store goal-name goal-args query-vars)))
     (for/list ([a (in-list answers)])
       (wf-answer a 'definite))]
    [else
     ;; Step 3: Create bilattice-vars for negation-participating predicates
     (define-values (net pred-bvar-map)
       (for/fold ([net (make-prop-network)] [m (hasheq)])
                 ([pred (in-list neg-preds)])
         (let-values ([(net2 bvar) (bilattice-new-var net bool-lattice)])
           (values net2 (hash-set m pred bvar)))))
     ;; Step 4: Iterative fixpoint
     (define-values (final-net final-answers)
       (wf-iterate config store net pred-bvar-map
                    goal-name goal-args query-vars))
     ;; Step 5: Annotate answers with certainty
     (annotate-answers final-net pred-bvar-map final-answers goal-name)]))

;; Annotate DFS answers with certainty based on bilattice state.
(define (annotate-answers net pred-bvar-map answers goal-name)
  (define bvar (hash-ref pred-bvar-map goal-name #f))
  (define certainty
    (cond
      [(not bvar) 'definite]  ;; not in bilattice → definite
      [else
       (define status (bilattice-read-bool net bvar))
       (case status
         [(true) 'definite]
         [(false) 'definite]   ;; definitely false = definite (just empty)
         [(unknown) 'unknown]
         [(contradiction) 'unknown])]))
  (for/list ([a (in-list answers)])
    (wf-answer a certainty)))

;; ========================================
;; Answer Conversion
;; ========================================

;; Convert wf-answer list to standard answer list.
;; mode: 'strict — only 'definite answers
;;       'all — include certainty tag
(define (wf-answers->standard answers mode)
  (case mode
    [(strict)
     (for/list ([a (in-list answers)]
                #:when (eq? (wf-answer-certainty a) 'definite))
       (wf-answer-bindings a))]
    [(all)
     (for/list ([a (in-list answers)])
       (hash-set (wf-answer-bindings a)
                 '__certainty (wf-answer-certainty a)))]
    [else
     (error 'wf-answers->standard "Unknown mode: ~a" mode)]))

;; ========================================
;; Explanation
;; ========================================

;; Explain a well-founded result.
(define (wf-explain-goal config store goal-name goal-args query-vars prov-level)
  (define all-preds (transitive-pred-closure store goal-name))
  (define neg-preds (preds-with-negation store all-preds))
  (cond
    [(null? neg-preds)
     ;; No negation → delegate to standard explain
     (define answers (solve-goal config store goal-name goal-args query-vars))
     (for/list ([a (in-list answers)])
       (wf-explained-answer a 'definite
         (explain-goal config store goal-name goal-args query-vars prov-level)))]
    [else
     (define-values (net pred-bvar-map)
       (for/fold ([net (make-prop-network)] [m (hasheq)])
                 ([pred (in-list neg-preds)])
         (let-values ([(net2 bvar) (bilattice-new-var net bool-lattice)])
           (values net2 (hash-set m pred bvar)))))
     (define-values (final-net final-answers)
       (wf-iterate config store net pred-bvar-map
                    goal-name goal-args query-vars))
     (define annotated (annotate-answers final-net pred-bvar-map final-answers goal-name))
     (for/list ([answer (in-list annotated)])
       (define certainty (wf-answer-certainty answer))
       (case certainty
         [(definite)
          (wf-explained-answer
           (wf-answer-bindings answer) 'definite
           (with-handlers ([exn:fail? (lambda (e) '())])
             (explain-goal config store goal-name goal-args query-vars prov-level)))]
         [(unknown)
          (define cycle (find-negation-cycle store goal-name))
          (wf-explained-answer
           (wf-answer-bindings answer) 'unknown
           (wf-undeterminacy-explanation goal-name cycle))]))]))

;; Extract dep-info from a relation-info (inlined to avoid circular dep with stratified-eval).
(define (wf-relation-info->dep-info ri)
  (define pos '())
  (define neg '())
  (for* ([v (in-list (relation-info-variants ri))]
         [c (in-list (variant-info-clauses v))]
         [g (in-list (clause-info-goals c))])
    (case (goal-desc-kind g)
      [(app) (set! pos (cons (car (goal-desc-args g)) pos))]
      [(not)
       (define inner (car (goal-desc-args g)))
       (when (expr-goal-app? inner)
         (set! neg (cons (expr-goal-app-name inner) neg)))]
      [else (void)]))
  (dep-info (relation-info-name ri)
            (remove-duplicates pos)
            (remove-duplicates neg)))

;; Find the negation cycle containing a predicate.
(define (find-negation-cycle store pred-name)
  (define dep-infos
    (for/list ([(name ri) (in-hash store)])
      (wf-relation-info->dep-info ri)))
  (define graph (build-dependency-graph dep-infos))
  (define sccs (tarjan-scc graph))
  ;; Find the SCC containing pred-name that has a negative internal edge
  (for/or ([scc (in-list sccs)])
    (and (member pred-name scc)
         (scc-has-negative-edge? graph scc)
         scc)))

;; Check if an SCC contains a negative internal edge.
(define (scc-has-negative-edge? graph scc)
  (define scc-set scc)
  (for/or ([node (in-list scc)])
    (define di (hash-ref graph node #f))
    (and di
         (for/or ([neg-dep (in-list (dep-info-neg-deps di))])
           (member neg-dep scc-set)))))
