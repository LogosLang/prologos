#lang racket/base

;;;
;;; PROLOGOS ZONKING
;;; Substitute solved metavariables throughout expressions and contexts.
;;;
;;; After elaboration and constraint solving, the zonking pass walks
;;; the entire term tree and replaces every solved metavariable with
;;; its solution. Unsolved metavariables remain as-is (they will be
;;; reported as errors in later sprints).
;;;
;;; zonk(expr) : replace solved metas recursively
;;; zonk-ctx(ctx) : zonk all types in a typing context
;;;

(require racket/match
         "syntax.rkt"
         "metavar-store.rkt")

(provide zonk zonk-ctx)

;; ========================================
;; Zonk: substitute solved metavariables
;; ========================================
(define (zonk e)
  (match e
    ;; THE KEY CASE: metavariable — follow solution recursively
    [(expr-meta id)
     (let ([sol (meta-solution id)])
       (if sol
           (zonk sol)       ; recursive: solution may contain more metas
           e))]             ; unsolved: leave as-is

    ;; Atoms — return unchanged
    [(expr-bvar _) e]
    [(expr-fvar _) e]
    [(expr-zero) e]
    [(expr-refl) e]
    [(expr-Nat) e]
    [(expr-Bool) e]
    [(expr-true) e]
    [(expr-false) e]
    [(expr-Type _) e]
    [(expr-hole) e]
    [(expr-error) e]

    ;; Binding forms
    [(expr-lam m t body)
     (expr-lam m (zonk t) (zonk body))]
    [(expr-Pi m dom cod)
     (expr-Pi m (zonk dom) (zonk cod))]
    [(expr-Sigma t1 t2)
     (expr-Sigma (zonk t1) (zonk t2))]

    ;; Non-binding compound forms
    [(expr-suc e1) (expr-suc (zonk e1))]
    [(expr-app f a) (expr-app (zonk f) (zonk a))]
    [(expr-pair e1 e2) (expr-pair (zonk e1) (zonk e2))]
    [(expr-fst e1) (expr-fst (zonk e1))]
    [(expr-snd e1) (expr-snd (zonk e1))]
    [(expr-ann e1 e2) (expr-ann (zonk e1) (zonk e2))]
    [(expr-Eq t e1 e2) (expr-Eq (zonk t) (zonk e1) (zonk e2))]

    ;; Eliminators
    [(expr-natrec mot base step target)
     (expr-natrec (zonk mot) (zonk base) (zonk step) (zonk target))]
    [(expr-J mot base left right proof)
     (expr-J (zonk mot) (zonk base) (zonk left) (zonk right) (zonk proof))]
    [(expr-boolrec mot tc fc target)
     (expr-boolrec (zonk mot) (zonk tc) (zonk fc) (zonk target))]

    ;; Vec/Fin
    [(expr-Vec t n) (expr-Vec (zonk t) (zonk n))]
    [(expr-vnil t) (expr-vnil (zonk t))]
    [(expr-vcons t n hd tl)
     (expr-vcons (zonk t) (zonk n) (zonk hd) (zonk tl))]
    [(expr-Fin n) (expr-Fin (zonk n))]
    [(expr-fzero n) (expr-fzero (zonk n))]
    [(expr-fsuc n i) (expr-fsuc (zonk n) (zonk i))]
    [(expr-vhead t n v) (expr-vhead (zonk t) (zonk n) (zonk v))]
    [(expr-vtail t n v) (expr-vtail (zonk t) (zonk n) (zonk v))]
    [(expr-vindex t n i v)
     (expr-vindex (zonk t) (zonk n) (zonk i) (zonk v))]

    ;; Posit8
    [(expr-Posit8) e]
    [(expr-posit8 _) e]
    [(expr-p8-add a b) (expr-p8-add (zonk a) (zonk b))]
    [(expr-p8-sub a b) (expr-p8-sub (zonk a) (zonk b))]
    [(expr-p8-mul a b) (expr-p8-mul (zonk a) (zonk b))]
    [(expr-p8-div a b) (expr-p8-div (zonk a) (zonk b))]
    [(expr-p8-neg a) (expr-p8-neg (zonk a))]
    [(expr-p8-abs a) (expr-p8-abs (zonk a))]
    [(expr-p8-sqrt a) (expr-p8-sqrt (zonk a))]
    [(expr-p8-lt a b) (expr-p8-lt (zonk a) (zonk b))]
    [(expr-p8-le a b) (expr-p8-le (zonk a) (zonk b))]
    [(expr-p8-from-nat n) (expr-p8-from-nat (zonk n))]
    [(expr-p8-if-nar t nc vc v)
     (expr-p8-if-nar (zonk t) (zonk nc) (zonk vc) (zonk v))]

    ;; Reduce (pattern matching)
    [(expr-reduce scrut arms structural?)
     (expr-reduce (zonk scrut)
                  (map (lambda (arm)
                         (expr-reduce-arm
                          (expr-reduce-arm-ctor-name arm)
                          (expr-reduce-arm-binding-count arm)
                          (zonk (expr-reduce-arm-body arm))))
                       arms)
                  structural?)]))

;; ========================================
;; Zonk a typing context
;; ========================================
;; Context is a list of (cons type mult). Zonk only the type part.
(define (zonk-ctx ctx)
  (map (lambda (binding)
         (cons (zonk (car binding)) (cdr binding)))
       ctx))
