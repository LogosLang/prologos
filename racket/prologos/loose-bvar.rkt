#lang racket/base

;; loose-bvar.rkt — pitfall #31 fix (Lean 4-style looseBVarRange)
;;
;; Provides `loose-bvar-range : Expr -> Nat` returning (1 + max free bvar
;; index) for an expression, or 0 if the expression is closed.
;;
;; Used by `shift` in substitution.rkt to short-circuit:
;;   (define (shift delta cutoff e)
;;     (if (<= (loose-bvar-range e) cutoff)
;;         e            ; <-- no free bvars at or above cutoff; nothing to shift
;;         ...recursive walk...))
;;
;; Per-call: O(1) amortized via a weak-eq memo. First time we see an
;; expression, walk its structure once (children's ranges are already
;; memoized, so each level is O(1) given children).
;;
;; This is the option-#1 fix described in
;; docs/tracking/2026-05-04_SUBSTITUTION_PERF_SURVEY.md and
;; github.com/LogosLang/prologos/issues/58.
;;
;; Lean 4 implements the same idea by storing `looseBVarRange` as a field
;; on every `Expr` (computed at construction). We use a weak-memo to get
;; the same asymptotic behavior without touching all 327 expr-* struct
;; definitions in syntax.rkt.

(require racket/match
         "syntax.rkt")

(provide loose-bvar-range
         clear-loose-bvar-cache!)

;; Memo. Weak so dead expressions are GC'd. Eq?-keyed so we don't pay
;; the structural-hash cost on lookup.
(define range-memo (make-weak-hasheq))

;; Public entry: returns (1 + max free bvar in e), or 0 if e is closed.
(define (loose-bvar-range e)
  (cond
    [(hash-ref range-memo e #f) => values]
    [else
     (define r (compute-range e))
     (hash-set! range-memo e r)
     r]))

(define (clear-loose-bvar-cache!)
  (set! range-memo (make-weak-hasheq)))

;; Compute range for expressions we know to be binding forms.
;; Fall through to `generic-range` for everything else.
(define (compute-range e)
  (match e
    ;; Variables
    [(expr-bvar k) (add1 k)]
    [(expr-fvar _) 0]

    ;; Single-binder forms: body's bvar 0 is the local binding;
    ;; external free bvars from body are (range body) - 1, floored at 0.
    [(expr-lam _ t body)
     (max (loose-bvar-range t)
          (let ([rb (loose-bvar-range body)])
            (if (zero? rb) 0 (sub1 rb))))]
    [(expr-Pi _ dom cod)
     (max (loose-bvar-range dom)
          (let ([rc (loose-bvar-range cod)])
            (if (zero? rc) 0 (sub1 rc))))]
    [(expr-Sigma t1 t2)
     (max (loose-bvar-range t1)
          (let ([r2 (loose-bvar-range t2)])
            (if (zero? r2) 0 (sub1 r2))))]

    ;; Reduce arms: body has (binding-count) binders.
    [(expr-reduce-arm _ binding-count body)
     (let ([rb (loose-bvar-range body)])
       (max 0 (- rb binding-count)))]

    ;; Generic structural fallback for all other expr-* forms.
    [_ (generic-range e)]))

;; Walk struct fields, recursing on struct or list children, taking max.
(define (generic-range e)
  (cond
    [(struct? e)
     (define vec (struct->vector e))
     (define n (vector-length vec))
     ;; Field 0 is the struct-tag; skip it.
     (let loop ([i 1] [r 0])
       (cond
         [(= i n) r]
         [else
          (define f (vector-ref vec i))
          (define fr
            (cond
              [(struct? f) (loose-bvar-range f)]
              [(pair? f) (range-of-list f)]
              [else 0]))
          (loop (add1 i) (max r fr))]))]
    [else 0]))

(define (range-of-list lst)
  (cond
    [(null? lst) 0]
    [(pair? lst)
     (define hd (car lst))
     (define hd-r
       (cond [(struct? hd) (loose-bvar-range hd)]
             [(pair? hd) (range-of-list hd)]
             [else 0]))
     (max hd-r (range-of-list (cdr lst)))]
    [else 0]))
