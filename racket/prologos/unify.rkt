#lang racket/base

;;;
;;; PROLOGOS UNIFICATION
;;; Pattern unification for dependent types with metavariable solving.
;;;
;;; unify(ctx, t1, t2) → #t | 'postponed | #f
;;;   Attempt to make t1 and t2 definitionally equal, solving metavariables
;;;   as side effects. Returns:
;;;     #t         — unified successfully (possibly solving metas)
;;;     'postponed — can't solve now, registered constraint for later retry
;;;     #f         — definitely incompatible (e.g., Nat vs Bool)
;;;
;;; occurs?(id, expr) → bool
;;;   Occur check: does metavariable `id` appear in `expr`?
;;;   Follows solved metas to detect cycles through indirection.
;;;
;;; Sprint 2a: Core structural unification (bare metas, decomposition)
;;; Sprint 2b: Miller's pattern condition, applied metas, binder handling
;;; Sprint 3:  Fresh fvar binder opening (Lean/Agda/Elab-Zoo technique)
;;; Sprint 5:  Constraint postponement — pattern-check failure → 'postponed
;;;

(require racket/match
         racket/list
         "syntax.rkt"
         "prelude.rkt"
         "reduction.rkt"
         "metavar-store.rkt"
         "substitution.rkt"
         "zonk.rkt"
         "source-location.rkt"
         "performance-counters.rkt")

(provide unify unify-ok? occurs?
         ;; Backward-compat alias (unify* = unify after P1-G7)
         unify* unify*-ok?
         ;; Internal core (for tests that need raw unification without propagator checks)
         unify-core
         ;; P-U1a/1b: Pure unification classifiers (no side effects)
         classify-whnf-problem
         classify-level-problem
         classify-mult-problem
         dispatch-unify-whnf
         ;; Sprint 2b exports
         decompose-meta-app pattern-check invert-args
         ;; Union type helpers
         flatten-union build-union-type
         ;; HKT normalization
         normalize-for-resolution normalizable-builtin?)

