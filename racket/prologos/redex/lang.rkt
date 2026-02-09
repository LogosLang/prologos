#lang racket/base

;;;
;;; PROLOGOS REDEX — LANGUAGE DEFINITION
;;; PLT Redex formalization of the Prologos expression grammar.
;;; Faithfully encodes all 31 constructors from syntax.rkt plus
;;; multiplicities and universe levels from prelude.rkt.
;;;
;;; Cross-reference: syntax.rkt (218 lines), prelude.rkt (104 lines)
;;;

(require redex/reduction-semantics)

(provide (all-defined-out))

(define-language Prologos

  ;; ========================================
  ;; Multiplicities (from prelude.rkt)
  ;; ========================================
  (m ::= m0 m1 mw)

  ;; ========================================
  ;; Universe Levels (from prelude.rkt)
  ;; ========================================
  (l ::= lzero (lsuc l))

  ;; ========================================
  ;; Expressions (from syntax.rkt)
  ;; Types are expressions in dependent type theory.
  ;; ========================================
  (e ::=
     ;; Variables (locally nameless: de Bruijn indices for bound, names for free)
     (bvar natural)                         ; bound variable at de Bruijn index
     (fvar variable-not-otherwise-mentioned) ; free variable (global/external)

     ;; Natural numbers
     zero
     (suc e)

     ;; Lambda and application
     (lam m e e)                            ; lam(mult, domain-type, body)
     (app e e)                              ; app(func, arg)

     ;; Pairs (Sigma intro/elim)
     (pair e e)
     (fst e)
     (snd e)

     ;; Equality introduction
     refl

     ;; Type annotation
     (ann e e)                              ; ann(term, type)

     ;; Nat eliminator
     (natrec e e e e)                       ; natrec(motive, base, step, target)

     ;; J eliminator for equality
     (J e e e e e)                          ; J(motive, base, left, right, proof)

     ;; Type constructors
     (Type l)                               ; Type(level) : Type(lsuc(level))
     Nat                                    ; Natural number type
     Bool                                   ; Boolean type
     true                                   ; Bool constructor
     false                                  ; Bool constructor

     ;; Dependent function type
     (Pi m e e)                             ; Pi(mult, domain, codomain)

     ;; Dependent pair type
     (Sigma e e)                            ; Sigma(fst-type, snd-type)

     ;; Identity/Equality type
     (Eq e e e)                             ; Eq(type, lhs, rhs)

     ;; Vec type and constructors
     (Vec e e)                              ; Vec(elem-type, length)
     (vnil e)                               ; vnil(A) : Vec(A, zero)
     (vcons e e e e)                        ; vcons(A, n, head, tail) : Vec(A, suc(n))

     ;; Fin type and constructors
     (Fin e)                                ; Fin(bound)
     (fzero e)                              ; fzero(n) : Fin(suc(n))
     (fsuc e e)                             ; fsuc(n, inner) : Fin(suc(n))

     ;; Vec eliminators
     (vhead e e e)                          ; vhead(A, n, vec) : A
     (vtail e e e)                          ; vtail(A, n, vec) : Vec(A, n)
     (vindex e e e e)                       ; vindex(A, n, idx, vec) : A

     ;; Error sentinel (for failed inference)
     err)

  ;; ========================================
  ;; Typing Contexts (from syntax.rkt)
  ;; ========================================
  ;; A context is a list of (type multiplicity) bindings.
  ;; Binding at position 0 is most recently added (head).
  ;; bvar(k) refers to the binding at position k.
  (Gamma ::=
         ()                                 ; empty context
         ((e m) Gamma))                     ; extend with type and multiplicity

  ;; Natural number non-terminal (for side conditions)
  (n ::= natural))

;; ========================================
;; Context helper metafunctions
;; ========================================

(define-metafunction Prologos
  ctx-len : Gamma -> natural
  [(ctx-len ()) 0]
  [(ctx-len ((e m) Gamma)) ,(add1 (term (ctx-len Gamma)))])

(define-metafunction Prologos
  lookup-type : natural Gamma -> e
  [(lookup-type 0 ((e m) Gamma)) e]
  [(lookup-type natural_k ((e m) Gamma))
   (lookup-type ,(sub1 (term natural_k)) Gamma)
   (side-condition (> (term natural_k) 0))]
  [(lookup-type natural_k ()) err])

(define-metafunction Prologos
  lookup-mult : natural Gamma -> m
  [(lookup-mult 0 ((e m) Gamma)) m]
  [(lookup-mult natural_k ((e m) Gamma))
   (lookup-mult ,(sub1 (term natural_k)) Gamma)
   (side-condition (> (term natural_k) 0))])

;; ========================================
;; Universe level helpers (from prelude.rkt)
;; ========================================

(define-metafunction Prologos
  lmax : l l -> l
  [(lmax lzero l) l]
  [(lmax l lzero) l]
  [(lmax (lsuc l_1) (lsuc l_2)) (lsuc (lmax l_1 l_2))]
  [(lmax l l) l])

;; ========================================
;; Multiplicity semiring (from prelude.rkt)
;; ========================================

(define-metafunction Prologos
  mult-add : m m -> m
  [(mult-add m0 m0) m0]
  [(mult-add m0 m1) m1]
  [(mult-add m1 m0) m1]
  [(mult-add m0 mw) mw]
  [(mult-add mw m0) mw]
  [(mult-add m1 m1) mw]
  [(mult-add m1 mw) mw]
  [(mult-add mw m1) mw]
  [(mult-add mw mw) mw])

(define-metafunction Prologos
  mult-mul : m m -> m
  [(mult-mul m0 m0) m0]
  [(mult-mul m0 m1) m0]
  [(mult-mul m1 m0) m0]
  [(mult-mul m0 mw) m0]
  [(mult-mul mw m0) m0]
  [(mult-mul m1 m1) m1]
  [(mult-mul m1 mw) mw]
  [(mult-mul mw m1) mw]
  [(mult-mul mw mw) mw])

(define-metafunction Prologos
  compatible : m m -> boolean
  ;; compatible(declared, actual) — is actual usage OK for declared multiplicity?
  [(compatible m0 m0) #t]
  [(compatible m0 m1) #f]
  [(compatible m0 mw) #f]
  [(compatible m1 m0) #f]
  [(compatible m1 m1) #t]
  [(compatible m1 mw) #f]
  [(compatible mw m0) #t]
  [(compatible mw m1) #t]
  [(compatible mw mw) #t])
