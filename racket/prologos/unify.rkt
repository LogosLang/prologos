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
         "source-location.rkt")

(provide unify unify-ok? occurs?
         ;; Sprint 2b exports
         decompose-meta-app pattern-check invert-args
         ;; Union type helpers
         flatten-union)

;; ========================================
;; Sprint 5: Three-valued result helper
;; ========================================
;; unify-ok? treats both #t and 'postponed as success (optimistic continuation).
;; Callers that need boolean semantics (e.g., (and ... (unify ...)))
;; should use (unify-ok? (unify ...)) instead of bare (unify ...).
(define (unify-ok? result) (not (eq? result #f)))

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

(define (solve-flex-rigid id rhs ctx)
  (cond
    ;; Already solved? Check consistency by unifying solution with rhs
    [(meta-solved? id)
     (unify ctx (meta-solution id) rhs)]
    ;; Occur check: prevent infinite types
    [(occurs? id rhs) #f]
    ;; Solve!
    [else
     (solve-meta! id rhs)
     #t]))

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

(define (unify ctx t1 t2)
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
    [_ #f]))

(define (unify-spine ctx a b)
  (cond
    [(and (expr-app? a) (expr-app? b))
     (and (unify-spine ctx (expr-app-func a) (expr-app-func b))
          (unify ctx (expr-app-arg a) (expr-app-arg b)))]
    [else (unify ctx a b)]))

;; Core unification after WHNF reduction
(define (unify-whnf ctx t1 t2)
  (let ([a (whnf t1)]
        [b (whnf t2)])
    (cond
      ;; Fast path: structurally identical after WHNF
      [(equal? a b) #t]

      ;; expr-hole wildcard (preserves existing conv behavior)
      [(expr-hole? a) #t]
      [(expr-hole? b) #t]

      ;; Both are the same unsolved metavariable
      [(and (expr-meta? a) (expr-meta? b)
            (eq? (expr-meta-id a) (expr-meta-id b)))
       #t]

      ;; Meta on left side: solve
      [(expr-meta? a)
       (solve-flex-rigid (expr-meta-id a) b ctx)]

      ;; Meta on right side: solve
      [(expr-meta? b)
       (solve-flex-rigid (expr-meta-id b) a ctx)]

      ;; --- Structural decomposition ---

      ;; Pi vs Pi: multiplicities must unify, then unify domains and codomains.
      ;; Codomains are opened with a fresh fvar to avoid de Bruijn depth issues.
      ;; Sprint 7: uses unify-mult instead of eq? for mult-meta support.
      ;; Sprint 11: Use zonk-at-depth(1, cod) before opening codomains.
      ;; When a meta is solved to bvar(N) during domain unification, that bvar
      ;; is at depth 0 (the domain level). Inside the codomain (depth 1), the
      ;; same context variable is at bvar(N+1). zonk-at-depth shifts meta
      ;; solutions by the accumulated binder depth, so bvar(N) becomes bvar(N+1)
      ;; in the codomain, yielding correct de Bruijn indices after open-expr.
      [(and (expr-Pi? a) (expr-Pi? b))
       (let ([m1 (expr-Pi-mult a)] [m2 (expr-Pi-mult b)])
         (and (unify-mult m1 m2)
              (unify ctx (expr-Pi-domain a) (expr-Pi-domain b))
              (let ([x (expr-fvar (gensym 'unify))])
                (unify ctx
                       (open-expr (zonk-at-depth 1 (expr-Pi-codomain a)) x)
                       (open-expr (zonk-at-depth 1 (expr-Pi-codomain b)) x)))))]

      ;; Sigma vs Sigma: opened with fresh fvar for second type
      ;; Same depth-aware zonking as Pi codomains.
      [(and (expr-Sigma? a) (expr-Sigma? b))
       (and (unify ctx (expr-Sigma-fst-type a) (expr-Sigma-fst-type b))
            (let ([x (expr-fvar (gensym 'unify))])
              (unify ctx
                     (open-expr (zonk-at-depth 1 (expr-Sigma-snd-type a)) x)
                     (open-expr (zonk-at-depth 1 (expr-Sigma-snd-type b)) x))))]

      ;; suc vs suc
      [(and (expr-suc? a) (expr-suc? b))
       (unify ctx (expr-suc-pred a) (expr-suc-pred b))]

      ;; app vs app (rigid-rigid): try structural decomposition first
      [(and (expr-app? a) (expr-app? b))
       (and (unify ctx (expr-app-func a) (expr-app-func b))
            (unify ctx (expr-app-arg a) (expr-app-arg b)))]

      ;; --- Sprint 2b: Applied meta (flex-app) handling ---
      ;; Fires when one side is (app ... (app (expr-meta ?m) x1) ... xn)
      ;; and the other is NOT an app (already handled above).
      [(flex-app? a)
       (solve-flex-app a b ctx)]
      [(flex-app? b)
       (solve-flex-app b a ctx)]

      ;; Eq vs Eq
      [(and (expr-Eq? a) (expr-Eq? b))
       (and (unify ctx (expr-Eq-type a) (expr-Eq-type b))
            (unify ctx (expr-Eq-lhs a) (expr-Eq-lhs b))
            (unify ctx (expr-Eq-rhs a) (expr-Eq-rhs b)))]

      ;; Vec vs Vec
      [(and (expr-Vec? a) (expr-Vec? b))
       (and (unify ctx (expr-Vec-elem-type a) (expr-Vec-elem-type b))
            (unify ctx (expr-Vec-length a) (expr-Vec-length b)))]

      ;; Fin vs Fin
      [(and (expr-Fin? a) (expr-Fin? b))
       (unify ctx (expr-Fin-bound a) (expr-Fin-bound b))]

      ;; lam vs lam: opened with fresh fvar for body
      ;; Same depth-aware zonking as Pi/Sigma.
      [(and (expr-lam? a) (expr-lam? b))
       (and (unify ctx (expr-lam-type a) (expr-lam-type b))
            (let ([x (expr-fvar (gensym 'unify))])
              (unify ctx
                     (open-expr (zonk-at-depth 1 (expr-lam-body a)) x)
                     (open-expr (zonk-at-depth 1 (expr-lam-body b)) x))))]

      ;; pair vs pair
      [(and (expr-pair? a) (expr-pair? b))
       (and (unify ctx (expr-pair-fst a) (expr-pair-fst b))
            (unify ctx (expr-pair-snd a) (expr-pair-snd b)))]

      ;; Type vs Type (universe levels) — Sprint 6: level-meta aware
      [(and (expr-Type? a) (expr-Type? b))
       (unify-level (expr-Type-level a) (expr-Type-level b))]

      ;; Union vs Union: flatten both, sort, and unify component-wise.
      ;; Handles ACI (associativity, commutativity, idempotence).
      [(and (expr-union? a) (expr-union? b))
       (let ([cs-a (flatten-union a)]
             [cs-b (flatten-union b)])
         (unify-union-components ctx cs-a cs-b))]

      ;; ann: should not survive WHNF, but handle defensively
      [(expr-ann? a) (unify ctx (expr-ann-term a) b)]
      [(expr-ann? b) (unify ctx a (expr-ann-term b))]

      ;; --- Fallback: conv-nf for atoms/neutrals ---
      ;; This handles bvar, fvar, zero, true, false, refl, Nat, Bool,
      ;; natrec, J, boolrec, and any remaining cases
      [else (conv-nf a b)])))

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
    [(expr-Bool) "0:Bool"]
    [(expr-Unit) "0:Unit"]
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
         (unify ctx a b))])))

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
     (add-constraint! flex-term rhs ctx
       (constraint-provenance
         srcloc-unknown
         "pattern condition failed for applied metavariable"
         (let-values ([(head-id _args) (decompose-meta-app flex-term)])
           (and head-id (let ([info (meta-lookup head-id)])
                          (and info (meta-info-source info)))))))
     'postponed]
    [(occurs? id rhs) #f]  ; occur check
    [else
     ;; Solve by inversion: construct lambda abstraction
     (solve-meta! id (invert-args args rhs))
     #t]))

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
;; Unify two universe levels, solving level-metas as side effects.
;; Returns #t if levels are equal (possibly after solving), #f otherwise.

(define (unify-level l1 l2)
  (cond
    [(equal? l1 l2) #t]
    ;; level-meta on left: follow or solve
    [(level-meta? l1)
     (let ([sol (level-meta-solution (level-meta-id l1))])
       (if sol
           (unify-level sol l2)
           (begin (solve-level-meta! (level-meta-id l1) l2) #t)))]
    ;; level-meta on right: follow or solve
    [(level-meta? l2)
     (let ([sol (level-meta-solution (level-meta-id l2))])
       (if sol
           (unify-level l1 sol)
           (begin (solve-level-meta! (level-meta-id l2) l1) #t)))]
    ;; lsuc vs lsuc: recurse
    [(and (lsuc? l1) (lsuc? l2))
     (unify-level (lsuc-pred l1) (lsuc-pred l2))]
    ;; Mismatch (e.g., lzero vs lsuc)
    [else #f]))

;; ========================================
;; Sprint 7: Multiplicity Unification
;; ========================================
;; Unify two multiplicities, solving mult-metas as side effects.
;; Returns #t if multiplicities are equal (possibly after solving), #f otherwise.

(define (unify-mult m1 m2)
  (cond
    [(equal? m1 m2) #t]
    ;; mult-meta on left: follow or solve
    [(mult-meta? m1)
     (let ([sol (mult-meta-solution (mult-meta-id m1))])
       (if sol
           (unify-mult sol m2)
           (begin (solve-mult-meta! (mult-meta-id m1) m2) #t)))]
    ;; mult-meta on right: follow or solve
    [(mult-meta? m2)
     (let ([sol (mult-meta-solution (mult-meta-id m2))])
       (if sol
           (unify-mult m1 sol)
           (begin (solve-mult-meta! (mult-meta-id m2) m1) #t)))]
    ;; Concrete mismatch
    [else #f]))

;; ========================================
;; Sprint 5: Install constraint retry callback
;; ========================================
;; When solve-meta! solves a metavariable, retry-constraints-for-meta!
;; calls this callback on each postponed constraint that mentions the meta.
(current-retry-unify
 (lambda (c)
   (let ([lhs (zonk-at-depth 0 (constraint-lhs c))]
         [rhs (zonk-at-depth 0 (constraint-rhs c))])
     (define result (unify (constraint-ctx c) lhs rhs))
     (cond
       [(eq? result #t)   (set-constraint-status! c 'solved)]
       [(eq? result #f)   (set-constraint-status! c 'failed)]
       ;; 'postponed: leave status as-is (will be set back to 'postponed
       ;; by retry-constraints-for-meta! if still 'retrying)
       ))))
