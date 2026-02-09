#lang racket/base

;;;
;;; PROLOGOS REDEX — BIDIRECTIONAL TYPE CHECKER
;;; PLT Redex metafunctions for type inference and checking.
;;; Faithful translation of typing-core.rkt (280 lines).
;;;
;;; infer(Gamma, e)       -> e         : synthesize a type (or err)
;;; check(Gamma, e, T)    -> boolean   : check that e has type T
;;; is-type(Gamma, T)     -> boolean   : verify T is a well-formed type
;;; infer-level(Gamma, T) -> any       : infer universe level (level or err)
;;;
;;; All four are define-metafunction (not judgment-form) for maximum
;;; flexibility with error handling and fallthrough logic.
;;;
;;; Cross-reference: typing-core.rkt
;;;

(require racket/match
         redex/reduction-semantics
         "lang.rkt"
         "subst.rkt"
         "reduce.rkt")

(provide infer check is-type infer-level)

;; ========================================
;; Type inference (synthesis mode)
;; Returns an expression (the inferred type) or err.
;; ========================================
(define-metafunction Prologos
  infer : Gamma e -> e

  ;; ---- Bound variable: lookup in context and shift ----
  ;; bvar(K) with K < len(Gamma): shift(K+1, 0, lookup-type(K, Gamma))
  [(infer Gamma (bvar natural_k))
   (shift ,(add1 (term natural_k)) 0 (lookup-type natural_k Gamma))
   (side-condition (< (term natural_k) (term (ctx-len Gamma))))]
  [(infer Gamma (bvar natural_k)) err]

  ;; ---- Free variable: no global env in Redex model ----
  [(infer Gamma (fvar variable_x)) err]

  ;; ---- Universes ----
  ;; Type(l) : Type(lsuc(l))
  [(infer Gamma (Type l)) (Type (lsuc l))]

  ;; ---- Natural numbers ----
  [(infer Gamma Nat) (Type lzero)]
  [(infer Gamma zero) Nat]
  ;; suc in synthesis: if argument infers to Nat
  [(infer Gamma (suc e_1))
   Nat
   (side-condition (equal? (term (infer Gamma e_1)) (term Nat)))]
  [(infer Gamma (suc e_1)) err]

  ;; ---- Booleans ----
  [(infer Gamma Bool) (Type lzero)]
  [(infer Gamma true) Bool]
  [(infer Gamma false) Bool]

  ;; ---- Annotated terms ----
  ;; ann(e, T) synthesizes T if T is a type and e checks against T
  [(infer Gamma (ann e_1 e_T))
   e_T
   (side-condition (term (is-type Gamma e_T)))
   (side-condition (term (check Gamma e_1 e_T)))]
  [(infer Gamma (ann e_1 e_T)) err]

  ;; ---- Pi elimination (application) ----
  ;; infer(G, app(e1, e2)):
  ;;   let t1 = whnf(infer(G, e1))
  ;;   if t1 is Pi(m, A, B) and check(G, e2, A) then subst(0, e2, B) else err
  [(infer Gamma (app e_1 e_2))
   ,(let ([t1 (term (whnf (infer Gamma e_1)))])
      (match t1
        [`(Pi ,m ,a ,b)
         (if (term (check Gamma e_2 ,a))
             (term (subst 0 e_2 ,b))
             (term err))]
        [_ (term err)]))]

  ;; ---- Sigma elimination: fst ----
  [(infer Gamma (fst e_1))
   ,(let ([t (term (whnf (infer Gamma e_1)))])
      (match t
        [`(Sigma ,a ,b) a]
        [_ (term err)]))]

  ;; ---- Sigma elimination: snd ----
  ;; snd(e1) : subst(0, fst(e1), B) when e1 : Sigma(A, B)
  [(infer Gamma (snd e_1))
   ,(let ([t (term (whnf (infer Gamma e_1)))])
      (match t
        [`(Sigma ,a ,b) (term (subst 0 (fst e_1) ,b))]
        [_ (term err)]))]

  ;; ---- Nat eliminator (natrec) ----
  ;; natrec(motive, base, step, target)
  ;; result type: app(motive, target)
  [(infer Gamma (natrec e_mot e_base e_step e_target))
   (app e_mot e_target)
   (side-condition (term (check Gamma e_target Nat)))
   (side-condition (term (check Gamma e_base (app e_mot zero))))]
  [(infer Gamma (natrec e_mot e_base e_step e_target)) err]

  ;; ---- J eliminator ----
  ;; J(motive, base, left, right, proof)
  ;; Need to extract type from proof's type Eq(A, t1, t2)
  ;; and verify conv(t1, left) and conv(t2, right)
  ;; result type: app(app(app(motive, left), right), proof)
  [(infer Gamma (J e_mot e_base e_left e_right e_proof))
   ,(let ([pt (term (whnf (infer Gamma e_proof)))])
      (match pt
        [`(Eq ,ty ,t1 ,t2)
         (if (and (term (conv ,t1 e_left))
                  (term (conv ,t2 e_right)))
             (term (app (app (app e_mot e_left) e_right) e_proof))
             (term err))]
        [_ (term err)]))]

  ;; ---- Vec eliminators ----
  ;; vhead(A, n, v) : A  when v : Vec(A, suc(n))
  [(infer Gamma (vhead e_A e_n e_v))
   e_A
   (side-condition (term (check Gamma e_v (Vec e_A (suc e_n)))))]
  [(infer Gamma (vhead e_A e_n e_v)) err]

  ;; vtail(A, n, v) : Vec(A, n)  when v : Vec(A, suc(n))
  [(infer Gamma (vtail e_A e_n e_v))
   (Vec e_A e_n)
   (side-condition (term (check Gamma e_v (Vec e_A (suc e_n)))))]
  [(infer Gamma (vtail e_A e_n e_v)) err]

  ;; vindex(A, n, i, v) : A  when i : Fin(n) and v : Vec(A, n)
  [(infer Gamma (vindex e_A e_n e_i e_v))
   e_A
   (side-condition (term (check Gamma e_i (Fin e_n))))
   (side-condition (term (check Gamma e_v (Vec e_A e_n))))]
  [(infer Gamma (vindex e_A e_n e_i e_v)) err]

  ;; ---- Fallback: cannot infer ----
  [(infer Gamma e) err])

