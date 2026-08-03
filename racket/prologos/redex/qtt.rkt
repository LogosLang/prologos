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

  ;; ---- Vec eliminators (QTT P5's usage rules, mirrored 2026-08-03) ----
  ;;
  ;; Usage passes the SUBJECT's usage through unchanged — the projection
  ;; stance `fst`/`snd` already take above. The discarded part of the vector
  ;; (the tail for vhead, the head for vtail, every other element for vindex)
  ;; is weakening, which is invisible to variable-level usage accounting, just
  ;; as `fst` discarding a pair's second component is.
  ;;
  ;; A/n are type-level indices and contribute nothing; for `vindex` the INDEX
  ;; does contribute, because it is a runtime value (`i : Fin n`), and it is
  ;; checked rather than inferred for the same reason the kernel checks it.
  ;;
  ;; The TYPE is delegated to `infer` — the no-drift twin pattern the kernel
  ;; uses at these same three arms. These rules compute USAGE.

  [(inferQ Gamma (vhead e_A e_n e_v))
   ,(let ([ty (term (infer Gamma (vhead e_A e_n e_v)))])
      (if (equal? ty (term err))
          'tu-error
          (let ([r (term (checkQ Gamma e_v (Vec e_A (suc e_n))))])
            (match r
              [`(bu #t ,u) (list 'tu ty u)]
              [_ 'tu-error]))))]

  [(inferQ Gamma (vtail e_A e_n e_v))
   ,(let ([ty (term (infer Gamma (vtail e_A e_n e_v)))])
      (if (equal? ty (term err))
          'tu-error
          (let ([r (term (checkQ Gamma e_v (Vec e_A (suc e_n))))])
            (match r
              [`(bu #t ,u) (list 'tu ty u)]
              [_ 'tu-error]))))]

  ;; vindex consumes BOTH the index and the vector, so its usage is the SUM,
  ;; not a passthrough. `add-usage`, not a join: both are read, so both happen.
  [(inferQ Gamma (vindex e_A e_n e_i e_v))
   ,(let ([ty (term (infer Gamma (vindex e_A e_n e_i e_v)))])
      (if (equal? ty (term err))
          'tu-error
          (let ([ri (term (checkQ Gamma e_i (Fin e_n)))]
                [rv (term (checkQ Gamma e_v (Vec e_A e_n)))])
            (match* (ri rv)
              [(`(bu #t ,ui) `(bu #t ,uv)) (list 'tu ty (add-usage ui uv))]
              [(_ _) 'tu-error]))))]

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

        ;; ---- Vec / Fin constructors (QTT P5's usage rules) ----
        ;;
        ;; CHECK arms by necessity, not by preference: `infer` has no case for
        ;; any of the four, so without them the conversion fallback delegates
        ;; to `inferQ`, hits its `tu-error` fallback, and every annotated
        ;; Vec/Fin term fails as a multiplicity violation — a diagnostic naming
        ;; a subsystem that is working perfectly.
        ;;
        ;; The usage split follows the runtime/type-level split in each form,
        ;; and it is not guesswork: `whnf`'s computation rules DISCARD the type
        ;; and length fields and consume only head/tail, so the indices are
        ;; erased and contribute NO usage while head/tail contribute their own.

        ;; vnil(A) : Vec(A, zero) — A is type-level, so no usage at all.
        [(`(vnil ,_) `(Vec ,_ ,_)) (list 'bu #t (zero-usage n))]

        ;; vcons(A, k, head, tail) — head and tail each consumed ONCE.
        ;; add-usage, not a join: both are stored, so both happen. This is
        ;; sequential composition, not alternation, which is what makes a
        ;; linear value consed into a vector consumed exactly once.
        [(`(vcons ,a1 ,n1 ,hd ,tl) `(Vec ,_ ,_))
         (let ([r-hd (term (checkQ Gamma ,hd ,a1))]
               [r-tl (term (checkQ Gamma ,tl (Vec ,a1 ,n1)))])
           (match* (r-hd r-tl)
             [(`(bu #t ,u-hd) `(bu #t ,u-tl))
              (list 'bu #t (add-usage u-hd u-tl))]
             [(_ _) (list 'bu #f (zero-usage n))]))]

        ;; fzero(k) : Fin(suc k) — k is the type-level bound; nothing runs.
        [(`(fzero ,_) `(Fin ,_)) (list 'bu #t (zero-usage n))]

        ;; fsuc(k, i) : Fin(suc k) — `i` is the runtime predecessor, `k` the
        ;; bound. Mirrors the `suc` arm at the top, which counts its argument.
        [(`(fsuc ,n1 ,i) `(Fin ,_))
         (let ([r (term (checkQ Gamma ,i (Fin ,n1)))])
           (match r
             [`(bu #t ,u) (list 'bu #t u)]
             [_ (list 'bu #f (zero-usage n))]))]

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
