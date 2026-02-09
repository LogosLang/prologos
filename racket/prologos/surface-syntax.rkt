#lang racket/base

;;;
;;; PROLOGOS SURFACE SYNTAX
;;; Surface AST with named variables and source locations.
;;; This is the output of the parser, before elaboration to core AST.
;;;

(require "source-location.rkt")

(provide
 ;; Surface expression structs
 (struct-out surf-var)
 (struct-out surf-nat-lit)
 (struct-out surf-zero)
 (struct-out surf-suc)
 (struct-out surf-true)
 (struct-out surf-false)
 (struct-out surf-lam)
 (struct-out surf-app)
 (struct-out surf-pi)
 (struct-out surf-arrow)
 (struct-out surf-sigma)
 (struct-out surf-pair)
 (struct-out surf-fst)
 (struct-out surf-snd)
 (struct-out surf-ann)
 (struct-out surf-refl)
 (struct-out surf-eq)
 (struct-out surf-type)
 (struct-out surf-nat-type)
 (struct-out surf-bool-type)
 (struct-out surf-boolrec)
 (struct-out surf-natrec)
 (struct-out surf-J)
 ;; Vec/Fin surface forms
 (struct-out surf-vec-type)
 (struct-out surf-vnil)
 (struct-out surf-vcons)
 (struct-out surf-fin-type)
 (struct-out surf-fzero)
 (struct-out surf-fsuc)
 (struct-out surf-vhead)
 (struct-out surf-vtail)
 (struct-out surf-vindex)
 ;; Posit8 surface forms
 (struct-out surf-posit8-type)
 (struct-out surf-posit8)
 (struct-out surf-p8-add)
 (struct-out surf-p8-sub)
 (struct-out surf-p8-mul)
 (struct-out surf-p8-div)
 (struct-out surf-p8-neg)
 (struct-out surf-p8-abs)
 (struct-out surf-p8-sqrt)
 (struct-out surf-p8-lt)
 (struct-out surf-p8-le)
 (struct-out surf-p8-from-nat)
 (struct-out surf-p8-if-nar)
 ;; Top-level commands
 (struct-out surf-def)
 (struct-out surf-defn)
 (struct-out surf-check)
 (struct-out surf-eval)
 (struct-out surf-infer)
 ;; Annotated lambda
 (struct-out surf-the-fn)
 ;; Binder info
 (struct-out binder-info))