;; ========================================
;; Type checking (checking mode)
;; Returns boolean.
;;
;; Delegates to check-whnf after reducing the expected type to WHNF,
;; so that pattern matching in check-whnf sees canonical type forms.
;; ========================================
(define-metafunction Prologos
  check : Gamma e e -> boolean
  [(check Gamma e e_T) (check-whnf Gamma e (whnf e_T))])

;; ---- check-whnf: the type argument is already in WHNF ----
(define-metafunction Prologos
  check-whnf : Gamma e e -> boolean

  ;; suc against Nat
  [(check-whnf Gamma (suc e_1) Nat) (check Gamma e_1 Nat)]

  ;; Lambda against Pi (same multiplicity enforced by pattern variable reuse)
  [(check-whnf Gamma (lam m e_A e_body) (Pi m e_dom e_cod))
   ,(and (term (conv e_A e_dom))
         (term (check ((e_A m) Gamma) e_body e_cod)))]

  ;; Lambda against Pi with different multiplicity: reject
  [(check-whnf Gamma (lam m_1 e_A e_body) (Pi m_2 e_dom e_cod)) #f]

  ;; Pair against Sigma
  [(check-whnf Gamma (pair e_1 e_2) (Sigma e_A e_B))
   ,(and (term (check Gamma e_1 e_A))
         (term (check Gamma e_2 (subst 0 e_1 e_B))))]

  ;; refl against Eq
  [(check-whnf Gamma refl (Eq e_T e_1 e_2)) (conv e_1 e_2)]

  ;; vnil against Vec: vnil(A1) : Vec(A2, n) iff A1 conv A2 and n conv zero
  [(check-whnf Gamma (vnil e_A1) (Vec e_A2 e_n))
   ,(and (term (is-type Gamma e_A1))
         (term (conv e_A1 e_A2))
         (term (conv e_n zero)))]

  ;; vcons against Vec: vcons(A1, n1, hd, tl) : Vec(A2, len) iff
  ;;   A1 conv A2, len conv suc(n1), hd : A1, tl : Vec(A1, n1)
  [(check-whnf Gamma (vcons e_A1 e_n1 e_hd e_tl) (Vec e_A2 e_len))
   ,(and (term (conv e_A1 e_A2))
         (term (conv e_len (suc e_n1)))
         (term (check Gamma e_hd e_A1))
         (term (check Gamma e_tl (Vec e_A1 e_n1))))]

  ;; fzero against Fin: fzero(n1) : Fin(bound) iff bound conv suc(n1) and n1 : Nat
  [(check-whnf Gamma (fzero e_n1) (Fin e_bound))
   ,(and (term (conv e_bound (suc e_n1)))
         (term (check Gamma e_n1 Nat)))]

  ;; fsuc against Fin: fsuc(n1, i) : Fin(bound) iff bound conv suc(n1) and i : Fin(n1)
  [(check-whnf Gamma (fsuc e_n1 e_i) (Fin e_bound))
   ,(and (term (conv e_bound (suc e_n1)))
         (term (check Gamma e_i (Fin e_n1))))]

  ;; ---- Conversion fallback ----
  ;; If e synthesizes to T' and conv(T, T'), then check succeeds.
  ;; Note: we use e_T (the WHNF-ed type) for comparison via conv,
  ;; but conv normalizes both sides, so it is sound.
  [(check-whnf Gamma e e_T)
   ,(let ([t1 (term (infer Gamma e))])
      (and (not (equal? t1 (term err)))
           (term (conv e_T ,t1))))])

