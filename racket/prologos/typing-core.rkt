#lang racket/base

;;;
;;; PROLOGOS TYPING-CORE
;;; Bidirectional type checker for the core dependent type theory.
;;; Direct translation of prologos-typing-core.maude + prologos-inductive.maude typing rules.
;;;
;;; infer(ctx, e)       -> Expr       : synthesize a type (or expr-error)
;;; check(ctx, e, T)    -> Bool       : check that e has type T
;;; is-type(ctx, T)     -> Bool       : verify T is a well-formed type
;;; infer-level(ctx, T) -> MaybeLevel : infer the universe level of type T
;;;
;;; IMPORTANT: When looking up bvar(K) in the context, the stored type
;;; must be shifted by (K+1) because it was stored relative to the context
;;; above position K, but we need it relative to the current scope.
;;;

(require racket/match
         racket/string

         "prelude.rkt"
         "syntax.rkt"
         "substitution.rkt"
         "reduction.rkt"
         "unify.rkt"
         "global-env.rkt"
         "macros.rkt"
         "namespace.rkt"
         "metavar-store.rkt"
         "warnings.rkt"
         "pretty-print.rkt"
)

(provide infer check is-type infer-level
         (struct-out no-level) (struct-out just-level)
         mark-structural-reduce! structural-reduce? structural-reduce-set
         subtype?
         list-type-fvar
         concrete-numeric-type? divisible-numeric-type? negatable-numeric-type?
         from-int-target-type? from-rat-target-type?
         numeric-join exact-numeric-type? posit-type?)

;; ========================================
;; Structural reduce tracking
;; ========================================
;; During type checking, expr-reduce nodes that need structural PM
;; (instead of Church fold) are recorded here. The driver uses this
;; to set the structural? flag before storing the body for evaluation.
(define structural-reduce-set (make-hasheq))