;; ========================================
;; Sprint 5: Three-valued result helper
;; ========================================
;; unify-ok? treats both #t and 'postponed as success (optimistic continuation).
;; Callers that need boolean semantics (e.g., (and ... (unify ...)))
;; should use (unify-ok? (unify ...)) instead of bare (unify ...).
(define (unify-ok? result) (not (eq? result #f)))

;; ========================================
;; HKT: Built-in type normalization for unification
;; ========================================
;; Check whether an expression is a built-in parameterized type (e.g., expr-PVec,
;; expr-Map, expr-Set) that can be normalized to expr-app/expr-tycon form.
;; This enables the unifier to decompose (expr-PVec A) vs (expr-app ?F A).
(define (normalizable-builtin? e)
  (or (expr-PVec? e) (expr-Set? e) (expr-Map? e)
      (expr-TVec? e) (expr-TSet? e) (expr-TMap? e)))

;; Normalize a core expression to expr-app/expr-tycon form for HKT unification.
;; Built-in type applications are converted to curried app chains:
;;   (expr-PVec A)   → (expr-app (expr-tycon 'PVec) A)
;;   (expr-Map K V)  → (expr-app (expr-app (expr-tycon 'Map) K) V)
;;   (expr-Set A)    → (expr-app (expr-tycon 'Set) A)
;; Recursively normalizes sub-expressions so nested types are also converted.
;; Also promotes known type constructor fvars (e.g., List, LSeq) to expr-tycon.
(define (normalize-for-resolution e)
  (match e
    ;; Built-in parameterized types → expr-app of expr-tycon
    [(expr-PVec a)   (expr-app (expr-tycon 'PVec) (normalize-for-resolution a))]
    [(expr-Set a)    (expr-app (expr-tycon 'Set)  (normalize-for-resolution a))]
    [(expr-Map k v)  (expr-app (expr-app (expr-tycon 'Map) (normalize-for-resolution k))
                               (normalize-for-resolution v))]
    [(expr-TVec a)   (expr-app (expr-tycon 'TVec) (normalize-for-resolution a))]
    [(expr-TSet a)   (expr-app (expr-tycon 'TSet) (normalize-for-resolution a))]
    [(expr-TMap k v) (expr-app (expr-app (expr-tycon 'TMap) (normalize-for-resolution k))
                               (normalize-for-resolution v))]
    ;; Recursive cases
    [(expr-app f a)  (expr-app (normalize-for-resolution f) (normalize-for-resolution a))]
    ;; Promote known type constructor fvars to expr-tycon
    [(expr-fvar name)
     (if (tycon-arity name)
         (expr-tycon name)
         e)]
    ;; Chase solved metas
    [(expr-meta id)
     (if (meta-solved? id)
         (normalize-for-resolution (meta-solution id))
         e)]
    ;; Everything else: leave unchanged
    [_ e]))

;; ========================================
;; Occur Check
;; ========================================
;; Uses generic struct->vector traversal (matching conv-nf's pattern).
;; Follows solved metas to detect cycles through indirection.

(define (occurs? id expr)
  (let check ([e expr])
    (cond
      [(expr-meta? e)
       (or (eq? (expr-meta-id e) id)
           (let ([sol (meta-solution (expr-meta-id e))])
             (and sol (check sol))))]
      [(struct? e)
       (let ([v (struct->vector e)])
         (for/or ([i (in-range 1 (vector-length v))])
           (check (vector-ref v i))))]
      [else #f])))

;; ========================================
;; Solve a bare (unapplied) metavariable
;; ========================================
;; P-U2a: After solve-meta!, check propagator network for contradictions.
;; This catches transitive inconsistencies from cell writes + quiescence
;; that the imperative path wouldn't detect until the top-level `unify` wrapper.

(define (solve-flex-rigid id rhs ctx)
  (cond
    ;; Already solved? Check consistency by unifying solution with rhs
    [(meta-solved? id)
     (unify-core ctx (meta-solution id) rhs)]
    ;; Occur check: prevent infinite types
    [(occurs? id rhs) #f]
    ;; Solve!
    [else
     (solve-meta! id rhs)
     ;; P-U2a: Post-solve contradiction check via propagator network.
     ;; solve-meta! writes to cell + runs quiescence, which may trigger
     ;; transitive propagation that reveals inconsistencies.
     (define check-fn (current-prop-has-contradiction?))
     (if (and check-fn (check-fn))
         #f   ;; Propagator network detected contradiction
         #t)]))

;; ========================================
;; Core Unification
;; ========================================
;; Algorithm:
;; 1. WHNF-reduce both sides (follows solved metas, unfolds definitions)
;; 2. Fast path: equal? (deep structural equality on transparent structs)
;; 3. expr-hole wildcard: return #t (preserves existing conv behavior)
;; 4. Same unsolved meta on both sides: #t
;; 5. Meta on one side: solve-flex-rigid
;; 6. Same head constructor: decompose and recurse
;; 7. Fallback: conv-nf for atoms/neutrals
;;
;; Binder handling (Sprint 3): When comparing under a binder (Pi codomain,
;; Sigma second type, lam body), we open the binder by substituting bvar(0)
;; with a fresh fvar via open-expr. This ensures meta solutions have correct
;; de Bruijn indices — open-expr automatically decrements higher bvar indices.

(define (unify-core ctx t1 t2)
  (perf-inc-unify!)
  ;; Pre-WHNF: try app-vs-app decomposition on the raw (zonked) terms.
  ;; This is critical for correctness with metavariables: when both sides
  ;; are applications (e.g., (app List ?m) vs (app List B)), decomposing
  ;; BEFORE WHNF avoids unfolding definitions, which would push unsolved
  ;; metas under binders and cause de Bruijn index mismatches in solutions.
  (let ([z1 (zonk-at-depth 0 t1)]
        [z2 (zonk-at-depth 0 t2)])
    ;; Fast path: structurally identical after zonk (no WHNF needed)
    (cond
      [(equal? z1 z2) #t]
      ;; Pre-WHNF app-vs-app: try decomposing applications before reducing.
      ;; If func heads are the same fvar, decompose without unfolding.
      [(and (expr-app? z1) (expr-app? z2)
            (let ([f1 (spine-head z1)] [f2 (spine-head z2)])
              (and f1 f2 (equal? f1 f2))))
       (unify-spine ctx z1 z2)]
      [else (unify-whnf ctx z1 z2)])))

;; Compare application spines without WHNF (preserves meta depth)
(define (spine-head e)
  (match e
    [(expr-app f _) (spine-head f)]
    [(expr-fvar _) e]
    [(expr-tycon _) e]
    [_ #f]))

(define (unify-spine ctx a b)
  (cond
    [(and (expr-app? a) (expr-app? b))
     (and (unify-spine ctx (expr-app-func a) (expr-app-func b))
          (unify-core ctx (expr-app-arg a) (expr-app-arg b)))]
    [else (unify-core ctx a b)]))

;; ========================================
;; P-U1a: Pure Unification Classifier
;; ========================================
;;
;; Given two WHNF-reduced terms, classify the unification problem without
;; performing any side effects. Returns a tagged list:
;;
;; '(ok)                                     — structurally equal or wildcard match
;; '(conv)                                   — structural mismatch (conv-nf fallback)
;; (list 'flex-rigid meta-id rhs)            — bare unsolved meta vs concrete
;; (list 'flex-app flex-term rhs)            — applied meta (spine-headed by unsolved meta)
;; (list 'sub goals)                         — goals: (listof (cons lhs rhs))
;; (list 'pi m1 m2 dom-a dom-b cod-a cod-b) — Pi: mult + domain + codomain
;; (list 'binder fst-a fst-b snd-a snd-b)   — Sigma/lam: first + binder-opened second
;; (list 'level l1 l2)                       — universe level unification
;; (list 'union cs-a cs-b)                   — union component lists
;; (list 'retry a* b*)                       — normalized terms, re-classify
;;
;; Binder cases ('pi, 'binder) return raw codomain/snd-type; the dispatcher
;; handles zonk-at-depth, open-expr, and fresh fvar generation.
;;
;; Does NOT perform: solve-meta!, add-constraint!, perf counters.
;; DOES perform: struct field reads (pure), flatten-union (pure).

(define (classify-whnf-problem a b)
  (cond
    ;; Fast path: structurally identical
    [(equal? a b) '(ok)]

    ;; Holes: wildcards
    [(expr-hole? a) '(ok)]
    [(expr-hole? b) '(ok)]
    [(expr-typed-hole? a) '(ok)]
    [(expr-typed-hole? b) '(ok)]

    ;; Same unsolved meta
    [(and (expr-meta? a) (expr-meta? b)
          (eq? (expr-meta-id a) (expr-meta-id b)))
     '(ok)]

    ;; Meta on left/right
    [(expr-meta? a) (list 'flex-rigid (expr-meta-id a) b)]
    [(expr-meta? b) (list 'flex-rigid (expr-meta-id b) a)]

    ;; --- Structural decomposition ---

    ;; Pi vs Pi
    [(and (expr-Pi? a) (expr-Pi? b))
     (list 'pi
           (expr-Pi-mult a) (expr-Pi-mult b)
           (expr-Pi-domain a) (expr-Pi-domain b)
           (expr-Pi-codomain a) (expr-Pi-codomain b))]

    ;; Sigma vs Sigma
    [(and (expr-Sigma? a) (expr-Sigma? b))
     (list 'binder
           (expr-Sigma-fst-type a) (expr-Sigma-fst-type b)
           (expr-Sigma-snd-type a) (expr-Sigma-snd-type b))]

    ;; suc vs suc
    [(and (expr-suc? a) (expr-suc? b))
     (list 'sub (list (cons (expr-suc-pred a) (expr-suc-pred b))))]

    ;; nat-val vs nat-val
    [(and (expr-nat-val? a) (expr-nat-val? b))
     (if (= (expr-nat-val-n a) (expr-nat-val-n b)) '(ok) '(conv))]

    ;; Cross-repr: nat-val(0) vs zero
    [(and (expr-nat-val? a) (expr-zero? b))
     (if (= (expr-nat-val-n a) 0) '(ok) '(conv))]
    [(and (expr-zero? a) (expr-nat-val? b))
     (if (= (expr-nat-val-n b) 0) '(ok) '(conv))]

    ;; Cross-repr: nat-val(n>0) vs suc(X)
    [(and (expr-nat-val? a) (> (expr-nat-val-n a) 0) (expr-suc? b))
     (list 'sub (list (cons (expr-nat-val (- (expr-nat-val-n a) 1)) (expr-suc-pred b))))]
    [(and (expr-suc? a) (expr-nat-val? b) (> (expr-nat-val-n b) 0))
     (list 'sub (list (cons (expr-suc-pred a) (expr-nat-val (- (expr-nat-val-n b) 1)))))]

    ;; Cross-repr: nat-val(0) vs suc(_) — fail
    [(and (expr-nat-val? a) (= (expr-nat-val-n a) 0) (expr-suc? b)) '(conv)]
    [(and (expr-suc? a) (expr-nat-val? b) (= (expr-nat-val-n b) 0)) '(conv)]

    ;; tycon vs tycon (HKT): same name = equal
    [(and (expr-tycon? a) (expr-tycon? b))
     (if (eq? (expr-tycon-name a) (expr-tycon-name b)) '(ok) '(conv))]

    ;; --- HKT normalization: retry after normalizing built-in types ---
    [(and (normalizable-builtin? a) (expr-app? b))
     (list 'retry (normalize-for-resolution a) b)]
    [(and (expr-app? a) (normalizable-builtin? b))
     (list 'retry a (normalize-for-resolution b))]
    [(and (normalizable-builtin? a) (normalizable-builtin? b))
     (list 'retry (normalize-for-resolution a) (normalize-for-resolution b))]
    [(and (normalizable-builtin? a) (flex-app? b))
     (list 'retry (normalize-for-resolution a) b)]
    [(and (flex-app? a) (normalizable-builtin? b))
     (list 'retry a (normalize-for-resolution b))]

    ;; app vs app (rigid-rigid)
    [(and (expr-app? a) (expr-app? b))
     (list 'sub (list (cons (expr-app-func a) (expr-app-func b))
                       (cons (expr-app-arg a) (expr-app-arg b))))]

    ;; Applied meta (flex-app) — one side is app headed by unsolved meta
    [(flex-app? a) (list 'flex-app a b)]
    [(flex-app? b) (list 'flex-app b a)]

    ;; Eq vs Eq
    [(and (expr-Eq? a) (expr-Eq? b))
     (list 'sub (list (cons (expr-Eq-type a) (expr-Eq-type b))
                       (cons (expr-Eq-lhs a) (expr-Eq-lhs b))
                       (cons (expr-Eq-rhs a) (expr-Eq-rhs b))))]

    ;; Vec vs Vec
    [(and (expr-Vec? a) (expr-Vec? b))
     (list 'sub (list (cons (expr-Vec-elem-type a) (expr-Vec-elem-type b))
                       (cons (expr-Vec-length a) (expr-Vec-length b))))]

    ;; Fin vs Fin
    [(and (expr-Fin? a) (expr-Fin? b))
     (list 'sub (list (cons (expr-Fin-bound a) (expr-Fin-bound b))))]

    ;; lam vs lam
    [(and (expr-lam? a) (expr-lam? b))
     (list 'binder
           (expr-lam-type a) (expr-lam-type b)
           (expr-lam-body a) (expr-lam-body b))]

    ;; pair vs pair
    [(and (expr-pair? a) (expr-pair? b))
     (list 'sub (list (cons (expr-pair-fst a) (expr-pair-fst b))
                       (cons (expr-pair-snd a) (expr-pair-snd b))))]

    ;; Type vs Type (universe levels)
    [(and (expr-Type? a) (expr-Type? b))
     (list 'level (expr-Type-level a) (expr-Type-level b))]

    ;; Union vs Union
    [(and (expr-union? a) (expr-union? b))
     (list 'union (flatten-union a) (flatten-union b))]

    ;; ann: strip annotation and retry
    [(expr-ann? a) (list 'retry (expr-ann-term a) b)]
    [(expr-ann? b) (list 'retry a (expr-ann-term b))]

    ;; Fallback: conv-nf for atoms/neutrals
    [else '(conv)]))

;; ========================================
;; P-U1a: Unification Dispatcher
;; ========================================
;; Given two WHNF terms and a classification from classify-whnf-problem,
;; dispatches to the appropriate solver. This function performs side effects
;; (solve-meta!, add-constraint!, etc.) based on the classification.

(define (dispatch-unify-whnf ctx a b classification)
  (match classification
    ['(ok) #t]
    ['(conv) (conv-nf a b)]
    [(list 'flex-rigid id rhs)
     (solve-flex-rigid id rhs ctx)]
    [(list 'flex-app flex-term rhs)
     (solve-flex-app flex-term rhs ctx)]
    [(list 'sub goals)
     ;; P-U3c: For multi-goal decomposition, flush network between goals
     ;; to propagate transitive constraints from earlier goals to later ones.
     (for/and ([g (in-list goals)])
       (begin0 (unify-core ctx (car g) (cdr g))
               (maybe-flush-network!)))]
    ;; Pi: mult unification (special) + domain + binder-opened codomain
    ;; Codomain uses zonk-at-depth(1, ...) + open-expr for correct de Bruijn indices.
    ;; P-U3c: flush network between domain and codomain for transitive propagation.
    [(list 'pi m1 m2 dom-a dom-b cod-a cod-b)
     (and (unify-mult m1 m2)
          (unify-core ctx dom-a dom-b)
          (begin (maybe-flush-network!)
            (let ([x (expr-fvar (gensym 'unify))])
              (unify-core ctx
                     (open-expr (zonk-at-depth 1 cod-a) x)
                     (open-expr (zonk-at-depth 1 cod-b) x)))))]
    ;; Sigma/lam: first component + binder-opened second
    ;; P-U3c: flush network between first and second for transitive propagation.
    [(list 'binder fst-a fst-b snd-a snd-b)
     (and (unify-core ctx fst-a fst-b)
          (begin (maybe-flush-network!)
            (let ([x (expr-fvar (gensym 'unify))])
              (unify-core ctx
                     (open-expr (zonk-at-depth 1 snd-a) x)
                     (open-expr (zonk-at-depth 1 snd-b) x)))))]
    [(list 'level l1 l2) (unify-level l1 l2)]
    [(list 'union cs-a cs-b) (unify-union-components ctx cs-a cs-b)]
    [(list 'retry a* b*) (unify-whnf ctx a* b*)]))

;; Core unification after WHNF reduction
;; Classifies the problem, then dispatches to the appropriate solver.
(define (unify-whnf ctx t1 t2)
  (let ([a (whnf t1)]
        [b (whnf t2)])
    (dispatch-unify-whnf ctx a b (classify-whnf-problem a b))))

;; ========================================
;; Union type unification helpers
;; ========================================

;; Flatten a (possibly nested) expr-union into a list of non-union components.
;; E.g., (union (union A B) C) → (A B C)
(define (flatten-union e)
  (match e
    [(expr-union l r)
     (append (flatten-union l) (flatten-union r))]
    [_ (list e)]))

;; Canonical key for sorting union components.
;; Uses pretty-print-like classification for deterministic ordering.
(define (union-sort-key e)
  (match e
    [(expr-Nat) "0:Nat"]
    [(expr-nat-val _) "0:NatVal"]
    [(expr-Bool) "0:Bool"]
    [(expr-Unit) "0:Unit"]
    [(expr-Nil) "0:Nil"]
    [(expr-Int) "0:Int"]
    [(expr-Rat) "0:Rat"]
    [(expr-Posit8) "0:Posit8"]
    [(expr-Posit16) "0:Posit16"]
    [(expr-Posit32) "0:Posit32"]
    [(expr-Posit64) "0:Posit64"]
    [(expr-Quire8) "0:Quire8"]
    [(expr-Quire16) "0:Quire16"]
    [(expr-Quire32) "0:Quire32"]
    [(expr-Quire64) "0:Quire64"]
    [(expr-Keyword) "0:Keyword"]
    [(expr-Char) "0:Char"]
    [(expr-String) "0:String"]
    [(expr-net-type) "0:PropNetwork"]
    [(expr-cell-id-type) "0:CellId"]
    [(expr-prop-id-type) "0:PropId"]
    [(expr-uf-type) "0:UnionFind"]
    [(expr-atms-type) "0:ATMS"]
    [(expr-assumption-id-type) "0:AssumptionId"]
    [(expr-table-store-type) "0:TableStore"]
    [(expr-solver-type) "0:Solver"]
    [(expr-goal-type) "0:Goal"]
    [(expr-derivation-type) "0:DerivationTree"]
    [(expr-schema-type name) (format "1:Schema:~a" name)]
    [(expr-answer-type _) "1:Answer"]
    [(expr-relation-type _) "1:Relation"]
    [(expr-Type l) (format "0:Type~a" l)]
    [(expr-fvar name) (format "1:~a" name)]
    [(expr-bvar idx) (format "2:~a" idx)]
    [(expr-Pi _ _ _) "3:Pi"]
    [(expr-Sigma _ _) "3:Sigma"]
    [(expr-Eq _ _ _) "3:Eq"]
    [(expr-Vec _ _) "3:Vec"]
    [(expr-Fin _) "3:Fin"]
    [(expr-Map _ _) "3:Map"]
    [(expr-PVec _) "3:PVec"]
    [(expr-Set _) "3:Set"]
    [(expr-TVec _) "3:TVec"]
    [(expr-TMap _ _) "3:TMap"]
    [(expr-TSet _) "3:TSet"]
    [(expr-tycon name) (format "1:tycon:~a" name)]
    [(expr-app _ _) "4:app"]
    [(expr-meta id) (format "5:?~a" id)]
    [_ "9:other"]))

;; Remove duplicate components (idempotence: A | A ≡ A).
;; Uses structural equality (equal?) after sorting.
(define (dedup-union-components cs)
  (if (null? cs) '()
      (let loop ([prev (car cs)] [rest (cdr cs)] [acc (list (car cs))])
        (cond
          [(null? rest) (reverse acc)]
          [(equal? prev (car rest))
           (loop prev (cdr rest) acc)]
          [else
           (loop (car rest) (cdr rest) (cons (car rest) acc))]))))

;; Build a canonical union type from a list of types.
;; Flattens any nested unions, deduplicates, sorts by union-sort-key,
;; and builds a right-associated expr-union chain.
;; Single type → identity (no wrapping).
(define (build-union-type types)
  (define flat (append-map flatten-union types))
  (define sorted (sort flat string<? #:key union-sort-key))
  (define deduped (dedup-union-components sorted))
  (cond
    [(null? deduped) (expr-error)]
    [(= (length deduped) 1) (car deduped)]
    [else (foldr expr-union (last deduped) (drop-right deduped 1))]))

;; Unify two lists of union components.
;; After flattening, sorting, and dedup, the lists should have the same
;; length and each pair must unify.
(define (unify-union-components ctx cs-a cs-b)
  (let ([sorted-a (dedup-union-components
                    (sort cs-a string<? #:key union-sort-key))]
        [sorted-b (dedup-union-components
                    (sort cs-b string<? #:key union-sort-key))])
    (cond
      [(not (= (length sorted-a) (length sorted-b))) #f]
      [else
       (for/and ([a (in-list sorted-a)]
                 [b (in-list sorted-b)])
         (unify-core ctx a b))])))

;; ========================================
;; Sprint 2b: Applied Meta (Flex-App) Support
;; ========================================

;; Detect whether an expression (already in WHNF) is an application chain
;; with an unsolved metavariable at the head.
(define (flex-app? e)
  (define-values (id args) (decompose-meta-app e))
  (and id #t))

;; Decompose an expression into (expr-meta id) applied to a spine of arguments.
;; Returns (values id args) if the head is an unsolved meta,
;; or (values #f #f) otherwise.
(define (decompose-meta-app e)
  (let loop ([expr e] [args '()])
    (match expr
      [(expr-app f a) (loop f (cons a args))]
      [(expr-meta id)
       (if (meta-solved? id)
           (values #f #f)    ; solved meta: not a flex head
           (values id args))]
      [_ (values #f #f)])))

;; Miller's pattern condition: all arguments must be distinct bound variables.
(define (pattern-check args)
  (and (andmap expr-bvar? args)
       (let ([indices (map expr-bvar-index args)])
         (= (length indices) (length (remove-duplicates indices eq?))))))

;; Solve an applied meta: (app ... (app ?m x0) ... xn) ≡ rhs
;; where x0..xn satisfy the pattern condition.
(define (solve-flex-app flex-term rhs ctx)
  (define-values (id args) (decompose-meta-app flex-term))
  (cond
    [(not id) #f]                    ; not a meta application (shouldn't happen)
    [(null? args)
     ;; Bare meta (shouldn't reach here from flex-app?, but defensive)
     (solve-flex-rigid id rhs ctx)]
    [(not (pattern-check args))
     ;; Failed pattern condition — postpone for later retry (Sprint 5)
     ;; Sprint 9: attach structured provenance from the head meta
     ;; Track 1 Phase 1d: read from cell (primary) with parameter fallback.
     (define pre-store (read-constraint-store))
     (add-constraint! flex-term rhs ctx
       (constraint-provenance
         srcloc-unknown
         "pattern condition failed for applied metavariable"
         (let-values ([(head-id _args) (decompose-meta-app flex-term)])
           (and head-id (let ([info (meta-lookup head-id)])
                          (and info (meta-info-source info)))))))
     ;; P-U2a: Check if quiescence already resolved the constraint.
     ;; add-constraint! creates propagator cells, so transitive propagation
     ;; may have solved the constraint immediately.
     ;; Track 1: cell uses merge-list-append (newest at tail); check last element.
     (define post-store (read-constraint-store))
     (cond
       [(and (pair? post-store)
             (not (eq? post-store pre-store))
             (let ([newest (last post-store)])
               (eq? (constraint-status newest) 'solved)))
        #t]  ;; Upgrade: constraint was resolved by quiescence
       [else 'postponed])]
    [(occurs? id rhs) #f]  ; occur check
    [else
     ;; Solve by inversion: construct lambda abstraction
     (solve-meta! id (invert-args args rhs))
     ;; P-U2a: Post-solve contradiction check (same as solve-flex-rigid)
     (define check-fn (current-prop-has-contradiction?))
     (if (and check-fn (check-fn))
         #f
         #t)]))

;; Construct a lambda abstraction that, when applied to the original arguments,
;; produces the RHS.
;;
;; Given args = (bvar(i0), bvar(i1), ..., bvar(in-1)) and body = rhs:
;; 1. Shift rhs up by n (make room for n new binders)
;; 2. For each arg bvar(ij), substitute bvar(ij + n) with bvar(n - 1 - j)
;; 3. Wrap in n lambdas with expr-hole types
(define (invert-args args body)
  (define n (length args))
  ;; Step 1: Shift rhs up by n to make room for n new binders
  (define shifted-body (shift n 0 body))
  ;; Step 2: For each original bvar(i), replace bvar(i+n) with bvar(n-1-k)
  ;; where k is the argument's position (0-indexed from outermost lambda)
  (define substituted-body
    (for/fold ([b shifted-body])
              ([arg (in-list args)]
               [k (in-naturals)])
      (let ([orig-index (+ (expr-bvar-index arg) n)]  ; shifted original index
            [new-index (- n 1 k)])                      ; new bvar under lambdas
        (rename-bvar orig-index new-index b))))
  ;; Step 3: Wrap in n lambdas
  (for/fold ([inner substituted-body])
            ([_ (in-range n)])
    (expr-lam 'mw (expr-hole) inner)))

;; Rename: replace all occurrences of bvar(from) with bvar(to) in an expression.
;; This is a targeted substitution that only swaps indices.
(define (rename-bvar from to e)
  (let walk ([expr e])
    (cond
      [(expr-bvar? expr)
       (if (= (expr-bvar-index expr) from)
           (expr-bvar to)
           expr)]
      [(struct? expr)
       (let ([v (struct->vector expr)])
         (define new-fields
           (for/list ([i (in-range 1 (vector-length v))])
             (let ([field (vector-ref v i)])
               (if (or (struct? field) (expr-bvar? field))
                   (walk field)
                   field))))
         ;; Reconstruct the struct from its fields
         (apply (struct-type-make-constructor
                 (let-values ([(st _) (struct-info expr)]) st))
                new-fields))]
      [else expr])))

;; ========================================
;; Sprint 6: Universe Level Unification
;; ========================================

;; P-U1b: Pure level classifier — follows solved metas (pure reads),
;; returns a tagged classification:
;;   '(ok)                          — structurally equal
;;   (list 'solve-level id rhs)     — unsolved level-meta, needs solving
;;   (list 'sub-level l1* l2*)      — lsuc vs lsuc: recurse on predecessors
;;   '(fail)                        — concrete mismatch
(define (classify-level-problem l1 l2)
  (cond
    [(equal? l1 l2) '(ok)]
    [(level-meta? l1)
     (let ([sol (level-meta-solution (level-meta-id l1))])
       (if sol
           (classify-level-problem sol l2)
           (list 'solve-level (level-meta-id l1) l2)))]
    [(level-meta? l2)
     (let ([sol (level-meta-solution (level-meta-id l2))])
       (if sol
           (classify-level-problem l1 sol)
           (list 'solve-level (level-meta-id l2) l1)))]
    [(and (lsuc? l1) (lsuc? l2))
     (list 'sub-level (lsuc-pred l1) (lsuc-pred l2))]
    [else '(fail)]))

;; Dispatcher: performs side-effecting solve or recurse.
(define (unify-level l1 l2)
  (define cl (classify-level-problem l1 l2))
  (match cl
    ['(ok) #t]
    ['(fail) #f]
    [(list 'solve-level id rhs) (solve-level-meta! id rhs) #t]
    [(list 'sub-level l1* l2*) (unify-level l1* l2*)]))

;; ========================================
;; Sprint 7: Multiplicity Unification
;; ========================================

;; P-U1b: Pure mult classifier — follows solved metas (pure reads),
;; returns a tagged classification:
;;   '(ok)                         — structurally equal
;;   (list 'solve-mult id rhs)     — unsolved mult-meta, needs solving
;;   '(fail)                       — concrete mismatch
(define (classify-mult-problem m1 m2)
  (cond
    [(equal? m1 m2) '(ok)]
    [(mult-meta? m1)
     (let ([sol (mult-meta-solution (mult-meta-id m1))])
       (if sol
           (classify-mult-problem sol m2)
           (list 'solve-mult (mult-meta-id m1) m2)))]
    [(mult-meta? m2)
     (let ([sol (mult-meta-solution (mult-meta-id m2))])
       (if sol
           (classify-mult-problem m1 sol)
           (list 'solve-mult (mult-meta-id m2) m1)))]
    [else '(fail)]))

;; Dispatcher: performs side-effecting solve.
(define (unify-mult m1 m2)
  (define cl (classify-mult-problem m1 m2))
  (match cl
    ['(ok) #t]
    ['(fail) #f]
    [(list 'solve-mult id rhs) (solve-mult-meta! id rhs) #t]))

;; ========================================
;; P1-G7: Propagator-Aware Unification (primary entry point)
;; ========================================
;;
;; unify(ctx, t1, t2) → #t | 'postponed | #f
;;
;; Calls unify-core (the raw unification engine), then checks the
;; propagator network for consistency:
;; 1. Contradictions not caught by the imperative path → downgrade to #f
;; 2. Solved constraints via transitive propagation → upgrade 'postponed → #t
;;
;; This is the ONLY entry point for unification in the main pipeline.
;; unify-core is internal (for recursive calls and constraint retry).

(define (unify ctx t1 t2)
  ;; Track 1 Phase 1d: read from cell (primary) with parameter fallback.
  ;; Snapshot constraint store to detect solved-via-quiescence.
  (define pre-store (read-constraint-store))
  (define result (unify-core ctx t1 t2))
  ;; Post-unification consistency check with propagator network.
  ;; Quiescence already ran inside solve-meta! (if any metas were solved).
  (define check-fn (current-prop-has-contradiction?))
  (cond
    [(not check-fn) result]  ;; No network (test context) → pass through
    ;; If unify-core said #t or 'postponed but network has contradiction → downgrade to #f
    [(and (not (eq? result #f)) (check-fn)) #f]
    ;; If unify-core returned 'postponed, check if quiescence resolved
    ;; the constraint via transitive propagation. If the most recent constraint
    ;; added during this call was solved by retry-via-cells, upgrade to #t.
    ;; Track 1: cell uses merge-list-append (newest at tail); check last element.
    [(eq? result 'postponed)
     (define post-store (read-constraint-store))
     (cond
       ;; A new constraint was added (post-store is longer than pre-store)
       [(and (pair? post-store)
             (not (eq? post-store pre-store))
             (let ([newest (last post-store)])
               (eq? (constraint-status newest) 'solved)))
        #t]  ;; Upgrade: constraint was resolved by quiescence
       [else 'postponed])]
    [else result]))

;; Backward-compat aliases
(define unify* unify)
(define unify*-ok? unify-ok?)

;; ========================================
;; Sprint 5: Install constraint retry callback
;; ========================================
;; When solve-meta! solves a metavariable, retry-constraints-for-meta!
;; calls this callback on each postponed constraint that mentions the meta.
;; Retry callback uses unify-core (not unify) to avoid double propagator
;; checking — the retry itself is triggered by propagator quiescence.
;; Track 6 Phase 1c: functional status updates via write-constraint-to-store!.
(current-retry-unify
 (lambda (c)
   (let ([lhs (zonk-at-depth 0 (constraint-lhs c))]
         [rhs (zonk-at-depth 0 (constraint-rhs c))])
     (define result (unify-core (constraint-ctx c) lhs rhs))
     (cond
       [(eq? result #t)
        (write-constraint-to-store! (struct-copy constraint c [status 'solved]))
        ;; Track 2 Phase 2: dual-write to status cell.
        (write-constraint-status-cell! (constraint-cid c) 'resolved)]
       [(eq? result #f)
        (write-constraint-to-store! (struct-copy constraint c [status 'failed]))
        ;; Track 2 Phase 2: dual-write to status cell.
        (write-constraint-status-cell! (constraint-cid c) 'resolved)]
       ;; 'postponed: leave status as-is (will be set back to 'postponed
       ;; by retry-constraints-for-meta! if still 'retrying)
       ))))
