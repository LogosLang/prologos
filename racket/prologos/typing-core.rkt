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
         "prelude.rkt"
         "syntax.rkt"
         "substitution.rkt"
         "reduction.rkt"
         "global-env.rkt")

(provide infer check is-type infer-level
         (struct-out no-level) (struct-out just-level))

;; ========================================
;; MaybeLevel: result of inferLevel
;; ========================================
(struct no-level () #:transparent)
(struct just-level (level) #:transparent)

;; ========================================
;; Forward declarations for mutual recursion
;; ========================================
;; infer, check, is-type, infer-level are all mutually recursive.
;; In Racket, top-level defines can reference each other, so no forward decl needed.

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
       (if ty ty (expr-error)))]

    ;; ---- Universes ----
    ;; Type(n) : Type(n+1)
    [(expr-Type l) (expr-Type (lsuc l))]

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

    ;; ---- Annotated terms ----
    ;; ann(e, T) synthesizes T if T is a type and e checks against T
    [(expr-ann e1 t)
     (if (and (is-type ctx t) (check ctx e1 t))
         t
         (expr-error))]

    ;; ---- Pi elimination (application) ----
    [(expr-app e1 e2)
     (let ([t1 (whnf (infer ctx e1))])
       (match t1
         [(expr-Pi m a b)
          (if (check ctx e2 a)
              (subst 0 e2 b)
              (expr-error))]
         [_ (expr-error)]))]

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

    ;; ---- Nat eliminator (natrec) ----
    ;; natrec(motive, base, step, target)
    ;; result type: app(motive, target)
    [(expr-natrec mot base step target)
     (if (and (check ctx target (expr-Nat))
              (check ctx base (expr-app mot (expr-zero))))
         (expr-app mot target)
         (expr-error))]

    ;; ---- J eliminator ----
    ;; J(motive, base, left, right, proof)
    ;; Need to extract type from proof's type Eq(A, left, right)
    ;; result type: app(app(app(motive, left), right), proof)
    [(expr-J mot base left right proof)
     (let ([pt (whnf (infer ctx proof))])
       (match pt
         [(expr-Eq t t1 t2)
          (if (and (conv t1 left) (conv t2 right))
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
    [((expr-lam m a body) (expr-Pi m2 t-dom b))
     (cond
       [(not (eq? m m2)) #f]  ; multiplicity mismatch
       [(not (conv a t-dom)) #f]  ; domain mismatch
       [else (check (ctx-extend ctx a m) body b)])]

    ;; ---- Pair: check against Sigma ----
    ;; check(G, pair(e1, e2), Sigma(A, B))
    [((expr-pair e1 e2) (expr-Sigma a b))
     (and (check ctx e1 a)
          (check ctx e2 (subst 0 e1 b)))]

    ;; ---- refl: check against Eq ----
    ;; refl : Eq(A, e1, e2) iff conv(e1, e2)
    [((expr-refl) (expr-Eq _ e1 e2))
     (conv e1 e2)]

    ;; ---- Vec constructors ----
    ;; vnil(A) : Vec(A, zero)
    [((expr-vnil a1) (expr-Vec a2 n))
     (and (is-type ctx a1)
          (conv a1 a2)
          (conv n (expr-zero)))]

    ;; vcons(A, n, head, tail) : Vec(A, suc(n))
    [((expr-vcons a1 n1 hd tl) (expr-Vec a2 len))
     (and (conv a1 a2)
          (conv len (expr-suc n1))
          (check ctx hd a1)
          (check ctx tl (expr-Vec a1 n1)))]

    ;; ---- Fin constructors ----
    ;; fzero(n) : Fin(suc(n))
    [((expr-fzero n1) (expr-Fin bound))
     (and (conv bound (expr-suc n1))
          (check ctx n1 (expr-Nat)))]

    ;; fsuc(n, i) : Fin(suc(n))  when i : Fin(n)
    [((expr-fsuc n1 i) (expr-Fin bound))
     (and (conv bound (expr-suc n1))
          (check ctx i (expr-Fin n1)))]

    ;; ---- Conversion fallback ----
    ;; If e synthesizes to T' and conv(T, T'), then check succeeds
    [(_ t-whnf)
     (let ([t1 (infer ctx e)])
       (and (not (expr-error? t1))
            (conv t t1)))]))

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
