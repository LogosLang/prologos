#lang racket/base

;;;
;;; PROLOGOS SUBSTITUTION
;;; Locally-nameless substitution operations for Prologos.
;;; Direct translation of prologos-substitution.maude + prologos-inductive.maude extensions.
;;;
;;; shift(delta, cutoff, expr) : increase all bound indices >= cutoff by delta in expr
;;; subst(k, s, expr)         : replace bvar(k) with s in expr (shifting s under binders)
;;; open-expr(body, arg)      : replace bvar(0) with arg and decrement other indices
;;;                             (used when entering a binder)
;;;

(require racket/match
         "prelude.rkt"
         "syntax.rkt")

(provide shift subst open-expr)

;; ========================================
;; Shift: increase bound indices >= cutoff by delta
;; ========================================
(define (shift delta cutoff e)
  (match e
    ;; Variables
    [(expr-bvar k)
     (if (>= k cutoff)
         (expr-bvar (+ k delta))
         (expr-bvar k))]
    [(expr-fvar _) e]

    ;; Constants (no bound variables inside)
    [(expr-zero) e]
    [(expr-suc e1) (expr-suc (shift delta cutoff e1))]
    [(expr-refl) e]
    [(expr-Nat) e]
    [(expr-Bool) e]
    [(expr-true) e]
    [(expr-false) e]
    [(expr-Unit) e]
    [(expr-unit) e]
    [(expr-Type _) e]
    [(expr-hole) e]
    [(expr-meta _) e]
    [(expr-error) e]

    ;; Binding forms: cutoff increases under binders
    [(expr-lam m t body)
     (expr-lam m (shift delta cutoff t) (shift delta (add1 cutoff) body))]
    [(expr-Pi m dom cod)
     (expr-Pi m (shift delta cutoff dom) (shift delta (add1 cutoff) cod))]
    [(expr-Sigma t1 t2)
     (expr-Sigma (shift delta cutoff t1) (shift delta (add1 cutoff) t2))]

    ;; Non-binding forms
    [(expr-app e1 e2)
     (expr-app (shift delta cutoff e1) (shift delta cutoff e2))]
    [(expr-pair e1 e2)
     (expr-pair (shift delta cutoff e1) (shift delta cutoff e2))]
    [(expr-fst e1) (expr-fst (shift delta cutoff e1))]
    [(expr-snd e1) (expr-snd (shift delta cutoff e1))]
    [(expr-ann e1 e2)
     (expr-ann (shift delta cutoff e1) (shift delta cutoff e2))]
    [(expr-Eq t e1 e2)
     (expr-Eq (shift delta cutoff t) (shift delta cutoff e1) (shift delta cutoff e2))]

    ;; Eliminators (all arguments are non-binding — motives are lambda terms)
    [(expr-natrec mot base step target)
     (expr-natrec (shift delta cutoff mot)
                  (shift delta cutoff base)
                  (shift delta cutoff step)
                  (shift delta cutoff target))]
    [(expr-J mot base left right proof)
     (expr-J (shift delta cutoff mot)
             (shift delta cutoff base)
             (shift delta cutoff left)
             (shift delta cutoff right)
             (shift delta cutoff proof))]
    [(expr-boolrec mot tc fc target)
     (expr-boolrec (shift delta cutoff mot)
                   (shift delta cutoff tc)
                   (shift delta cutoff fc)
                   (shift delta cutoff target))]

    ;; Vec/Fin (all non-binding)
    [(expr-Vec t n)
     (expr-Vec (shift delta cutoff t) (shift delta cutoff n))]
    [(expr-vnil t) (expr-vnil (shift delta cutoff t))]
    [(expr-vcons t n hd tl)
     (expr-vcons (shift delta cutoff t) (shift delta cutoff n)
                 (shift delta cutoff hd) (shift delta cutoff tl))]
    [(expr-Fin n) (expr-Fin (shift delta cutoff n))]
    [(expr-fzero n) (expr-fzero (shift delta cutoff n))]
    [(expr-fsuc n i) (expr-fsuc (shift delta cutoff n) (shift delta cutoff i))]
    [(expr-vhead t n v)
     (expr-vhead (shift delta cutoff t) (shift delta cutoff n) (shift delta cutoff v))]
    [(expr-vtail t n v)
     (expr-vtail (shift delta cutoff t) (shift delta cutoff n) (shift delta cutoff v))]
    [(expr-vindex t n i v)
     (expr-vindex (shift delta cutoff t) (shift delta cutoff n)
                  (shift delta cutoff i) (shift delta cutoff v))]

    ;; Posit8 (all non-binding)
    [(expr-Posit8) e]
    [(expr-posit8 _) e]
    [(expr-p8-add a b) (expr-p8-add (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p8-sub a b) (expr-p8-sub (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p8-mul a b) (expr-p8-mul (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p8-div a b) (expr-p8-div (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p8-neg a) (expr-p8-neg (shift delta cutoff a))]
    [(expr-p8-abs a) (expr-p8-abs (shift delta cutoff a))]
    [(expr-p8-sqrt a) (expr-p8-sqrt (shift delta cutoff a))]
    [(expr-p8-lt a b) (expr-p8-lt (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p8-le a b) (expr-p8-le (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p8-from-nat n) (expr-p8-from-nat (shift delta cutoff n))]
    [(expr-p8-if-nar t nc vc v)
     (expr-p8-if-nar (shift delta cutoff t) (shift delta cutoff nc)
                     (shift delta cutoff vc) (shift delta cutoff v))]

    ;; Int (all non-binding)
    [(expr-Int) e]
    [(expr-int _) e]
    [(expr-int-add a b) (expr-int-add (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-int-sub a b) (expr-int-sub (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-int-mul a b) (expr-int-mul (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-int-div a b) (expr-int-div (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-int-mod a b) (expr-int-mod (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-int-neg a) (expr-int-neg (shift delta cutoff a))]
    [(expr-int-abs a) (expr-int-abs (shift delta cutoff a))]
    [(expr-int-lt a b) (expr-int-lt (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-int-le a b) (expr-int-le (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-int-eq a b) (expr-int-eq (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-from-nat n) (expr-from-nat (shift delta cutoff n))]

    ;; Union types (non-binding)
    [(expr-union l r)
     (expr-union (shift delta cutoff l) (shift delta cutoff r))]

    ;; Foreign function (opaque leaf — no Prologos sub-expressions)
    [(expr-foreign-fn _ _ _ _ _ _) e]

    ;; Reduce: scrutinee is non-binding, arm bodies have binding-count binders
    [(expr-reduce scrut arms structural?)
     (expr-reduce (shift delta cutoff scrut)
                  (map (lambda (arm)
                         (expr-reduce-arm
                          (expr-reduce-arm-ctor-name arm)
                          (expr-reduce-arm-binding-count arm)
                          (shift delta (+ cutoff (expr-reduce-arm-binding-count arm))
                                (expr-reduce-arm-body arm))))
                       arms)
                  structural?)]))

;; ========================================
;; Substitution: replace bvar(k) with s in e
;; When going under a binder, k increases and s is shifted up
;; ========================================
(define (subst k s e)
  (match e
    ;; Variables
    [(expr-bvar n)
     (cond
       [(= n k) s]           ; target variable: replace with s
       [(> n k) (expr-bvar (- n 1))]  ; above target: decrement (binder removed)
       [else (expr-bvar n)])]         ; below target: unchanged
    [(expr-fvar _) e]

    ;; Constants
    [(expr-zero) e]
    [(expr-suc e1) (expr-suc (subst k s e1))]
    [(expr-refl) e]
    [(expr-Nat) e]
    [(expr-Bool) e]
    [(expr-true) e]
    [(expr-false) e]
    [(expr-Unit) e]
    [(expr-unit) e]
    [(expr-Type _) e]
    [(expr-hole) e]
    [(expr-meta _) e]
    [(expr-error) e]

    ;; Binding forms: increase k, shift s up by 1
    [(expr-lam m t body)
     (expr-lam m (subst k s t) (subst (add1 k) (shift 1 0 s) body))]
    [(expr-Pi m dom cod)
     (expr-Pi m (subst k s dom) (subst (add1 k) (shift 1 0 s) cod))]
    [(expr-Sigma t1 t2)
     (expr-Sigma (subst k s t1) (subst (add1 k) (shift 1 0 s) t2))]

    ;; Non-binding forms
    [(expr-app e1 e2)
     (expr-app (subst k s e1) (subst k s e2))]
    [(expr-pair e1 e2)
     (expr-pair (subst k s e1) (subst k s e2))]
    [(expr-fst e1) (expr-fst (subst k s e1))]
    [(expr-snd e1) (expr-snd (subst k s e1))]
    [(expr-ann e1 e2)
     (expr-ann (subst k s e1) (subst k s e2))]
    [(expr-Eq t e1 e2)
     (expr-Eq (subst k s t) (subst k s e1) (subst k s e2))]

    ;; Eliminators (non-binding)
    [(expr-natrec mot base step target)
     (expr-natrec (subst k s mot)
                  (subst k s base)
                  (subst k s step)
                  (subst k s target))]
    [(expr-J mot base left right proof)
     (expr-J (subst k s mot)
             (subst k s base)
             (subst k s left)
             (subst k s right)
             (subst k s proof))]
    [(expr-boolrec mot tc fc target)
     (expr-boolrec (subst k s mot)
                   (subst k s tc)
                   (subst k s fc)
                   (subst k s target))]

    ;; Vec/Fin (all non-binding)
    [(expr-Vec t n)
     (expr-Vec (subst k s t) (subst k s n))]
    [(expr-vnil t) (expr-vnil (subst k s t))]
    [(expr-vcons t n hd tl)
     (expr-vcons (subst k s t) (subst k s n)
                 (subst k s hd) (subst k s tl))]
    [(expr-Fin n) (expr-Fin (subst k s n))]
    [(expr-fzero n) (expr-fzero (subst k s n))]
    [(expr-fsuc n i) (expr-fsuc (subst k s n) (subst k s i))]
    [(expr-vhead t n v)
     (expr-vhead (subst k s t) (subst k s n) (subst k s v))]
    [(expr-vtail t n v)
     (expr-vtail (subst k s t) (subst k s n) (subst k s v))]
    [(expr-vindex t n i v)
     (expr-vindex (subst k s t) (subst k s n)
                  (subst k s i) (subst k s v))]

    ;; Posit8 (all non-binding)
    [(expr-Posit8) e]
    [(expr-posit8 _) e]
    [(expr-p8-add a b) (expr-p8-add (subst k s a) (subst k s b))]
    [(expr-p8-sub a b) (expr-p8-sub (subst k s a) (subst k s b))]
    [(expr-p8-mul a b) (expr-p8-mul (subst k s a) (subst k s b))]
    [(expr-p8-div a b) (expr-p8-div (subst k s a) (subst k s b))]
    [(expr-p8-neg a) (expr-p8-neg (subst k s a))]
    [(expr-p8-abs a) (expr-p8-abs (subst k s a))]
    [(expr-p8-sqrt a) (expr-p8-sqrt (subst k s a))]
    [(expr-p8-lt a b) (expr-p8-lt (subst k s a) (subst k s b))]
    [(expr-p8-le a b) (expr-p8-le (subst k s a) (subst k s b))]
    [(expr-p8-from-nat n) (expr-p8-from-nat (subst k s n))]
    [(expr-p8-if-nar t nc vc v)
     (expr-p8-if-nar (subst k s t) (subst k s nc)
                     (subst k s vc) (subst k s v))]

    ;; Int (all non-binding)
    [(expr-Int) e]
    [(expr-int _) e]
    [(expr-int-add a b) (expr-int-add (subst k s a) (subst k s b))]
    [(expr-int-sub a b) (expr-int-sub (subst k s a) (subst k s b))]
    [(expr-int-mul a b) (expr-int-mul (subst k s a) (subst k s b))]
    [(expr-int-div a b) (expr-int-div (subst k s a) (subst k s b))]
    [(expr-int-mod a b) (expr-int-mod (subst k s a) (subst k s b))]
    [(expr-int-neg a) (expr-int-neg (subst k s a))]
    [(expr-int-abs a) (expr-int-abs (subst k s a))]
    [(expr-int-lt a b) (expr-int-lt (subst k s a) (subst k s b))]
    [(expr-int-le a b) (expr-int-le (subst k s a) (subst k s b))]
    [(expr-int-eq a b) (expr-int-eq (subst k s a) (subst k s b))]
    [(expr-from-nat n) (expr-from-nat (subst k s n))]

    ;; Union types (non-binding)
    [(expr-union l r)
     (expr-union (subst k s l) (subst k s r))]

    ;; Foreign function (opaque leaf — no Prologos sub-expressions)
    [(expr-foreign-fn _ _ _ _ _ _) e]

    ;; Reduce: arm bodies have binding-count binders
    [(expr-reduce scrut arms structural?)
     (expr-reduce (subst k s scrut)
                  (map (lambda (arm)
                         (define bc (expr-reduce-arm-binding-count arm))
                         (expr-reduce-arm
                          (expr-reduce-arm-ctor-name arm)
                          bc
                          (subst (+ k bc) (shift bc 0 s)
                                 (expr-reduce-arm-body arm))))
                       arms)
                  structural?)]))

;; ========================================
;; Open: substitute s for bvar(0)
;; open(e, s) = subst(0, s, e)
;; ========================================
(define (open-expr body arg)
  (subst 0 arg body))
