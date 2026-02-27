#lang racket/base

;;;
;;; type-lattice.rkt — Type lattice for propagator-based type inference
;;;
;;; Defines the merge function (lattice join) for type-valued propagator cells.
;;; This is the FlatLattice over Prologos type expressions:
;;;
;;;   type-bot  (⊥, no information — fresh metavariable)
;;;       ↓
;;;   T         (concrete type expression)
;;;       ↓
;;;   type-top  (⊤, contradiction — incompatible types)
;;;
;;; The merge function attempts pure structural unification: if two non-equal
;;; types are written to the same cell, unification determines whether they
;;; are compatible (e.g., Pi Nat Bool = Pi Nat Bool) or contradictory
;;; (e.g., Nat ≠ Bool → ⊤).
;;;
;;; CRITICAL: This module does NOT depend on metavar-store.rkt. The merge
;;; function is pure — no solve-meta!, no add-constraint!, no side effects.
;;; This is required because propagator networks are persistent/immutable.
;;;
;;; Design reference: docs/tracking/2026-02-25_TYPE_INFERENCE_ON_LOGIC_ENGINE_DESIGN.md §3.2, §5.1
;;;

(require racket/match
         racket/list
         "prelude.rkt"         ;; mult-meta?, mult-meta-id (Phase E1)
         "syntax.rkt"
         "reduction.rkt"       ;; whnf (read-only)
         "zonk.rkt"            ;; zonk-at-depth (read-only)
         "substitution.rkt")   ;; open-expr (read-only)

(provide type-bot type-top type-bot? type-top?
         type-lattice-merge
         type-lattice-contradicts?
         try-unify-pure
         ;; Phase E1: Meta-solution callback for propagator-aware merge
         current-lattice-meta-solution-fn
         install-lattice-meta-solution-fn!
         has-unsolved-meta?)

;; ========================================
;; Sentinel values
;; ========================================