;; ========================================
;; Universe level inference
;; Returns a level (lzero, (lsuc l), ...) or err for "no level".
;; Uses `any` as the contract since the result is either a level or err.
;; ========================================
(define-metafunction Prologos
  infer-level : Gamma e -> any

  ;; Pi formation: Pi(m, A, B) : Type(lmax(level(A), level(B)))
  ;; B is checked in context extended with A at multiplicity m
  [(infer-level Gamma (Pi m e_A e_B))
   ,(let ([la (term (infer-level Gamma e_A))])
      (if (equal? la (term err))
          (term err)
          (let ([lb (term (infer-level ((e_A m) Gamma) e_B))])
            (if (equal? lb (term err))
                (term err)
                (term (lmax ,la ,lb))))))]

  ;; Sigma formation: Sigma(A, B) : Type(lmax(level(A), level(B)))
  ;; B is checked in context extended with A at multiplicity mw (unrestricted)
  [(infer-level Gamma (Sigma e_A e_B))
   ,(let ([la (term (infer-level Gamma e_A))])
      (if (equal? la (term err))
          (term err)
          (let ([lb (term (infer-level ((e_A mw) Gamma) e_B))])
            (if (equal? lb (term err))
                (term err)
                (term (lmax ,la ,lb))))))]

  ;; Eq formation: Eq(A, e1, e2) : Type(level(A)) if e1 : A and e2 : A
  [(infer-level Gamma (Eq e_A e_1 e_2))
   ,(let ([la (term (infer-level Gamma e_A))])
      (if (equal? la (term err))
          (term err)
          (if (and (term (check Gamma e_1 e_A))
                   (term (check Gamma e_2 e_A)))
              la
              (term err))))]

  ;; Vec formation: Vec(A, n) : Type(level(A)) if n : Nat
  [(infer-level Gamma (Vec e_A e_n))
   ,(let ([la (term (infer-level Gamma e_A))])
      (if (equal? la (term err))
          (term err)
          (if (term (check Gamma e_n Nat))
              la
              (term err))))]

  ;; Fin formation: Fin(n) : Type(lzero) if n : Nat
  [(infer-level Gamma (Fin e_n))
   ,(if (term (check Gamma e_n Nat))
        (term lzero)
        (term err))]

  ;; Fallback: infer type, check if it reduces to Type(l)
  [(infer-level Gamma e)
   ,(let ([t (term (whnf (infer Gamma e)))])
      (match t
        [`(Type ,l) l]
        [_ (term err)]))])

;; ========================================
;; Type formation check
;; Returns boolean: is e a well-formed type in context Gamma?
;; ========================================
(define-metafunction Prologos
  is-type : Gamma e -> boolean

  ;; Type(l) is always a type
  [(is-type Gamma (Type l)) #t]

  ;; Otherwise, try to infer its universe level
  [(is-type Gamma e)
   ,(not (equal? (term (infer-level Gamma e)) (term err)))])