(define (mark-structural-reduce! reduce-expr)
  (hash-set! structural-reduce-set reduce-expr #t))

(define (structural-reduce? reduce-expr)
  (hash-ref structural-reduce-set reduce-expr #f))

;; ========================================
;; MaybeLevel: result of inferLevel
;; ========================================
(struct no-level () #:transparent)
(struct just-level (level) #:transparent)

;; ========================================
;; Within-family subtype predicate (Phase 3e)
;; ========================================
;; Automatic widening within two type families:
;;   Exact:  Nat <: Int <: Rat
;;   Posit:  Posit8 <: Posit16 <: Posit32 <: Posit64
;; All 9 edges enumerated directly (small, fixed relation — no transitive closure needed).
;; Arguments: (subtype? inferred expected) — is inferred a subtype of expected?
(define (subtype? t1 t2)
  (match* (t1 t2)
    ;; Exact: Nat <: Int <: Rat
    [((expr-Nat) (expr-Int)) #t]
    [((expr-Nat) (expr-Rat)) #t]
    [((expr-Int) (expr-Rat)) #t]
    ;; Posit: 8 <: 16 <: 32 <: 64
    [((expr-Posit8)  (expr-Posit16)) #t]
    [((expr-Posit8)  (expr-Posit32)) #t]
    [((expr-Posit8)  (expr-Posit64)) #t]
    [((expr-Posit16) (expr-Posit32)) #t]
    [((expr-Posit16) (expr-Posit64)) #t]
    [((expr-Posit32) (expr-Posit64)) #t]
    [(_ _) #f]))

;; ========================================
;; Forward declarations for mutual recursion
;; ========================================
;; infer, check, is-type, infer-level are all mutually recursive.
;; In Racket, top-level defines can reference each other, so no forward decl needed.

;; ========================================
;; List type fvar resolution
;; ========================================
;; In module contexts, 'List' is qualified as 'prologos::data::list::List'.
;; In bare (no-prelude) contexts, it's just 'List'.
;; This helper returns the correct expr-fvar for constructing List types
;; in typing rules for map-keys, map-vals, set-to-list, pvec-to-list.
(define (list-type-fvar)
  (if (global-env-lookup-type 'prologos::data::list::List)
      (expr-fvar 'prologos::data::list::List)
      (expr-fvar 'List)))

;; ========================================
;; Generic arithmetic type helpers
;; ========================================
;; Concrete numeric types for which generic operators are valid.
(define (concrete-numeric-type? t)
  (or (expr-Nat? t) (expr-Int? t) (expr-Rat? t)
      (expr-Posit8? t) (expr-Posit16? t)
      (expr-Posit32? t) (expr-Posit64? t)))

;; Types that support division (excludes Nat).
(define (divisible-numeric-type? t)
  (or (expr-Int? t) (expr-Rat? t)
      (expr-Posit8? t) (expr-Posit16? t)
      (expr-Posit32? t) (expr-Posit64? t)))

;; Types that support negation (excludes Nat).
(define (negatable-numeric-type? t)
  (or (expr-Int? t) (expr-Rat? t)
      (expr-Posit8? t) (expr-Posit16? t)
      (expr-Posit32? t) (expr-Posit64? t)))

;; Valid target types for from-integer (Int -> T): Int, Rat, Posit8-64.
(define (from-int-target-type? t)
  (or (expr-Int? t) (expr-Rat? t)
      (expr-Posit8? t) (expr-Posit16? t)
      (expr-Posit32? t) (expr-Posit64? t)))

;; Valid target types for from-rational (Rat -> T): Rat, Posit8-64.
(define (from-rat-target-type? t)
  (or (expr-Rat? t)
      (expr-Posit8? t) (expr-Posit16? t)
      (expr-Posit32? t) (expr-Posit64? t)))

;; ========================================
;; Numeric type join (least upper bound)
;; ========================================
;; exact-numeric-type? — Nat, Int, Rat (exact family)
(define (exact-numeric-type? t)
  (or (expr-Nat? t) (expr-Int? t) (expr-Rat? t)))

;; posit-type? — Posit8, Posit16, Posit32, Posit64 (approximate family)
(define (posit-type? t)
  (or (expr-Posit8? t) (expr-Posit16? t) (expr-Posit32? t) (expr-Posit64? t)))

;; Rank within exact family: Nat < Int < Rat
(define (exact-rank t)
  (cond [(expr-Nat? t) 0] [(expr-Int? t) 1] [(expr-Rat? t) 2] [else -1]))

;; Rank within posit family: P8 < P16 < P32 < P64
(define (posit-rank t)
  (cond [(expr-Posit8? t) 0] [(expr-Posit16? t) 1]
        [(expr-Posit32? t) 2] [(expr-Posit64? t) 3] [else -1]))

;; Type at a given exact rank
(define (exact-type-at-rank r)
  (case r [(0) (expr-Nat)] [(1) (expr-Int)] [(2) (expr-Rat)] [else #f]))

;; Type at a given posit rank
(define (posit-type-at-rank r)
  (case r [(0) (expr-Posit8)] [(1) (expr-Posit16)]
          [(2) (expr-Posit32)] [(3) (expr-Posit64)] [else #f]))

;; numeric-join: least upper bound of two numeric types.
;; Returns the wider type, or #f if not numeric types.
;; Within-family: wider wins (Nat < Int < Rat; P8 < P16 < P32 < P64).
;; Cross-family: posit wins (approximate dominates exact).
;; The resulting posit width is max(P32, posit operand width) for cross-family.
(define (numeric-join t1 t2)
  (cond
    ;; Same numeric type
    [(and (equal? t1 t2) (concrete-numeric-type? t1)) t1]
    ;; Both exact
    [(and (exact-numeric-type? t1) (exact-numeric-type? t2))
     (exact-type-at-rank (max (exact-rank t1) (exact-rank t2)))]
    ;; Both posit
    [(and (posit-type? t1) (posit-type? t2))
     (posit-type-at-rank (max (posit-rank t1) (posit-rank t2)))]
    ;; Cross-family: posit wins
    [(and (exact-numeric-type? t1) (posit-type? t2))
     ;; Posit dominates; ensure at least P32 for precision
     (posit-type-at-rank (max 2 (posit-rank t2)))]
    [(and (posit-type? t1) (exact-numeric-type? t2))
     (posit-type-at-rank (max 2 (posit-rank t1)))]
    ;; Not numeric types
    [else #f]))

;; Human-readable name for a numeric type expression (for warnings).
(define (numeric-type-name t)
  (cond
    [(expr-Nat? t) "Nat"] [(expr-Int? t) "Int"] [(expr-Rat? t) "Rat"]
    [(expr-Posit8? t) "Posit8"] [(expr-Posit16? t) "Posit16"]
    [(expr-Posit32? t) "Posit32"] [(expr-Posit64? t) "Posit64"]
    [else "?"]))

;; numeric-join with coercion warning: emit a warning when exact→posit coercion occurs.
(define (numeric-join/warn! t1 t2)
  (define j (numeric-join t1 t2))
  (when (and j (not (equal? t1 t2)))
    ;; Cross-family: one exact, one posit → loss of exactness
    (when (or (and (exact-numeric-type? t1) (posit-type? t2))
              (and (posit-type? t1) (exact-numeric-type? t2))
              ;; Also warn if both exact but result is approximate (shouldn't happen,
              ;; but guard anyway)
              )
      ;; Determine which operand is exact
      (define exact-t (cond [(exact-numeric-type? t1) t1]
                            [(exact-numeric-type? t2) t2]
                            [else #f]))
      (when exact-t
        (emit-coercion-warning! (numeric-type-name exact-t)
                                (numeric-type-name j)))))
  j)

;; ========================================
;; Type inference (synthesis mode)
;; ========================================
(define (infer ctx e)
  (match e
    ;; ---- Bound variable: lookup in context and SHIFT the type ----
    [(expr-bvar k)
     (if (< k (ctx-len ctx))
         (shift (+ k 1) 0 (lookup-type k ctx))
         (expr-error))]

    ;; ---- Free variable: lookup in global environment ----
    [(expr-fvar name)
     (let ([ty (global-env-lookup-type name)])
       (when ty
         ;; Check for deprecation warning
         (let ([se (lookup-spec name)])
           (when se
             (let ([md (spec-entry-metadata se)])
               (when md
                 (let ([dep (hash-ref md ':deprecated #f)])
                   (when dep
                     (emit-deprecation-warning!
                      name
                      (if (string? dep) dep #f)))))))))
       (if ty ty (expr-error)))]

    ;; ---- Universes ----
    ;; Type(n) : Type(n+1)
    [(expr-Type l) (expr-Type (lsuc l))]

    ;; ---- Pi type formation ----
    ;; Pi(m, A, B) : Type(max(level(A), level(B)))
    [(expr-Pi m a b)
     (match (infer-level ctx (expr-Pi m a b))
       [(just-level l) (expr-Type l)]
       [_ (expr-error)])]

    ;; ---- Sigma type formation ----
    ;; Sigma(A, B) : Type(max(level(A), level(B)))
    [(expr-Sigma a b)
     (match (infer-level ctx (expr-Sigma a b))
       [(just-level l) (expr-Type l)]
       [_ (expr-error)])]

    ;; ---- Eq type formation ----
    ;; Eq(A, a, b) : Type(level(A))
    [(expr-Eq a e1 e2)
     (match (infer-level ctx (expr-Eq a e1 e2))
       [(just-level l) (expr-Type l)]
       [_ (expr-error)])]

    ;; ---- Union type formation ----
    ;; A | B : Type(max(level(A), level(B)))
    [(expr-union l r)
     (match (infer-level ctx (expr-union l r))
       [(just-level lv) (expr-Type lv)]
       [_ (expr-error)])]

    ;; ---- Unapplied type constructor (HKT) ----
    ;; Returns the kind as a curried Pi type: Type -> Type -> ... -> Type
    ;; Arity from builtin-tycon-arity table
    [(expr-tycon name)
     (let ([arity (hash-ref builtin-tycon-arity name #f)])
       (if arity
           (let loop ([n arity])
             (if (= n 0)
                 (expr-Type (lzero))
                 (expr-Pi 'm0 (expr-Type (lzero)) (loop (sub1 n)))))
           (expr-error)))]

    ;; ---- Natural numbers ----
    [(expr-Nat) (expr-Type (lzero))]
    [(expr-zero) (expr-Nat)]
    ;; suc in synthesis: if argument infers to Nat
    [(expr-suc e1)
     (if (equal? (infer ctx e1) (expr-Nat))
         (expr-Nat)
         (expr-error))]

    ;; ---- Booleans ----
    [(expr-Bool) (expr-Type (lzero))]
    [(expr-true) (expr-Bool)]
    [(expr-false) (expr-Bool)]

    ;; ---- Unit ----
    [(expr-Unit) (expr-Type (lzero))]
    [(expr-unit) (expr-Unit)]

    ;; ---- Annotated terms ----
    ;; ann(e, T) synthesizes T if T is a type and e checks against T
    [(expr-ann e1 t)
     (if (and (is-type ctx t) (check ctx e1 t))
         t
         (expr-error))]

    ;; ---- Pi elimination (application) ----
    [(expr-app e1 e2)
     (match e1
       ;; Special case: ((lam m A body) arg) — direct beta-typed application
       ;; The lambda's domain gives us the argument type, and we infer the body
       ;; type in the extended context. This supports let-expansion and similar patterns.
       [(expr-lam m dom body)
        (cond
          ;; Hole domain: infer arg type and use as domain (let type inference)
          [(expr-hole? dom)
           (let ([arg-ty (infer ctx e2)])
             (if (equal? arg-ty (expr-error))
                 (expr-error)
                 (let ([body-ty (infer (ctx-extend ctx arg-ty m) body)])
                   (if (equal? body-ty (expr-error))
                       (expr-error)
                       (subst 0 e2 body-ty)))))]
          ;; Explicit domain: check arg against it
          [(and (is-type ctx dom)
                (check ctx e2 dom))
           (let ([body-ty (infer (ctx-extend ctx dom m) body)])
             (if (equal? body-ty (expr-error))
                 (expr-error)
                 (subst 0 e2 body-ty)))]
          [else (expr-error)])]
       ;; General case: infer function type, check argument
       [_
        (let ([t1 (whnf (infer ctx e1))])
          (match t1
            [(expr-Pi m a b)
             (if (check ctx e2 a)
                 (subst 0 e2 b)
                 (expr-error))]
            [_ (expr-error)]))])]

    ;; ---- Sigma elimination: fst ----
    [(expr-fst e1)
     (let ([t (whnf (infer ctx e1))])
       (match t
         [(expr-Sigma a _) a]
         [_ (expr-error)]))]

    ;; ---- Sigma elimination: snd ----
    [(expr-snd e1)
     (let ([t (whnf (infer ctx e1))])
       (match t
         [(expr-Sigma _ b) (subst 0 (expr-fst e1) b)]
         [_ (expr-error)]))]

    ;; ---- Bool eliminator (boolrec) ----
    ;; boolrec(motive, true-case, false-case, target)
    ;; motive : Bool -> Type(l)
    ;; true-case : motive(true)
    ;; false-case : motive(false)
    ;; target : Bool
    ;; result type: app(motive, target)
    ;;
    ;; Note: The motive's codomain is not explicitly verified to be Type(l).
    ;; This is safe because the result type app(mot, target) propagates upward,
    ;; and any consumer that uses it as a type will fail if it's not one.
    ;; Adding is-type here causes re-entrancy issues with mult-meta solving.
    [(expr-boolrec mot tc fc target)
     (let ([mot-ty (whnf (infer ctx mot))])
       (match mot-ty
         [(expr-Pi _ dom _)
          (if (and (unify-ok? (unify ctx dom (expr-Bool)))
                   (check ctx tc (expr-app mot (expr-true)))
                   (check ctx fc (expr-app mot (expr-false)))
                   (check ctx target (expr-Bool)))
              (expr-app mot target)
              (expr-error))]
         [_ (expr-error)]))]

    ;; ---- Nat eliminator (natrec) ----
    ;; natrec(motive, base, step, target)
    ;; motive : Nat → Type(l)
    ;; base   : motive(zero)
    ;; step   : Π(n:Nat). motive(n) → motive(suc(n))
    ;; target : Nat
    ;; result type: app(motive, target)
    [(expr-natrec mot base step target)
     (let ([step-type
            ;; Π(n:Nat). motive(n) → motive(suc(n))
            ;; Under one binder (n), mot must be shifted by 1.
            ;; Under two binders (n, rec), mot must be shifted by 2.
            (expr-Pi 'mw (expr-Nat)
              (expr-Pi 'mw (expr-app (shift 1 0 mot) (expr-bvar 0))
                (expr-app (shift 2 0 mot) (expr-suc (expr-bvar 1)))))])
       (if (and (check ctx target (expr-Nat))
                (check ctx base (expr-app mot (expr-zero)))
                (check ctx step step-type))
           (expr-app mot target)
           (expr-error)))]

    ;; ---- J eliminator ----
    ;; J(motive, base, left, right, proof)
    ;; motive : Π(a:A). Π(b:A). Eq(A,a,b) → Type(l)
    ;; base   : Π(a:A). motive(a, a, refl)
    ;; proof  : Eq(A, left, right)
    ;; result type: app(app(app(motive, left), right), proof)
    ;;
    ;; Note: The motive's codomain is not explicitly checked to be Type(l).
    ;; This is safe because the result type propagates upward, and any consumer
    ;; that uses it as a type will fail if it's not one. Adding is-type here
    ;; causes re-entrancy issues with mult-meta solving.
    [(expr-J mot base left right proof)
     (let ([pt (whnf (infer ctx proof))])
       (match pt
         [(expr-Eq t t1 t2)
          (if (and (unify-ok? (unify ctx t1 left))
                   (unify-ok? (unify ctx t2 right))
                   ;; Verify base has correct type: Π(a:A). motive(a, a, refl)
                   (check ctx base
                     (expr-Pi 'mw t
                       (expr-app (expr-app (expr-app (shift 1 0 mot) (expr-bvar 0))
                                           (expr-bvar 0))
                                 (expr-refl)))))
              (expr-app (expr-app (expr-app mot left) right) proof)
              (expr-error))]
         [_ (expr-error)]))]

    ;; ---- Vec eliminators ----
    ;; vhead(A, n, v) : A  when v : Vec(A, suc(n))
    [(expr-vhead a n v)
     (if (check ctx v (expr-Vec a (expr-suc n)))
         a
         (expr-error))]

    ;; vtail(A, n, v) : Vec(A, n)  when v : Vec(A, suc(n))
    [(expr-vtail a n v)
     (if (check ctx v (expr-Vec a (expr-suc n)))
         (expr-Vec a n)
         (expr-error))]

    ;; vindex(A, n, i, v) : A  when i : Fin(n) and v : Vec(A, n)
    [(expr-vindex a n i v)
     (if (and (check ctx i (expr-Fin n))
              (check ctx v (expr-Vec a n)))
         a
         (expr-error))]

    ;; ---- Int (arbitrary-precision integers) ----
    [(expr-Int) (expr-Type (lzero))]

    ;; int literal: val must be a Racket exact integer
    [(expr-int v)
     (if (exact-integer? v)
         (expr-Int)
         (expr-error))]

    ;; Binary arithmetic: Int -> Int -> Int
    [(expr-int-add a b)
     (if (and (check ctx a (expr-Int)) (check ctx b (expr-Int)))
         (expr-Int) (expr-error))]
    [(expr-int-sub a b)
     (if (and (check ctx a (expr-Int)) (check ctx b (expr-Int)))
         (expr-Int) (expr-error))]
    [(expr-int-mul a b)
     (if (and (check ctx a (expr-Int)) (check ctx b (expr-Int)))
         (expr-Int) (expr-error))]
    [(expr-int-div a b)
     (if (and (check ctx a (expr-Int)) (check ctx b (expr-Int)))
         (expr-Int) (expr-error))]
    [(expr-int-mod a b)
     (if (and (check ctx a (expr-Int)) (check ctx b (expr-Int)))
         (expr-Int) (expr-error))]

    ;; Unary ops: Int -> Int
    [(expr-int-neg a)
     (if (check ctx a (expr-Int)) (expr-Int) (expr-error))]
    [(expr-int-abs a)
     (if (check ctx a (expr-Int)) (expr-Int) (expr-error))]

    ;; Comparison: Int -> Int -> Bool
    [(expr-int-lt a b)
     (if (and (check ctx a (expr-Int)) (check ctx b (expr-Int)))
         (expr-Bool) (expr-error))]
    [(expr-int-le a b)
     (if (and (check ctx a (expr-Int)) (check ctx b (expr-Int)))
         (expr-Bool) (expr-error))]
    [(expr-int-eq a b)
     (if (and (check ctx a (expr-Int)) (check ctx b (expr-Int)))
         (expr-Bool) (expr-error))]

    ;; Conversion: Nat -> Int
    [(expr-from-nat n)
     (if (check ctx n (expr-Nat)) (expr-Int) (expr-error))]

    ;; ---- Rat (exact rationals) ----
    [(expr-Rat) (expr-Type (lzero))]

    ;; rat literal: val must be a Racket exact rational
    [(expr-rat v)
     (if (and (exact? v) (rational? v))
         (expr-Rat)
         (expr-error))]

    ;; Binary arithmetic: Rat -> Rat -> Rat
    [(expr-rat-add a b)
     (if (and (check ctx a (expr-Rat)) (check ctx b (expr-Rat)))
         (expr-Rat) (expr-error))]
    [(expr-rat-sub a b)
     (if (and (check ctx a (expr-Rat)) (check ctx b (expr-Rat)))
         (expr-Rat) (expr-error))]
    [(expr-rat-mul a b)
     (if (and (check ctx a (expr-Rat)) (check ctx b (expr-Rat)))
         (expr-Rat) (expr-error))]
    [(expr-rat-div a b)
     (if (and (check ctx a (expr-Rat)) (check ctx b (expr-Rat)))
         (expr-Rat) (expr-error))]

    ;; Unary ops: Rat -> Rat
    [(expr-rat-neg a)
     (if (check ctx a (expr-Rat)) (expr-Rat) (expr-error))]
    [(expr-rat-abs a)
     (if (check ctx a (expr-Rat)) (expr-Rat) (expr-error))]

    ;; Comparison: Rat -> Rat -> Bool
    [(expr-rat-lt a b)
     (if (and (check ctx a (expr-Rat)) (check ctx b (expr-Rat)))
         (expr-Bool) (expr-error))]
    [(expr-rat-le a b)
     (if (and (check ctx a (expr-Rat)) (check ctx b (expr-Rat)))
         (expr-Bool) (expr-error))]
    [(expr-rat-eq a b)
     (if (and (check ctx a (expr-Rat)) (check ctx b (expr-Rat)))
         (expr-Bool) (expr-error))]

    ;; Conversion: Int -> Rat
    [(expr-from-int n)
     (if (check ctx n (expr-Int)) (expr-Rat) (expr-error))]

    ;; Projections: Rat -> Int
    [(expr-rat-numer a)
     (if (check ctx a (expr-Rat)) (expr-Int) (expr-error))]
    [(expr-rat-denom a)
     (if (check ctx a (expr-Rat)) (expr-Int) (expr-error))]

    ;; ---- Generic arithmetic operators ----
    ;; Binary arithmetic: T1 -> T2 -> join(T1,T2) (coercion via numeric-join)
    [(expr-generic-add a b)
     (let* ([ta (infer ctx a)] [tb (infer ctx b)]
            [j (numeric-join/warn! ta tb)])
       (if j j (expr-error)))]
    [(expr-generic-sub a b)
     (let* ([ta (infer ctx a)] [tb (infer ctx b)]
            [j (numeric-join/warn! ta tb)])
       (if j j (expr-error)))]
    [(expr-generic-mul a b)
     (let* ([ta (infer ctx a)] [tb (infer ctx b)]
            [j (numeric-join/warn! ta tb)])
       (if j j (expr-error)))]
    [(expr-generic-div a b)
     (let* ([ta (infer ctx a)] [tb (infer ctx b)]
            [j (numeric-join/warn! ta tb)])
       (if (and j (divisible-numeric-type? j)) j (expr-error)))]

    ;; Binary comparison: T1 -> T2 -> Bool (coercion via numeric-join)
    [(expr-generic-lt a b)
     (let* ([ta (infer ctx a)] [tb (infer ctx b)]
            [j (numeric-join/warn! ta tb)])
       (if j (expr-Bool) (expr-error)))]
    [(expr-generic-le a b)
     (let* ([ta (infer ctx a)] [tb (infer ctx b)]
            [j (numeric-join/warn! ta tb)])
       (if j (expr-Bool) (expr-error)))]
    [(expr-generic-eq a b)
     (let* ([ta (infer ctx a)] [tb (infer ctx b)]
            [j (numeric-join/warn! ta tb)])
       (if j (expr-Bool) (expr-error)))]

    ;; Unary: T -> T
    [(expr-generic-negate a)
     (let ([ta (infer ctx a)])
       (if (negatable-numeric-type? ta) ta (expr-error)))]
    [(expr-generic-abs a)
     (let ([ta (infer ctx a)])
       (if (concrete-numeric-type? ta) ta (expr-error)))]

    ;; Generic conversion: from-integer TargetType val (Int -> T)
    [(expr-generic-from-int target-type arg)
     (let ([tt (infer ctx target-type)])
       (cond
         [(not (expr-Type? tt)) (expr-error)]   ; target must be a type
         [(not (from-int-target-type? target-type)) (expr-error)]
         [(not (check ctx arg (expr-Int))) (expr-error)]
         [else target-type]))]
    ;; Generic conversion: from-rational TargetType val (Rat -> T)
    [(expr-generic-from-rat target-type arg)
     (let ([tt (infer ctx target-type)])
       (cond
         [(not (expr-Type? tt)) (expr-error)]   ; target must be a type
         [(not (from-rat-target-type? target-type)) (expr-error)]
         [(not (check ctx arg (expr-Rat))) (expr-error)]
         [else target-type]))]

    ;; ---- Posit8 ----
    [(expr-Posit8) (expr-Type (lzero))]

    ;; posit8 literal
    [(expr-posit8 v)
     (if (and (exact-integer? v) (<= 0 v 255))
         (expr-Posit8)
         (expr-error))]

    ;; Binary arithmetic: Posit8 -> Posit8 -> Posit8
    [(expr-p8-add a b)
     (if (and (check ctx a (expr-Posit8)) (check ctx b (expr-Posit8)))
         (expr-Posit8) (expr-error))]
    [(expr-p8-sub a b)
     (if (and (check ctx a (expr-Posit8)) (check ctx b (expr-Posit8)))
         (expr-Posit8) (expr-error))]
    [(expr-p8-mul a b)
     (if (and (check ctx a (expr-Posit8)) (check ctx b (expr-Posit8)))
         (expr-Posit8) (expr-error))]
    [(expr-p8-div a b)
     (if (and (check ctx a (expr-Posit8)) (check ctx b (expr-Posit8)))
         (expr-Posit8) (expr-error))]

    ;; Unary ops: Posit8 -> Posit8
    [(expr-p8-neg a)
     (if (check ctx a (expr-Posit8)) (expr-Posit8) (expr-error))]
    [(expr-p8-abs a)
     (if (check ctx a (expr-Posit8)) (expr-Posit8) (expr-error))]
    [(expr-p8-sqrt a)
     (if (check ctx a (expr-Posit8)) (expr-Posit8) (expr-error))]

    ;; Comparison: Posit8 -> Posit8 -> Bool
    [(expr-p8-lt a b)
     (if (and (check ctx a (expr-Posit8)) (check ctx b (expr-Posit8)))
         (expr-Bool) (expr-error))]
    [(expr-p8-le a b)
     (if (and (check ctx a (expr-Posit8)) (check ctx b (expr-Posit8)))
         (expr-Bool) (expr-error))]
    [(expr-p8-eq a b)
     (if (and (check ctx a (expr-Posit8)) (check ctx b (expr-Posit8)))
         (expr-Bool) (expr-error))]

    ;; Conversion: Nat -> Posit8
    [(expr-p8-from-nat n)
     (if (check ctx n (expr-Nat)) (expr-Posit8) (expr-error))]

    ;; Phase 3f: Cross-family conversions for Posit8
    [(expr-p8-to-rat a)
     (if (check ctx a (expr-Posit8)) (expr-Rat) (expr-error))]
    [(expr-p8-from-rat a)
     (if (check ctx a (expr-Rat)) (expr-Posit8) (expr-error))]
    [(expr-p8-from-int a)
     (if (check ctx a (expr-Int)) (expr-Posit8) (expr-error))]

    ;; p8-if-nar(A, nar-case, normal-case, val) : A
    [(expr-p8-if-nar tp nc vc v)
     (if (and (is-type ctx tp)
              (check ctx nc tp)
              (check ctx vc tp)
              (check ctx v (expr-Posit8)))
         tp (expr-error))]

    ;; ---- Posit16 ----
    [(expr-Posit16) (expr-Type (lzero))]

    ;; posit16 literal
    [(expr-posit16 v)
     (if (and (exact-integer? v) (<= 0 v 65535))
         (expr-Posit16)
         (expr-error))]

    ;; Binary arithmetic: Posit16 -> Posit16 -> Posit16
    [(expr-p16-add a b)
     (if (and (check ctx a (expr-Posit16)) (check ctx b (expr-Posit16)))
         (expr-Posit16) (expr-error))]
    [(expr-p16-sub a b)
     (if (and (check ctx a (expr-Posit16)) (check ctx b (expr-Posit16)))
         (expr-Posit16) (expr-error))]
    [(expr-p16-mul a b)
     (if (and (check ctx a (expr-Posit16)) (check ctx b (expr-Posit16)))
         (expr-Posit16) (expr-error))]
    [(expr-p16-div a b)
     (if (and (check ctx a (expr-Posit16)) (check ctx b (expr-Posit16)))
         (expr-Posit16) (expr-error))]

    ;; Unary ops: Posit16 -> Posit16
    [(expr-p16-neg a)
     (if (check ctx a (expr-Posit16)) (expr-Posit16) (expr-error))]
    [(expr-p16-abs a)
     (if (check ctx a (expr-Posit16)) (expr-Posit16) (expr-error))]
    [(expr-p16-sqrt a)
     (if (check ctx a (expr-Posit16)) (expr-Posit16) (expr-error))]

    ;; Comparison: Posit16 -> Posit16 -> Bool
    [(expr-p16-lt a b)
     (if (and (check ctx a (expr-Posit16)) (check ctx b (expr-Posit16)))
         (expr-Bool) (expr-error))]
    [(expr-p16-le a b)
     (if (and (check ctx a (expr-Posit16)) (check ctx b (expr-Posit16)))
         (expr-Bool) (expr-error))]
    [(expr-p16-eq a b)
     (if (and (check ctx a (expr-Posit16)) (check ctx b (expr-Posit16)))
         (expr-Bool) (expr-error))]

    ;; Conversion: Nat -> Posit16
    [(expr-p16-from-nat n)
     (if (check ctx n (expr-Nat)) (expr-Posit16) (expr-error))]

    ;; Phase 3f: Cross-family conversions for Posit16
    [(expr-p16-to-rat a)
     (if (check ctx a (expr-Posit16)) (expr-Rat) (expr-error))]
    [(expr-p16-from-rat a)
     (if (check ctx a (expr-Rat)) (expr-Posit16) (expr-error))]
    [(expr-p16-from-int a)
     (if (check ctx a (expr-Int)) (expr-Posit16) (expr-error))]

    ;; p16-if-nar(A, nar-case, normal-case, val) : A
    [(expr-p16-if-nar tp nc vc v)
     (if (and (is-type ctx tp)
              (check ctx nc tp)
              (check ctx vc tp)
              (check ctx v (expr-Posit16)))
         tp (expr-error))]

    ;; ---- Posit32 ----
    [(expr-Posit32) (expr-Type (lzero))]

    ;; posit32 literal
    [(expr-posit32 v)
     (if (and (exact-integer? v) (<= 0 v 4294967295))
         (expr-Posit32)
         (expr-error))]

    ;; Binary arithmetic: Posit32 -> Posit32 -> Posit32
    [(expr-p32-add a b)
     (if (and (check ctx a (expr-Posit32)) (check ctx b (expr-Posit32)))
         (expr-Posit32) (expr-error))]
    [(expr-p32-sub a b)
     (if (and (check ctx a (expr-Posit32)) (check ctx b (expr-Posit32)))
         (expr-Posit32) (expr-error))]
    [(expr-p32-mul a b)
     (if (and (check ctx a (expr-Posit32)) (check ctx b (expr-Posit32)))
         (expr-Posit32) (expr-error))]
    [(expr-p32-div a b)
     (if (and (check ctx a (expr-Posit32)) (check ctx b (expr-Posit32)))
         (expr-Posit32) (expr-error))]

    ;; Unary ops: Posit32 -> Posit32
    [(expr-p32-neg a)
     (if (check ctx a (expr-Posit32)) (expr-Posit32) (expr-error))]
    [(expr-p32-abs a)
     (if (check ctx a (expr-Posit32)) (expr-Posit32) (expr-error))]
    [(expr-p32-sqrt a)
     (if (check ctx a (expr-Posit32)) (expr-Posit32) (expr-error))]

    ;; Comparison: Posit32 -> Posit32 -> Bool
    [(expr-p32-lt a b)
     (if (and (check ctx a (expr-Posit32)) (check ctx b (expr-Posit32)))
         (expr-Bool) (expr-error))]
    [(expr-p32-le a b)
     (if (and (check ctx a (expr-Posit32)) (check ctx b (expr-Posit32)))
         (expr-Bool) (expr-error))]
    [(expr-p32-eq a b)
     (if (and (check ctx a (expr-Posit32)) (check ctx b (expr-Posit32)))
         (expr-Bool) (expr-error))]

    ;; Conversion: Nat -> Posit32
    [(expr-p32-from-nat n)
     (if (check ctx n (expr-Nat)) (expr-Posit32) (expr-error))]

    ;; Phase 3f: Cross-family conversions for Posit32
    [(expr-p32-to-rat a)
     (if (check ctx a (expr-Posit32)) (expr-Rat) (expr-error))]
    [(expr-p32-from-rat a)
     (if (check ctx a (expr-Rat)) (expr-Posit32) (expr-error))]
    [(expr-p32-from-int a)
     (if (check ctx a (expr-Int)) (expr-Posit32) (expr-error))]

    ;; p32-if-nar(A, nar-case, normal-case, val) : A
    [(expr-p32-if-nar tp nc vc v)
     (if (and (is-type ctx tp)
              (check ctx nc tp)
              (check ctx vc tp)
              (check ctx v (expr-Posit32)))
         tp (expr-error))]

    ;; ---- Posit64 ----
    [(expr-Posit64) (expr-Type (lzero))]

    ;; posit64 literal
    [(expr-posit64 v)
     (if (and (exact-integer? v) (<= 0 v 18446744073709551615))
         (expr-Posit64)
         (expr-error))]

    ;; Binary arithmetic: Posit64 -> Posit64 -> Posit64
    [(expr-p64-add a b)
     (if (and (check ctx a (expr-Posit64)) (check ctx b (expr-Posit64)))
         (expr-Posit64) (expr-error))]
    [(expr-p64-sub a b)
     (if (and (check ctx a (expr-Posit64)) (check ctx b (expr-Posit64)))
         (expr-Posit64) (expr-error))]
    [(expr-p64-mul a b)
     (if (and (check ctx a (expr-Posit64)) (check ctx b (expr-Posit64)))
         (expr-Posit64) (expr-error))]
    [(expr-p64-div a b)
     (if (and (check ctx a (expr-Posit64)) (check ctx b (expr-Posit64)))
         (expr-Posit64) (expr-error))]

    ;; Unary ops: Posit64 -> Posit64
    [(expr-p64-neg a)
     (if (check ctx a (expr-Posit64)) (expr-Posit64) (expr-error))]
    [(expr-p64-abs a)
     (if (check ctx a (expr-Posit64)) (expr-Posit64) (expr-error))]
    [(expr-p64-sqrt a)
     (if (check ctx a (expr-Posit64)) (expr-Posit64) (expr-error))]

    ;; Comparison: Posit64 -> Posit64 -> Bool
    [(expr-p64-lt a b)
     (if (and (check ctx a (expr-Posit64)) (check ctx b (expr-Posit64)))
         (expr-Bool) (expr-error))]
    [(expr-p64-le a b)
     (if (and (check ctx a (expr-Posit64)) (check ctx b (expr-Posit64)))
         (expr-Bool) (expr-error))]
    [(expr-p64-eq a b)
     (if (and (check ctx a (expr-Posit64)) (check ctx b (expr-Posit64)))
         (expr-Bool) (expr-error))]

    ;; Conversion: Nat -> Posit64
    [(expr-p64-from-nat n)
     (if (check ctx n (expr-Nat)) (expr-Posit64) (expr-error))]

    ;; Phase 3f: Cross-family conversions for Posit64
    [(expr-p64-to-rat a)
     (if (check ctx a (expr-Posit64)) (expr-Rat) (expr-error))]
    [(expr-p64-from-rat a)
     (if (check ctx a (expr-Rat)) (expr-Posit64) (expr-error))]
    [(expr-p64-from-int a)
     (if (check ctx a (expr-Int)) (expr-Posit64) (expr-error))]

    ;; p64-if-nar(A, nar-case, normal-case, val) : A
    [(expr-p64-if-nar tp nc vc v)
     (if (and (is-type ctx tp)
              (check ctx nc tp)
              (check ctx vc tp)
              (check ctx v (expr-Posit64)))
         tp (expr-error))]

    ;; ---- Quire types ----
    ;; QuireW : Type 0
    [(expr-Quire8) (expr-Type (lzero))]
    [(expr-Quire16) (expr-Type (lzero))]
    [(expr-Quire32) (expr-Type (lzero))]
    [(expr-Quire64) (expr-Type (lzero))]

    ;; quireW-val: runtime literal → QuireW
    [(expr-quire8-val _) (expr-Quire8)]
    [(expr-quire16-val _) (expr-Quire16)]
    [(expr-quire32-val _) (expr-Quire32)]
    [(expr-quire64-val _) (expr-Quire64)]

    ;; quireW-fma: QuireW → PositW → PositW → QuireW
    [(expr-quire8-fma q a b)
     (if (and (check ctx q (expr-Quire8))
              (check ctx a (expr-Posit8))
              (check ctx b (expr-Posit8)))
         (expr-Quire8) (expr-error))]
    [(expr-quire16-fma q a b)
     (if (and (check ctx q (expr-Quire16))
              (check ctx a (expr-Posit16))
              (check ctx b (expr-Posit16)))
         (expr-Quire16) (expr-error))]
    [(expr-quire32-fma q a b)
     (if (and (check ctx q (expr-Quire32))
              (check ctx a (expr-Posit32))
              (check ctx b (expr-Posit32)))
         (expr-Quire32) (expr-error))]
    [(expr-quire64-fma q a b)
     (if (and (check ctx q (expr-Quire64))
              (check ctx a (expr-Posit64))
              (check ctx b (expr-Posit64)))
         (expr-Quire64) (expr-error))]

    ;; quireW-to: QuireW → PositW
    [(expr-quire8-to q)
     (if (check ctx q (expr-Quire8)) (expr-Posit8) (expr-error))]
    [(expr-quire16-to q)
     (if (check ctx q (expr-Quire16)) (expr-Posit16) (expr-error))]
    [(expr-quire32-to q)
     (if (check ctx q (expr-Quire32)) (expr-Posit32) (expr-error))]
    [(expr-quire64-to q)
     (if (check ctx q (expr-Quire64)) (expr-Posit64) (expr-error))]

    ;; ---- Symbol type and literals ----
    [(expr-Symbol) (expr-Type (lzero))]
    [(expr-symbol _) (expr-Symbol)]

    ;; ---- Keyword type and literals ----
    [(expr-Keyword) (expr-Type (lzero))]
    [(expr-keyword _) (expr-Keyword)]

    ;; ---- Char type and literals ----
    [(expr-Char) (expr-Type (lzero))]
    [(expr-char _) (expr-Char)]

    ;; ---- String type and literals ----
    [(expr-String) (expr-Type (lzero))]
    [(expr-string _) (expr-String)]

    ;; ---- Map type and operations ----
    [(expr-Map k v)
     (if (and (is-type ctx k) (is-type ctx v))
         (expr-Type (lzero))
         (expr-error))]
    [(expr-champ _) (expr-error)]  ;; champ needs checking context
    [(expr-map-empty k v)
     (if (and (is-type ctx k) (is-type ctx v))
         (expr-Map k v)
         (expr-error))]
    [(expr-map-assoc m k v)
     (let ([tm (infer ctx m)])
       (match tm
         [(expr-Map kt vt)
          (cond
            ;; Key must check against key type
            [(not (check ctx k kt)) (expr-error)]
            ;; Value fits existing value type — no widening needed
            [(let ([saved (save-meta-state)])
               (if (check ctx v vt)
                   #t
                   (begin (restore-meta-state! saved) #f)))
             (expr-Map kt vt)]
            ;; Value doesn't fit — widen via union
            [else
             (let ([tv (infer ctx v)])
               (if (expr-error? tv)
                   (expr-error)
                   ;; whnf resolves solved metas so build-union-type
                   ;; sees concrete types, not raw meta references
                   (expr-Map kt (build-union-type (list (whnf vt) tv)))))])]
         [_ (expr-error)]))]
    [(expr-map-get m k)
     (let ([tm (whnf (infer ctx m))])
       (match tm
         [(expr-Map kt vt)
          (if (check ctx k kt) vt (expr-error))]
         [(expr-union _ _)
          ;; Union type: extract Map components, check key, collect value types
          (let* ([components (flatten-union tm)]
                 [map-vts
                  (let loop ([cs components] [acc '()])
                    (if (null? cs)
                        (reverse acc)
                        (let ([c* (whnf (car cs))])
                          (if (expr-Map? c*)
                              (let ([saved (save-meta-state)])
                                (if (check ctx k (expr-Map-k-type c*))
                                    (loop (cdr cs) (cons (expr-Map-v-type c*) acc))
                                    (begin (restore-meta-state! saved)
                                           (loop (cdr cs) acc))))
                              (loop (cdr cs) acc)))))])
            (if (null? map-vts)
                (expr-error)
                (build-union-type map-vts)))]
         [_ (expr-error)]))]
    [(expr-map-dissoc m k)
     (let ([tm (infer ctx m)])
       (match tm
         [(expr-Map kt vt)
          (if (check ctx k kt) (expr-Map kt vt) (expr-error))]
         [_ (expr-error)]))]
    [(expr-map-size m)
     (let ([tm (infer ctx m)])
       (match tm
         [(expr-Map _ _) (expr-Nat)]
         [_ (expr-error)]))]
    [(expr-map-has-key m k)
     (let ([tm (infer ctx m)])
       (match tm
         [(expr-Map kt _)
          (if (check ctx k kt) (expr-Bool) (expr-error))]
         [_ (expr-error)]))]
    ;; map-keys: Map K V → List K
    [(expr-map-keys m)
     (let ([tm (infer ctx m)])
       (match tm
         [(expr-Map kt _) (expr-app (list-type-fvar) kt)]
         [_ (expr-error)]))]
    ;; map-vals: Map K V → List V
    [(expr-map-vals m)
     (let ([tm (infer ctx m)])
       (match tm
         [(expr-Map _ vt) (expr-app (list-type-fvar) vt)]
         [_ (expr-error)]))]

    ;; ---- Set type and operations ----
    [(expr-Set a)
     (match (infer-level ctx a)
       [(just-level l) (expr-Type l)]
       [_ (expr-error)])]
    [(expr-hset _) (expr-error)]  ;; hset needs checking context
    [(expr-set-empty a)
     (if (is-type ctx a) (expr-Set a) (expr-error))]
    [(expr-set-insert s a)
     (let ([ts (whnf (infer ctx s))])
       (match ts
         [(expr-Set a-ty)
          (if (check ctx a a-ty) (expr-Set a-ty) (expr-error))]
         [_ (expr-error)]))]
    [(expr-set-member s a)
     (let ([ts (whnf (infer ctx s))])
       (match ts
         [(expr-Set a-ty)
          (if (check ctx a a-ty) (expr-Bool) (expr-error))]
         [_ (expr-error)]))]
    [(expr-set-delete s a)
     (let ([ts (whnf (infer ctx s))])
       (match ts
         [(expr-Set a-ty)
          (if (check ctx a a-ty) (expr-Set a-ty) (expr-error))]
         [_ (expr-error)]))]
    [(expr-set-size s)
     (let ([ts (whnf (infer ctx s))])
       (match ts
         [(expr-Set _) (expr-Nat)]
         [_ (expr-error)]))]
    [(expr-set-union s1 s2)
     (let ([ts1 (whnf (infer ctx s1))])
       (match ts1
         [(expr-Set a-ty)
          (if (check ctx s2 (expr-Set a-ty)) (expr-Set a-ty) (expr-error))]
         [_ (expr-error)]))]
    [(expr-set-intersect s1 s2)
     (let ([ts1 (whnf (infer ctx s1))])
       (match ts1
         [(expr-Set a-ty)
          (if (check ctx s2 (expr-Set a-ty)) (expr-Set a-ty) (expr-error))]
         [_ (expr-error)]))]
    [(expr-set-diff s1 s2)
     (let ([ts1 (whnf (infer ctx s1))])
       (match ts1
         [(expr-Set a-ty)
          (if (check ctx s2 (expr-Set a-ty)) (expr-Set a-ty) (expr-error))]
         [_ (expr-error)]))]
    ;; set-to-list: Set A → List A
    [(expr-set-to-list s)
     (let ([ts (infer ctx s)])
       (match ts
         [(expr-Set a) (expr-app (list-type-fvar) a)]
         [_ (expr-error)]))]

    ;; ---- PVec type and operations ----
    [(expr-PVec a)
     (if (is-type ctx a) (expr-Type (lzero)) (expr-error))]
    [(expr-rrb _) (expr-error)]   ;; rrb needs checking context
    [(expr-pvec-empty a)
     (if (is-type ctx a) (expr-PVec a) (expr-error))]
    [(expr-pvec-push v x)
     (let ([tv (infer ctx v)])
       (match tv
         [(expr-PVec a) (if (check ctx x a) (expr-PVec a) (expr-error))]
         [_ (expr-error)]))]
    [(expr-pvec-nth v i)
     (let ([tv (infer ctx v)])
       (match tv
         [(expr-PVec a) (if (check ctx i (expr-Nat)) a (expr-error))]
         [_ (expr-error)]))]
    [(expr-pvec-update v i x)
     (let ([tv (infer ctx v)])
       (match tv
         [(expr-PVec a) (if (and (check ctx i (expr-Nat)) (check ctx x a))
                            (expr-PVec a) (expr-error))]
         [_ (expr-error)]))]
    [(expr-pvec-length v)
     (let ([tv (infer ctx v)])
       (match tv
         [(expr-PVec _) (expr-Nat)]
         [_ (expr-error)]))]
    [(expr-pvec-pop v)
     (let ([tv (infer ctx v)])
       (match tv
         [(expr-PVec a) (expr-PVec a)]
         [_ (expr-error)]))]
    [(expr-pvec-concat v1 v2)
     (let ([tv1 (infer ctx v1)])
       (match tv1
         [(expr-PVec a) (if (check ctx v2 (expr-PVec a)) (expr-PVec a) (expr-error))]
         [_ (expr-error)]))]
    [(expr-pvec-slice v lo hi)
     (let ([tv (infer ctx v)])
       (match tv
         [(expr-PVec a) (if (and (check ctx lo (expr-Nat)) (check ctx hi (expr-Nat)))
                            (expr-PVec a) (expr-error))]
         [_ (expr-error)]))]
    ;; pvec-to-list : PVec A → List A
    [(expr-pvec-to-list v)
     (let ([tv (infer ctx v)])
       (match tv
         [(expr-PVec a) (expr-app (list-type-fvar) a)]
         [_ (expr-error)]))]
    ;; pvec-fold : (B → A → B) → B → PVec A → B
    ;; Left fold over a PVec: f takes (accumulator, element), returns accumulator.
    ;; Pi codomain types are shifted to account for the binder (de Bruijn convention).
    [(expr-pvec-fold f init vec)
     (let ([tv (infer ctx vec)]
           [tb (infer ctx init)])
       (match tv
         [(expr-PVec a)
          (let ([expected-f (expr-Pi 'mw tb (expr-Pi 'mw (shift 1 0 a) (shift 2 0 tb)))])
            (if (check ctx f expected-f)
                tb
                (expr-error)))]
         [_ (expr-error)]))]

    ;; pvec-map : (A → B) → PVec A → PVec B
    ;; Infers B from f's return type. Handles both named functions and lambdas.
    [(expr-pvec-map f vec)
     (let ([tv (infer ctx vec)])
       (match tv
         [(expr-PVec a)
          ;; Try to infer f's type first (works for named functions)
          (let ([tf (infer ctx f)])
            (if (equal? tf (expr-error))
                ;; Fallback for lambdas: check f against A → ?B by extending ctx
                (match f
                  [(expr-lam m dom body)
                   (let* ([actual-dom (if (expr-hole? dom) a (whnf dom))])
                     (if (or (expr-hole? dom) (unify-ok? (unify ctx actual-dom a)))
                         (let ([b (infer (cons (cons actual-dom 'mw) ctx) body)])
                           (if (equal? b (expr-error))
                               (expr-error)
                               ;; b is at extended depth; un-shift via subst
                               (expr-PVec (whnf (subst 0 (expr-zero) b)))))
                         (expr-error)))]
                  [_ (expr-error)])
                ;; Normal path: f inferred to Pi — un-shift codomain via subst
                (match (whnf tf)
                  [(expr-Pi _ dom cod)
                   (if (unify-ok? (unify ctx dom a))
                       (expr-PVec (whnf (subst 0 (expr-zero) cod)))
                       (expr-error))]
                  [_ (expr-error)])))]
         [_ (expr-error)]))]

    ;; pvec-filter : (A → Bool) → PVec A → PVec A
    [(expr-pvec-filter pred vec)
     (let ([tv (infer ctx vec)])
       (match tv
         [(expr-PVec a)
          (if (check ctx pred (expr-Pi 'mw a (expr-Bool)))
              (expr-PVec a)
              (expr-error))]
         [_ (expr-error)]))]

    ;; set-fold : (B → A → B) → B → Set A → B
    [(expr-set-fold f init set)
     (let ([ts (infer ctx set)]
           [tb (infer ctx init)])
       (match ts
         [(expr-Set a)
          (let ([expected-f (expr-Pi 'mw tb (expr-Pi 'mw (shift 1 0 a) (shift 2 0 tb)))])
            (if (check ctx f expected-f)
                tb
                (expr-error)))]
         [_ (expr-error)]))]

    ;; set-filter : (A → Bool) → Set A → Set A
    [(expr-set-filter pred set)
     (let ([ts (infer ctx set)])
       (match ts
         [(expr-Set a)
          (if (check ctx pred (expr-Pi 'mw a (expr-Bool)))
              (expr-Set a)
              (expr-error))]
         [_ (expr-error)]))]

    ;; map-fold-entries : (B → K → V → B) → B → Map K V → B
    [(expr-map-fold-entries f init map)
     (let ([tm (infer ctx map)]
           [tb (infer ctx init)])
       (match tm
         [(expr-Map k v)
          (let ([expected-f (expr-Pi 'mw tb
                              (expr-Pi 'mw (shift 1 0 k)
                                (expr-Pi 'mw (shift 2 0 v) (shift 3 0 tb))))])
            (if (check ctx f expected-f)
                tb
                (expr-error)))]
         [_ (expr-error)]))]

    ;; map-filter-entries : (K → V → Bool) → Map K V → Map K V
    [(expr-map-filter-entries pred map)
     (let ([tm (infer ctx map)])
       (match tm
         [(expr-Map k v)
          (if (check ctx pred (expr-Pi 'mw k (expr-Pi 'mw (shift 1 0 v) (expr-Bool))))
              (expr-Map k v)
              (expr-error))]
         [_ (expr-error)]))]

    ;; map-map-vals : (V → W) → Map K V → Map K W
    ;; Handles both named functions and lambdas for f.
    [(expr-map-map-vals f map)
     (let ([tm (infer ctx map)])
       (match tm
         [(expr-Map k v)
          (let ([tf (infer ctx f)])
            (if (equal? tf (expr-error))
                ;; Fallback for lambdas
                (match f
                  [(expr-lam m dom body)
                   (let* ([actual-dom (if (expr-hole? dom) v (whnf dom))])
                     (if (or (expr-hole? dom) (unify-ok? (unify ctx actual-dom v)))
                         (let ([w (infer (cons (cons actual-dom 'mw) ctx) body)])
                           (if (equal? w (expr-error))
                               (expr-error)
                               ;; w is at extended depth; un-shift via subst
                               (expr-Map k (whnf (subst 0 (expr-zero) w)))))
                         (expr-error)))]
                  [_ (expr-error)])
                ;; Normal path — un-shift codomain via subst
                (match (whnf tf)
                  [(expr-Pi _ dom cod)
                   (if (unify-ok? (unify ctx dom v))
                       (expr-Map k (whnf (subst 0 (expr-zero) cod)))
                       (expr-error))]
                  [_ (expr-error)])))]
         [_ (expr-error)]))]

    ;; pvec-from-list : List A → PVec A
    ;; List constructor name may be 'List or 'prologos::data::list::List (qualified)
    [(expr-pvec-from-list v)
     (let ([tv (whnf (infer ctx v))])
       (match tv
         [(expr-app (? (lambda (f)
                         (and (expr-fvar? f)
                              (let* ([n (symbol->string (expr-fvar-name f))]
                                     [len (string-length n)])
                                (or (string=? n "List")
                                    (and (>= len 6)
                                         (string=? (substring n (- len 6)) "::List"))))))) a)
          (expr-PVec a)]
         [_ (expr-error)]))]

    ;; ---- Transient Builders ----
    ;; Generic transient: dispatch on collection type
    [(expr-transient coll)
     (let ([tc (infer ctx coll)])
       (match (whnf tc)
         [(expr-PVec a) (expr-TVec a)]
         [(expr-Map k v) (expr-TMap k v)]
         [(expr-Set a) (expr-TSet a)]
         [_ (expr-error)]))]
    ;; Generic persist: dispatch on transient type
    [(expr-persist coll)
     (let ([tc (infer ctx coll)])
       (match (whnf tc)
         [(expr-TVec a) (expr-PVec a)]
         [(expr-TMap k v) (expr-Map k v)]
         [(expr-TSet a) (expr-Set a)]
         [_ (expr-error)]))]
    [(expr-TVec a)
     (if (is-type ctx a) (expr-Type (lzero)) (expr-error))]
    [(expr-TMap k v)
     (if (and (is-type ctx k) (is-type ctx v)) (expr-Type (lzero)) (expr-error))]
    [(expr-TSet a)
     (if (is-type ctx a) (expr-Type (lzero)) (expr-error))]
    [(expr-trrb _) (expr-error)]   ;; trrb needs checking context
    [(expr-tchamp _) (expr-error)]  ;; tchamp needs checking context
    [(expr-thset _) (expr-error)]   ;; thset needs checking context
    [(expr-transient-vec v)
     (let ([tv (infer ctx v)])
       (match tv
         [(expr-PVec a) (expr-TVec a)]
         [_ (expr-error)]))]
    [(expr-persist-vec t)
     (let ([tt (infer ctx t)])
       (match tt
         [(expr-TVec a) (expr-PVec a)]
         [_ (expr-error)]))]
    [(expr-transient-map m)
     (let ([tm (infer ctx m)])
       (match tm
         [(expr-Map k v) (expr-TMap k v)]
         [_ (expr-error)]))]
    [(expr-persist-map t)
     (let ([tt (infer ctx t)])
       (match tt
         [(expr-TMap k v) (expr-Map k v)]
         [_ (expr-error)]))]
    [(expr-transient-set s)
     (let ([ts (infer ctx s)])
       (match ts
         [(expr-Set a) (expr-TSet a)]
         [_ (expr-error)]))]
    [(expr-persist-set t)
     (let ([tt (infer ctx t)])
       (match tt
         [(expr-TSet a) (expr-Set a)]
         [_ (expr-error)]))]
    [(expr-tvec-push! t x)
     (let ([tt (infer ctx t)])
       (match tt
         [(expr-TVec a) (if (check ctx x a) (expr-TVec a) (expr-error))]
         [_ (expr-error)]))]
    [(expr-tvec-update! t i x)
     (let ([tt (infer ctx t)])
       (match tt
         [(expr-TVec a) (if (and (check ctx i (expr-Nat)) (check ctx x a))
                            (expr-TVec a) (expr-error))]
         [_ (expr-error)]))]
    [(expr-tmap-assoc! t k v)
     (let ([tt (infer ctx t)])
       (match tt
         [(expr-TMap kt vt)
          (if (and (check ctx k kt) (check ctx v vt))
              (expr-TMap kt vt) (expr-error))]
         [_ (expr-error)]))]
    [(expr-tmap-dissoc! t k)
     (let ([tt (infer ctx t)])
       (match tt
         [(expr-TMap kt vt)
          (if (check ctx k kt) (expr-TMap kt vt) (expr-error))]
         [_ (expr-error)]))]
    [(expr-tset-insert! t a)
     (let ([tt (infer ctx t)])
       (match tt
         [(expr-TSet a-ty)
          (if (check ctx a a-ty) (expr-TSet a-ty) (expr-error))]
         [_ (expr-error)]))]
    [(expr-tset-delete! t a)
     (let ([tt (infer ctx t)])
       (match tt
         [(expr-TSet a-ty)
          (if (check ctx a a-ty) (expr-TSet a-ty) (expr-error))]
         [_ (expr-error)]))]

    ;; ---- Foreign function: look up type from global env ----
    [(expr-foreign-fn name _ _ _ _ _)
     (or (global-env-lookup-type name) (expr-error))]

    ;; ---- PropNetwork type constructors ----
    [(expr-net-type) (expr-Type (lzero))]
    [(expr-cell-id-type) (expr-Type (lzero))]
    [(expr-prop-id-type) (expr-Type (lzero))]

    ;; ---- PropNetwork runtime wrappers ----
    [(expr-prop-network _) (expr-net-type)]
    [(expr-cell-id _) (expr-cell-id-type)]
    [(expr-prop-id _) (expr-prop-id-type)]

    ;; ---- PropNetwork operations ----

    ;; net-new : Int -> PropNetwork
    [(expr-net-new fuel)
     (if (check ctx fuel (expr-Int))
         (expr-net-type)
         (expr-error))]

    ;; net-new-cell : PropNetwork -> A -> (A -> A -> A) -> [PropNetwork * CellId]
    [(expr-net-new-cell net init merge)
     (if (check ctx net (expr-net-type))
         (let ([init-ty (infer ctx init)])
           (if (expr-error? init-ty)
               (expr-error)
               (let ([merge-ty (arrow init-ty (arrow init-ty init-ty))])
                 (if (check ctx merge merge-ty)
                     (expr-Sigma (expr-net-type) (expr-cell-id-type))
                     (expr-error)))))
         (expr-error))]

    ;; net-cell-read : PropNetwork -> CellId -> A (type-unsafe: returns fresh hole)
    [(expr-net-cell-read net cell)
     (if (and (check ctx net (expr-net-type))
              (check ctx cell (expr-cell-id-type)))
         (expr-hole)   ;; type-unsafe — caller must use (the T ...) or checking context
         (expr-error))]

    ;; net-cell-write : PropNetwork -> CellId -> A -> PropNetwork
    [(expr-net-cell-write net cell val)
     (if (and (check ctx net (expr-net-type))
              (check ctx cell (expr-cell-id-type)))
         (let ([_ (infer ctx val)])  ;; val can be any type
           (expr-net-type))
         (expr-error))]

    ;; net-add-prop : PropNetwork -> List CellId -> List CellId -> (PropNetwork -> PropNetwork) -> [PropNetwork * PropId]
    [(expr-net-add-prop net ins outs fn)
     (let ([list-cid (expr-app (list-type-fvar) (expr-cell-id-type))])
       (if (and (check ctx net (expr-net-type))
                (check ctx ins list-cid)
                (check ctx outs list-cid)
                (check ctx fn (arrow (expr-net-type) (expr-net-type))))
           (expr-Sigma (expr-net-type) (expr-prop-id-type))
           (expr-error)))]

    ;; net-run : PropNetwork -> PropNetwork
    [(expr-net-run net)
     (if (check ctx net (expr-net-type))
         (expr-net-type)
         (expr-error))]

    ;; net-snapshot : PropNetwork -> PropNetwork (identity — documents backtracking intent)
    [(expr-net-snapshot net)
     (if (check ctx net (expr-net-type))
         (expr-net-type)
         (expr-error))]

    ;; net-contradict? : PropNetwork -> Bool
    [(expr-net-contradiction net)
     (if (check ctx net (expr-net-type))
         (expr-Bool)
         (expr-error))]

    ;; ---- UnionFind type constructor ----
    [(expr-uf-type) (expr-Type (lzero))]

    ;; ---- UnionFind runtime wrapper ----
    [(expr-uf-store _) (expr-uf-type)]

    ;; ---- UnionFind operations ----

    ;; uf-empty : UnionFind
    [(expr-uf-empty) (expr-uf-type)]

    ;; uf-make-set : UnionFind -> Nat -> A -> UnionFind
    [(expr-uf-make-set store id val)
     (if (and (check ctx store (expr-uf-type))
              (check ctx id (expr-Nat)))
         (let ([_ (infer ctx val)])  ;; val can be any type
           (expr-uf-type))
         (expr-error))]

    ;; uf-find : UnionFind -> Nat -> [Nat * UnionFind]
    [(expr-uf-find store id)
     (if (and (check ctx store (expr-uf-type))
              (check ctx id (expr-Nat)))
         (expr-Sigma (expr-Nat) (expr-uf-type))
         (expr-error))]

    ;; uf-union : UnionFind -> Nat -> Nat -> UnionFind
    [(expr-uf-union store id1 id2)
     (if (and (check ctx store (expr-uf-type))
              (check ctx id1 (expr-Nat))
              (check ctx id2 (expr-Nat)))
         (expr-uf-type)
         (expr-error))]

    ;; uf-value : UnionFind -> Nat -> A (type-unsafe: returns fresh hole)
    [(expr-uf-value store id)
     (if (and (check ctx store (expr-uf-type))
              (check ctx id (expr-Nat)))
         (expr-hole)   ;; type-unsafe — caller must use (the T ...) or checking context
         (expr-error))]

    ;; ---- ATMS type constructors ----
    [(expr-atms-type) (expr-Type (lzero))]
    [(expr-assumption-id-type) (expr-Type (lzero))]

    ;; ---- ATMS runtime wrappers ----
    [(expr-atms-store _) (expr-atms-type)]
    [(expr-assumption-id-val _) (expr-assumption-id-type)]

    ;; ---- ATMS operations ----

    ;; atms-new : PropNetwork -> ATMS
    [(expr-atms-new network)
     (if (check ctx network (expr-net-type))
         (expr-atms-type)
         (expr-error))]

    ;; atms-assume : ATMS -> A -> A -> [ATMS * AssumptionId]
    [(expr-atms-assume a name datum)
     (if (check ctx a (expr-atms-type))
         (begin (infer ctx name)    ;; name can be any type
                (infer ctx datum)   ;; datum can be any type
                (expr-Sigma (expr-atms-type) (expr-assumption-id-type)))
         (expr-error))]

    ;; atms-retract : ATMS -> AssumptionId -> ATMS
    [(expr-atms-retract a aid)
     (if (and (check ctx a (expr-atms-type))
              (check ctx aid (expr-assumption-id-type)))
         (expr-atms-type)
         (expr-error))]

    ;; atms-nogood : ATMS -> List AssumptionId -> ATMS
    [(expr-atms-nogood a aids)
     (let ([list-aid (expr-app (list-type-fvar) (expr-assumption-id-type))])
       (if (and (check ctx a (expr-atms-type))
                (check ctx aids list-aid))
           (expr-atms-type)
           (expr-error)))]

    ;; atms-amb : ATMS -> List A -> [ATMS * _]
    [(expr-atms-amb a alternatives)
     (if (check ctx a (expr-atms-type))
         (let ([_ (infer ctx alternatives)])  ;; alternatives is a List of anything
           (expr-Sigma (expr-atms-type) (expr-hole)))
         (expr-error))]

    ;; atms-solve-all : ATMS -> CellId -> _ (type-unsafe)
    [(expr-atms-solve-all a goal)
     (if (and (check ctx a (expr-atms-type))
              (check ctx goal (expr-cell-id-type)))
         (expr-hole)
         (expr-error))]

    ;; atms-read : ATMS -> CellId -> _ (type-unsafe)
    [(expr-atms-read a cell)
     (if (and (check ctx a (expr-atms-type))
              (check ctx cell (expr-cell-id-type)))
         (expr-hole)
         (expr-error))]

    ;; atms-write : ATMS -> CellId -> A -> List AssumptionId -> ATMS
    [(expr-atms-write a cell val support)
     (let ([list-aid (expr-app (list-type-fvar) (expr-assumption-id-type))])
       (if (and (check ctx a (expr-atms-type))
                (check ctx cell (expr-cell-id-type)))
           (let ([_ (infer ctx val)])  ;; val can be any type
             (if (check ctx support list-aid)
                 (expr-atms-type)
                 (expr-error)))
           (expr-error)))]

    ;; atms-consistent? : ATMS -> List AssumptionId -> Bool
    [(expr-atms-consistent a aids)
     (let ([list-aid (expr-app (list-type-fvar) (expr-assumption-id-type))])
       (if (and (check ctx a (expr-atms-type))
                (check ctx aids list-aid))
           (expr-Bool)
           (expr-error)))]

    ;; atms-worldview : ATMS -> List AssumptionId -> ATMS
    [(expr-atms-worldview a aids)
     (let ([list-aid (expr-app (list-type-fvar) (expr-assumption-id-type))])
       (if (and (check ctx a (expr-atms-type))
                (check ctx aids list-aid))
           (expr-atms-type)
           (expr-error)))]

    ;; ---- Tabling type constructor ----
    [(expr-table-store-type) (expr-Type (lzero))]

    ;; ---- Tabling runtime wrapper ----
    [(expr-table-store-val _) (expr-table-store-type)]

    ;; ---- Tabling operations ----

    ;; table-new : PropNetwork -> TableStore
    [(expr-table-new network)
     (if (check ctx network (expr-net-type))
         (expr-table-store-type)
         (expr-error))]

    ;; table-register : TableStore -> Keyword -> Keyword -> [TableStore * CellId]
    [(expr-table-register store name mode)
     (if (and (check ctx store (expr-table-store-type))
              (check ctx name (expr-Keyword))
              (check ctx mode (expr-Keyword)))
         (expr-Sigma (expr-table-store-type) (expr-cell-id-type))
         (expr-error))]

    ;; table-add : TableStore -> Keyword -> A -> TableStore
    [(expr-table-add store name answer)
     (if (and (check ctx store (expr-table-store-type))
              (check ctx name (expr-Keyword)))
         (begin (infer ctx answer)  ;; answer can be any type
                (expr-table-store-type))
         (expr-error))]

    ;; table-answers : TableStore -> Keyword -> _ (type-unsafe)
    [(expr-table-answers store name)
     (if (and (check ctx store (expr-table-store-type))
              (check ctx name (expr-Keyword)))
         (expr-hole)
         (expr-error))]

    ;; table-freeze : TableStore -> Keyword -> TableStore
    [(expr-table-freeze store name)
     (if (and (check ctx store (expr-table-store-type))
              (check ctx name (expr-Keyword)))
         (expr-table-store-type)
         (expr-error))]

    ;; table-complete? : TableStore -> Keyword -> Bool
    [(expr-table-complete store name)
     (if (and (check ctx store (expr-table-store-type))
              (check ctx name (expr-Keyword)))
         (expr-Bool)
         (expr-error))]

    ;; table-run : TableStore -> TableStore
    [(expr-table-run store)
     (if (check ctx store (expr-table-store-type))
         (expr-table-store-type)
         (expr-error))]

    ;; table-lookup : TableStore -> Keyword -> A -> Bool
    [(expr-table-lookup store name answer)
     (if (and (check ctx store (expr-table-store-type))
              (check ctx name (expr-Keyword)))
         (begin (infer ctx answer)  ;; answer can be any type
                (expr-Bool))
         (expr-error))]

    ;; ---- Fallback: cannot infer ----
    [_ (expr-error)]))

;; ========================================
;; Type checking (checking mode)
;; ========================================
(define (check ctx e t)
  (match* (e (whnf t))
    ;; ---- suc: check against Nat ----
    [((expr-suc e1) (expr-Nat))
     (check ctx e1 (expr-Nat))]

    ;; ---- Lambda: check against Pi ----
    ;; check(G, lam(m, A, body), Pi(m, A', B))
    ;; requires A conv A' and body checks against B in extended context
    ;; Special case: if A is expr-hole, use the expected domain AND multiplicity
    [((expr-lam m a body) (expr-Pi m2 t-dom b))
     (cond
       [(expr-hole? a)
        ;; Type hole: accept both the expected domain and multiplicity from the Pi type
        (check (ctx-extend ctx t-dom m2) body b)]
       ;; Sprint 7: lambda mult is mult-meta → accept Pi's mult
       [(mult-meta? m)
        (let ([resolved (if (mult-meta? m2) 'mw m2)])
          (solve-mult-meta! (mult-meta-id m) resolved)
          (when (mult-meta? m2)
            (solve-mult-meta! (mult-meta-id m2) resolved))
          (and (unify-ok? (unify ctx a t-dom))
               (check (ctx-extend ctx a resolved) body b)))]
       ;; Sprint 7: Pi mult is mult-meta → accept lambda's mult
       [(mult-meta? m2)
        (solve-mult-meta! (mult-meta-id m2) m)
        (and (unify-ok? (unify ctx a t-dom))
             (check (ctx-extend ctx a m) body b))]
       ;; Concrete mults: must match
       [(not (eq? m m2)) #f]
       [(not (unify-ok? (unify ctx a t-dom))) #f]
       [else (check (ctx-extend ctx a m) body b)])]

    ;; ---- Pair: check against Sigma ----
    ;; check(G, pair(e1, e2), Sigma(A, B))
    [((expr-pair e1 e2) (expr-Sigma a b))
     (and (check ctx e1 a)
          (check ctx e2 (subst 0 e1 b)))]

    ;; ---- refl: check against Eq ----
    ;; refl : Eq(A, e1, e2) iff conv(e1, e2)
    [((expr-refl) (expr-Eq _ e1 e2))
     (unify-ok? (unify ctx e1 e2))]

    ;; ---- Vec constructors ----
    ;; vnil(A) : Vec(A, zero)
    [((expr-vnil a1) (expr-Vec a2 n))
     (and (is-type ctx a1)
          (unify-ok? (unify ctx a1 a2))
          (unify-ok? (unify ctx n (expr-zero))))]

    ;; vcons(A, n, head, tail) : Vec(A, suc(n))
    [((expr-vcons a1 n1 hd tl) (expr-Vec a2 len))
     (and (unify-ok? (unify ctx a1 a2))
          (unify-ok? (unify ctx len (expr-suc n1)))
          (check ctx hd a1)
          (check ctx tl (expr-Vec a1 n1)))]

    ;; ---- Fin constructors ----
    ;; fzero(n) : Fin(suc(n))
    [((expr-fzero n1) (expr-Fin bound))
     (and (unify-ok? (unify ctx bound (expr-suc n1)))
          (check ctx n1 (expr-Nat)))]

    ;; fsuc(n, i) : Fin(suc(n))  when i : Fin(n)
    [((expr-fsuc n1 i) (expr-Fin bound))
     (and (unify-ok? (unify ctx bound (expr-suc n1)))
          (check ctx i (expr-Fin n1)))]

    ;; ---- Int literal check ----
    [((expr-int v) (expr-Int))
     (exact-integer? v)]

    ;; ---- Rat literal check ----
    [((expr-rat v) (expr-Rat))
     (and (exact? v) (rational? v))]

    ;; ---- Posit8 literal check ----
    [((expr-posit8 v) (expr-Posit8))
     (and (exact-integer? v) (<= 0 v 255))]

    ;; ---- Posit16 literal check ----
    [((expr-posit16 v) (expr-Posit16))
     (and (exact-integer? v) (<= 0 v 65535))]

    ;; ---- Posit32 literal check ----
    [((expr-posit32 v) (expr-Posit32))
     (and (exact-integer? v) (<= 0 v 4294967295))]

    ;; ---- Posit64 literal check ----
    [((expr-posit64 v) (expr-Posit64))
     (and (exact-integer? v) (<= 0 v 18446744073709551615))]

    ;; ---- Symbol literal check ----
    [((expr-symbol _) (expr-Symbol)) #t]

    ;; ---- Keyword literal check ----
    [((expr-keyword _) (expr-Keyword)) #t]

    ;; ---- Char literal check ----
    [((expr-char _) (expr-Char)) #t]

    ;; ---- String literal check ----
    [((expr-string _) (expr-String)) #t]

    ;; ---- Map checks ----
    ;; champ checked against Map K V
    [((expr-champ _) (expr-Map _ _)) #t]
    ;; map-empty checked against Map K V
    [((expr-map-empty k1 v1) (expr-Map k2 v2))
     (and (unify-ok? (unify ctx k1 k2))
          (unify-ok? (unify ctx v1 v2)))]
    ;; map-assoc checked against Map K V — propagate expected type
    [((expr-map-assoc m k v) (expr-Map kt vt))
     (and (check ctx m (expr-Map kt vt))
          (check ctx k kt)
          (check ctx v vt))]

    ;; ---- Set checks ----
    ;; hset checked against Set A
    [((expr-hset _) (expr-Set _)) #t]
    ;; set-empty checked against Set A
    [((expr-set-empty a1) (expr-Set a2))
     (unify-ok? (unify ctx a1 a2))]
    ;; set-insert checked against Set A — propagate expected type
    [((expr-set-insert s a) (expr-Set a-ty))
     (and (check ctx s (expr-Set a-ty))
          (check ctx a a-ty))]

    ;; ---- PVec checks ----
    [((expr-rrb _) (expr-PVec _)) #t]
    [((expr-pvec-empty a1) (expr-PVec a2))
     (unify-ok? (unify ctx a1 a2))]
    [((expr-pvec-push v x) (expr-PVec a))
     (and (check ctx v (expr-PVec a))
          (check ctx x a))]
    ;; pvec-fold : check against result type B
    ;; Pi codomains shifted for de Bruijn convention.
    [((expr-pvec-fold f init vec) expected-type)
     (let ([tv (infer ctx vec)])
       (match tv
         [(expr-PVec a)
          (and (check ctx init expected-type)
               (check ctx f (expr-Pi 'mw expected-type
                              (expr-Pi 'mw (shift 1 0 a) (shift 2 0 expected-type)))))]
         [_ #f]))]
    ;; pvec-map : check against PVec B
    [((expr-pvec-map f vec) (expr-PVec b))
     (let ([tv (infer ctx vec)])
       (match tv
         [(expr-PVec a)
          (check ctx f (expr-Pi 'mw a (shift 1 0 b)))]
         [_ #f]))]
    ;; pvec-filter : check against PVec A
    [((expr-pvec-filter pred vec) (expr-PVec a))
     (and (check ctx pred (expr-Pi 'mw a (expr-Bool)))
          (check ctx vec (expr-PVec a)))]
    ;; set-fold : check against result type B
    [((expr-set-fold f init set) expected-type)
     (let ([ts (infer ctx set)])
       (match ts
         [(expr-Set a)
          (and (check ctx init expected-type)
               (check ctx f (expr-Pi 'mw expected-type
                              (expr-Pi 'mw (shift 1 0 a) (shift 2 0 expected-type)))))]
         [_ #f]))]
    ;; set-filter : check against Set A
    [((expr-set-filter pred set) (expr-Set a))
     (and (check ctx pred (expr-Pi 'mw a (expr-Bool)))
          (check ctx set (expr-Set a)))]
    ;; map-fold-entries : check against result type B
    [((expr-map-fold-entries f init map) expected-type)
     (let ([tm (infer ctx map)])
       (match tm
         [(expr-Map k v)
          (and (check ctx init expected-type)
               (check ctx f (expr-Pi 'mw expected-type
                              (expr-Pi 'mw (shift 1 0 k)
                                (expr-Pi 'mw (shift 2 0 v) (shift 3 0 expected-type))))))]
         [_ #f]))]
    ;; map-filter-entries : check against Map K V
    [((expr-map-filter-entries pred map) (expr-Map k v))
     (and (check ctx pred (expr-Pi 'mw k (expr-Pi 'mw (shift 1 0 v) (expr-Bool))))
          (check ctx map (expr-Map k v)))]
    ;; map-map-vals : check against Map K W
    [((expr-map-map-vals f map) (expr-Map k w))
     (let ([tm (infer ctx map)])
       (match tm
         [(expr-Map k2 v)
          (and (unify-ok? (unify ctx k k2))
               (check ctx f (expr-Pi 'mw v (shift 1 0 w))))]
         [_ #f]))]

    ;; ---- Transient Builder checks ----
    [((expr-trrb _) (expr-TVec _)) #t]
    [((expr-tchamp _) (expr-TMap _ _)) #t]
    [((expr-thset _) (expr-TSet _)) #t]
    [((expr-persist-vec t) (expr-PVec a))
     (check ctx t (expr-TVec a))]
    [((expr-persist-map t) (expr-Map k v))
     (check ctx t (expr-TMap k v))]
    [((expr-persist-set t) (expr-Set a))
     (check ctx t (expr-TSet a))]
    [((expr-tvec-push! t x) (expr-TVec a))
     (and (check ctx t (expr-TVec a))
          (check ctx x a))]
    [((expr-tvec-update! t i x) (expr-TVec a))
     (and (check ctx t (expr-TVec a))
          (check ctx i (expr-Nat))
          (check ctx x a))]
    [((expr-tmap-assoc! t k v) (expr-TMap kt vt))
     (and (check ctx t (expr-TMap kt vt))
          (check ctx k kt)
          (check ctx v vt))]
    [((expr-tmap-dissoc! t k) (expr-TMap kt vt))
     (and (check ctx t (expr-TMap kt vt))
          (check ctx k kt))]
    [((expr-tset-insert! t a) (expr-TSet a-ty))
     (and (check ctx t (expr-TSet a-ty))
          (check ctx a a-ty))]
    [((expr-tset-delete! t a) (expr-TSet a-ty))
     (and (check ctx t (expr-TSet a-ty))
          (check ctx a a-ty))]

    ;; ---- PropNetwork runtime wrappers ----
    [((expr-prop-network _) (expr-net-type)) #t]
    [((expr-cell-id _) (expr-cell-id-type)) #t]
    [((expr-prop-id _) (expr-prop-id-type)) #t]

    ;; ---- UnionFind runtime wrapper ----
    [((expr-uf-store _) (expr-uf-type)) #t]

    ;; ---- ATMS runtime wrappers ----
    [((expr-atms-store _) (expr-atms-type)) #t]
    [((expr-assumption-id-val _) (expr-assumption-id-type)) #t]

    ;; ---- Tabling runtime wrapper ----
    [((expr-table-store-val _) (expr-table-store-type)) #t]

    ;; ---- Reduce: ML-style Church elimination ----
    ;; check(G, reduce(scrutinee, arms), T)
    ;; 1. Infer scrutinee type, WHNF it to get Church Pi chain
    ;; 2. Build the Church application: (scrutinee T arm1 arm2 ...)
    ;; 3. Type-check the generated application
    [((expr-reduce scrutinee arms _) expected-type)
     (check-reduce ctx e scrutinee arms expected-type)]

    ;; ---- Hole expression: checks against any type ----
    ;; An expr-hole is a placeholder that will be filled by type inference.
    [((expr-hole) _) #t]

    ;; ---- Typed hole: reports expected type + context to stderr, then succeeds ----
    [((expr-typed-hole name) expected)
     (define hole-label (if name (format "??~a" name) "??"))
     (define pp-type (pp-expr expected))
     ;; Build context report with synthetic names
     (define hole-base-names '("x" "y" "z" "a" "b" "c" "d" "e" "f" "g" "h"))
     (define ctx-lines
       (for/list ([i (in-range (ctx-len ctx))])
         (define ty (lookup-type i ctx))
         (define m (lookup-mult i ctx))
         (define var-name
           (if (< i (length hole-base-names))
               (list-ref hole-base-names i)
               (format "v~a" i)))
         ;; Build name stack for pp-expr: indices 0..i mapped to names
         (define names-for-pp
           (for/list ([j (in-range (+ i 1))])
             (if (< j (length hole-base-names))
                 (list-ref hole-base-names j)
                 (format "v~a" j))))
         (format "  ~a : ~a  (~a)" var-name (pp-expr ty names-for-pp) (pp-mult m))))
     (fprintf (current-error-port)
              "Hole ~a : ~a\n~a"
              hole-label
              pp-type
              (if (null? ctx-lines)
                  ""
                  (format "Context:\n~a\n" (string-join ctx-lines "\n"))))
     #t]

    ;; ---- Meta expression: optimistically succeed ----
    ;; A metavariable in expression position (e.g., implicit argument)
    ;; will be solved by unification constraints from other arguments.
    ;; We can't infer its type yet, so accept it optimistically.
    [((expr-meta _) _) #t]

    ;; ---- Union type: check against A | B ----
    ;; check(G, e, A | B) succeeds if e : A or e : B.
    ;; Uses speculative meta state to avoid contamination from failed attempts.
    [(_ (expr-union l r))
     (let ([saved (save-meta-state)])
       (if (check ctx e l)
           #t
           (begin
             (restore-meta-state! saved)
             (check ctx e r))))]

    ;; ---- Checking against hole type: succeed if expression is inferrable ----
    ;; When the expected type is a hole, just verify the expression is well-typed.
    [(_ (expr-hole))
     (not (expr-error? (infer ctx e)))]

    ;; ---- Conversion fallback ----
    ;; If e synthesizes to T' and conv(T, T'), then check succeeds.
    ;; Cumulativity: if T' = Type(m) and T = Type(n) where m ≤ n, accept.
    ;; This allows types from lower universes to be used where higher universes are expected.
    [(_ t-whnf)
     (let ([t1 (infer ctx e)])
       (and (not (expr-error? t1))
            (or (unify-ok? (unify ctx t t1))
                (match* ((whnf t) (whnf t1))
                  ;; Cumulativity: Type(m) ≤ Type(n) when m ≤ n
                  [((expr-Type l1) (expr-Type l2))
                   (level<=? l2 l1)]
                  ;; Phase 3e: within-family subtyping
                  [(t-w t1-w) (subtype? t1-w t-w)]))))]))

;; ========================================
;; check-reduce: type-check a reduce (match) expression
;; ========================================
;; Two paths:
;;   Path A (structural): When constructor metadata is available (types defined via `data`),
;;     use true structural pattern matching — look up constructor field types,
;;     extend the context, and check each arm body directly. This lifts the
;;     Type 0 restriction from Church encoding, allowing match to return Type 1.
;;   Path B (Church fold): Fallback for built-in types or when metadata is unavailable.
;;     Desugars match into a Church application as before.

;; Decompose (app (app (fvar 'List) Nat) ...) → (values 'List (list Nat ...))
(define (decompose-type-app e)
  (let loop ([expr e] [args '()])
    (match expr
      [(expr-app f a) (loop f (cons a args))]
      [(expr-fvar name) (values name args)]
      ;; Built-in types: Nat, Bool, Unit (no type parameters)
      [(expr-Nat) (values 'Nat args)]
      [(expr-Bool) (values 'Bool args)]
      [(expr-Unit) (values 'Unit args)]
      [_ (values #f #f)])))

;; 'prologos::data::list::List → 'List, 'List → 'List
(define (bare-name sym)
  (define-values (_prefix short) (split-qualified-name sym))
  (or short sym))

;; Substitute type-args into leading m0 Pi binders of a constructor type.
;; Returns the remaining Pi chain with field types as domains.
(define (instantiate-pi-chain type args)
  (cond
    [(null? args) type]
    [else
     (match (whnf type)
       [(expr-Pi 'm0 _dom cod)
        (instantiate-pi-chain (subst 0 (car args) cod) (cdr args))]
       [_ #f])]))

;; Walk the instantiated Pi chain, extending ctx with each field's domain type.
(define (extend-ctx-with-fields ctx type n-fields)
  (let loop ([ty (whnf type)] [ctx ctx] [remaining n-fields])
    (if (= remaining 0)
        ctx
        (match ty
          [(expr-Pi m dom cod)
           (loop cod (ctx-extend ctx dom m) (- remaining 1))]
          [_ ctx]))))

;; Qualify a bare ctor name using the type constructor's FQN prefix.
;; e.g., ctor='cons, type-fqn='prologos::data::list::List → 'prologos::data::list::cons
(define (qualify-ctor-name ctor-name type-ctor-fqn)
  (define-values (prefix _short) (split-qualified-name type-ctor-fqn))
  (if prefix
      (string->symbol
       (string-append (symbol->string prefix) "::"
                      (symbol->string ctor-name)))
      ctor-name))

(define (check-reduce ctx reduce-expr scrutinee arms expected-type)
  (define scrut-type (infer ctx scrutinee))
  (cond
    [(expr-error? scrut-type) #f]
    [else
     (let-values ([(type-ctor-name type-args) (decompose-type-app scrut-type)])
       (define bare-tc (and type-ctor-name (bare-name type-ctor-name)))
       (define type-ctors (and bare-tc (lookup-type-ctors bare-tc)))
       (cond
         ;; Structural PM for all types with constructor metadata
         ;; (both built-in and user-defined). With native constructors,
         ;; there is no Church fold / structural PM split — all match
         ;; uses structural decomposition.
         [(and type-ctors (not (null? type-ctors)))
          (let ([result (check-reduce-structural ctx arms expected-type
                                                  type-ctor-name type-args)])
            (when result (mark-structural-reduce! reduce-expr))
            result)]
         ;; Fallback: Church fold for types without constructor metadata
         [else (check-reduce-church ctx scrutinee arms expected-type)]))]))


;; Built-in constructor types for Nat/Bool (not in global-env)
(define (builtin-ctor-type ctor-name)
  (case ctor-name
    [(zero) (expr-Nat)]
    [(suc)  (expr-Pi 'mw (expr-Nat) (expr-Nat))]
    [(true) (expr-Bool)]
    [(false) (expr-Bool)]
    [(unit) (expr-Unit)]
    [else #f]))

;; Path A: True structural pattern matching using constructor metadata
(define (check-reduce-structural ctx arms expected-type
                                  type-ctor-name type-args)
  (for/and ([arm (in-list arms)])
    (define ctor-name (expr-reduce-arm-ctor-name arm))
    (define bc (expr-reduce-arm-binding-count arm))
    (define body (expr-reduce-arm-body arm))
    ;; Look up constructor type from global-env (try FQN, bare, then built-in)
    (define ctor-fqn (qualify-ctor-name ctor-name type-ctor-name))
    (define ctor-type (or (global-env-lookup-type ctor-fqn)
                          (global-env-lookup-type ctor-name)
                          (builtin-ctor-type ctor-name)))
    (cond
      [(not ctor-type) #f]
      [else
       (define instantiated (instantiate-pi-chain ctor-type type-args))
       (cond
         [(not instantiated) #f]
         [else
          (if (= bc 0)
              (check ctx body expected-type)
              (let ([ext-ctx (extend-ctx-with-fields ctx instantiated bc)])
                (define shifted-exp (shift bc 0 expected-type))
                (check ext-ctx body shifted-exp)))])])))

;; Path B: Church fold desugaring (fallback for built-in types)
(define (check-reduce-church ctx scrutinee arms expected-type)
  (define branch-lams
    (for/list ([arm (in-list arms)])
      (define bc (expr-reduce-arm-binding-count arm))
      (define body (expr-reduce-arm-body arm))
      (if (= bc 0)
          body
          (for/fold ([inner body])
                    ([_ (in-range bc)])
            (expr-lam 'mw (expr-hole) inner)))))
  (define church-app
    (foldl (lambda (branch app-so-far)
             (expr-app app-so-far branch))
           (expr-app scrutinee expected-type)
           branch-lams))
  (check ctx church-app expected-type))

;; ========================================
;; Infer universe level of a type
;; ========================================
(define (infer-level ctx e)
  (match e
    ;; Pi formation: Pi(m, A, B) : Type(max(level(A), level(B)))
    [(expr-Pi m a b)
     (let ([la (infer-level ctx a)])
       (match la
         [(just-level l1)
          (let ([lb (infer-level (ctx-extend ctx a m) b)])
            (match lb
              [(just-level l2) (just-level (lmax l1 l2))]
              [_ (no-level)]))]
         [_ (no-level)]))]

    ;; Sigma formation
    [(expr-Sigma a b)
     (let ([la (infer-level ctx a)])
       (match la
         [(just-level l1)
          (let ([lb (infer-level (ctx-extend ctx a 'mw) b)])
            (match lb
              [(just-level l2) (just-level (lmax l1 l2))]
              [_ (no-level)]))]
         [_ (no-level)]))]

    ;; Eq formation
    [(expr-Eq a e1 e2)
     (let ([la (infer-level ctx a)])
       (match la
         [(just-level l)
          (if (and (check ctx e1 a) (check ctx e2 a))
              (just-level l)
              (no-level))]
         [_ (no-level)]))]

    ;; Vec formation: Vec(A, n) : Type(level(A))  if A : Type(l) and n : Nat
    [(expr-Vec a n)
     (let ([la (infer-level ctx a)])
       (match la
         [(just-level l)
          (if (check ctx n (expr-Nat))
              (just-level l)
              (no-level))]
         [_ (no-level)]))]

    ;; Fin formation: Fin(n) : Type(0)  if n : Nat
    [(expr-Fin n)
     (if (check ctx n (expr-Nat))
         (just-level (lzero))
         (no-level))]

    ;; Int formation: Int : Type(0)
    [(expr-Int) (just-level (lzero))]

    ;; Rat formation: Rat : Type(0)
    [(expr-Rat) (just-level (lzero))]

    ;; Posit8 formation: Posit8 : Type(0)
    [(expr-Posit8) (just-level (lzero))]

    ;; Posit16 formation: Posit16 : Type(0)
    [(expr-Posit16) (just-level (lzero))]

    ;; Posit32 formation: Posit32 : Type(0)
    [(expr-Posit32) (just-level (lzero))]

    ;; Posit64 formation: Posit64 : Type(0)
    [(expr-Posit64) (just-level (lzero))]

    ;; Quire formations: QuireW : Type(0)
    [(expr-Quire8) (just-level (lzero))]
    [(expr-Quire16) (just-level (lzero))]
    [(expr-Quire32) (just-level (lzero))]
    [(expr-Quire64) (just-level (lzero))]

    ;; Symbol formation: Symbol : Type(0)
    [(expr-Symbol) (just-level (lzero))]

    ;; Keyword formation: Keyword : Type(0)
    [(expr-Keyword) (just-level (lzero))]

    ;; Char formation: Char : Type(0)
    [(expr-Char) (just-level (lzero))]

    ;; String formation: String : Type(0)
    [(expr-String) (just-level (lzero))]

    ;; Map formation: Map K V : Type(max(level(K), level(V)))
    [(expr-Map k v)
     (let ([lk (infer-level ctx k)]
           [lv (infer-level ctx v)])
       (match* (lk lv)
         [((just-level lk*) (just-level lv*))
          (just-level (lmax lk* lv*))]
         [(_ _) (no-level)]))]

    ;; Set formation: Set A : Type(level(A))
    [(expr-Set a) (infer-level ctx a)]

    ;; PVec formation: PVec A : Type(level(A))
    [(expr-PVec a) (infer-level ctx a)]

    ;; Transient type formations
    [(expr-TVec a) (infer-level ctx a)]
    [(expr-TMap k v)
     (let ([lk (infer-level ctx k)])
       (match lk
         [(just-level lk*)
          (let ([lv (infer-level ctx v)])
            (match lv
              [(just-level lv*) (just-level (lmax lk* lv*))]
              [_ (no-level)]))]
         [_ (no-level)]))]
    [(expr-TSet a) (infer-level ctx a)]

    ;; PropNetwork type constructors — all ground types at Type 0
    [(expr-net-type) (just-level (lzero))]
    [(expr-cell-id-type) (just-level (lzero))]
    [(expr-prop-id-type) (just-level (lzero))]

    ;; UnionFind type constructor — ground type at Type 0
    [(expr-uf-type) (just-level (lzero))]

    ;; ATMS type constructors — ground types at Type 0
    [(expr-atms-type) (just-level (lzero))]
    [(expr-assumption-id-type) (just-level (lzero))]

    ;; Tabling type constructor — ground type at Type 0
    [(expr-table-store-type) (just-level (lzero))]

    ;; Union formation: A | B : Type(max(level(A), level(B)))
    [(expr-union l r)
     (let ([ll (infer-level ctx l)])
       (match ll
         [(just-level l1)
          (let ([lr (infer-level ctx r)])
            (match lr
              [(just-level l2) (just-level (lmax l1 l2))]
              [_ (no-level)]))]
         [_ (no-level)]))]

    ;; Metavariable: if solved, follow solution; if unsolved, assume Type(lzero).
    ;; Unsolved metas in type position (e.g. map-empty key/value types) will be
    ;; resolved later via unification. This mirrors check's [(expr-meta _) _) #t].
    [(expr-meta id)
     (let ([sol (meta-solution id)])
       (if sol
           (infer-level ctx sol)
           (just-level (lzero))))]

    ;; Fallback: try to infer and match Type(L)
    [_
     (let ([t (whnf (infer ctx e))])
       (match t
         [(expr-Type l) (just-level l)]
         [_ (no-level)]))]))

;; ========================================
;; Type formation check
;; ========================================
(define (is-type ctx e)
  (match e
    ;; Type(L) is always a type
    [(expr-Type _) #t]
    ;; Otherwise, try to infer its level
    [_ (just-level? (infer-level ctx e))]))