(define type-bot 'type-bot)
(define type-top 'type-top)

(define (type-bot? v) (eq? v 'type-bot))
(define (type-top? v) (eq? v 'type-top))

;; ========================================
;; Phase E1: Meta-solution callback
;; ========================================
;; Read-only callback for following solved metavariable solutions in pure merge.
;; Signature: (meta-id → expr | #f) — returns solution or #f if unsolved.
;; Installed by driver.rkt; default #f (pure structural only).
;; CRITICAL: This is READ-ONLY. No side effects (no solve-meta!, no cell writes).
(define current-lattice-meta-solution-fn (make-parameter #f))

(define (install-lattice-meta-solution-fn! fn)
  (current-lattice-meta-solution-fn fn))

;; Phase E1: Check if an expression contains unsolved metavariables.
;; Uses the meta-solution callback to distinguish solved from unsolved.
(define (has-unsolved-meta? e)
  (define sol-fn (current-lattice-meta-solution-fn))
  (cond
    [(not sol-fn) #f]    ;; No callback → can't check, assume no metas
    [(type-bot? e) #f]
    [(type-top? e) #f]
    [(expr-meta? e)
     (not (sol-fn (expr-meta-id e)))]
    [(expr-Pi? e)
     (or (and (mult-meta? (expr-Pi-mult e))
              (not (sol-fn (mult-meta-id (expr-Pi-mult e)))))
         (has-unsolved-meta? (expr-Pi-domain e))
         (has-unsolved-meta? (expr-Pi-codomain e)))]
    [(expr-app? e)
     (or (has-unsolved-meta? (expr-app-func e))
         (has-unsolved-meta? (expr-app-arg e)))]
    [(expr-Eq? e)
     (or (has-unsolved-meta? (expr-Eq-type e))
         (has-unsolved-meta? (expr-Eq-lhs e))
         (has-unsolved-meta? (expr-Eq-rhs e)))]
    [(expr-Vec? e)
     (or (has-unsolved-meta? (expr-Vec-elem-type e))
         (has-unsolved-meta? (expr-Vec-length e)))]
    [(expr-Sigma? e)
     (or (has-unsolved-meta? (expr-Sigma-fst-type e))
         (has-unsolved-meta? (expr-Sigma-snd-type e)))]
    [(expr-PVec? e) (has-unsolved-meta? (expr-PVec-elem-type e))]
    [(expr-Set? e) (has-unsolved-meta? (expr-Set-elem-type e))]
    [(expr-Map? e)
     (or (has-unsolved-meta? (expr-Map-k-type e))
         (has-unsolved-meta? (expr-Map-v-type e)))]
    [(expr-union? e)
     (or (has-unsolved-meta? (expr-union-left e))
         (has-unsolved-meta? (expr-union-right e)))]
    [(expr-lam? e)
     (or (has-unsolved-meta? (expr-lam-type e))
         (has-unsolved-meta? (expr-lam-body e)))]
    [(expr-pair? e)
     (or (has-unsolved-meta? (expr-pair-fst e))
         (has-unsolved-meta? (expr-pair-snd e)))]
    [(expr-suc? e) (has-unsolved-meta? (expr-suc-pred e))]
    [(expr-Fin? e) (has-unsolved-meta? (expr-Fin-bound e))]
    [else #f]))

;; ========================================
;; Lattice merge (join)
;; ========================================
;;
;; Satisfies: commutative, associative, idempotent, with type-bot as identity.
;; - merge(⊥, x)  = x           (identity)
;; - merge(x, ⊥)  = x           (commutativity of identity)
;; - merge(⊤, x)  = ⊤           (absorbing element)
;; - merge(x, x)  = x           (idempotent)
;; - merge(T1, T2) = unify(T1,T2) if structurally compatible, else ⊤

(define (type-lattice-merge v1 v2)
  (cond
    [(type-bot? v1) v2]
    [(type-bot? v2) v1]
    [(type-top? v1) type-top]
    [(type-top? v2) type-top]
    [(eq? v1 v2) v1]            ;; Phase 7b: pointer-equal fast path (interned atoms, sentinels)
    [(equal? v1 v2) v1]
    [else
     (define result (try-unify-pure v1 v2))
     (cond
       [result result]
       ;; Phase E1: If either side has unsolved metas, we can't declare
       ;; contradiction yet — keep the more concrete value. When the meta
       ;; is solved, solve-meta! writes to its cell, the unify propagator
       ;; fires again, and merge re-runs with the resolved type.
       [(or (has-unsolved-meta? v1) (has-unsolved-meta? v2))
        (if (has-unsolved-meta? v1) v2 v1)]
       [else type-top])]))

;; ========================================
;; Contradiction predicate
;; ========================================

(define (type-lattice-contradicts? v)
  (type-top? v))

;; ========================================
;; Pure structural unification
;; ========================================
;;
;; try-unify-pure : Expr Expr → Expr | #f
;;
;; Attempts to unify two type expressions structurally, returning the unified
;; result or #f if incompatible. Has NO side effects — no meta solving, no
;; constraint creation. When metas are encountered, returns #f (can't solve
;; in pure mode).
;;
;; Unlike the full `unify` in unify.rkt (which returns #t/#f/'postponed and
;; performs side effects), this function RECONSTRUCTS the result type.
;;
;; Based on the structural decomposition in unify-whnf (unify.rkt lines 182-322),
;; but stripped of all side-effecting branches.

(define (try-unify-pure t1 t2)
  ;; First reduce both to WHNF
  (let ([a (whnf t1)]
        [b (whnf t2)])
    (cond
      ;; Fast path: structurally identical
      [(equal? a b) a]

      ;; Metas: follow solved metas via callback (Phase E1); unsolved → #f
      [(expr-meta? a)
       (define sol-fn (current-lattice-meta-solution-fn))
       (define sol (and sol-fn (sol-fn (expr-meta-id a))))
       (if sol (try-unify-pure sol b) #f)]
      [(expr-meta? b)
       (define sol-fn (current-lattice-meta-solution-fn))
       (define sol (and sol-fn (sol-fn (expr-meta-id b))))
       (if sol (try-unify-pure a sol) #f)]

      ;; Holes: can't handle in pure mode
      [(expr-hole? a) #f]
      [(expr-hole? b) #f]
      [(expr-typed-hole? a) #f]
      [(expr-typed-hole? b) #f]

      ;; --- Structural decomposition ---

      ;; Pi vs Pi: unify multiplicities, domains, codomains
      [(and (expr-Pi? a) (expr-Pi? b))
       (let ([m1 (expr-Pi-mult a)] [m2 (expr-Pi-mult b)])
         (cond
           ;; Multiplicities must match; Phase E1: follow solved mult-metas
           [(not (equal? m1 m2))
            (define sol-fn (current-lattice-meta-solution-fn))
            (define m1* (if (and sol-fn (mult-meta? m1))
                            (or (sol-fn (mult-meta-id m1)) m1)
                            m1))
            (define m2* (if (and sol-fn (mult-meta? m2))
                            (or (sol-fn (mult-meta-id m2)) m2)
                            m2))
            (if (equal? m1* m2*)
                ;; Resolved mults match — continue with domain/codomain
                (let ()
                  (define dom (try-unify-pure (expr-Pi-domain a) (expr-Pi-domain b)))
                  (and dom
                       (let ([x (expr-fvar (gensym 'pure-unify))])
                         (define cod-a (open-expr (zonk-at-depth 1 (expr-Pi-codomain a)) x))
                         (define cod-b (open-expr (zonk-at-depth 1 (expr-Pi-codomain b)) x))
                         (define cod (try-unify-pure cod-a cod-b))
                         (and cod (expr-Pi m1* dom (expr-Pi-codomain a))))))
                #f)]
           [else
            (define dom (try-unify-pure (expr-Pi-domain a) (expr-Pi-domain b)))
            (and dom
                 (let ([x (expr-fvar (gensym 'pure-unify))])
                   (define cod-a (open-expr (zonk-at-depth 1 (expr-Pi-codomain a)) x))
                   (define cod-b (open-expr (zonk-at-depth 1 (expr-Pi-codomain b)) x))
                   (define cod (try-unify-pure cod-a cod-b))
                   ;; We return a reconstructed Pi with the original codomain structure.
                   ;; Since both sides were equal (unified successfully), either original is fine.
                   ;; Use the first side's codomain as-is (they're structurally equal after unification).
                   (and cod (expr-Pi m1 dom (expr-Pi-codomain a)))))]))]

      ;; Sigma vs Sigma: unify fst-types, snd-types
      [(and (expr-Sigma? a) (expr-Sigma? b))
       (define fst (try-unify-pure (expr-Sigma-fst-type a) (expr-Sigma-fst-type b)))
       (and fst
            (let ([x (expr-fvar (gensym 'pure-unify))])
              (define snd-a (open-expr (zonk-at-depth 1 (expr-Sigma-snd-type a)) x))
              (define snd-b (open-expr (zonk-at-depth 1 (expr-Sigma-snd-type b)) x))
              (define snd (try-unify-pure snd-a snd-b))
              (and snd (expr-Sigma fst (expr-Sigma-snd-type a)))))]

      ;; suc vs suc
      [(and (expr-suc? a) (expr-suc? b))
       (define pred (try-unify-pure (expr-suc-pred a) (expr-suc-pred b)))
       (and pred (expr-suc pred))]

      ;; tycon vs tycon: same name
      [(and (expr-tycon? a) (expr-tycon? b))
       (and (eq? (expr-tycon-name a) (expr-tycon-name b)) a)]

      ;; app vs app: unify func + arg
      [(and (expr-app? a) (expr-app? b))
       (define func (try-unify-pure (expr-app-func a) (expr-app-func b)))
       (and func
            (let ([arg (try-unify-pure (expr-app-arg a) (expr-app-arg b))])
              (and arg (expr-app func arg))))]

      ;; Eq vs Eq
      [(and (expr-Eq? a) (expr-Eq? b))
       (define ty (try-unify-pure (expr-Eq-type a) (expr-Eq-type b)))
       (and ty
            (let ([lhs (try-unify-pure (expr-Eq-lhs a) (expr-Eq-lhs b))])
              (and lhs
                   (let ([rhs (try-unify-pure (expr-Eq-rhs a) (expr-Eq-rhs b))])
                     (and rhs (expr-Eq ty lhs rhs))))))]

      ;; Vec vs Vec
      [(and (expr-Vec? a) (expr-Vec? b))
       (define et (try-unify-pure (expr-Vec-elem-type a) (expr-Vec-elem-type b)))
       (and et
            (let ([len (try-unify-pure (expr-Vec-length a) (expr-Vec-length b))])
              (and len (expr-Vec et len))))]

      ;; Fin vs Fin
      [(and (expr-Fin? a) (expr-Fin? b))
       (define bound (try-unify-pure (expr-Fin-bound a) (expr-Fin-bound b)))
       (and bound (expr-Fin bound))]

      ;; lam vs lam: unify types and bodies
      [(and (expr-lam? a) (expr-lam? b))
       (define ty (try-unify-pure (expr-lam-type a) (expr-lam-type b)))
       (and ty
            (let ([x (expr-fvar (gensym 'pure-unify))])
              (define body-a (open-expr (zonk-at-depth 1 (expr-lam-body a)) x))
              (define body-b (open-expr (zonk-at-depth 1 (expr-lam-body b)) x))
              (define body (try-unify-pure body-a body-b))
              (and body (expr-lam ty (expr-lam-body a)))))]

      ;; pair vs pair
      [(and (expr-pair? a) (expr-pair? b))
       (define fst (try-unify-pure (expr-pair-fst a) (expr-pair-fst b)))
       (and fst
            (let ([snd (try-unify-pure (expr-pair-snd a) (expr-pair-snd b))])
              (and snd (expr-pair fst snd))))]

      ;; Type vs Type: level equality (structural, no level-meta solving)
      [(and (expr-Type? a) (expr-Type? b))
       (and (equal? (expr-Type-level a) (expr-Type-level b)) a)]

      ;; Union vs Union: flatten, sort, dedup, pairwise unify
      [(and (expr-union? a) (expr-union? b))
       (try-unify-pure-unions a b)]

      ;; PVec vs PVec
      [(and (expr-PVec? a) (expr-PVec? b))
       (define et (try-unify-pure (expr-PVec-elem-type a) (expr-PVec-elem-type b)))
       (and et (expr-PVec et))]

      ;; Set vs Set
      [(and (expr-Set? a) (expr-Set? b))
       (define et (try-unify-pure (expr-Set-elem-type a) (expr-Set-elem-type b)))
       (and et (expr-Set et))]

      ;; Map vs Map
      [(and (expr-Map? a) (expr-Map? b))
       (define kt (try-unify-pure (expr-Map-k-type a) (expr-Map-k-type b)))
       (and kt
            (let ([vt (try-unify-pure (expr-Map-v-type a) (expr-Map-v-type b))])
              (and vt (expr-Map kt vt))))]

      ;; ann: strip (should not survive WHNF, but handle defensively)
      [(expr-ann? a) (try-unify-pure (expr-ann-term a) b)]
      [(expr-ann? b) (try-unify-pure a (expr-ann-term b))]

      ;; Fallback: structural equality for all atoms/neutrals
      ;; (bvar, fvar, zero, true, false, refl, Nat, Bool, etc.)
      ;; equal? already covered above; reaching here means incompatible
      [else #f])))

;; ========================================
;; Union type pure unification
;; ========================================
;;
;; Duplicated from unify.rkt to avoid importing metavar-store.rkt
;; (unify.rkt requires metavar-store.rkt, which we must avoid).
;; These are pure functions on AST structs.

(define (flatten-union-pure e)
  (match e
    [(expr-union l r)
     (append (flatten-union-pure l) (flatten-union-pure r))]
    [_ (list e)]))

;; Canonical sort key (copied from unify.rkt union-sort-key)
(define (union-sort-key-pure e)
  (match e
    [(expr-Nat) "0:Nat"]
    [(expr-Bool) "0:Bool"]
    [(expr-Unit) "0:Unit"]
    [(expr-Int) "0:Int"]
    [(expr-Rat) "0:Rat"]
    [(expr-String) "0:String"]
    [(expr-Keyword) "0:Keyword"]
    [(expr-Char) "0:Char"]
    [(expr-Type l) (format "0:Type~a" l)]
    [(expr-fvar name) (format "1:~a" name)]
    [(expr-tycon name) (format "1:tycon:~a" name)]
    [(expr-bvar idx) (format "2:~a" idx)]
    [(expr-Pi _ _ _) "3:Pi"]
    [(expr-Sigma _ _) "3:Sigma"]
    [(expr-Eq _ _ _) "3:Eq"]
    [(expr-Vec _ _) "3:Vec"]
    [(expr-Fin _) "3:Fin"]
    [(expr-Map _ _) "3:Map"]
    [(expr-PVec _) "3:PVec"]
    [(expr-Set _) "3:Set"]
    [(expr-app _ _) "4:app"]
    [(expr-meta id) (format "5:?~a" id)]
    [_ "9:other"]))

(define (dedup-union-components-pure cs)
  (if (null? cs) '()
      (let loop ([prev (car cs)] [rest (cdr cs)] [acc (list (car cs))])
        (cond
          [(null? rest) (reverse acc)]
          [(equal? prev (car rest))
           (loop prev (cdr rest) acc)]
          [else
           (loop (car rest) (cdr rest) (cons (car rest) acc))]))))

(define (try-unify-pure-unions a b)
  (define cs-a (dedup-union-components-pure
                 (sort (flatten-union-pure a) string<? #:key union-sort-key-pure)))
  (define cs-b (dedup-union-components-pure
                 (sort (flatten-union-pure b) string<? #:key union-sort-key-pure)))
  (cond
    [(not (= (length cs-a) (length cs-b))) #f]
    [else
     ;; Pairwise unify components
     (define unified
       (for/list ([ca (in-list cs-a)]
                  [cb (in-list cs-b)])
         (try-unify-pure ca cb)))
     (cond
       [(ormap not unified) #f]
       ;; Reconstruct union from unified components
       [(= (length unified) 1) (car unified)]
       [else (foldr expr-union (last unified) (drop-right unified 1))])]))
