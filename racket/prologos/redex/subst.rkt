#lang racket/base

;;;
;;; PROLOGOS REDEX — SUBSTITUTION
;;; PLT Redex metafunctions for shift, subst, and open-expr.
;;; Clause-by-clause translation of substitution.rkt (172 lines).
;;;
;;; shift(delta, cutoff, e) : increase bound indices >= cutoff by delta
;;; subst(k, s, e)         : replace bvar(k) with s in e (shifting s under binders)
;;; open-expr(body, arg)   : subst(0, arg, body)
;;;
;;; Cross-reference: substitution.rkt
;;;

(require redex/reduction-semantics
         "lang.rkt")

(provide (all-defined-out))

;; ========================================
;; Shift: increase bound indices >= cutoff by delta
;; ========================================
(define-metafunction Prologos
  shift : natural natural e -> e

  ;; Variables
  [(shift natural_d natural_c (bvar natural_k))
   (bvar ,(+ (term natural_k) (term natural_d)))
   (side-condition (>= (term natural_k) (term natural_c)))]
  [(shift natural_d natural_c (bvar natural_k))
   (bvar natural_k)
   (side-condition (< (term natural_k) (term natural_c)))]
  [(shift natural_d natural_c (fvar variable_x))
   (fvar variable_x)]

  ;; Constants (no bound variables inside)
  [(shift natural_d natural_c zero) zero]
  [(shift natural_d natural_c (suc e_1))
   (suc (shift natural_d natural_c e_1))]
  [(shift natural_d natural_c refl) refl]
  [(shift natural_d natural_c Nat) Nat]
  [(shift natural_d natural_c Bool) Bool]
  [(shift natural_d natural_c true) true]
  [(shift natural_d natural_c false) false]
  [(shift natural_d natural_c (Type l)) (Type l)]
  [(shift natural_d natural_c err) err]

  ;; Binding forms: cutoff increases under binders
  [(shift natural_d natural_c (lam m e_t e_body))
   (lam m (shift natural_d natural_c e_t)
          (shift natural_d ,(add1 (term natural_c)) e_body))]
  [(shift natural_d natural_c (Pi m e_dom e_cod))
   (Pi m (shift natural_d natural_c e_dom)
         (shift natural_d ,(add1 (term natural_c)) e_cod))]
  [(shift natural_d natural_c (Sigma e_t1 e_t2))
   (Sigma (shift natural_d natural_c e_t1)
          (shift natural_d ,(add1 (term natural_c)) e_t2))]

  ;; Non-binding forms
  [(shift natural_d natural_c (app e_1 e_2))
   (app (shift natural_d natural_c e_1) (shift natural_d natural_c e_2))]
  [(shift natural_d natural_c (pair e_1 e_2))
   (pair (shift natural_d natural_c e_1) (shift natural_d natural_c e_2))]
  [(shift natural_d natural_c (fst e_1))
   (fst (shift natural_d natural_c e_1))]
  [(shift natural_d natural_c (snd e_1))
   (snd (shift natural_d natural_c e_1))]
  [(shift natural_d natural_c (ann e_1 e_2))
   (ann (shift natural_d natural_c e_1) (shift natural_d natural_c e_2))]
  [(shift natural_d natural_c (Eq e_t e_1 e_2))
   (Eq (shift natural_d natural_c e_t)
       (shift natural_d natural_c e_1)
       (shift natural_d natural_c e_2))]

  ;; Eliminators (all arguments non-binding — motives are lambda terms)
  [(shift natural_d natural_c (natrec e_mot e_base e_step e_target))
   (natrec (shift natural_d natural_c e_mot)
           (shift natural_d natural_c e_base)
           (shift natural_d natural_c e_step)
           (shift natural_d natural_c e_target))]
  [(shift natural_d natural_c (J e_mot e_base e_left e_right e_proof))
   (J (shift natural_d natural_c e_mot)
      (shift natural_d natural_c e_base)
      (shift natural_d natural_c e_left)
      (shift natural_d natural_c e_right)
      (shift natural_d natural_c e_proof))]

  ;; Vec/Fin (all non-binding)
  [(shift natural_d natural_c (Vec e_t e_n))
   (Vec (shift natural_d natural_c e_t) (shift natural_d natural_c e_n))]
  [(shift natural_d natural_c (vnil e_t))
   (vnil (shift natural_d natural_c e_t))]
  [(shift natural_d natural_c (vcons e_t e_n e_hd e_tl))
   (vcons (shift natural_d natural_c e_t)
          (shift natural_d natural_c e_n)
          (shift natural_d natural_c e_hd)
          (shift natural_d natural_c e_tl))]
  [(shift natural_d natural_c (Fin e_n))
   (Fin (shift natural_d natural_c e_n))]
  [(shift natural_d natural_c (fzero e_n))
   (fzero (shift natural_d natural_c e_n))]
  [(shift natural_d natural_c (fsuc e_n e_i))
   (fsuc (shift natural_d natural_c e_n) (shift natural_d natural_c e_i))]
  [(shift natural_d natural_c (vhead e_t e_n e_v))
   (vhead (shift natural_d natural_c e_t)
          (shift natural_d natural_c e_n)
          (shift natural_d natural_c e_v))]
  [(shift natural_d natural_c (vtail e_t e_n e_v))
   (vtail (shift natural_d natural_c e_t)
          (shift natural_d natural_c e_n)
          (shift natural_d natural_c e_v))]
  [(shift natural_d natural_c (vindex e_t e_n e_i e_v))
   (vindex (shift natural_d natural_c e_t)
           (shift natural_d natural_c e_n)
           (shift natural_d natural_c e_i)
           (shift natural_d natural_c e_v))])

