#lang racket/base

;;;
;;; PROLOGOS SYNTAX
;;; The complete term language for Prologos in locally-nameless representation.
;;; Direct translation of prologos-syntax.maude + prologos-inductive.maude constructors.
;;;
;;; Bound variables are de Bruijn indices (expr-bvar).
;;; Free variables are names (expr-fvar).
;;; Types are Expr (types are first-class in dependent type theory).
;;;

(require "prelude.rkt")

(provide
 ;; Expression constructors
 (struct-out expr-bvar)
 (struct-out expr-fvar)
 (struct-out expr-zero)
 (struct-out expr-suc)
 (struct-out expr-lam)
 (struct-out expr-app)
 (struct-out expr-pair)
 (struct-out expr-fst)
 (struct-out expr-snd)
 (struct-out expr-refl)
 (struct-out expr-ann)
 (struct-out expr-natrec)
 (struct-out expr-J)
 ;; Type constructors (also Exprs)
 (struct-out expr-Type)
 (struct-out expr-Nat)
 (struct-out expr-Bool)
 (struct-out expr-true)
 (struct-out expr-false)
 (struct-out expr-boolrec)
 (struct-out expr-Pi)
 (struct-out expr-Sigma)
 (struct-out expr-Eq)
 ;; Vec/Fin (from inductive module — defined upfront)
 (struct-out expr-Vec)
 (struct-out expr-vnil)
 (struct-out expr-vcons)
 (struct-out expr-Fin)
 (struct-out expr-fzero)
 (struct-out expr-fsuc)
 (struct-out expr-vhead)
 (struct-out expr-vtail)
 (struct-out expr-vindex)
 ;; Posit8 (8-bit posit, es=2, 2022 Standard)
 (struct-out expr-Posit8)
 (struct-out expr-posit8)
 (struct-out expr-p8-add)
 (struct-out expr-p8-sub)
 (struct-out expr-p8-mul)
 (struct-out expr-p8-div)
 (struct-out expr-p8-neg)
 (struct-out expr-p8-abs)
 (struct-out expr-p8-sqrt)
 (struct-out expr-p8-lt)
 (struct-out expr-p8-le)
 (struct-out expr-p8-from-nat)
 (struct-out expr-p8-if-nar)
 ;; Error marker
 (struct-out expr-error)
 ;; Expr predicate
 expr?
 ;; Convenience
 nat->expr arrow sigma-pair
 ;; Context operations
 ctx-empty ctx-extend
 lookup-type lookup-mult ctx-len)

;; ========================================
;; Expression Constructors
;; ========================================

