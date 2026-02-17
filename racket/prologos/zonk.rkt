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

    ;; Posit16 (all non-binding)
    [(expr-Posit16) e]
    [(expr-posit16 _) e]
    [(expr-p16-add a b) (expr-p16-add (zonk a) (zonk b))]
    [(expr-p16-sub a b) (expr-p16-sub (zonk a) (zonk b))]
    [(expr-p16-mul a b) (expr-p16-mul (zonk a) (zonk b))]
    [(expr-p16-div a b) (expr-p16-div (zonk a) (zonk b))]
    [(expr-p16-neg a) (expr-p16-neg (zonk a))]
    [(expr-p16-abs a) (expr-p16-abs (zonk a))]
    [(expr-p16-sqrt a) (expr-p16-sqrt (zonk a))]
    [(expr-p16-lt a b) (expr-p16-lt (zonk a) (zonk b))]
    [(expr-p16-le a b) (expr-p16-le (zonk a) (zonk b))]
    [(expr-p16-from-nat n) (expr-p16-from-nat (zonk n))]
    [(expr-p16-if-nar t nc vc v)
     (expr-p16-if-nar (zonk t) (zonk nc) (zonk vc) (zonk v))]

    ;; Posit32 (all non-binding)
    [(expr-Posit32) e]
    [(expr-posit32 _) e]
    [(expr-p32-add a b) (expr-p32-add (zonk a) (zonk b))]
    [(expr-p32-sub a b) (expr-p32-sub (zonk a) (zonk b))]
    [(expr-p32-mul a b) (expr-p32-mul (zonk a) (zonk b))]
    [(expr-p32-div a b) (expr-p32-div (zonk a) (zonk b))]
    [(expr-p32-neg a) (expr-p32-neg (zonk a))]
    [(expr-p32-abs a) (expr-p32-abs (zonk a))]
    [(expr-p32-sqrt a) (expr-p32-sqrt (zonk a))]
    [(expr-p32-lt a b) (expr-p32-lt (zonk a) (zonk b))]
    [(expr-p32-le a b) (expr-p32-le (zonk a) (zonk b))]
    [(expr-p32-from-nat n) (expr-p32-from-nat (zonk n))]
    [(expr-p32-if-nar t nc vc v)
     (expr-p32-if-nar (zonk t) (zonk nc) (zonk vc) (zonk v))]

    ;; Posit64 (all non-binding)
    [(expr-Posit64) e]
    [(expr-posit64 _) e]
    [(expr-p64-add a b) (expr-p64-add (zonk a) (zonk b))]
    [(expr-p64-sub a b) (expr-p64-sub (zonk a) (zonk b))]
    [(expr-p64-mul a b) (expr-p64-mul (zonk a) (zonk b))]
    [(expr-p64-div a b) (expr-p64-div (zonk a) (zonk b))]
    [(expr-p64-neg a) (expr-p64-neg (zonk a))]
    [(expr-p64-abs a) (expr-p64-abs (zonk a))]
    [(expr-p64-sqrt a) (expr-p64-sqrt (zonk a))]
    [(expr-p64-lt a b) (expr-p64-lt (zonk a) (zonk b))]
    [(expr-p64-le a b) (expr-p64-le (zonk a) (zonk b))]
    [(expr-p64-from-nat n) (expr-p64-from-nat (zonk n))]
    [(expr-p64-if-nar t nc vc v)
     (expr-p64-if-nar (zonk t) (zonk nc) (zonk vc) (zonk v))]

    ;; Quire8 (exact accumulator for Posit8)
    [(expr-Quire8) e]
    [(expr-quire8-val _) e]
    [(expr-quire8-fma q a b) (expr-quire8-fma (zonk q) (zonk a) (zonk b))]
    [(expr-quire8-to q) (expr-quire8-to (zonk q))]

    ;; Quire16 (exact accumulator for Posit16)
    [(expr-Quire16) e]
    [(expr-quire16-val _) e]
    [(expr-quire16-fma q a b) (expr-quire16-fma (zonk q) (zonk a) (zonk b))]
    [(expr-quire16-to q) (expr-quire16-to (zonk q))]

    ;; Quire32 (exact accumulator for Posit32)
    [(expr-Quire32) e]
    [(expr-quire32-val _) e]
    [(expr-quire32-fma q a b) (expr-quire32-fma (zonk q) (zonk a) (zonk b))]
    [(expr-quire32-to q) (expr-quire32-to (zonk q))]

    ;; Quire64 (exact accumulator for Posit64)
    [(expr-Quire64) e]
    [(expr-quire64-val _) e]
    [(expr-quire64-fma q a b) (expr-quire64-fma (zonk q) (zonk a) (zonk b))]
    [(expr-quire64-to q) (expr-quire64-to (zonk q))]

    ;; Keyword
    [(expr-Keyword) e]
    [(expr-keyword _) e]
    ;; Map
    [(expr-Map k v) (expr-Map (zonk k) (zonk v))]
    [(expr-champ _) e]
    [(expr-map-empty k v) (expr-map-empty (zonk k) (zonk v))]
    [(expr-map-assoc m k v) (expr-map-assoc (zonk m) (zonk k) (zonk v))]
    [(expr-map-get m k) (expr-map-get (zonk m) (zonk k))]
    [(expr-map-dissoc m k) (expr-map-dissoc (zonk m) (zonk k))]
    [(expr-map-size m) (expr-map-size (zonk m))]
    [(expr-map-has-key m k) (expr-map-has-key (zonk m) (zonk k))]
    [(expr-map-keys m) (expr-map-keys (zonk m))]
    [(expr-map-vals m) (expr-map-vals (zonk m))]

    ;; PVec (all non-binding)
    [(expr-PVec a) (expr-PVec (zonk a))]
    [(expr-rrb _) e]
    [(expr-pvec-empty a) (expr-pvec-empty (zonk a))]
    [(expr-pvec-push v x) (expr-pvec-push (zonk v) (zonk x))]
    [(expr-pvec-nth v i) (expr-pvec-nth (zonk v) (zonk i))]
    [(expr-pvec-update v i x) (expr-pvec-update (zonk v) (zonk i) (zonk x))]
    [(expr-pvec-length v) (expr-pvec-length (zonk v))]
    [(expr-pvec-pop v) (expr-pvec-pop (zonk v))]
    [(expr-pvec-concat v1 v2) (expr-pvec-concat (zonk v1) (zonk v2))]
    [(expr-pvec-slice v lo hi) (expr-pvec-slice (zonk v) (zonk lo) (zonk hi))]

    ;; Int
    [(expr-Int) e]
    [(expr-int _) e]
    [(expr-int-add a b) (expr-int-add (zonk a) (zonk b))]
    [(expr-int-sub a b) (expr-int-sub (zonk a) (zonk b))]
    [(expr-int-mul a b) (expr-int-mul (zonk a) (zonk b))]
    [(expr-int-div a b) (expr-int-div (zonk a) (zonk b))]
    [(expr-int-mod a b) (expr-int-mod (zonk a) (zonk b))]
    [(expr-int-neg a) (expr-int-neg (zonk a))]
    [(expr-int-abs a) (expr-int-abs (zonk a))]
    [(expr-int-lt a b) (expr-int-lt (zonk a) (zonk b))]
    [(expr-int-le a b) (expr-int-le (zonk a) (zonk b))]
    [(expr-int-eq a b) (expr-int-eq (zonk a) (zonk b))]
    [(expr-from-nat n) (expr-from-nat (zonk n))]

    ;; Rat
    [(expr-Rat) e]
    [(expr-rat _) e]
    [(expr-rat-add a b) (expr-rat-add (zonk a) (zonk b))]
    [(expr-rat-sub a b) (expr-rat-sub (zonk a) (zonk b))]
    [(expr-rat-mul a b) (expr-rat-mul (zonk a) (zonk b))]
    [(expr-rat-div a b) (expr-rat-div (zonk a) (zonk b))]
    [(expr-rat-neg a) (expr-rat-neg (zonk a))]
    [(expr-rat-abs a) (expr-rat-abs (zonk a))]
    [(expr-rat-lt a b) (expr-rat-lt (zonk a) (zonk b))]
    [(expr-rat-le a b) (expr-rat-le (zonk a) (zonk b))]
    [(expr-rat-eq a b) (expr-rat-eq (zonk a) (zonk b))]
    [(expr-from-int n) (expr-from-int (zonk n))]
    [(expr-rat-numer a) (expr-rat-numer (zonk a))]
    [(expr-rat-denom a) (expr-rat-denom (zonk a))]

    ;; Union types
    [(expr-union l r) (expr-union (zonk l) (zonk r))]

    ;; Foreign function (opaque leaf)
    [(expr-foreign-fn _ _ _ _ _ _) e]

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

    ;; Posit16 (all non-binding)
    [(expr-Posit16) e]
    [(expr-posit16 _) e]
    [(expr-p16-add a b) (expr-p16-add (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p16-sub a b) (expr-p16-sub (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p16-mul a b) (expr-p16-mul (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p16-div a b) (expr-p16-div (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p16-neg a) (expr-p16-neg (zonk-at-depth depth a))]
    [(expr-p16-abs a) (expr-p16-abs (zonk-at-depth depth a))]
    [(expr-p16-sqrt a) (expr-p16-sqrt (zonk-at-depth depth a))]
    [(expr-p16-lt a b) (expr-p16-lt (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p16-le a b) (expr-p16-le (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p16-from-nat n) (expr-p16-from-nat (zonk-at-depth depth n))]
    [(expr-p16-if-nar t nc vc v)
     (expr-p16-if-nar (zonk-at-depth depth t) (zonk-at-depth depth nc)
                      (zonk-at-depth depth vc) (zonk-at-depth depth v))]

    ;; Posit32 (all non-binding)
    [(expr-Posit32) e]
    [(expr-posit32 _) e]
    [(expr-p32-add a b) (expr-p32-add (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p32-sub a b) (expr-p32-sub (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p32-mul a b) (expr-p32-mul (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p32-div a b) (expr-p32-div (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p32-neg a) (expr-p32-neg (zonk-at-depth depth a))]
    [(expr-p32-abs a) (expr-p32-abs (zonk-at-depth depth a))]
    [(expr-p32-sqrt a) (expr-p32-sqrt (zonk-at-depth depth a))]
    [(expr-p32-lt a b) (expr-p32-lt (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p32-le a b) (expr-p32-le (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p32-from-nat n) (expr-p32-from-nat (zonk-at-depth depth n))]
    [(expr-p32-if-nar t nc vc v)
     (expr-p32-if-nar (zonk-at-depth depth t) (zonk-at-depth depth nc)
                      (zonk-at-depth depth vc) (zonk-at-depth depth v))]

    ;; Posit64 (all non-binding)
    [(expr-Posit64) e]
    [(expr-posit64 _) e]
    [(expr-p64-add a b) (expr-p64-add (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p64-sub a b) (expr-p64-sub (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p64-mul a b) (expr-p64-mul (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p64-div a b) (expr-p64-div (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p64-neg a) (expr-p64-neg (zonk-at-depth depth a))]
    [(expr-p64-abs a) (expr-p64-abs (zonk-at-depth depth a))]
    [(expr-p64-sqrt a) (expr-p64-sqrt (zonk-at-depth depth a))]
    [(expr-p64-lt a b) (expr-p64-lt (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p64-le a b) (expr-p64-le (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-p64-from-nat n) (expr-p64-from-nat (zonk-at-depth depth n))]
    [(expr-p64-if-nar t nc vc v)
     (expr-p64-if-nar (zonk-at-depth depth t) (zonk-at-depth depth nc)
                      (zonk-at-depth depth vc) (zonk-at-depth depth v))]

    ;; Quire8
    [(expr-Quire8) e]
    [(expr-quire8-val _) e]
    [(expr-quire8-fma q a b) (expr-quire8-fma (zonk-at-depth depth q) (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-quire8-to q) (expr-quire8-to (zonk-at-depth depth q))]

    ;; Quire16
    [(expr-Quire16) e]
    [(expr-quire16-val _) e]
    [(expr-quire16-fma q a b) (expr-quire16-fma (zonk-at-depth depth q) (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-quire16-to q) (expr-quire16-to (zonk-at-depth depth q))]

    ;; Quire32
    [(expr-Quire32) e]
    [(expr-quire32-val _) e]
    [(expr-quire32-fma q a b) (expr-quire32-fma (zonk-at-depth depth q) (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-quire32-to q) (expr-quire32-to (zonk-at-depth depth q))]

    ;; Quire64
    [(expr-Quire64) e]
    [(expr-quire64-val _) e]
    [(expr-quire64-fma q a b) (expr-quire64-fma (zonk-at-depth depth q) (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-quire64-to q) (expr-quire64-to (zonk-at-depth depth q))]

    ;; Keyword
    [(expr-Keyword) e]
    [(expr-keyword _) e]
    ;; Map
    [(expr-Map k v) (expr-Map (zonk-at-depth depth k) (zonk-at-depth depth v))]
    [(expr-champ _) e]
    [(expr-map-empty k v) (expr-map-empty (zonk-at-depth depth k) (zonk-at-depth depth v))]
    [(expr-map-assoc m k v) (expr-map-assoc (zonk-at-depth depth m) (zonk-at-depth depth k) (zonk-at-depth depth v))]
    [(expr-map-get m k) (expr-map-get (zonk-at-depth depth m) (zonk-at-depth depth k))]
    [(expr-map-dissoc m k) (expr-map-dissoc (zonk-at-depth depth m) (zonk-at-depth depth k))]
    [(expr-map-size m) (expr-map-size (zonk-at-depth depth m))]
    [(expr-map-has-key m k) (expr-map-has-key (zonk-at-depth depth m) (zonk-at-depth depth k))]
    [(expr-map-keys m) (expr-map-keys (zonk-at-depth depth m))]
    [(expr-map-vals m) (expr-map-vals (zonk-at-depth depth m))]

    ;; PVec (all non-binding)
    [(expr-PVec a) (expr-PVec (zonk-at-depth depth a))]
    [(expr-rrb _) e]
    [(expr-pvec-empty a) (expr-pvec-empty (zonk-at-depth depth a))]
    [(expr-pvec-push v x) (expr-pvec-push (zonk-at-depth depth v) (zonk-at-depth depth x))]
    [(expr-pvec-nth v i) (expr-pvec-nth (zonk-at-depth depth v) (zonk-at-depth depth i))]
    [(expr-pvec-update v i x) (expr-pvec-update (zonk-at-depth depth v) (zonk-at-depth depth i) (zonk-at-depth depth x))]
    [(expr-pvec-length v) (expr-pvec-length (zonk-at-depth depth v))]
    [(expr-pvec-pop v) (expr-pvec-pop (zonk-at-depth depth v))]
    [(expr-pvec-concat v1 v2) (expr-pvec-concat (zonk-at-depth depth v1) (zonk-at-depth depth v2))]
    [(expr-pvec-slice v lo hi) (expr-pvec-slice (zonk-at-depth depth v) (zonk-at-depth depth lo) (zonk-at-depth depth hi))]

    ;; Int
    [(expr-Int) e]
    [(expr-int _) e]
    [(expr-int-add a b) (expr-int-add (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-int-sub a b) (expr-int-sub (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-int-mul a b) (expr-int-mul (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-int-div a b) (expr-int-div (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-int-mod a b) (expr-int-mod (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-int-neg a) (expr-int-neg (zonk-at-depth depth a))]
    [(expr-int-abs a) (expr-int-abs (zonk-at-depth depth a))]
    [(expr-int-lt a b) (expr-int-lt (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-int-le a b) (expr-int-le (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-int-eq a b) (expr-int-eq (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-from-nat n) (expr-from-nat (zonk-at-depth depth n))]

    ;; Rat
    [(expr-Rat) e]
    [(expr-rat _) e]
    [(expr-rat-add a b) (expr-rat-add (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-rat-sub a b) (expr-rat-sub (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-rat-mul a b) (expr-rat-mul (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-rat-div a b) (expr-rat-div (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-rat-neg a) (expr-rat-neg (zonk-at-depth depth a))]
    [(expr-rat-abs a) (expr-rat-abs (zonk-at-depth depth a))]
    [(expr-rat-lt a b) (expr-rat-lt (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-rat-le a b) (expr-rat-le (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-rat-eq a b) (expr-rat-eq (zonk-at-depth depth a) (zonk-at-depth depth b))]
    [(expr-from-int n) (expr-from-int (zonk-at-depth depth n))]
    [(expr-rat-numer a) (expr-rat-numer (zonk-at-depth depth a))]
    [(expr-rat-denom a) (expr-rat-denom (zonk-at-depth depth a))]

    ;; Union types
    [(expr-union l r) (expr-union (zonk-at-depth depth l) (zonk-at-depth depth r))]

    ;; Foreign function (opaque leaf)
    [(expr-foreign-fn _ _ _ _ _ _) e]

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
    ;; Posit16 (all non-binding)
    [(expr-Posit16) e]
    [(expr-posit16 _) e]
    [(expr-p16-add a b) (expr-p16-add (default-metas a) (default-metas b))]
    [(expr-p16-sub a b) (expr-p16-sub (default-metas a) (default-metas b))]
    [(expr-p16-mul a b) (expr-p16-mul (default-metas a) (default-metas b))]
    [(expr-p16-div a b) (expr-p16-div (default-metas a) (default-metas b))]
    [(expr-p16-neg a) (expr-p16-neg (default-metas a))]
    [(expr-p16-abs a) (expr-p16-abs (default-metas a))]
    [(expr-p16-sqrt a) (expr-p16-sqrt (default-metas a))]
    [(expr-p16-lt a b) (expr-p16-lt (default-metas a) (default-metas b))]
    [(expr-p16-le a b) (expr-p16-le (default-metas a) (default-metas b))]
    [(expr-p16-from-nat n) (expr-p16-from-nat (default-metas n))]
    [(expr-p16-if-nar t nc vc v)
     (expr-p16-if-nar (default-metas t) (default-metas nc)
                      (default-metas vc) (default-metas v))]
    ;; Posit32 (all non-binding)
    [(expr-Posit32) e]
    [(expr-posit32 _) e]
    [(expr-p32-add a b) (expr-p32-add (default-metas a) (default-metas b))]
    [(expr-p32-sub a b) (expr-p32-sub (default-metas a) (default-metas b))]
    [(expr-p32-mul a b) (expr-p32-mul (default-metas a) (default-metas b))]
    [(expr-p32-div a b) (expr-p32-div (default-metas a) (default-metas b))]
    [(expr-p32-neg a) (expr-p32-neg (default-metas a))]
    [(expr-p32-abs a) (expr-p32-abs (default-metas a))]
    [(expr-p32-sqrt a) (expr-p32-sqrt (default-metas a))]
    [(expr-p32-lt a b) (expr-p32-lt (default-metas a) (default-metas b))]
    [(expr-p32-le a b) (expr-p32-le (default-metas a) (default-metas b))]
    [(expr-p32-from-nat n) (expr-p32-from-nat (default-metas n))]
    [(expr-p32-if-nar t nc vc v)
     (expr-p32-if-nar (default-metas t) (default-metas nc)
                      (default-metas vc) (default-metas v))]
    ;; Posit64 (all non-binding)
    [(expr-Posit64) e]
    [(expr-posit64 _) e]
    [(expr-p64-add a b) (expr-p64-add (default-metas a) (default-metas b))]
    [(expr-p64-sub a b) (expr-p64-sub (default-metas a) (default-metas b))]
    [(expr-p64-mul a b) (expr-p64-mul (default-metas a) (default-metas b))]
    [(expr-p64-div a b) (expr-p64-div (default-metas a) (default-metas b))]
    [(expr-p64-neg a) (expr-p64-neg (default-metas a))]
    [(expr-p64-abs a) (expr-p64-abs (default-metas a))]
    [(expr-p64-sqrt a) (expr-p64-sqrt (default-metas a))]
    [(expr-p64-lt a b) (expr-p64-lt (default-metas a) (default-metas b))]
    [(expr-p64-le a b) (expr-p64-le (default-metas a) (default-metas b))]
    [(expr-p64-from-nat n) (expr-p64-from-nat (default-metas n))]
    [(expr-p64-if-nar t nc vc v)
     (expr-p64-if-nar (default-metas t) (default-metas nc)
                      (default-metas vc) (default-metas v))]
    ;; Quire8
    [(expr-Quire8) e]
    [(expr-quire8-val _) e]
    [(expr-quire8-fma q a b) (expr-quire8-fma (default-metas q) (default-metas a) (default-metas b))]
    [(expr-quire8-to q) (expr-quire8-to (default-metas q))]
    ;; Quire16
    [(expr-Quire16) e]
    [(expr-quire16-val _) e]
    [(expr-quire16-fma q a b) (expr-quire16-fma (default-metas q) (default-metas a) (default-metas b))]
    [(expr-quire16-to q) (expr-quire16-to (default-metas q))]
    ;; Quire32
    [(expr-Quire32) e]
    [(expr-quire32-val _) e]
    [(expr-quire32-fma q a b) (expr-quire32-fma (default-metas q) (default-metas a) (default-metas b))]
    [(expr-quire32-to q) (expr-quire32-to (default-metas q))]
    ;; Quire64
    [(expr-Quire64) e]
    [(expr-quire64-val _) e]
    [(expr-quire64-fma q a b) (expr-quire64-fma (default-metas q) (default-metas a) (default-metas b))]
    [(expr-quire64-to q) (expr-quire64-to (default-metas q))]
    ;; Keyword
    [(expr-Keyword) e]
    [(expr-keyword _) e]
    ;; Map
    [(expr-Map k v) (expr-Map (default-metas k) (default-metas v))]
    [(expr-champ _) e]
    [(expr-map-empty k v) (expr-map-empty (default-metas k) (default-metas v))]
    [(expr-map-assoc m k v) (expr-map-assoc (default-metas m) (default-metas k) (default-metas v))]
    [(expr-map-get m k) (expr-map-get (default-metas m) (default-metas k))]
    [(expr-map-dissoc m k) (expr-map-dissoc (default-metas m) (default-metas k))]
    [(expr-map-size m) (expr-map-size (default-metas m))]
    [(expr-map-has-key m k) (expr-map-has-key (default-metas m) (default-metas k))]
    [(expr-map-keys m) (expr-map-keys (default-metas m))]
    [(expr-map-vals m) (expr-map-vals (default-metas m))]
    ;; PVec (all non-binding)
    [(expr-PVec a) (expr-PVec (default-metas a))]
    [(expr-rrb _) e]
    [(expr-pvec-empty a) (expr-pvec-empty (default-metas a))]
    [(expr-pvec-push v x) (expr-pvec-push (default-metas v) (default-metas x))]
    [(expr-pvec-nth v i) (expr-pvec-nth (default-metas v) (default-metas i))]
    [(expr-pvec-update v i x) (expr-pvec-update (default-metas v) (default-metas i) (default-metas x))]
    [(expr-pvec-length v) (expr-pvec-length (default-metas v))]
    [(expr-pvec-pop v) (expr-pvec-pop (default-metas v))]
    [(expr-pvec-concat v1 v2) (expr-pvec-concat (default-metas v1) (default-metas v2))]
    [(expr-pvec-slice v lo hi) (expr-pvec-slice (default-metas v) (default-metas lo) (default-metas hi))]
    [(expr-Int) e]
    [(expr-int _) e]
    [(expr-int-add a b) (expr-int-add (default-metas a) (default-metas b))]
    [(expr-int-sub a b) (expr-int-sub (default-metas a) (default-metas b))]
    [(expr-int-mul a b) (expr-int-mul (default-metas a) (default-metas b))]
    [(expr-int-div a b) (expr-int-div (default-metas a) (default-metas b))]
    [(expr-int-mod a b) (expr-int-mod (default-metas a) (default-metas b))]
    [(expr-int-neg a) (expr-int-neg (default-metas a))]
    [(expr-int-abs a) (expr-int-abs (default-metas a))]
    [(expr-int-lt a b) (expr-int-lt (default-metas a) (default-metas b))]
    [(expr-int-le a b) (expr-int-le (default-metas a) (default-metas b))]
    [(expr-int-eq a b) (expr-int-eq (default-metas a) (default-metas b))]
    [(expr-from-nat n) (expr-from-nat (default-metas n))]
    [(expr-Rat) e]
    [(expr-rat _) e]
    [(expr-rat-add a b) (expr-rat-add (default-metas a) (default-metas b))]
    [(expr-rat-sub a b) (expr-rat-sub (default-metas a) (default-metas b))]
    [(expr-rat-mul a b) (expr-rat-mul (default-metas a) (default-metas b))]
    [(expr-rat-div a b) (expr-rat-div (default-metas a) (default-metas b))]
    [(expr-rat-neg a) (expr-rat-neg (default-metas a))]
    [(expr-rat-abs a) (expr-rat-abs (default-metas a))]
    [(expr-rat-lt a b) (expr-rat-lt (default-metas a) (default-metas b))]
    [(expr-rat-le a b) (expr-rat-le (default-metas a) (default-metas b))]
    [(expr-rat-eq a b) (expr-rat-eq (default-metas a) (default-metas b))]
    [(expr-from-int n) (expr-from-int (default-metas n))]
    [(expr-rat-numer a) (expr-rat-numer (default-metas a))]
    [(expr-rat-denom a) (expr-rat-denom (default-metas a))]
    [(expr-union l r) (expr-union (default-metas l) (default-metas r))]
    ;; Foreign function (opaque leaf)
    [(expr-foreign-fn _ _ _ _ _ _) e]
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
