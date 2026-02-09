#lang racket/base

;;;
;;; PROLOGOS REDEX — REDUCTION
;;; PLT Redex reduction relation, WHNF, NF, and conversion.
;;; Faithful translation of reduction.rkt (163 lines).
;;;
;;; whnf-red    : single-step reduction relation (for traces visualization)
;;; whnf(e)     : reduce to weak head normal form (metafunction)
;;; nf(e)       : reduce to full normal form
;;; conv(e1,e2) : definitional equality (compare normal forms)
;;;
;;; Note: The kernel's whnf also unfolds free variables via global-env.
;;; This Redex formalization omits the global environment — all terms
;;; are closed or use ann() for type annotations. This simplifies
;;; the model for metatheoretic property checking.
;;;
;;; Cross-reference: reduction.rkt
;;;

(require redex/reduction-semantics
         "lang.rkt"
         "subst.rkt")

(provide whnf-red whnf nf nf-whnf conv)

;; ========================================
;; Single-step reduction relation (for `traces`)
;; ========================================
(define whnf-red
  (reduction-relation
   Prologos
   #:domain e

   ;; Beta reduction
   (--> (app (lam m e_A e_body) e_arg)
        (subst 0 e_arg e_body)
        "beta")

   ;; Projections on pairs
   (--> (fst (pair e_1 e_2)) e_1 "fst-pair")
   (--> (snd (pair e_1 e_2)) e_2 "snd-pair")

   ;; Iota reduction for natrec
   (--> (natrec e_mot e_base e_step zero)
        e_base
        "natrec-zero")
   (--> (natrec e_mot e_base e_step (suc e_n))
        (app (app e_step e_n) (natrec e_mot e_base e_step e_n))
        "natrec-suc")

   ;; J reduction
   (--> (J e_mot e_base e_left e_right refl)
        (app e_base e_left)
        "J-refl")

   ;; Annotation erasure
   (--> (ann e_1 e_2) e_1 "ann-erase")

   ;; Vec eliminators
   (--> (vhead e_t e_n (vcons e_t2 e_n2 e_hd e_tl))
        e_hd
        "vhead-vcons")
   (--> (vtail e_t e_n (vcons e_t2 e_n2 e_hd e_tl))
        e_tl
        "vtail-vcons")))

;; ========================================
;; WHNF metafunction
;; Matches the kernel's whnf exactly, except for global env lookup.
;; Uses iterative head reduction: reduces the head/scrutinee position
;; until a redex is found or the term is stuck.
;; ========================================
(define-metafunction Prologos
  whnf : e -> e

  ;; === Direct reductions (redexes) ===

  ;; Beta: app(lam(m, A, body), arg) → whnf(subst(0, arg, body))
  [(whnf (app (lam m e_A e_body) e_arg))
   (whnf (subst 0 e_arg e_body))]

  ;; Projections on pairs
  [(whnf (fst (pair e_1 e_2))) (whnf e_1)]
  [(whnf (snd (pair e_1 e_2))) (whnf e_2)]

  ;; Natrec
  [(whnf (natrec e_mot e_base e_step zero)) (whnf e_base)]
  [(whnf (natrec e_mot e_base e_step (suc e_n)))
   (whnf (app (app e_step e_n) (natrec e_mot e_base e_step e_n)))]

  ;; J on refl
  [(whnf (J e_mot e_base e_left e_right refl))
   (whnf (app e_base e_left))]

  ;; Annotation erasure
  [(whnf (ann e_1 e_2)) (whnf e_1)]

  ;; Vec eliminators on constructors
  [(whnf (vhead e_t e_n (vcons e_t2 e_n2 e_hd e_tl))) (whnf e_hd)]
  [(whnf (vtail e_t e_n (vcons e_t2 e_n2 e_hd e_tl))) (whnf e_tl)]

  ;; === Head reduction for stuck compound terms ===
  ;; Try reducing the head/scrutinee first; if it changes, retry.

  ;; Application of non-lambda: reduce function first
  [(whnf (app e_1 e_2))
   (whnf (app (whnf e_1) e_2))
   (side-condition (not (equal? (term e_1) (term (whnf e_1)))))]

  ;; Projection of non-pair: reduce argument first
  [(whnf (fst e_1))
   (whnf (fst (whnf e_1)))
   (side-condition (not (equal? (term e_1) (term (whnf e_1)))))]
  [(whnf (snd e_1))
   (whnf (snd (whnf e_1)))
   (side-condition (not (equal? (term e_1) (term (whnf e_1)))))]

  ;; Natrec with non-canonical target
  [(whnf (natrec e_mot e_base e_step e_target))
   (whnf (natrec e_mot e_base e_step (whnf e_target)))
   (side-condition (not (equal? (term e_target) (term (whnf e_target)))))]

  ;; J with non-refl proof
  [(whnf (J e_mot e_base e_left e_right e_proof))
   (whnf (J e_mot e_base e_left e_right (whnf e_proof)))
   (side-condition (not (equal? (term e_proof) (term (whnf e_proof)))))]

  ;; Vec eliminators with non-constructor argument
  [(whnf (vhead e_t e_n e_v))
   (whnf (vhead e_t e_n (whnf e_v)))
   (side-condition (not (equal? (term e_v) (term (whnf e_v)))))]
  [(whnf (vtail e_t e_n e_v))
   (whnf (vtail e_t e_n (whnf e_v)))
   (side-condition (not (equal? (term e_v) (term (whnf e_v)))))]

  ;; === Base case: already in WHNF ===
  [(whnf e) e])