;; ========================================
;; Binder information (for lam, Pi, Sigma)
;; ========================================
(struct binder-info (name mult type) #:transparent)

;; ========================================
;; Surface Expressions
;; ========================================

;; Variables (named, not de Bruijn)
(struct surf-var (name srcloc) #:transparent)

;; Natural number literal (desugars to suc(suc(...zero)))
(struct surf-nat-lit (value srcloc) #:transparent)

;; Nat constants
(struct surf-zero (srcloc) #:transparent)
(struct surf-suc (pred srcloc) #:transparent)

;; Bool constants
(struct surf-true (srcloc) #:transparent)
(struct surf-false (srcloc) #:transparent)

;; Lambda: (lam (x : T) body) or (lam (x :1 T) body)
(struct surf-lam (binder body srcloc) #:transparent)

;; Application: (f a b c) -> multi-arg
(struct surf-app (func args srcloc) #:transparent)

;; Pi type: (Pi (x : T) body)
(struct surf-pi (binder body srcloc) #:transparent)

;; Non-dependent function: (-> A B)
(struct surf-arrow (domain codomain srcloc) #:transparent)

;; Sigma type: (Sigma (x : T) body)
(struct surf-sigma (binder body srcloc) #:transparent)

;; Pair: (pair a b)
(struct surf-pair (fst snd srcloc) #:transparent)

;; Projections: (fst e), (snd e)
(struct surf-fst (expr srcloc) #:transparent)
(struct surf-snd (expr srcloc) #:transparent)

;; Type annotation: (the T e)
(struct surf-ann (type term srcloc) #:transparent)

;; Reflexivity: refl
(struct surf-refl (srcloc) #:transparent)

;; Equality type: (Eq A a b)
(struct surf-eq (type lhs rhs srcloc) #:transparent)

;; Universe: (Type n)
(struct surf-type (level srcloc) #:transparent)

;; Nat type: Nat
(struct surf-nat-type (srcloc) #:transparent)

;; Bool type: Bool
(struct surf-bool-type (srcloc) #:transparent)

;; Bool eliminator: (boolrec motive true-case false-case target)
(struct surf-boolrec (motive true-case false-case target srcloc) #:transparent)

;; Nat eliminator: (natrec motive base step target)
(struct surf-natrec (motive base step target srcloc) #:transparent)

;; J eliminator: (J motive base left right proof)
(struct surf-J (motive base left right proof srcloc) #:transparent)

;; ========================================
;; Vec/Fin surface forms
;; ========================================

;; Vec type: (Vec A n)
(struct surf-vec-type (elem-type length srcloc) #:transparent)

;; vnil: (vnil A)
(struct surf-vnil (type srcloc) #:transparent)

;; vcons: (vcons A n head tail)
(struct surf-vcons (type len head tail srcloc) #:transparent)

;; Fin type: (Fin n)
(struct surf-fin-type (bound srcloc) #:transparent)

;; fzero: (fzero n)
(struct surf-fzero (n srcloc) #:transparent)

;; fsuc: (fsuc n inner)
(struct surf-fsuc (n inner srcloc) #:transparent)

;; vhead: (vhead A n v)
(struct surf-vhead (type len vec srcloc) #:transparent)

;; vtail: (vtail A n v)
(struct surf-vtail (type len vec srcloc) #:transparent)

;; vindex: (vindex A n i v)
(struct surf-vindex (type len idx vec srcloc) #:transparent)

;; ========================================
;; Posit8 surface forms (8-bit posit, es=2, 2022 Standard)
;; ========================================

;; Posit8 type: Posit8
(struct surf-posit8-type (srcloc) #:transparent)

;; Posit8 literal: (posit8 <integer>)
(struct surf-posit8 (val srcloc) #:transparent)

;; Binary arithmetic: (p8+ a b), (p8- a b), (p8* a b), (p8/ a b)
(struct surf-p8-add (a b srcloc) #:transparent)
(struct surf-p8-sub (a b srcloc) #:transparent)
(struct surf-p8-mul (a b srcloc) #:transparent)
(struct surf-p8-div (a b srcloc) #:transparent)

;; Unary ops: (p8-neg a), (p8-abs a), (p8-sqrt a)
(struct surf-p8-neg (a srcloc) #:transparent)
(struct surf-p8-abs (a srcloc) #:transparent)
(struct surf-p8-sqrt (a srcloc) #:transparent)

;; Comparison: (p8< a b), (p8<= a b)
(struct surf-p8-lt (a b srcloc) #:transparent)
(struct surf-p8-le (a b srcloc) #:transparent)

;; Conversion: (p8-from-nat n)
(struct surf-p8-from-nat (n srcloc) #:transparent)

;; Eliminator: (p8-if-nar A nar-case normal-case val)
(struct surf-p8-if-nar (type nar-case normal-case val srcloc) #:transparent)

;; ========================================
;; Top-level commands
;; ========================================

;; Definition: (def name : type body)
(struct surf-def (name type body srcloc) #:transparent)

;; Sugared definition: (defn name : type [params...] body)
;; Desugars to (def name : type (fn ...nested lambdas... body))
(struct surf-defn (name type param-names body srcloc) #:transparent)

;; Type check: (check expr : type)
(struct surf-check (expr type srcloc) #:transparent)

;; Evaluate: (eval expr)
(struct surf-eval (expr srcloc) #:transparent)

;; Infer type: (infer expr)
(struct surf-infer (expr srcloc) #:transparent)

;; Annotated lambda: (the-fn type [params...] body)
;; Desugars to (the type (fn (p1:T1) (fn (p2:T2) ... body)))
(struct surf-the-fn (type param-names body srcloc) #:transparent)