;; Variables
(struct expr-bvar (index) #:transparent)         ; bound variable (de Bruijn index)
(struct expr-fvar (name) #:transparent)           ; free variable (named)

;; Natural numbers
(struct expr-zero () #:transparent)
(struct expr-suc (pred) #:transparent)

;; Lambda and application
(struct expr-lam (mult type body) #:transparent)  ; lam(mult, type, body)
(struct expr-app (func arg) #:transparent)        ; app(func, arg)

;; Pairs (Sigma intro/elim)
(struct expr-pair (fst snd) #:transparent)
(struct expr-fst (expr) #:transparent)
(struct expr-snd (expr) #:transparent)

;; Equality introduction
(struct expr-refl () #:transparent)

;; Type annotation
(struct expr-ann (term type) #:transparent)       ; ann(term, type)

;; Nat eliminator
;; natrec(motive, base, step, target)
;; motive : Nat -> Type
;; base   : motive(0)
;; step   : Pi(n:Nat). motive(n) -> motive(suc(n))
;; target : Nat
(struct expr-natrec (motive base step target) #:transparent)

;; J eliminator for equality
;; J(motive, base, target-left, target-right, proof)
;; motive : Pi(a:A). Pi(b:A). (a = b) -> Type
;; base   : Pi(a:A). motive(a, a, refl)
;; target-left, target-right : A
;; proof  : target-left = target-right
(struct expr-J (motive base left right proof) #:transparent)

;; ========================================
;; Type Constructors (also Exprs)
;; ========================================

;; Universe
(struct expr-Type (level) #:transparent)          ; Type(n) : Type(n+1)

;; Natural number type
(struct expr-Nat () #:transparent)

;; Bool type
(struct expr-Bool () #:transparent)
(struct expr-true () #:transparent)
(struct expr-false () #:transparent)

;; Bool eliminator
;; boolrec(motive, true-case, false-case, target)
;; motive     : Bool -> Type(l)
;; true-case  : motive(true)
;; false-case : motive(false)
;; target     : Bool
;; result     : motive(target)
(struct expr-boolrec (motive true-case false-case target) #:transparent)

;; Dependent function type
(struct expr-Pi (mult domain codomain) #:transparent) ; Pi(mult, domain, codomain)

;; Dependent pair type
(struct expr-Sigma (fst-type snd-type) #:transparent) ; Sigma(fst-type, snd-type)

;; Identity/Equality type
(struct expr-Eq (type lhs rhs) #:transparent)     ; Eq(type, lhs, rhs)

;; ========================================
;; Vec and Fin (from prologos-inductive.maude)
;; Defined upfront since the full set of constructors is known.
;; ========================================

;; Vec type: Vec(A, n) where A : Type and n : Nat
(struct expr-Vec (elem-type length) #:transparent)

;; Vec constructors
(struct expr-vnil (type) #:transparent)            ; vnil(A) : Vec(A, zero)
(struct expr-vcons (type len head tail) #:transparent) ; vcons(A, n, head, tail) : Vec(A, suc(n))

;; Fin type: Fin(n) where n : Nat
(struct expr-Fin (bound) #:transparent)

;; Fin constructors
(struct expr-fzero (n) #:transparent)              ; fzero(n) : Fin(suc(n))
(struct expr-fsuc (n inner) #:transparent)         ; fsuc(n, i) : Fin(suc(n)) when i : Fin(n)

;; Vec eliminators
(struct expr-vhead (type len vec) #:transparent)   ; vhead(A, n, v) : A
(struct expr-vtail (type len vec) #:transparent)   ; vtail(A, n, v) : Vec(A, n)
(struct expr-vindex (type len idx vec) #:transparent) ; vindex(A, n, i, v) : A

;; ========================================
;; Posit8 (8-bit posit, es=2, 2022 Standard)
;; ========================================

;; Type
(struct expr-Posit8 () #:transparent)                           ; Posit8 : Type 0

;; Value (val is exact integer 0–255 representing the posit8 bit pattern)
(struct expr-posit8 (val) #:transparent)                        ; posit8 literal

;; Binary arithmetic (Posit8 -> Posit8 -> Posit8)
(struct expr-p8-add (a b) #:transparent)
(struct expr-p8-sub (a b) #:transparent)
(struct expr-p8-mul (a b) #:transparent)
(struct expr-p8-div (a b) #:transparent)

;; Unary operations (Posit8 -> Posit8)
(struct expr-p8-neg (a) #:transparent)
(struct expr-p8-abs (a) #:transparent)
(struct expr-p8-sqrt (a) #:transparent)

;; Comparison (Posit8 -> Posit8 -> Bool)
(struct expr-p8-lt (a b) #:transparent)
(struct expr-p8-le (a b) #:transparent)

;; Conversion (Nat -> Posit8)
(struct expr-p8-from-nat (n) #:transparent)

;; Eliminator: branch on NaR
;; p8-if-nar(A, nar-case, normal-case, x) : A
;; If x is NaR, return nar-case; otherwise, return normal-case
(struct expr-p8-if-nar (type nar-case normal-case val) #:transparent)

;; ========================================
;; Error marker (for failed inference)
;; ========================================
(struct expr-error () #:transparent)

;; ========================================
;; Expr predicate
;; ========================================
(define (expr? x)
  (or (expr-bvar? x) (expr-fvar? x)
      (expr-zero? x) (expr-suc? x)
      (expr-lam? x) (expr-app? x)
      (expr-pair? x) (expr-fst? x) (expr-snd? x)
      (expr-refl? x) (expr-ann? x)
      (expr-natrec? x) (expr-J? x)
      (expr-Type? x) (expr-Nat? x)
      (expr-Bool? x) (expr-true? x) (expr-false? x) (expr-boolrec? x)
      (expr-Pi? x) (expr-Sigma? x) (expr-Eq? x)
      (expr-Vec? x) (expr-vnil? x) (expr-vcons? x)
      (expr-Fin? x) (expr-fzero? x) (expr-fsuc? x)
      (expr-vhead? x) (expr-vtail? x) (expr-vindex? x)
      (expr-Posit8? x) (expr-posit8? x)
      (expr-p8-add? x) (expr-p8-sub? x) (expr-p8-mul? x) (expr-p8-div? x)
      (expr-p8-neg? x) (expr-p8-abs? x) (expr-p8-sqrt? x)
      (expr-p8-lt? x) (expr-p8-le? x)
      (expr-p8-from-nat? x) (expr-p8-if-nar? x)
      (expr-error? x)))

;; ========================================
;; Convenience: convert Racket natural to Prologos numerals
;; ========================================
;; nat(0) = zero
;; nat(n+1) = suc(nat(n))
(define (nat->expr n)
  (if (zero? n)
      (expr-zero)
      (expr-suc (nat->expr (sub1 n)))))

;; Non-dependent function type sugar: A --> B = Pi(mw, A, B)
(define (arrow a b)
  (expr-Pi mw a b))

;; Non-dependent pair type sugar: A ** B = Sigma(A, B)
(define (sigma-pair a b)
  (expr-Sigma a b))

;; ========================================
;; Contexts
;; ========================================
;; A context is a list of (cons type mult) bindings.
;; Binding at position 0 is the most recently added (head of list).
;; bvar(k) refers to the binding at position k.

(define ctx-empty '())

;; extend(ctx, type, mult) — add a binding to the front
(define (ctx-extend ctx type mult)
  (cons (cons type mult) ctx))

;; lookup-type: retrieve the type at position k
(define (lookup-type k ctx)
  (if (< k (length ctx))
      (car (list-ref ctx k))
      (expr-error)))

;; lookup-mult: retrieve the multiplicity at position k
(define (lookup-mult k ctx)
  (if (< k (length ctx))
      (cdr (list-ref ctx k))
      (error 'lookup-mult "index ~a out of bounds for context of length ~a" k (length ctx))))

;; ctx-len: number of bindings in context
(define (ctx-len ctx)
  (length ctx))