;; ========================================
;; Substitution: replace bvar(k) with s in e
;; When going under a binder, k increases and s is shifted up
;; ========================================
(define-metafunction Prologos
  subst : natural e e -> e

  ;; Variables
  [(subst natural_k e_s (bvar natural_k)) e_s]
  [(subst natural_k e_s (bvar natural_n))
   (bvar natural_n)
   (side-condition (not (= (term natural_k) (term natural_n))))]
  [(subst natural_k e_s (fvar variable_x))
   (fvar variable_x)]

  ;; Constants
  [(subst natural_k e_s zero) zero]
  [(subst natural_k e_s (suc e_1))
   (suc (subst natural_k e_s e_1))]
  [(subst natural_k e_s refl) refl]
  [(subst natural_k e_s Nat) Nat]
  [(subst natural_k e_s Bool) Bool]
  [(subst natural_k e_s true) true]
  [(subst natural_k e_s false) false]
  [(subst natural_k e_s (Type l)) (Type l)]
  [(subst natural_k e_s err) err]

  ;; Binding forms: increase k, shift s up by 1
  [(subst natural_k e_s (lam m e_t e_body))
   (lam m (subst natural_k e_s e_t)
          (subst ,(add1 (term natural_k)) (shift 1 0 e_s) e_body))]
  [(subst natural_k e_s (Pi m e_dom e_cod))
   (Pi m (subst natural_k e_s e_dom)
         (subst ,(add1 (term natural_k)) (shift 1 0 e_s) e_cod))]
  [(subst natural_k e_s (Sigma e_t1 e_t2))
   (Sigma (subst natural_k e_s e_t1)
          (subst ,(add1 (term natural_k)) (shift 1 0 e_s) e_t2))]

  ;; Non-binding forms
  [(subst natural_k e_s (app e_1 e_2))
   (app (subst natural_k e_s e_1) (subst natural_k e_s e_2))]
  [(subst natural_k e_s (pair e_1 e_2))
   (pair (subst natural_k e_s e_1) (subst natural_k e_s e_2))]
  [(subst natural_k e_s (fst e_1))
   (fst (subst natural_k e_s e_1))]
  [(subst natural_k e_s (snd e_1))
   (snd (subst natural_k e_s e_1))]
  [(subst natural_k e_s (ann e_1 e_2))
   (ann (subst natural_k e_s e_1) (subst natural_k e_s e_2))]
  [(subst natural_k e_s (Eq e_t e_1 e_2))
   (Eq (subst natural_k e_s e_t)
       (subst natural_k e_s e_1)
       (subst natural_k e_s e_2))]

  ;; Eliminators (non-binding)
  [(subst natural_k e_s (natrec e_mot e_base e_step e_target))
   (natrec (subst natural_k e_s e_mot)
           (subst natural_k e_s e_base)
           (subst natural_k e_s e_step)
           (subst natural_k e_s e_target))]
  [(subst natural_k e_s (J e_mot e_base e_left e_right e_proof))
   (J (subst natural_k e_s e_mot)
      (subst natural_k e_s e_base)
      (subst natural_k e_s e_left)
      (subst natural_k e_s e_right)
      (subst natural_k e_s e_proof))]

  ;; Vec/Fin (all non-binding)
  [(subst natural_k e_s (Vec e_t e_n))
   (Vec (subst natural_k e_s e_t) (subst natural_k e_s e_n))]
  [(subst natural_k e_s (vnil e_t))
   (vnil (subst natural_k e_s e_t))]
  [(subst natural_k e_s (vcons e_t e_n e_hd e_tl))
   (vcons (subst natural_k e_s e_t)
          (subst natural_k e_s e_n)
          (subst natural_k e_s e_hd)
          (subst natural_k e_s e_tl))]
  [(subst natural_k e_s (Fin e_n))
   (Fin (subst natural_k e_s e_n))]
  [(subst natural_k e_s (fzero e_n))
   (fzero (subst natural_k e_s e_n))]
  [(subst natural_k e_s (fsuc e_n e_i))
   (fsuc (subst natural_k e_s e_n) (subst natural_k e_s e_i))]
  [(subst natural_k e_s (vhead e_t e_n e_v))
   (vhead (subst natural_k e_s e_t)
          (subst natural_k e_s e_n)
          (subst natural_k e_s e_v))]
  [(subst natural_k e_s (vtail e_t e_n e_v))
   (vtail (subst natural_k e_s e_t)
          (subst natural_k e_s e_n)
          (subst natural_k e_s e_v))]
  [(subst natural_k e_s (vindex e_t e_n e_i e_v))
   (vindex (subst natural_k e_s e_t)
           (subst natural_k e_s e_n)
           (subst natural_k e_s e_i)
           (subst natural_k e_s e_v))])

;; ========================================
;; Open: substitute arg for bvar(0) in body
;; open-expr(body, arg) = subst(0, arg, body)
;; ========================================
(define-metafunction Prologos
  open-expr : e e -> e
  [(open-expr e_body e_arg) (subst 0 e_arg e_body)])
