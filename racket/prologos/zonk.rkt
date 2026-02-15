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
         "metavar-store.rkt"
         "substitution.rkt")

(provide zonk zonk-ctx zonk-final zonk-at-depth)

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
    [(expr-Unit) e]
    [(expr-unit) e]
    [(expr-Type l) (expr-Type (zonk-level l))]
    [(expr-hole) e]
    [(expr-error) e]

    ;; Binding forms (Sprint 7: zonk mult field for mult-metas)
    [(expr-lam m t body)
     (expr-lam (zonk-mult m) (zonk t) (zonk body))]
    [(expr-Pi m dom cod)
     (expr-Pi (zonk-mult m) (zonk dom) (zonk cod))]
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

    ;; Union types
    [(expr-union l r) (expr-union (zonk l) (zonk r))]

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
;; Zonk-at-depth: depth-aware zonk for use under binders.
;; ========================================
;; When a metavariable is solved to an expression containing bvars,
;; those bvar indices are relative to the depth where the meta was solved.
;; If the meta appears under additional binders (e.g., in a Pi codomain),
;; the solution's bvar indices need shifting by the number of extra binders.
;;
;; zonk-at-depth(depth, e):
;;   Like zonk, but shifts meta solutions by `depth` when substituting.
;;   Call with depth=0 for normal behavior (equivalent to plain zonk).
;;   Use depth=1 when zonking a Pi/Sigma/lam codomain/body.
(define (zonk-at-depth depth e)
  (match e
    ;; THE KEY CASE: metavariable — follow solution and shift by accumulated depth
    [(expr-meta id)
     (let ([sol (meta-solution id)])
       (if sol
           (let ([zonked-sol (zonk sol)])  ; zonk at depth 0 (solution is at solve-site depth)
             (if (> depth 0)
                 (shift depth 0 zonked-sol)
                 zonked-sol))
           e))]  ; unsolved: leave as-is

    ;; Atoms — return unchanged
    [(expr-bvar _) e]
    [(expr-fvar _) e]
    [(expr-zero) e]
    [(expr-refl) e]
    [(expr-Nat) e]
    [(expr-Bool) e]
    [(expr-true) e]
    [(expr-false) e]
    [(expr-Unit) e]
    [(expr-unit) e]
    [(expr-Type l) (expr-Type (zonk-level l))]
    [(expr-hole) e]
    [(expr-error) e]

    ;; Binding forms: increment depth for codomains/bodies
    [(expr-lam m t body)
     (expr-lam (zonk-mult m) (zonk-at-depth depth t) (zonk-at-depth (add1 depth) body))]
    [(expr-Pi m dom cod)
     (expr-Pi (zonk-mult m) (zonk-at-depth depth dom) (zonk-at-depth (add1 depth) cod))]
    [(expr-Sigma t1 t2)
     (expr-Sigma (zonk-at-depth depth t1) (zonk-at-depth (add1 depth) t2))]

    ;; Non-binding compound forms
    [(expr-suc e1) (expr-suc (zonk-at-depth depth e1))]
    [(expr-app f a) (expr-app (zonk-at-depth depth f) (zonk-at-depth depth a))]
    [(expr-pair e1 e2) (expr-pair (zonk-at-depth depth e1) (zonk-at-depth depth e2))]
    [(expr-fst e1) (expr-fst (zonk-at-depth depth e1))]
    [(expr-snd e1) (expr-snd (zonk-at-depth depth e1))]
    [(expr-ann e1 e2) (expr-ann (zonk-at-depth depth e1) (zonk-at-depth depth e2))]
    [(expr-Eq t e1 e2) (expr-Eq (zonk-at-depth depth t) (zonk-at-depth depth e1) (zonk-at-depth depth e2))]

    ;; Eliminators
    [(expr-natrec mot base step target)
     (expr-natrec (zonk-at-depth depth mot) (zonk-at-depth depth base)
                  (zonk-at-depth depth step) (zonk-at-depth depth target))]
    [(expr-J mot base left right proof)
     (expr-J (zonk-at-depth depth mot) (zonk-at-depth depth base)
             (zonk-at-depth depth left) (zonk-at-depth depth right) (zonk-at-depth depth proof))]
    [(expr-boolrec mot tc fc target)
     (expr-boolrec (zonk-at-depth depth mot) (zonk-at-depth depth tc)
                   (zonk-at-depth depth fc) (zonk-at-depth depth target))]

    ;; Vec/Fin
    [(expr-Vec t n) (expr-Vec (zonk-at-depth depth t) (zonk-at-depth depth n))]
    [(expr-vnil t) (expr-vnil (zonk-at-depth depth t))]
    [(expr-vcons t n hd tl)
     (expr-vcons (zonk-at-depth depth t) (zonk-at-depth depth n)
                 (zonk-at-depth depth hd) (zonk-at-depth depth tl))]
    [(expr-Fin n) (expr-Fin (zonk-at-depth depth n))]
    [(expr-fzero n) (expr-fzero (zonk-at-depth depth n))]
    [(expr-fsuc n i) (expr-fsuc (zonk-at-depth depth n) (zonk-at-depth depth i))]
    [(expr-vhead t n v) (expr-vhead (zonk-at-depth depth t) (zonk-at-depth depth n) (zonk-at-depth depth v))]
    [(expr-vtail t n v) (expr-vtail (zonk-at-depth depth t) (zonk-at-depth depth n) (zonk-at-depth depth v))]
    [(expr-vindex t n i v)
     (expr-vindex (zonk-at-depth depth t) (zonk-at-depth depth n)
                  (zonk-at-depth depth i) (zonk-at-depth depth v))]

    ;; Posit8
    [(expr-Posit8) e]
    [(expr-posit8 _) e]
    [(expr-p8-add a b) (expr-p8-add (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p8-sub a b) (expr-p8-sub (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p8-mul a b) (expr-p8-mul (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p8-div a b) (expr-p8-div (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p8-neg a) (expr-p8-neg (zonk-at-depth depth a))]
    [(expr-p8-abs a) (expr-p8-abs (zonk-at-depth depth a))]
    [(expr-p8-sqrt a) (expr-p8-sqrt (zonk-at-depth depth a))]
    [(expr-p8-lt a b) (expr-p8-lt (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p8-le a b) (expr-p8-le (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p8-from-nat n) (expr-p8-from-nat (zonk-at-depth depth n))]
    [(expr-p8-if-nar t nc vc v)
     (expr-p8-if-nar (zonk-at-depth depth t) (zonk-at-depth depth nc)
                     (zonk-at-depth depth vc) (zonk-at-depth depth v))]

    ;; Union types
    [(expr-union l r) (expr-union (zonk-at-depth depth l) (zonk-at-depth depth r))]

    ;; Reduce (pattern matching)
    [(expr-reduce scrut arms structural?)
     (expr-reduce (zonk-at-depth depth scrut)
                  (map (lambda (arm)
                         (expr-reduce-arm
                          (expr-reduce-arm-ctor-name arm)
                          (expr-reduce-arm-binding-count arm)
                          (zonk-at-depth (+ depth (expr-reduce-arm-binding-count arm))
                                         (expr-reduce-arm-body arm))))
                       arms)
                  structural?)]))

;; ========================================
;; Zonk-final: zonk + default unsolved metas to ground values
;; ========================================
;; Used as the final pass before storing in global env or displaying output.
;; Regular `zonk` preserves unsolved level/mult-metas (needed during unification).
;; Sprint 6: defaults unsolved level-metas to lzero.
;; Sprint 7: defaults unsolved mult-metas to 'mw.
(define (zonk-final e)
  (define z (zonk e))
  (default-metas z))

;; Walk an expression replacing all unsolved level-metas with lzero
;; and all unsolved mult-metas with 'mw.
(define (default-metas e)
  (match e
    [(expr-Type l) (expr-Type (zonk-level-default l))]
    [(expr-meta _) e]
    [(expr-bvar _) e]
    [(expr-fvar _) e]
    [(expr-zero) e]
    [(expr-refl) e]
    [(expr-Nat) e]
    [(expr-Bool) e]
    [(expr-true) e]
    [(expr-false) e]
    [(expr-Unit) e]
    [(expr-unit) e]
    [(expr-hole) e]
    [(expr-error) e]
    [(expr-lam m t body) (expr-lam (zonk-mult-default m) (default-metas t) (default-metas body))]
    [(expr-Pi m dom cod) (expr-Pi (zonk-mult-default m) (default-metas dom) (default-metas cod))]
    [(expr-Sigma t1 t2) (expr-Sigma (default-metas t1) (default-metas t2))]
    [(expr-suc e1) (expr-suc (default-metas e1))]
    [(expr-app f a) (expr-app (default-metas f) (default-metas a))]
    [(expr-pair e1 e2) (expr-pair (default-metas e1) (default-metas e2))]
    [(expr-fst e1) (expr-fst (default-metas e1))]
    [(expr-snd e1) (expr-snd (default-metas e1))]
    [(expr-ann e1 e2) (expr-ann (default-metas e1) (default-metas e2))]
    [(expr-Eq t e1 e2) (expr-Eq (default-metas t) (default-metas e1) (default-metas e2))]
    [(expr-natrec mot base step target)
     (expr-natrec (default-metas mot) (default-metas base)
                  (default-metas step) (default-metas target))]
    [(expr-J mot base left right proof)
     (expr-J (default-metas mot) (default-metas base)
             (default-metas left) (default-metas right) (default-metas proof))]
    [(expr-boolrec mot tc fc target)
     (expr-boolrec (default-metas mot) (default-metas tc)
                   (default-metas fc) (default-metas target))]
    [(expr-Vec t n) (expr-Vec (default-metas t) (default-metas n))]
    [(expr-vnil t) (expr-vnil (default-metas t))]
    [(expr-vcons t n hd tl)
     (expr-vcons (default-metas t) (default-metas n)
                 (default-metas hd) (default-metas tl))]
    [(expr-Fin n) (expr-Fin (default-metas n))]
    [(expr-fzero n) (expr-fzero (default-metas n))]
    [(expr-fsuc n i) (expr-fsuc (default-metas n) (default-metas i))]
    [(expr-vhead t n v) (expr-vhead (default-metas t) (default-metas n) (default-metas v))]
    [(expr-vtail t n v) (expr-vtail (default-metas t) (default-metas n) (default-metas v))]
    [(expr-vindex t n i v)
     (expr-vindex (default-metas t) (default-metas n)
                  (default-metas i) (default-metas v))]
    [(expr-Posit8) e]
    [(expr-posit8 _) e]
    [(expr-p8-add a b) (expr-p8-add (default-metas a) (default-metas b))]
    [(expr-p8-sub a b) (expr-p8-sub (default-metas a) (default-metas b))]
    [(expr-p8-mul a b) (expr-p8-mul (default-metas a) (default-metas b))]
    [(expr-p8-div a b) (expr-p8-div (default-metas a) (default-metas b))]
    [(expr-p8-neg a) (expr-p8-neg (default-metas a))]
    [(expr-p8-abs a) (expr-p8-abs (default-metas a))]
    [(expr-p8-sqrt a) (expr-p8-sqrt (default-metas a))]
    [(expr-p8-lt a b) (expr-p8-lt (default-metas a) (default-metas b))]
    [(expr-p8-le a b) (expr-p8-le (default-metas a) (default-metas b))]
    [(expr-p8-from-nat n) (expr-p8-from-nat (default-metas n))]
    [(expr-p8-if-nar t nc vc v)
     (expr-p8-if-nar (default-metas t) (default-metas nc)
                     (default-metas vc) (default-metas v))]
    [(expr-union l r) (expr-union (default-metas l) (default-metas r))]
    [(expr-reduce scrut arms structural?)
     (expr-reduce (default-metas scrut)
                  (map (lambda (arm)
                         (expr-reduce-arm
                          (expr-reduce-arm-ctor-name arm)
                          (expr-reduce-arm-binding-count arm)
                          (default-metas (expr-reduce-arm-body arm))))
                       arms)
                  structural?)]
    [_ e]))

;; ========================================
;; Zonk a typing context
;; ========================================
;; Context is a list of (cons type mult). Zonk only the type part.
(define (zonk-ctx ctx)
  (map (lambda (binding)
         (cons (zonk (car binding)) (cdr binding)))
       ctx))
