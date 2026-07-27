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

;; Walk struct fields, recursing into any container child, taking max.
;;
;; This is the total-by-construction fallback the Exhaustive Walkers rule
;; (.claude/rules/pipeline.md) asks for: a new expr-* node needs no arm here,
;; because every field is walked generically. That only holds if `value-range`
;; is total over the CONTAINER shapes fields actually use — an under-covered
;; container is a SILENT wrong answer (0 = "closed"), which makes `shift`
;; short-circuit to a no-op and leaves de Bruijn indices unrenumbered.
;;
;; That is not hypothetical: `range-of-list` used to walk only the CAR of each
;; pair and recur on the cdr as if it were always a list tail, so an
;; ASSOCIATION pair `(cons key <struct>)` dropped its value entirely. CIU T6's
;; `expr-Record` stores exactly that shape — `(list (cons 'a (record-field …)))`
;; — so a record holding a bvar reported range 0, `shift` no-op'd, and the bvar
;; came back unshifted (caught by test-record-node's "shift: recurses into a
;; bvar field type"). Keep this walker total; do not narrow it back to lists.
(define (generic-range e)
  (cond
    [(struct? e)
     (define vec (struct->vector e))
     (define n (vector-length vec))
     ;; Field 0 is the struct-tag; skip it.
     (let loop ([i 1] [r 0])
       (cond
         [(= i n) r]
         [else (loop (add1 i) (max r (value-range (vector-ref vec i))))]))]
    [else 0]))

;; Range of an arbitrary field VALUE. Structs go through the memo; containers
;; are walked in both directions. Anything else contributes 0.
(define (value-range v)
  (cond
    [(struct? v) (loose-bvar-range v)]
    ;; Both halves — proper list tails, improper tails, and assoc pairs alike.
    [(pair? v) (max (value-range (car v)) (value-range (cdr v)))]
    [(null? v) 0]
    [(vector? v)
     (for/fold ([r 0]) ([x (in-vector v)]) (max r (value-range x)))]
    [(hash? v)
     (for/fold ([r 0]) ([(k x) (in-hash v)])
       (max r (value-range k) (value-range x)))]
    [(box? v) (value-range (unbox v))]
    [else 0]))
