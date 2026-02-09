#lang racket/base

;;;
;;; PROLOGOS REDEX — QTT (Quantitative Type Theory)
;;; PLT Redex metafunctions for multiplicity tracking.
;;; Faithful translation of qtt.rkt (267 lines) into Redex metafunctions.
;;;
;;; The QTT layer tracks how each variable is used (0, 1, or w times)
;;; and verifies that actual usage is compatible with declared multiplicities.
;;;
;;; Usage contexts are plain Racket lists of multiplicity symbols '(m0 m1 mw ...).
;;; inferQ and checkQ are define-metafunction with `any` return type,
;;; using `,` escapes for complex conditional logic.
;;;
;;; Results are Racket values:
;;;   Success inference: (list 'tu type-term usage-list)
;;;   Failure:           'tu-error
;;;   Success check:     (list 'bu bool usage-list)
;;;
;;; Cross-reference: qtt.rkt (kernel, 267 lines)
;;;

(require racket/match
         racket/list
         redex/reduction-semantics
         "lang.rkt"
         "subst.rkt"
         "reduce.rkt"
         "typing.rkt")

(provide inferQ checkQ checkQ-top
         zero-usage single-usage add-usage scale-usage
         check-all-usages)

;; ========================================
;; Usage Context Operations (Racket functions)
;; ========================================

;; Create a zero-usage context of length n
(define (zero-usage n)
  (make-list n 'm0))

;; Create a usage with m1 at position k, m0 elsewhere, length n
(define (single-usage k n)
  (for/list ([i (in-range n)])
    (if (= i k) 'm1 'm0)))

;; Pointwise addition of usage contexts
;; Uses the mult-add metafunction from lang.rkt
(define (add-usage u1 u2)
  (cond
    [(and (null? u1) (null? u2)) '()]
    [(null? u1) u2]
    [(null? u2) u1]
    [else (cons (term (mult-add ,(car u1) ,(car u2)))
                (add-usage (cdr u1) (cdr u2)))]))

;; Scalar multiplication of usage context
(define (scale-usage m u)
  (map (lambda (x) (term (mult-mul ,m ,x))) u))

;; Check that actual usages are compatible with declared multiplicities.
;; ctx-term is a Redex context s-expression: () or ((e m) Gamma)
;; usage is a Racket list of multiplicity symbols.
(define (check-all-usages ctx-term usage)
  (match ctx-term
    ['() (null? usage)]
    [`((,_ ,decl-mult) ,rest)
     (and (not (null? usage))
          (equal? #t (term (compatible ,decl-mult ,(car usage))))
          (check-all-usages rest (cdr usage)))]
    [_ #f]))

;; ========================================
;; QTT Inference: inferQ
;; Returns (list 'tu type-term usage-list) or 'tu-error
;; ========================================
(define-metafunction Prologos
  inferQ : Gamma e -> any

  ;; Variable: bvar(K) uses position K exactly once
  [(inferQ Gamma (bvar natural_k))
   ,(let ([k (term natural_k)]
          [n (term (ctx-len Gamma))])
      (if (< k n)
          (list 'tu
                (term (shift ,(add1 k) 0 (lookup-type natural_k Gamma)))
                (single-usage k n))
          'tu-error))]

  ;; Free variable: cannot infer
  [(inferQ Gamma (fvar variable_x))
   ,'tu-error]

  ;; Constants: zero usage
  [(inferQ Gamma (Type l))
   ,(list 'tu (term (Type (lsuc l))) (zero-usage (term (ctx-len Gamma))))]

  [(inferQ Gamma Nat)
   ,(list 'tu (term (Type lzero)) (zero-usage (term (ctx-len Gamma))))]

  [(inferQ Gamma Bool)
   ,(list 'tu (term (Type lzero)) (zero-usage (term (ctx-len Gamma))))]

  [(inferQ Gamma zero)
   ,(list 'tu (term Nat) (zero-usage (term (ctx-len Gamma))))]

  [(inferQ Gamma true)
   ,(list 'tu (term Bool) (zero-usage (term (ctx-len Gamma))))]

  [(inferQ Gamma false)
   ,(list 'tu (term Bool) (zero-usage (term (ctx-len Gamma))))]

  ;; suc: usage from the argument
  [(inferQ Gamma (suc e_1))
   ,(let ([r (term (inferQ Gamma e_1))])
      (match r
        [`(tu ,t ,u)
         (if (equal? t (term Nat))
             (list 'tu (term Nat) u)
             'tu-error)]
        [_ 'tu-error]))]

  ;; Annotation: ann(e, T)
  [(inferQ Gamma (ann e_1 e_T))
   ,(if (equal? #t (term (is-type Gamma e_T)))
        (let ([r (term (checkQ Gamma e_1 e_T))])
          (match r
            [`(bu #t ,u) (list 'tu (term e_T) u)]
            [_ 'tu-error]))
        'tu-error)]

  ;; Application: Usage = U_func + pi * U_arg
  [(inferQ Gamma (app e_1 e_2))
   ,(let ([r1 (term (inferQ Gamma e_1))])
      (match r1
        [`(tu ,t1 ,u1)
         (let ([t1w (term (whnf ,t1))])
           (match t1w
             [`(Pi ,m ,a ,b)
              (let ([r2 (term (checkQ Gamma e_2 ,a))])
                (match r2
                  [`(bu #t ,u2)
                   (list 'tu
                         (term (subst 0 e_2 ,b))
                         (add-usage u1 (scale-usage m u2)))]
                  [_ 'tu-error]))]
             [_ 'tu-error]))]
        [_ 'tu-error]))]

  ;; fst
  [(inferQ Gamma (fst e_1))
   ,(let ([r (term (inferQ Gamma e_1))])
      (match r
        [`(tu ,t ,u)
         (let ([tw (term (whnf ,t))])
           (match tw
             [`(Sigma ,a ,b) (list 'tu a u)]
             [_ 'tu-error]))]
        [_ 'tu-error]))]

  ;; snd
  [(inferQ Gamma (snd e_1))
   ,(let ([r (term (inferQ Gamma e_1))])
      (match r
        [`(tu ,t ,u)
         (let ([tw (term (whnf ,t))])
           (match tw
             [`(Sigma ,a ,b) (list 'tu (term (subst 0 (fst e_1) ,b)) u)]
             [_ 'tu-error]))]
        [_ 'tu-error]))]

  ;; natrec: Usage = U_target + U_base + U_step
  [(inferQ Gamma (natrec e_mot e_base e_step e_target))
   ,(let ([r4 (term (checkQ Gamma e_target Nat))])
      (match r4
        [`(bu #t ,u4)
         (let ([r2 (term (checkQ Gamma e_base (app e_mot zero)))])
           (match r2
             [`(bu #t ,u2)
              (let ([r3 (term (inferQ Gamma e_step))])
                (match r3
                  [`(tu ,_ ,u3)
                   (list 'tu
                         (term (app e_mot e_target))
                         (add-usage u4 (add-usage u2 u3)))]
                  [_ 'tu-error]))]
             [_ 'tu-error]))]
        [_ 'tu-error]))]

  ;; J eliminator
  [(inferQ Gamma (J e_mot e_base e_left e_right e_proof))
   ,(let ([r5 (term (inferQ Gamma e_proof))])
      (match r5
        [`(tu ,t5 ,u5)
         (let ([t5w (term (whnf ,t5))])
           (match t5w
             [`(Eq ,ty ,t1 ,t2)
              (if (and (equal? #t (term (conv ,t1 e_left)))
                       (equal? #t (term (conv ,t2 e_right))))
                  (list 'tu
                        (term (app (app (app e_mot e_left) e_right) e_proof))
                        u5)
                  'tu-error)]
             [_ 'tu-error]))]
        [_ 'tu-error]))]

  ;; Fallback: cannot infer
  [(inferQ Gamma e)
   ,'tu-error])

;; ========================================
;; QTT Checking: checkQ
;; Returns (list 'bu bool usage-list)
;; ========================================
(define-metafunction Prologos
  checkQ : Gamma e e -> any

  [(checkQ Gamma e e_T)
   ,(let* ([n (term (ctx-len Gamma))]
           [t-whnf (term (whnf e_T))])
      (match* ((term e) t-whnf)
        ;; suc against Nat
        [(`(suc ,e1) 'Nat)
         (let ([r (term (checkQ Gamma ,e1 Nat))])
           (match r
             [`(bu #t ,u) (list 'bu #t u)]
             [_ (list 'bu #f (zero-usage n))]))]

        ;; Lambda against Pi
        [(`(lam ,m ,a ,body) `(Pi ,m2 ,t-dom ,b))
         (cond
           [(not (eq? m m2)) (list 'bu #f (zero-usage n))]
           [(not (equal? #t (term (conv ,a ,t-dom)))) (list 'bu #f (zero-usage n))]
           [else
            (let ([r (term (checkQ ((,a ,m) Gamma) ,body ,b))])
              (match r
                [`(bu #t ,u)
                 (if (equal? #t (term (compatible ,m ,(car u))))
                     (list 'bu #t (cdr u))
                     (list 'bu #f (zero-usage n)))]
                [_ (list 'bu #f (zero-usage n))]))])]

        ;; Pair against Sigma
        [(`(pair ,e1 ,e2) `(Sigma ,a ,b))
         (let ([r1 (term (checkQ Gamma ,e1 ,a))])
           (match r1
             [`(bu #t ,u1)
              (let ([r2 (term (checkQ Gamma ,e2 (subst 0 ,e1 ,b)))])
                (match r2
                  [`(bu #t ,u2) (list 'bu #t (add-usage u1 u2))]
                  [_ (list 'bu #f (zero-usage n))]))]
             [_ (list 'bu #f (zero-usage n))]))]

        ;; refl against Eq
        [('refl `(Eq ,_ ,e1 ,e2))
         (list 'bu (equal? #t (term (conv ,e1 ,e2))) (zero-usage n))]

        ;; Conversion fallback: infer and compare
        [(_ _)
         (let ([r (term (inferQ Gamma e))])
           (match r
             [`(tu ,t1 ,u)
              (if (and (not (equal? t1 (term err)))
                       (equal? #t (term (conv e_T ,t1))))
                  (list 'bu #t u)
                  (list 'bu #f (zero-usage n)))]
             [_ (list 'bu #f (zero-usage n))]))]))])

;; ========================================
;; Top-level QTT check
;; Verifies that a term has the given type and that all variable usages
;; are compatible with their declared multiplicities.
;; ========================================
(define (checkQ-top ctx-term e-term t-term)
  (let ([r (term (checkQ ,ctx-term ,e-term ,t-term))])
    (match r
      [`(bu #t ,u) (check-all-usages ctx-term u)]
      [_ #f])))
