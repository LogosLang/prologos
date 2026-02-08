#lang racket/base

;;;
;;; PROLOGOS ELABORATOR
;;; Transforms surface AST (named variables) to core AST (de Bruijn indices).
;;; Performs name resolution, scope checking, and desugaring.
;;;

(require racket/match
         "prelude.rkt"
         "syntax.rkt"
         "source-location.rkt"
         "surface-syntax.rkt"
         "errors.rkt"
         "global-env.rkt")

(provide elaborate
         elaborate-top-level)

;; ========================================
;; Elaboration environment
;; ========================================
;; An environment is a list of (cons name depth) pairs, most recent first.
;; When we look up a name at current depth D, we find its binding depth BD,
;; and the de Bruijn index is D - BD - 1.

;; Lookup a name in the environment, returning de Bruijn index or #f
(define (env-lookup env name depth)
  (cond
    [(null? env) #f]
    [(eq? (caar env) name)
     (- depth (cdar env) 1)]
    [else (env-lookup (cdr env) name depth)]))

;; Extend environment with a new binding
(define (env-extend env name depth)
  (cons (cons name depth) env))

;; ========================================
;; Main elaboration: surface -> core
;; ========================================

;; elaborate: surface-expr, env, depth -> (or/c expr? prologos-error?)
(define (elaborate surf [env '()] [depth 0])
  (match surf
    ;; Variable: look up name, compute de Bruijn index
    [(surf-var name loc)
     (let ([idx (env-lookup env name depth)])
       (cond
         [idx (expr-bvar idx)]
         ;; Check global environment
         [(global-env-lookup-type name) (expr-fvar name)]
         [else (unbound-variable-error loc "Unbound variable" name)]))]

    ;; Nat literal: desugar to suc chain
    [(surf-nat-lit n loc)
     (nat->expr n)]

    ;; Constants
    [(surf-zero _) (expr-zero)]
    [(surf-suc pred loc)
     (let ([e (elaborate pred env depth)])
       (if (prologos-error? e) e (expr-suc e)))]
    [(surf-true _) (expr-true)]
    [(surf-false _) (expr-false)]
    [(surf-refl _) (expr-refl)]
    [(surf-nat-type _) (expr-Nat)]
    [(surf-bool-type _) (expr-Bool)]

    ;; Type universe
    [(surf-type n loc)
     (expr-Type (nat->level n))]

    ;; Arrow (non-dependent): (-> A B) -> Pi(mw, elab-A, elab-B-shifted)
    ;; Pi introduces a binder, so codomain is under a binder even for arrows.
    ;; We elaborate B at depth+1 (under a dummy binding) so that references
    ;; to outer variables get the correct de Bruijn indices.
    [(surf-arrow dom cod loc)
     (let ([a (elaborate dom env depth)]
           [b (elaborate cod env (+ depth 1))])
       (cond
         [(prologos-error? a) a]
         [(prologos-error? b) b]
         [else (expr-Pi 'mw a b)]))]

    ;; Pi type: (Pi (x :m A) B) -> Pi(m, elab-A, elab-B) with x bound in B
    [(surf-pi binder body loc)
     (let* ([name (binder-info-name binder)]
            [mult (binder-info-mult binder)]
            [ty-surf (binder-info-type binder)]
            [ty (elaborate ty-surf env depth)])
       (if (prologos-error? ty) ty
           (let* ([new-env (env-extend env name depth)]
                  [new-depth (+ depth 1)]
                  [bod (elaborate body new-env new-depth)])
             (if (prologos-error? bod) bod
                 (expr-Pi mult ty bod)))))]

    ;; Lambda: (lam (x :m A) body) -> lam(m, elab-A, elab-body) with x bound
    [(surf-lam binder body loc)
     (let* ([name (binder-info-name binder)]
            [mult (binder-info-mult binder)]
            [ty-surf (binder-info-type binder)]
            [ty (elaborate ty-surf env depth)])
       (if (prologos-error? ty) ty
           (let* ([new-env (env-extend env name depth)]
                  [new-depth (+ depth 1)]
                  [bod (elaborate body new-env new-depth)])
             (if (prologos-error? bod) bod
                 (expr-lam mult ty bod)))))]

    ;; Sigma: (Sigma (x : A) B) -> Sigma(elab-A, elab-B) with x bound in B
    [(surf-sigma binder body loc)
     (let* ([name (binder-info-name binder)]
            [ty-surf (binder-info-type binder)]
            [ty (elaborate ty-surf env depth)])
       (if (prologos-error? ty) ty
           (let* ([new-env (env-extend env name depth)]
                  [new-depth (+ depth 1)]
                  [bod (elaborate body new-env new-depth)])
             (if (prologos-error? bod) bod
                 (expr-Sigma ty bod)))))]

    ;; Application: (f a b c) -> app(app(app(elab-f, elab-a), elab-b), elab-c)
    [(surf-app func args loc)
     (let ([ef (elaborate func env depth)])
       (if (prologos-error? ef) ef
           (elaborate-args ef args env depth loc)))]

    ;; Pair
    [(surf-pair e1 e2 loc)
     (let ([a (elaborate e1 env depth)]
           [b (elaborate e2 env depth)])
       (cond [(prologos-error? a) a]
             [(prologos-error? b) b]
             [else (expr-pair a b)]))]

    ;; Projections
    [(surf-fst e loc)
     (let ([e1 (elaborate e env depth)])
       (if (prologos-error? e1) e1 (expr-fst e1)))]
    [(surf-snd e loc)
     (let ([e1 (elaborate e env depth)])
       (if (prologos-error? e1) e1 (expr-snd e1)))]

    ;; Annotation: (the T e) -> ann(elab-e, elab-T)
    [(surf-ann type term loc)
     (let ([t (elaborate type env depth)]
           [e (elaborate term env depth)])
       (cond [(prologos-error? t) t]
             [(prologos-error? e) e]
             [else (expr-ann e t)]))]

    ;; Equality type
    [(surf-eq type lhs rhs loc)
     (let ([t (elaborate type env depth)]
           [l (elaborate lhs env depth)]
           [r (elaborate rhs env depth)])
       (cond [(prologos-error? t) t]
             [(prologos-error? l) l]
             [(prologos-error? r) r]
             [else (expr-Eq t l r)]))]

    ;; natrec
    [(surf-natrec mot base step target loc)
     (let ([m (elaborate mot env depth)]
           [b (elaborate base env depth)]
           [s (elaborate step env depth)]
           [tgt (elaborate target env depth)])
       (cond [(prologos-error? m) m]
             [(prologos-error? b) b]
             [(prologos-error? s) s]
             [(prologos-error? tgt) tgt]
             [else (expr-natrec m b s tgt)]))]

    ;; J
    [(surf-J mot base left right proof loc)
     (let ([m (elaborate mot env depth)]
           [b (elaborate base env depth)]
           [l (elaborate left env depth)]
           [r (elaborate right env depth)]
           [p (elaborate proof env depth)])
       (cond [(prologos-error? m) m]
             [(prologos-error? b) b]
             [(prologos-error? l) l]
             [(prologos-error? r) r]
             [(prologos-error? p) p]
             [else (expr-J m b l r p)]))]

    ;; Vec/Fin
    [(surf-vec-type t n loc)
     (let ([a (elaborate t env depth)]
           [len (elaborate n env depth)])
       (cond [(prologos-error? a) a]
             [(prologos-error? len) len]
             [else (expr-Vec a len)]))]
    [(surf-vnil t loc)
     (let ([a (elaborate t env depth)])
       (if (prologos-error? a) a (expr-vnil a)))]
    [(surf-vcons t n hd tl loc)
     (let ([a (elaborate t env depth)]
           [len (elaborate n env depth)]
           [h (elaborate hd env depth)]
           [tail (elaborate tl env depth)])
       (cond [(prologos-error? a) a]
             [(prologos-error? len) len]
             [(prologos-error? h) h]
             [(prologos-error? tail) tail]
             [else (expr-vcons a len h tail)]))]
    [(surf-fin-type n loc)
     (let ([bound (elaborate n env depth)])
       (if (prologos-error? bound) bound (expr-Fin bound)))]
    [(surf-fzero n loc)
     (let ([bound (elaborate n env depth)])
       (if (prologos-error? bound) bound (expr-fzero bound)))]
    [(surf-fsuc n inner loc)
     (let ([bound (elaborate n env depth)]
           [i (elaborate inner env depth)])
       (cond [(prologos-error? bound) bound]
             [(prologos-error? i) i]
             [else (expr-fsuc bound i)]))]
    [(surf-vhead t n v loc)
     (let ([a (elaborate t env depth)]
           [len (elaborate n env depth)]
           [vec (elaborate v env depth)])
       (cond [(prologos-error? a) a]
             [(prologos-error? len) len]
             [(prologos-error? vec) vec]
             [else (expr-vhead a len vec)]))]
    [(surf-vtail t n v loc)
     (let ([a (elaborate t env depth)]
           [len (elaborate n env depth)]
           [vec (elaborate v env depth)])
       (cond [(prologos-error? a) a]
             [(prologos-error? len) len]
             [(prologos-error? vec) vec]
             [else (expr-vtail a len vec)]))]
    [(surf-vindex t n i v loc)
     (let ([a (elaborate t env depth)]
           [len (elaborate n env depth)]
           [idx (elaborate i env depth)]
           [vec (elaborate v env depth)])
       (cond [(prologos-error? a) a]
             [(prologos-error? len) len]
             [(prologos-error? idx) idx]
             [(prologos-error? vec) vec]
             [else (expr-vindex a len idx vec)]))]

    ;; Fallback
    [_ (prologos-error srcloc-unknown (format "Cannot elaborate: ~a" surf))]))

;; ========================================
;; Elaborate a list of arguments into nested application
;; ========================================
(define (elaborate-args func-expr arg-surfs env depth loc)
  (if (null? arg-surfs)
      func-expr
      (let ([arg (elaborate (car arg-surfs) env depth)])
        (if (prologos-error? arg) arg
            (elaborate-args (expr-app func-expr arg)
                           (cdr arg-surfs) env depth loc)))))

;; ========================================
;; Helper: natural -> level
;; ========================================
(define (nat->level n)
  (if (= n 0) (lzero) (lsuc (nat->level (- n 1)))))

;; ========================================
;; Elaborate top-level commands
;; Returns the surface command + elaborated expressions,
;; or a prologos-error
;; ========================================
(define (elaborate-top-level surf)
  (match surf
    [(surf-def name type-surf body-surf loc)
     (let ([ty (elaborate type-surf)]
           [bd (elaborate body-surf)])
       (cond
         [(prologos-error? ty) ty]
         [(prologos-error? bd) bd]
         [else (list 'def name ty bd)]))]

    [(surf-check expr-surf type-surf loc)
     (let ([e (elaborate expr-surf)]
           [t (elaborate type-surf)])
       (cond
         [(prologos-error? e) e]
         [(prologos-error? t) t]
         [else (list 'check e t)]))]

    [(surf-eval expr-surf loc)
     (let ([e (elaborate expr-surf)])
       (if (prologos-error? e) e
           (list 'eval e)))]

    [(surf-infer expr-surf loc)
     (let ([e (elaborate expr-surf)])
       (if (prologos-error? e) e
           (list 'infer e)))]

    [_ (prologos-error srcloc-unknown (format "Unknown top-level form: ~a" surf))]))
