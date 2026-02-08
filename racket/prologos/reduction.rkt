#lang racket/base

;;;
;;; PROLOGOS REDUCTION
;;; Weak head normal form reduction, full normalization, and definitional equality.
;;; Direct translation of prologos-reduction.maude + prologos-inductive.maude extensions.
;;;
;;; whnf(e)      : reduce to weak head normal form (beta, iota, projections)
;;; nf(e)        : reduce to full normal form (under all binders)
;;; conv(e1, e2) : check definitional equality (compare normal forms)
;;;

(require racket/match
         "prelude.rkt"
         "syntax.rkt"
         "substitution.rkt"
         "global-env.rkt")

(provide whnf nf nf-whnf conv)

;; ========================================
;; Weak Head Normal Form
;; ========================================
(define (whnf e)
  (match e
    ;; Beta reduction: app(lam(m, A, body), arg) -> whnf(subst(0, arg, body))
    [(expr-app (expr-lam _ _ body) arg)
     (whnf (subst 0 arg body))]

    ;; Projections on pairs
    [(expr-fst (expr-pair e1 _)) (whnf e1)]
    [(expr-snd (expr-pair _ e2)) (whnf e2)]

    ;; Iota reduction for natrec
    ;; natrec(motive, base, step, zero) -> base
    [(expr-natrec _ base _ (expr-zero)) (whnf base)]
    ;; natrec(motive, base, step, suc(n)) -> app(app(step, n), natrec(motive, base, step, n))
    [(expr-natrec mot base step (expr-suc n))
     (whnf (expr-app (expr-app step n) (expr-natrec mot base step n)))]

    ;; J reduction: J(motive, base, a, _, refl) -> app(base, a)
    [(expr-J _ base left _ (expr-refl)) (whnf (expr-app base left))]

    ;; Annotation erasure
    [(expr-ann e1 _) (whnf e1)]

    ;; Vec eliminators: vhead/vtail on vcons
    [(expr-vhead _ _ (expr-vcons _ _ hd _)) (whnf hd)]
    [(expr-vtail _ _ (expr-vcons _ _ _ tl)) (whnf tl)]

    ;; Application of non-lambda: reduce function first
    [(expr-app e1 e2)
     (let ([e1* (whnf e1)])
       (if (equal? e1* e1)
           e  ; stuck — already in WHNF
           (whnf (expr-app e1* e2))))]

    ;; Projection of non-pair: reduce argument first
    [(expr-fst e1)
     (let ([e1* (whnf e1)])
       (if (equal? e1* e1)
           e
           (whnf (expr-fst e1*))))]
    [(expr-snd e1)
     (let ([e1* (whnf e1)])
       (if (equal? e1* e1)
           e
           (whnf (expr-snd e1*))))]

    ;; natrec with non-canonical target: reduce target first, then retry
    [(expr-natrec mot base step target)
     (let ([target* (whnf target)])
       (if (equal? target* target)
           e  ; stuck — target is neutral
           (whnf (expr-natrec mot base step target*))))]

    ;; J with non-refl proof: reduce proof first, then retry
    [(expr-J mot base left right proof)
     (let ([proof* (whnf proof)])
       (if (equal? proof* proof)
           e  ; stuck
           (whnf (expr-J mot base left right proof*))))]

    ;; vhead/vtail with non-vcons: reduce vec first
    [(expr-vhead t n v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-vhead t n v*))))]
    [(expr-vtail t n v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-vtail t n v*))))]

    ;; Free variable: unfold global definition if available
    [(expr-fvar name)
     (let ([val (global-env-lookup-value name)])
       (if val (whnf val) e))]

    ;; Everything else is already in WHNF
    [_ e]))

;; ========================================
;; Full Normalization
;; First reduce to WHNF, then normalize all subterms
;; ========================================
(define (nf e)
  (nf-whnf (whnf e)))

;; Helper: normalize a term that is already in WHNF
(define (nf-whnf e)
  (match e
    ;; Atoms / leaves — already normal
    [(expr-bvar _) e]
    [(expr-fvar _) e]
    [(expr-zero) e]
    [(expr-refl) e]
    [(expr-Nat) e]
    [(expr-Bool) e]
    [(expr-true) e]
    [(expr-false) e]
    [(expr-Type _) e]
    [(expr-error) e]

    ;; Structured terms: normalize subterms
    [(expr-suc e1) (expr-suc (nf e1))]
    [(expr-lam m t body) (expr-lam m (nf t) (nf body))]
    [(expr-Pi m dom cod) (expr-Pi m (nf dom) (nf cod))]
    [(expr-Sigma t1 t2) (expr-Sigma (nf t1) (nf t2))]
    [(expr-pair e1 e2) (expr-pair (nf e1) (nf e2))]
    [(expr-Eq t e1 e2) (expr-Eq (nf t) (nf e1) (nf e2))]

    ;; Application that didn't reduce (neutral term)
    [(expr-app e1 e2) (expr-app (nf e1) (nf e2))]
    ;; Projection that didn't reduce (neutral)
    [(expr-fst e1) (expr-fst (nf e1))]
    [(expr-snd e1) (expr-snd (nf e1))]

    ;; Annotation erasure (shouldn't usually appear in WHNF, but handle it)
    [(expr-ann e1 _) (nf e1)]

    ;; Eliminators stuck on neutral
    [(expr-natrec mot base step target)
     (expr-natrec (nf mot) (nf base) (nf step) (nf target))]
    [(expr-J mot base left right proof)
     (expr-J (nf mot) (nf base) (nf left) (nf right) (nf proof))]

    ;; Vec/Fin normalization
    [(expr-Vec t n) (expr-Vec (nf t) (nf n))]
    [(expr-vnil t) (expr-vnil (nf t))]
    [(expr-vcons t n hd tl) (expr-vcons (nf t) (nf n) (nf hd) (nf tl))]
    [(expr-Fin n) (expr-Fin (nf n))]
    [(expr-fzero n) (expr-fzero (nf n))]
    [(expr-fsuc n i) (expr-fsuc (nf n) (nf i))]
    [(expr-vhead t n v) (expr-vhead (nf t) (nf n) (nf v))]
    [(expr-vtail t n v) (expr-vtail (nf t) (nf n) (nf v))]
    [(expr-vindex t n i v) (expr-vindex (nf t) (nf n) (nf i) (nf v))]))

;; ========================================
;; Definitional Equality (conversion)
;; Two terms are definitionally equal iff their normal forms
;; are syntactically identical.
;; (#:transparent structs give us deep structural equal?)
;; ========================================
(define (conv e1 e2)
  (equal? (nf e1) (nf e2)))