;; ========================================
;; Full Normalization: WHNF then normalize all subterms
;; ========================================
(define-metafunction Prologos
  nf : e -> e
  [(nf e) (nf-whnf (whnf e))])

;; Helper: normalize a term that is already in WHNF
(define-metafunction Prologos
  nf-whnf : e -> e

  ;; Atoms / leaves — already normal
  [(nf-whnf (bvar natural_k)) (bvar natural_k)]
  [(nf-whnf (fvar variable_x)) (fvar variable_x)]
  [(nf-whnf zero) zero]
  [(nf-whnf refl) refl]
  [(nf-whnf Nat) Nat]
  [(nf-whnf Bool) Bool]
  [(nf-whnf true) true]
  [(nf-whnf false) false]
  [(nf-whnf (Type l)) (Type l)]
  [(nf-whnf err) err]

  ;; Structured terms: normalize subterms
  [(nf-whnf (suc e_1)) (suc (nf e_1))]
  [(nf-whnf (lam m e_t e_body)) (lam m (nf e_t) (nf e_body))]
  [(nf-whnf (Pi m e_dom e_cod)) (Pi m (nf e_dom) (nf e_cod))]
  [(nf-whnf (Sigma e_t1 e_t2)) (Sigma (nf e_t1) (nf e_t2))]
  [(nf-whnf (pair e_1 e_2)) (pair (nf e_1) (nf e_2))]
  [(nf-whnf (Eq e_t e_1 e_2)) (Eq (nf e_t) (nf e_1) (nf e_2))]

  ;; Stuck applications and projections (neutral terms)
  [(nf-whnf (app e_1 e_2)) (app (nf e_1) (nf e_2))]
  [(nf-whnf (fst e_1)) (fst (nf e_1))]
  [(nf-whnf (snd e_1)) (snd (nf e_1))]

  ;; Annotation erasure (shouldn't appear in WHNF, but handle gracefully)
  [(nf-whnf (ann e_1 e_2)) (nf e_1)]

  ;; Stuck eliminators (neutral)
  [(nf-whnf (natrec e_mot e_base e_step e_target))
   (natrec (nf e_mot) (nf e_base) (nf e_step) (nf e_target))]
  [(nf-whnf (J e_mot e_base e_left e_right e_proof))
   (J (nf e_mot) (nf e_base) (nf e_left) (nf e_right) (nf e_proof))]

  ;; Vec/Fin normalization
  [(nf-whnf (Vec e_t e_n)) (Vec (nf e_t) (nf e_n))]
  [(nf-whnf (vnil e_t)) (vnil (nf e_t))]
  [(nf-whnf (vcons e_t e_n e_hd e_tl))
   (vcons (nf e_t) (nf e_n) (nf e_hd) (nf e_tl))]
  [(nf-whnf (Fin e_n)) (Fin (nf e_n))]
  [(nf-whnf (fzero e_n)) (fzero (nf e_n))]
  [(nf-whnf (fsuc e_n e_i)) (fsuc (nf e_n) (nf e_i))]
  [(nf-whnf (vhead e_t e_n e_v)) (vhead (nf e_t) (nf e_n) (nf e_v))]
  [(nf-whnf (vtail e_t e_n e_v)) (vtail (nf e_t) (nf e_n) (nf e_v))]
  [(nf-whnf (vindex e_t e_n e_i e_v))
   (vindex (nf e_t) (nf e_n) (nf e_i) (nf e_v))])

;; ========================================
;; Conversion: definitional equality
;; Two terms are equal iff their normal forms are identical.
;; ========================================
(define-metafunction Prologos
  conv : e e -> boolean
  [(conv e_1 e_2)
   ,(equal? (term (nf e_1)) (term (nf e_2)))])
