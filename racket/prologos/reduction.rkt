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
         racket/list
         racket/string
         "prelude.rkt"
         "syntax.rkt"
         "substitution.rkt"
         "global-env.rkt"
         "posit-impl.rkt"
         "macros.rkt"
         "metavar-store.rkt"
         "foreign.rkt"
         "champ.rkt"
         "rrb.rkt"
         "propagator.rkt"
         "union-find.rkt"
         "atms.rkt"
         "tabling.rkt")

(provide whnf nf nf-whnf conv conv-nf
         current-nf-cache current-whnf-cache
         current-reduction-fuel current-nat-value-cache)

;; ========================================
;; Helpers for building Prologos List values in reduction
;; ========================================
;; List constructors (nil, cons) are inductive-type fvars registered by
;; `data List {A}` in prologos::data::list.  At the reduction level they
;; appear as (expr-fvar 'nil) and (expr-app (expr-app (expr-fvar 'cons) elem) rest).
;; These helpers convert Racket-level lists of AST exprs into Prologos Lists.

;; Convert a Racket list of AST expressions → Prologos List value
(define (racket-list->prologos-list elems)
  (foldr (lambda (e acc)
           (expr-app (expr-app (expr-fvar 'cons) e) acc))
         (expr-fvar 'nil)
         elems))

;; Convert a Racket list of (cons key val) pairs → Prologos List of (pair k v)
(define (racket-pairs->prologos-pair-list pairs)
  (racket-list->prologos-list
   (map (lambda (p)
          (expr-app (expr-app (expr-fvar 'pair) (car p)) (cdr p)))
        pairs)))

;; Helper: check if an fvar name matches 'nil or '...::nil (qualified)
(define (nil-name? name)
  (let ([s (symbol->string name)])
    (or (string=? s "nil")
        (let ([len (string-length s)])
          (and (>= len 5) (string=? (substring s (- len 5)) "::nil"))))))

;; Helper: check if an fvar name matches 'cons or '...::cons (qualified)
(define (cons-name? name)
  (let ([s (symbol->string name)])
    (or (string=? s "cons")
        (let ([len (string-length s)])
          (and (>= len 6) (string=? (substring s (- len 6)) "::cons"))))))

;; Convert a Prologos List value (nil/cons chain) → Racket list of AST exprs, or #f if stuck
(define (prologos-list->racket-list e)
  (let loop ([cur (whnf e)] [acc '()])
    (cond
      ;; nil — end of list
      [(and (expr-fvar? cur) (nil-name? (expr-fvar-name cur)))
       (reverse acc)]
      ;; (nil A) — nil applied to type argument
      [(and (expr-app? cur)
            (let ([f (expr-app-func cur)])
              (and (expr-fvar? f) (nil-name? (expr-fvar-name f)))))
       (reverse acc)]
      ;; (cons x xs) — two-arg constructor applied as ((cons x) xs)
      [(and (expr-app? cur)
            (expr-app? (expr-app-func cur))
            (let ([inner (expr-app-func (expr-app-func cur))])
              (or (and (expr-fvar? inner) (cons-name? (expr-fvar-name inner)))
                  ;; (cons A x xs) — cons applied to type arg first: (((cons A) x) xs)
                  (and (expr-app? inner)
                       (let ([innermost (expr-app-func inner)])
                         (and (expr-fvar? innermost) (cons-name? (expr-fvar-name innermost))))))))
       (let* ([xs (expr-app-arg cur)]
              ;; head is trickier: could be ((cons x) ...) or (((cons A) x) ...)
              [head-app (expr-app-func cur)]
              [head (if (and (expr-app? (expr-app-func head-app))
                             (let ([f (expr-app-func (expr-app-func head-app))])
                               (and (expr-fvar? f) (cons-name? (expr-fvar-name f)))))
                        ;; (((cons A) x) xs) — skip the type arg, head = x
                        (expr-app-arg head-app)
                        ;; ((cons x) xs) — head = x
                        (expr-app-arg head-app))])
         (loop (whnf xs) (cons head acc)))]
      [else #f])))

;; ========================================
;; Helper: Racket integer → Prologos Nat expression
;; ========================================

;; Convert a non-negative Racket integer to an expr-suc/expr-zero chain.
(define (racket-nat->expr n)
  (let loop ([k n])
    (if (zero? k)
        (expr-zero)
        (expr-suc (loop (sub1 k))))))

;; ========================================
;; Helpers for ATMS list ↔ assumption-id set conversion
;; ========================================

;; Convert a Prologos List of expr-assumption-id-val → hasheq (assumption-id → #t)
;; Returns #f if the list can't be fully unwrapped (stuck or wrong types).
(define (prologos-list->assumption-set e)
  (define elems (prologos-list->racket-list e))
  (and elems
       (let loop ([es elems] [acc (hasheq)])
         (cond
           [(null? es) acc]
           [else
            (let ([e* (whnf (car es))])
              (if (expr-assumption-id-val? e*)
                  (loop (cdr es)
                        (hash-set acc (expr-assumption-id-val-aid-value e*) #t))
                  #f))]))))

;; Convert a hasheq (assumption-id → #t) → Prologos List of expr-assumption-id-val
(define (assumption-set->prologos-list aset)
  (racket-list->prologos-list
   (for/list ([(aid _) (in-hash aset)])
     (expr-assumption-id-val aid))))

;; ========================================
;; Helpers for Posit8 reduction
;; ========================================

;; Extract a Racket natural number from an expr-zero/expr-suc chain, or #f if not a numeral.
;; Per-command memoization avoids O(N^2) re-traversal during coercion.
(define current-nat-value-cache (make-parameter #f))

(define (nat-value e)
  (define cache (current-nat-value-cache))
  (cond
    [(and cache (hash-ref cache e #f)) => values]
    [else
     (define result
       (match e
         [(expr-zero) 0]
         [(expr-suc e1) (let ([v (nat-value e1)]) (and v (+ v 1)))]
         [_ #f]))
     (when (and cache result)
       (hash-set! cache e result))
     result]))

;; ========================================
;; Phase 3e: Subtype coercion helpers for stuck-term reduction
;; ========================================
;; When an operation (e.g., int-add) has operands in WHNF but of a narrower
;; type (e.g., expr-suc/expr-zero instead of expr-int), these helpers coerce
;; to the target type. Returns the coerced value, or #f if not coercible.

;; Try to coerce a WHNF value to Int. Nat → Int.
(define (try-coerce-to-int e)
  (let ([k (nat-value e)])
    (and k (expr-int k))))

;; Try to coerce a WHNF value to Rat. Nat → Rat, Int → Rat.
(define (try-coerce-to-rat e)
  (cond
    [(expr-int? e) (expr-rat (expr-int-val e))]
    [else (let ([k (nat-value e)])
            (and k (expr-rat k)))]))

;; Try to coerce a WHNF posit value to a wider width. Returns wider posit or #f.
(define (try-coerce-to-posit target-width e)
  (cond
    [(and (expr-posit8? e) (> target-width 8))
     (case target-width
       [(16) (expr-posit16 (posit-widen 8 16 (expr-posit8-val e)))]
       [(32) (expr-posit32 (posit-widen 8 32 (expr-posit8-val e)))]
       [(64) (expr-posit64 (posit-widen 8 64 (expr-posit8-val e)))]
       [else #f])]
    [(and (expr-posit16? e) (> target-width 16))
     (case target-width
       [(32) (expr-posit32 (posit-widen 16 32 (expr-posit16-val e)))]
       [(64) (expr-posit64 (posit-widen 16 64 (expr-posit16-val e)))]
       [else #f])]
    [(and (expr-posit32? e) (> target-width 32))
     (case target-width
       [(64) (expr-posit64 (posit-widen 32 64 (expr-posit32-val e)))]
       [else #f])]
    [else #f]))

;; ========================================
;; Stuck-term reduction helpers
;; ========================================
;; Phase 3e: Each helper now attempts subtype coercion before declaring stuck.
;; If coercion changes an operand, rebuild the expression and retry whnf.

;; Reduce a binary Int operation: Nat operands coerce to Int.
(define (reduce-int-binary ctor a b)
  (let* ([a* (whnf a)]
         [b* (whnf b)])
    (let ([ca (or (try-coerce-to-int a*) a*)]
          [cb (or (try-coerce-to-int b*) b*)])
      (cond
        ;; Coercion changed something → retry with coerced operands
        [(or (not (eq? ca a*)) (not (eq? cb b*)))
         (whnf (ctor ca cb))]
        ;; Standard: one operand reduced → retry
        [(not (equal? a* a)) (whnf (ctor a* b))]
        [(not (equal? b* b)) (whnf (ctor a b*))]
        ;; Stuck
        [else (ctor a b)]))))

;; Reduce a unary Int operation: Nat operand coerces to Int.
(define (reduce-int-unary ctor a)
  (let* ([a* (whnf a)]
         [ca (or (try-coerce-to-int a*) a*)])
    (cond
      [(not (eq? ca a*)) (whnf (ctor ca))]
      [(not (equal? a* a)) (whnf (ctor a*))]
      [else (ctor a)])))

;; Reduce a binary Rat operation: Nat/Int operands coerce to Rat.
(define (reduce-rat-binary ctor a b)
  (let* ([a* (whnf a)]
         [b* (whnf b)])
    (let ([ca (or (try-coerce-to-rat a*) a*)]
          [cb (or (try-coerce-to-rat b*) b*)])
      (cond
        [(or (not (eq? ca a*)) (not (eq? cb b*)))
         (whnf (ctor ca cb))]
        [(not (equal? a* a)) (whnf (ctor a* b))]
        [(not (equal? b* b)) (whnf (ctor a b*))]
        [else (ctor a b)]))))

;; Reduce a unary Rat operation: Nat/Int operand coerces to Rat.
(define (reduce-rat-unary ctor a)
  (let* ([a* (whnf a)]
         [ca (or (try-coerce-to-rat a*) a*)])
    (cond
      [(not (eq? ca a*)) (whnf (ctor ca))]
      [(not (equal? a* a)) (whnf (ctor a*))]
      [else (ctor a)])))

;; Unified posit binary reducer. target-width: 8, 16, 32, or 64.
;; Posit8 has no narrower type; Posit16/32/64 coerce from narrower widths.
(define (reduce-posit-binary target-width ctor a b)
  (let* ([a* (whnf a)]
         [b* (whnf b)])
    (if (= target-width 8)
        ;; Posit8: no coercion possible
        (cond
          [(not (equal? a* a)) (whnf (ctor a* b))]
          [(not (equal? b* b)) (whnf (ctor a b*))]
          [else (ctor a b)])
        ;; Posit16/32/64: try coercion from narrower widths
        (let ([ca (or (try-coerce-to-posit target-width a*) a*)]
              [cb (or (try-coerce-to-posit target-width b*) b*)])
          (cond
            [(or (not (eq? ca a*)) (not (eq? cb b*)))
             (whnf (ctor ca cb))]
            [(not (equal? a* a)) (whnf (ctor a* b))]
            [(not (equal? b* b)) (whnf (ctor a b*))]
            [else (ctor a b)])))))

;; Unified posit unary reducer.
(define (reduce-posit-unary target-width ctor a)
  (let ([a* (whnf a)])
    (if (= target-width 8)
        (if (equal? a* a) (ctor a) (whnf (ctor a*)))
        (let ([ca (or (try-coerce-to-posit target-width a*) a*)])
          (cond
            [(not (eq? ca a*)) (whnf (ctor ca))]
            [(not (equal? a* a)) (whnf (ctor a*))]
            [else (ctor a)])))))

;; Extract the Racket-level exact rational value from a concrete numeric literal.
;; Returns #f for non-literal/non-numeric expressions.
(define (literal->rational e)
  (cond
    [(expr-int? e) (expr-int-val e)]
    [(expr-rat? e) (expr-rat-val e)]
    [(expr-posit8? e) (posit8-decode (expr-posit8-val e))]
    [(expr-posit16? e) (posit16-decode (expr-posit16-val e))]
    [(expr-posit32? e) (posit32-decode (expr-posit32-val e))]
    [(expr-posit64? e) (posit64-decode (expr-posit64-val e))]
    [else
     (let ([nv (nat-value e)])
       (and nv nv))]))

;; Classify a concrete numeric literal: 'nat, 'int, 'rat, 'p8, 'p16, 'p32, 'p64, or #f
(define (literal-type-tag e)
  (cond
    [(nat-value e) 'nat]
    [(expr-int? e) 'int]
    [(expr-rat? e) 'rat]
    [(expr-posit8? e) 'p8]
    [(expr-posit16? e) 'p16]
    [(expr-posit32? e) 'p32]
    [(expr-posit64? e) 'p64]
    [else #f]))

;; Coerce a Racket rational value to a target type tag, returning an AST literal.
(define (rational->literal val tag)
  (case tag
    [(nat) (nat->expr (max 0 (inexact->exact (floor val))))]
    [(int) (expr-int (inexact->exact (floor val)))]
    [(rat) (expr-rat val)]
    [(p8)  (expr-posit8 (posit8-encode val))]
    [(p16) (expr-posit16 (posit16-encode val))]
    [(p32) (expr-posit32 (posit32-encode val))]
    [(p64) (expr-posit64 (posit64-encode val))]
    [else #f]))

;; Type-tag ranking for numeric-join at reduction level.
;; Exact: nat(0) < int(1) < rat(2). Posit: p8(10) < p16(11) < p32(12) < p64(13).
(define (type-tag-rank tag)
  (case tag
    [(nat) 0] [(int) 1] [(rat) 2]
    [(p8) 10] [(p16) 11] [(p32) 12] [(p64) 13]
    [else -1]))

;; Compute the join type tag for two type tags.
(define (type-tag-join t1 t2)
  (cond
    [(eq? t1 t2) t1]
    ;; Both exact
    [(and (memq t1 '(nat int rat)) (memq t2 '(nat int rat)))
     (if (> (type-tag-rank t1) (type-tag-rank t2)) t1 t2)]
    ;; Both posit
    [(and (memq t1 '(p8 p16 p32 p64)) (memq t2 '(p8 p16 p32 p64)))
     (if (> (type-tag-rank t1) (type-tag-rank t2)) t1 t2)]
    ;; Cross-family: posit dominates, minimum p32
    [(and (memq t1 '(nat int rat)) (memq t2 '(p8 p16 p32 p64)))
     (if (>= (type-tag-rank t2) (type-tag-rank 'p32)) t2 'p32)]
    [(and (memq t1 '(p8 p16 p32 p64)) (memq t2 '(nat int rat)))
     (if (>= (type-tag-rank t1) (type-tag-rank 'p32)) t1 'p32)]
    [else #f]))

;; Reduce a generic binary operation: reduce both operands, retry.
;; Handles Nat operands and cross-type coercion via numeric-join.
(define (reduce-generic-binary ctor a b)
  (let ([a* (whnf a)]
        [b* (whnf b)])
    ;; Classify both operands
    (define ta (literal-type-tag a*))
    (define tb (literal-type-tag b*))
    (cond
      ;; Both are concrete numeric literals
      [(and ta tb)
       (let ([join (type-tag-join ta tb)])
         (cond
           [(not join) (ctor a* b*)]  ;; shouldn't happen (type error caught earlier)
           ;; Same type — compute directly
           [(eq? ta tb)
            (cond
              ;; Nat — delegate to nat-specific dispatch
              [(eq? ta 'nat)
               (let ([na (nat-value a*)] [nb (nat-value b*)])
                 (cond
                   [(eq? ctor expr-generic-add) (nat->expr (+ na nb))]
                   [(eq? ctor expr-generic-sub) (nat->expr (max 0 (- na nb)))]
                   [(eq? ctor expr-generic-mul) (nat->expr (* na nb))]
                   [(eq? ctor expr-generic-lt)  (if (< na nb) (expr-true) (expr-false))]
                   [(eq? ctor expr-generic-le)  (if (<= na nb) (expr-true) (expr-false))]
                   [(eq? ctor expr-generic-eq)  (if (= na nb) (expr-true) (expr-false))]
                   [else (ctor a* b*)]))]
              ;; Non-Nat same type: the same-type iota rules in whnf will handle it.
              ;; Retry via whnf so the pattern-match iota rules fire.
              [else (whnf (ctor a* b*))])]
           ;; Different types — coerce both to join type, retry
           [else
            (let ([ca (rational->literal (literal->rational a*) join)]
                  [cb (rational->literal (literal->rational b*) join)])
              (if (and ca cb)
                  (whnf (ctor ca cb))
                  (ctor a* b*)))]))]
      ;; One operand reduced → retry
      [(not (equal? a* a)) (whnf (ctor a* b))]
      [(not (equal? b* b)) (whnf (ctor a b*))]
      ;; Stuck
      [else (ctor a b)])))

;; Reduce a generic unary operation: reduce operand, retry.
;; Also handles Nat operands for abs (identity).
(define (reduce-generic-unary ctor a)
  (let ([a* (whnf a)])
    ;; Try Nat: operand is Nat numeral?
    (define na (nat-value a*))
    (cond
      [(and na (eq? ctor expr-generic-abs))
       ;; abs on Nat is identity
       a*]
      [(not (equal? a* a)) (whnf (ctor a*))]
      [else (ctor a)])))

;; ========================================
;; Structural pattern matching for reduce
;; ========================================
;; Decompose an expression into (head-fvar arg1 arg2 ...) if possible.
;; Returns (values fvar-name args-list) or (values #f #f).
(define (decompose-app e)
  (let loop ([expr e] [args '()])
    (match expr
      [(expr-app f a) (loop f (cons a args))]
      [(expr-fvar name) (values name args)]
      [_ (values #f #f)])))

;; Try structural reduce: if scrutinee is a constructor application,
;; match the arm and substitute field values into the body.
;; Returns the substituted body expression, or #f if not a constructor.
(define (try-structural-reduce scrut arms)
  (define-values (head-name all-args) (decompose-app scrut))
  (and head-name
       (let ([meta (or (lookup-ctor head-name)
                       (lookup-ctor (ctor-short-name head-name)))])
         (and meta
              (let* ([n-type-params (length (ctor-meta-params meta))]
                     [short-name (ctor-short-name head-name)]
                     ;; Find matching arm
                     [matching-arm
                      (findf (lambda (arm)
                               (eq? (expr-reduce-arm-ctor-name arm) short-name))
                             arms)])
                (and matching-arm
                     (let* ([bc (expr-reduce-arm-binding-count matching-arm)]
                            [body (expr-reduce-arm-body matching-arm)]
                            ;; Compute field-values: handle both WITH and WITHOUT type args.
                            ;; racket-list->prologos-list creates cons/nil chains without
                            ;; type args. When (length all-args) == bc, type args are absent;
                            ;; when (length all-args) == bc + n-type-params, they're present.
                            [n-args (length all-args)]
                            [field-values
                             (cond
                               [(= n-args (+ bc n-type-params))
                                ;; Full args: skip type params
                                (drop all-args n-type-params)]
                               [(= n-args bc)
                                ;; No type args present (e.g., from racket-list->prologos-list)
                                all-args]
                               [else #f])])
                       (and field-values
                            ;; Substitute field values for bindings.
                            ;; bindings: bvar(0) = last field, bvar(1) = second-to-last, etc.
                            ;; We substitute bvar(0) first with last field, which decrements
                            ;; higher indices, then repeat for the next.
                            (for/fold ([result body])
                                      ([fv (in-list (reverse field-values))])
                              (subst 0 fv result))))))))))

;; Extract the short (bare) name from a potentially FQN symbol.
;; 'prologos::data::list::cons → 'cons, 'cons → 'cons
(define (ctor-short-name fqn)
  (define parts (string-split (symbol->string fqn) "::"))
  (string->symbol (last parts)))

;; Try built-in structural reduce for Nat/Bool constructors.
;; These are primitive expr nodes (not fvar applications), so decompose-app
;; can't handle them. Returns substituted body expression, or #f.
(define (try-builtin-reduce scrut arms)
  (cond
    ;; Nat: zero (nullary)
    [(expr-zero? scrut)
     (let ([arm (findf (lambda (a) (eq? (expr-reduce-arm-ctor-name a) 'zero)) arms)])
       (and arm (= (expr-reduce-arm-binding-count arm) 0)
            (expr-reduce-arm-body arm)))]
    ;; Nat: suc/suc (one field: the predecessor)
    [(expr-suc? scrut)
     (let ([arm (findf (lambda (a) (eq? (expr-reduce-arm-ctor-name a) 'suc)) arms)])
       (and arm (= (expr-reduce-arm-binding-count arm) 1)
            (subst 0 (expr-suc-pred scrut) (expr-reduce-arm-body arm))))]
    ;; Bool: true (nullary)
    [(expr-true? scrut)
     (let ([arm (findf (lambda (a) (eq? (expr-reduce-arm-ctor-name a) 'true)) arms)])
       (and arm (= (expr-reduce-arm-binding-count arm) 0)
            (expr-reduce-arm-body arm)))]
    ;; Bool: false (nullary)
    [(expr-false? scrut)
     (let ([arm (findf (lambda (a) (eq? (expr-reduce-arm-ctor-name a) 'false)) arms)])
       (and arm (= (expr-reduce-arm-binding-count arm) 0)
            (expr-reduce-arm-body arm)))]
    ;; Unit: unit (nullary)
    [(expr-unit? scrut)
     (let ([arm (findf (lambda (a) (eq? (expr-reduce-arm-ctor-name a) 'unit)) arms)])
       (and arm (= (expr-reduce-arm-binding-count arm) 0)
            (expr-reduce-arm-body arm)))]
    [else #f]))


;; ========================================
;; Value classification for map-get graceful degradation
;; ========================================
;; A value is "definitely not a map" if it cannot possibly be a CHAMP map
;; at runtime. Used by map-get to return none instead of a stuck term
;; when applied to non-map values from union-typed expressions.
(define (definitely-not-map? e)
  (not (or (expr-champ? e)          ;; IS a map runtime value
           (expr-fvar? e)           ;; could resolve to a map
           (expr-bvar? e)           ;; bound variable, unknown
           (expr-meta? e)           ;; unsolved meta, unknown
           (expr-app? e)            ;; application, could produce a map
           (expr-hole? e)           ;; hole, unknown
           (expr-typed-hole? e)    ;; typed hole, unknown
           (expr-map-empty? e)      ;; map constructor
           (expr-map-assoc? e)      ;; map operation
           (expr-map-get? e)        ;; nested map-get
           (expr-map-dissoc? e)     ;; map operation
           (expr-error? e))))       ;; error propagation

;; ========================================
;; Weak Head Normal Form
;; Per-command memoization: when current-whnf-cache is active,
;; cache whnf results keyed by expr.
;; ========================================
(define current-whnf-cache (make-parameter #f))
;; Fuel: #f = unlimited, or a box containing remaining step count.
;; Use (box N) to set a limit; whnf-impl decrements on each call.
(define current-reduction-fuel (make-parameter #f))

(define (whnf e)
  (define cache (current-whnf-cache))
  (cond
    [(and cache (hash-ref cache e #f))
     => values]
    [else
     (define result (whnf-impl e))
     (when cache
       (hash-set! cache e result))
     result]))

(define (whnf-impl e)
  ;; Check fuel
  (let ([fuel (current-reduction-fuel)])
    (when fuel
      (when (<= (unbox fuel) 0)
        (error 'reduction "fuel exhausted after too many reduction steps"))
      (set-box! fuel (sub1 (unbox fuel)))))
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

    ;; Bool elimination (iota rules)
    ;; boolrec(M, t, f, true)  -> t
    ;; boolrec(M, t, f, false) -> f
    [(expr-boolrec _ tc _ (expr-true)) (whnf tc)]
    [(expr-boolrec _ _ fc (expr-false)) (whnf fc)]

    ;; Annotation erasure
    [(expr-ann e1 _) (whnf e1)]

    ;; Vec eliminators: vhead/vtail on vcons
    [(expr-vhead _ _ (expr-vcons _ _ hd _)) (whnf hd)]
    [(expr-vtail _ _ (expr-vcons _ _ _ tl)) (whnf tl)]

    ;; Foreign function application: accumulate args, call when arity reached
    [(expr-app (expr-foreign-fn name proc arity args marshal-in marshal-out) arg)
     (let* ([arg* (whnf arg)]
            [new-args (append args (list arg*))])
       (if (= (length new-args) arity)
           ;; All args collected — fully normalize for marshalling, then call Racket
           (let* ([nf-args (map nf new-args)]
                  [rkt-args (map (lambda (m a) (m a)) marshal-in nf-args)]
                  [rkt-result (apply proc rkt-args)]
                  [prologos-result (marshal-out rkt-result)])
             (whnf prologos-result))
           ;; Partial application — return updated foreign-fn
           (expr-foreign-fn name proc arity new-args marshal-in marshal-out)))]

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

    ;; boolrec with non-canonical target: reduce target first
    [(expr-boolrec mot tc fc target)
     (let ([target* (whnf target)])
       (if (equal? target* target)
           e  ; stuck — target is neutral
           (whnf (expr-boolrec mot tc fc target*))))]

    ;; vhead/vtail with non-vcons: reduce vec first
    [(expr-vhead t n v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-vhead t n v*))))]
    [(expr-vtail t n v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-vtail t n v*))))]

    ;; ---- Int iota rules: compute when arguments are int literals ----

    ;; Binary arithmetic on literals
    [(expr-int-add (expr-int a) (expr-int b)) (expr-int (+ a b))]
    [(expr-int-sub (expr-int a) (expr-int b)) (expr-int (- a b))]
    [(expr-int-mul (expr-int a) (expr-int b)) (expr-int (* a b))]
    [(expr-int-div (expr-int a) (expr-int b))
     (if (zero? b) e (expr-int (quotient a b)))]
    [(expr-int-mod (expr-int a) (expr-int b))
     (if (zero? b) e (expr-int (remainder a b)))]

    ;; Unary ops on literals
    [(expr-int-neg (expr-int a)) (expr-int (- a))]
    [(expr-int-abs (expr-int a)) (expr-int (abs a))]

    ;; Comparison on literals → Bool
    [(expr-int-lt (expr-int a) (expr-int b))
     (if (< a b) (expr-true) (expr-false))]
    [(expr-int-le (expr-int a) (expr-int b))
     (if (<= a b) (expr-true) (expr-false))]
    [(expr-int-eq (expr-int a) (expr-int b))
     (if (= a b) (expr-true) (expr-false))]

    ;; from-nat: compute when arg is a Nat numeral
    [(expr-from-nat n)
     (let ([n* (whnf n)])
       (let ([k (nat-value n*)])
         (cond
           [k (expr-int k)]
           [(equal? n* n) e]    ; stuck
           [else (whnf (expr-from-nat n*))])))]

    ;; ---- Int stuck-term reduction ----

    ;; Binary ops: reduce operands
    [(expr-int-add a b) (reduce-int-binary expr-int-add a b)]
    [(expr-int-sub a b) (reduce-int-binary expr-int-sub a b)]
    [(expr-int-mul a b) (reduce-int-binary expr-int-mul a b)]
    [(expr-int-div a b) (reduce-int-binary expr-int-div a b)]
    [(expr-int-mod a b) (reduce-int-binary expr-int-mod a b)]
    [(expr-int-lt a b) (reduce-int-binary expr-int-lt a b)]
    [(expr-int-le a b) (reduce-int-binary expr-int-le a b)]
    [(expr-int-eq a b) (reduce-int-binary expr-int-eq a b)]

    ;; Unary ops: reduce operand
    [(expr-int-neg a) (reduce-int-unary expr-int-neg a)]
    [(expr-int-abs a) (reduce-int-unary expr-int-abs a)]

    ;; ---- Rat iota rules: compute when arguments are rat literals ----

    ;; Binary arithmetic on literals
    [(expr-rat-add (expr-rat a) (expr-rat b)) (expr-rat (+ a b))]
    [(expr-rat-sub (expr-rat a) (expr-rat b)) (expr-rat (- a b))]
    [(expr-rat-mul (expr-rat a) (expr-rat b)) (expr-rat (* a b))]
    [(expr-rat-div (expr-rat a) (expr-rat b))
     (if (zero? b) e (expr-rat (/ a b)))]

    ;; Unary ops on literals
    [(expr-rat-neg (expr-rat a)) (expr-rat (- a))]
    [(expr-rat-abs (expr-rat a)) (expr-rat (abs a))]

    ;; Comparison on literals → Bool
    [(expr-rat-lt (expr-rat a) (expr-rat b))
     (if (< a b) (expr-true) (expr-false))]
    [(expr-rat-le (expr-rat a) (expr-rat b))
     (if (<= a b) (expr-true) (expr-false))]
    [(expr-rat-eq (expr-rat a) (expr-rat b))
     (if (= a b) (expr-true) (expr-false))]

    ;; from-int: compute when arg is an int literal
    [(expr-from-int n)
     (let ([n* (whnf n)])
       (cond
         [(expr-int? n*) (expr-rat (expr-int-val n*))]
         [(equal? n* n) e]    ; stuck
         [else (whnf (expr-from-int n*))]))]

    ;; rat-numer: extract numerator when arg is a rat literal
    [(expr-rat-numer (expr-rat v)) (expr-int (numerator v))]

    ;; rat-denom: extract denominator when arg is a rat literal
    [(expr-rat-denom (expr-rat v)) (expr-int (denominator v))]

    ;; ---- Rat stuck-term reduction ----

    ;; Binary ops: reduce operands
    [(expr-rat-add a b) (reduce-rat-binary expr-rat-add a b)]
    [(expr-rat-sub a b) (reduce-rat-binary expr-rat-sub a b)]
    [(expr-rat-mul a b) (reduce-rat-binary expr-rat-mul a b)]
    [(expr-rat-div a b) (reduce-rat-binary expr-rat-div a b)]
    [(expr-rat-lt a b) (reduce-rat-binary expr-rat-lt a b)]
    [(expr-rat-le a b) (reduce-rat-binary expr-rat-le a b)]
    [(expr-rat-eq a b) (reduce-rat-binary expr-rat-eq a b)]

    ;; Unary ops: reduce operand
    [(expr-rat-neg a) (reduce-rat-unary expr-rat-neg a)]
    [(expr-rat-abs a) (reduce-rat-unary expr-rat-abs a)]
    [(expr-rat-numer a) (reduce-rat-unary expr-rat-numer a)]
    [(expr-rat-denom a) (reduce-rat-unary expr-rat-denom a)]

    ;; ---- Posit8 iota rules: compute when arguments are posit8 literals ----

    ;; Binary arithmetic on literals
    [(expr-p8-add (expr-posit8 a) (expr-posit8 b)) (expr-posit8 (posit8-add a b))]
    [(expr-p8-sub (expr-posit8 a) (expr-posit8 b)) (expr-posit8 (posit8-sub a b))]
    [(expr-p8-mul (expr-posit8 a) (expr-posit8 b)) (expr-posit8 (posit8-mul a b))]
    [(expr-p8-div (expr-posit8 a) (expr-posit8 b)) (expr-posit8 (posit8-div a b))]

    ;; Unary ops on literals
    [(expr-p8-neg (expr-posit8 a)) (expr-posit8 (posit8-neg a))]
    [(expr-p8-abs (expr-posit8 a)) (expr-posit8 (posit8-abs a))]
    [(expr-p8-sqrt (expr-posit8 a)) (expr-posit8 (posit8-sqrt a))]

    ;; Comparison on literals → Bool
    [(expr-p8-lt (expr-posit8 a) (expr-posit8 b))
     (if (posit8-lt? a b) (expr-true) (expr-false))]
    [(expr-p8-le (expr-posit8 a) (expr-posit8 b))
     (if (posit8-le? a b) (expr-true) (expr-false))]
    [(expr-p8-eq (expr-posit8 a) (expr-posit8 b))
     (if (posit8-eq? a b) (expr-true) (expr-false))]

    ;; from-nat: compute when arg is a Nat numeral
    [(expr-p8-from-nat n)
     (let ([n* (whnf n)])
       (let ([k (nat-value n*)])
         (cond
           [k (expr-posit8 (posit8-from-nat k))]
           [(equal? n* n) e]    ; stuck
           [else (whnf (expr-p8-from-nat n*))])))]

    ;; Phase 3f: p8-to-rat -- Posit8 -> Rat
    [(expr-p8-to-rat (expr-posit8 v))
     (let ([r (posit8-to-rational v)])
       (if (eq? r 'nar) (expr-error) (expr-rat r)))]
    [(expr-p8-to-rat a) (reduce-posit-unary 8 expr-p8-to-rat a)]

    ;; Phase 3f: p8-from-rat -- Rat -> Posit8
    [(expr-p8-from-rat (expr-rat v))
     (expr-posit8 (posit8-encode v))]
    [(expr-p8-from-rat a) (reduce-rat-unary expr-p8-from-rat a)]

    ;; Phase 3f: p8-from-int -- Int -> Posit8
    [(expr-p8-from-int (expr-int v))
     (expr-posit8 (posit8-encode v))]
    [(expr-p8-from-int a) (reduce-int-unary expr-p8-from-int a)]

    ;; p8-if-nar: branch when val is a literal
    [(expr-p8-if-nar _ nc _ (expr-posit8 128)) (whnf nc)]    ; NaR = 0x80 = 128
    [(expr-p8-if-nar _ _ vc (expr-posit8 _)) (whnf vc)]      ; any non-NaR literal

    ;; ---- Posit8 stuck-term reduction ----

    ;; Binary ops: reduce operands
    [(expr-p8-add a b) (reduce-posit-binary 8 expr-p8-add a b)]
    [(expr-p8-sub a b) (reduce-posit-binary 8 expr-p8-sub a b)]
    [(expr-p8-mul a b) (reduce-posit-binary 8 expr-p8-mul a b)]
    [(expr-p8-div a b) (reduce-posit-binary 8 expr-p8-div a b)]
    [(expr-p8-lt a b) (reduce-posit-binary 8 expr-p8-lt a b)]
    [(expr-p8-le a b) (reduce-posit-binary 8 expr-p8-le a b)]
    [(expr-p8-eq a b) (reduce-posit-binary 8 expr-p8-eq a b)]

    ;; Unary ops: reduce operand
    [(expr-p8-neg a) (reduce-posit-unary 8 expr-p8-neg a)]
    [(expr-p8-abs a) (reduce-posit-unary 8 expr-p8-abs a)]
    [(expr-p8-sqrt a) (reduce-posit-unary 8 expr-p8-sqrt a)]

    ;; p8-if-nar: reduce the value argument
    [(expr-p8-if-nar t nc vc v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-p8-if-nar t nc vc v*))))]

    ;; ---- Posit16 iota rules: compute when arguments are posit16 literals ----

    ;; Binary arithmetic on literals
    [(expr-p16-add (expr-posit16 a) (expr-posit16 b)) (expr-posit16 (posit16-add a b))]
    [(expr-p16-sub (expr-posit16 a) (expr-posit16 b)) (expr-posit16 (posit16-sub a b))]
    [(expr-p16-mul (expr-posit16 a) (expr-posit16 b)) (expr-posit16 (posit16-mul a b))]
    [(expr-p16-div (expr-posit16 a) (expr-posit16 b)) (expr-posit16 (posit16-div a b))]

    ;; Unary ops on literals
    [(expr-p16-neg (expr-posit16 a)) (expr-posit16 (posit16-neg a))]
    [(expr-p16-abs (expr-posit16 a)) (expr-posit16 (posit16-abs a))]
    [(expr-p16-sqrt (expr-posit16 a)) (expr-posit16 (posit16-sqrt a))]

    ;; Comparison on literals → Bool
    [(expr-p16-lt (expr-posit16 a) (expr-posit16 b))
     (if (posit16-lt? a b) (expr-true) (expr-false))]
    [(expr-p16-le (expr-posit16 a) (expr-posit16 b))
     (if (posit16-le? a b) (expr-true) (expr-false))]
    [(expr-p16-eq (expr-posit16 a) (expr-posit16 b))
     (if (posit16-eq? a b) (expr-true) (expr-false))]

    ;; from-nat: compute when arg is a Nat numeral
    [(expr-p16-from-nat n)
     (let ([n* (whnf n)])
       (let ([k (nat-value n*)])
         (cond
           [k (expr-posit16 (posit16-from-nat k))]
           [(equal? n* n) e]    ; stuck
           [else (whnf (expr-p16-from-nat n*))])))]

    ;; Phase 3f: p16-to-rat -- Posit16 -> Rat
    [(expr-p16-to-rat (expr-posit16 v))
     (let ([r (posit16-to-rational v)])
       (if (eq? r 'nar) (expr-error) (expr-rat r)))]
    [(expr-p16-to-rat a) (reduce-posit-unary 16 expr-p16-to-rat a)]

    ;; Phase 3f: p16-from-rat -- Rat -> Posit16
    [(expr-p16-from-rat (expr-rat v))
     (expr-posit16 (posit16-encode v))]
    [(expr-p16-from-rat a) (reduce-rat-unary expr-p16-from-rat a)]

    ;; Phase 3f: p16-from-int -- Int -> Posit16
    [(expr-p16-from-int (expr-int v))
     (expr-posit16 (posit16-encode v))]
    [(expr-p16-from-int a) (reduce-int-unary expr-p16-from-int a)]

    ;; p16-if-nar: branch when val is a literal
    [(expr-p16-if-nar _ nc _ (expr-posit16 32768)) (whnf nc)]    ; NaR = 0x8000 = 32768
    [(expr-p16-if-nar _ _ vc (expr-posit16 _)) (whnf vc)]        ; any non-NaR literal

    ;; ---- Posit16 stuck-term reduction ----

    ;; Binary ops: reduce operands
    [(expr-p16-add a b) (reduce-posit-binary 16 expr-p16-add a b)]
    [(expr-p16-sub a b) (reduce-posit-binary 16 expr-p16-sub a b)]
    [(expr-p16-mul a b) (reduce-posit-binary 16 expr-p16-mul a b)]
    [(expr-p16-div a b) (reduce-posit-binary 16 expr-p16-div a b)]
    [(expr-p16-lt a b) (reduce-posit-binary 16 expr-p16-lt a b)]
    [(expr-p16-le a b) (reduce-posit-binary 16 expr-p16-le a b)]
    [(expr-p16-eq a b) (reduce-posit-binary 16 expr-p16-eq a b)]

    ;; Unary ops: reduce operand
    [(expr-p16-neg a) (reduce-posit-unary 16 expr-p16-neg a)]
    [(expr-p16-abs a) (reduce-posit-unary 16 expr-p16-abs a)]
    [(expr-p16-sqrt a) (reduce-posit-unary 16 expr-p16-sqrt a)]

    ;; p16-if-nar: reduce the value argument
    [(expr-p16-if-nar t nc vc v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-p16-if-nar t nc vc v*))))]

    ;; ---- Posit32 iota rules: compute when arguments are posit32 literals ----

    ;; Binary arithmetic on literals
    [(expr-p32-add (expr-posit32 a) (expr-posit32 b)) (expr-posit32 (posit32-add a b))]
    [(expr-p32-sub (expr-posit32 a) (expr-posit32 b)) (expr-posit32 (posit32-sub a b))]
    [(expr-p32-mul (expr-posit32 a) (expr-posit32 b)) (expr-posit32 (posit32-mul a b))]
    [(expr-p32-div (expr-posit32 a) (expr-posit32 b)) (expr-posit32 (posit32-div a b))]

    ;; Unary ops on literals
    [(expr-p32-neg (expr-posit32 a)) (expr-posit32 (posit32-neg a))]
    [(expr-p32-abs (expr-posit32 a)) (expr-posit32 (posit32-abs a))]
    [(expr-p32-sqrt (expr-posit32 a)) (expr-posit32 (posit32-sqrt a))]

    ;; Comparison on literals → Bool
    [(expr-p32-lt (expr-posit32 a) (expr-posit32 b))
     (if (posit32-lt? a b) (expr-true) (expr-false))]
    [(expr-p32-le (expr-posit32 a) (expr-posit32 b))
     (if (posit32-le? a b) (expr-true) (expr-false))]
    [(expr-p32-eq (expr-posit32 a) (expr-posit32 b))
     (if (posit32-eq? a b) (expr-true) (expr-false))]

    ;; from-nat: compute when arg is a Nat numeral
    [(expr-p32-from-nat n)
     (let ([n* (whnf n)])
       (let ([k (nat-value n*)])
         (cond
           [k (expr-posit32 (posit32-from-nat k))]
           [(equal? n* n) e]    ; stuck
           [else (whnf (expr-p32-from-nat n*))])))]

    ;; Phase 3f: p32-to-rat -- Posit32 -> Rat
    [(expr-p32-to-rat (expr-posit32 v))
     (let ([r (posit32-to-rational v)])
       (if (eq? r 'nar) (expr-error) (expr-rat r)))]
    [(expr-p32-to-rat a) (reduce-posit-unary 32 expr-p32-to-rat a)]

    ;; Phase 3f: p32-from-rat -- Rat -> Posit32
    [(expr-p32-from-rat (expr-rat v))
     (expr-posit32 (posit32-encode v))]
    [(expr-p32-from-rat a) (reduce-rat-unary expr-p32-from-rat a)]

    ;; Phase 3f: p32-from-int -- Int -> Posit32
    [(expr-p32-from-int (expr-int v))
     (expr-posit32 (posit32-encode v))]
    [(expr-p32-from-int a) (reduce-int-unary expr-p32-from-int a)]

    ;; p32-if-nar: branch when val is a literal
    [(expr-p32-if-nar _ nc _ (expr-posit32 2147483648)) (whnf nc)]    ; NaR = 0x80000000 = 2147483648
    [(expr-p32-if-nar _ _ vc (expr-posit32 _)) (whnf vc)]             ; any non-NaR literal

    ;; ---- Posit32 stuck-term reduction ----

    ;; Binary ops: reduce operands
    [(expr-p32-add a b) (reduce-posit-binary 32 expr-p32-add a b)]
    [(expr-p32-sub a b) (reduce-posit-binary 32 expr-p32-sub a b)]
    [(expr-p32-mul a b) (reduce-posit-binary 32 expr-p32-mul a b)]
    [(expr-p32-div a b) (reduce-posit-binary 32 expr-p32-div a b)]
    [(expr-p32-lt a b) (reduce-posit-binary 32 expr-p32-lt a b)]
    [(expr-p32-le a b) (reduce-posit-binary 32 expr-p32-le a b)]
    [(expr-p32-eq a b) (reduce-posit-binary 32 expr-p32-eq a b)]

    ;; Unary ops: reduce operand
    [(expr-p32-neg a) (reduce-posit-unary 32 expr-p32-neg a)]
    [(expr-p32-abs a) (reduce-posit-unary 32 expr-p32-abs a)]
    [(expr-p32-sqrt a) (reduce-posit-unary 32 expr-p32-sqrt a)]

    ;; p32-if-nar: reduce the value argument
    [(expr-p32-if-nar t nc vc v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-p32-if-nar t nc vc v*))))]

    ;; ---- Posit64 iota rules: compute when arguments are posit64 literals ----

    ;; Binary arithmetic on literals
    [(expr-p64-add (expr-posit64 a) (expr-posit64 b)) (expr-posit64 (posit64-add a b))]
    [(expr-p64-sub (expr-posit64 a) (expr-posit64 b)) (expr-posit64 (posit64-sub a b))]
    [(expr-p64-mul (expr-posit64 a) (expr-posit64 b)) (expr-posit64 (posit64-mul a b))]
    [(expr-p64-div (expr-posit64 a) (expr-posit64 b)) (expr-posit64 (posit64-div a b))]

    ;; Unary ops on literals
    [(expr-p64-neg (expr-posit64 a)) (expr-posit64 (posit64-neg a))]
    [(expr-p64-abs (expr-posit64 a)) (expr-posit64 (posit64-abs a))]
    [(expr-p64-sqrt (expr-posit64 a)) (expr-posit64 (posit64-sqrt a))]

    ;; Comparison on literals → Bool
    [(expr-p64-lt (expr-posit64 a) (expr-posit64 b))
     (if (posit64-lt? a b) (expr-true) (expr-false))]
    [(expr-p64-le (expr-posit64 a) (expr-posit64 b))
     (if (posit64-le? a b) (expr-true) (expr-false))]
    [(expr-p64-eq (expr-posit64 a) (expr-posit64 b))
     (if (posit64-eq? a b) (expr-true) (expr-false))]

    ;; from-nat: compute when arg is a Nat numeral
    [(expr-p64-from-nat n)
     (let ([n* (whnf n)])
       (let ([k (nat-value n*)])
         (cond
           [k (expr-posit64 (posit64-from-nat k))]
           [(equal? n* n) e]    ; stuck
           [else (whnf (expr-p64-from-nat n*))])))]

    ;; Phase 3f: p64-to-rat -- Posit64 -> Rat
    [(expr-p64-to-rat (expr-posit64 v))
     (let ([r (posit64-to-rational v)])
       (if (eq? r 'nar) (expr-error) (expr-rat r)))]
    [(expr-p64-to-rat a) (reduce-posit-unary 64 expr-p64-to-rat a)]

    ;; Phase 3f: p64-from-rat -- Rat -> Posit64
    [(expr-p64-from-rat (expr-rat v))
     (expr-posit64 (posit64-encode v))]
    [(expr-p64-from-rat a) (reduce-rat-unary expr-p64-from-rat a)]

    ;; Phase 3f: p64-from-int -- Int -> Posit64
    [(expr-p64-from-int (expr-int v))
     (expr-posit64 (posit64-encode v))]
    [(expr-p64-from-int a) (reduce-int-unary expr-p64-from-int a)]

    ;; p64-if-nar: branch when val is a literal
    [(expr-p64-if-nar _ nc _ (expr-posit64 9223372036854775808)) (whnf nc)]    ; NaR = 0x8000000000000000
    [(expr-p64-if-nar _ _ vc (expr-posit64 _)) (whnf vc)]                      ; any non-NaR literal

    ;; ---- Posit64 stuck-term reduction ----

    ;; Binary ops: reduce operands
    [(expr-p64-add a b) (reduce-posit-binary 64 expr-p64-add a b)]
    [(expr-p64-sub a b) (reduce-posit-binary 64 expr-p64-sub a b)]
    [(expr-p64-mul a b) (reduce-posit-binary 64 expr-p64-mul a b)]
    [(expr-p64-div a b) (reduce-posit-binary 64 expr-p64-div a b)]
    [(expr-p64-lt a b) (reduce-posit-binary 64 expr-p64-lt a b)]
    [(expr-p64-le a b) (reduce-posit-binary 64 expr-p64-le a b)]
    [(expr-p64-eq a b) (reduce-posit-binary 64 expr-p64-eq a b)]

    ;; Unary ops: reduce operand
    [(expr-p64-neg a) (reduce-posit-unary 64 expr-p64-neg a)]
    [(expr-p64-abs a) (reduce-posit-unary 64 expr-p64-abs a)]
    [(expr-p64-sqrt a) (reduce-posit-unary 64 expr-p64-sqrt a)]

    ;; p64-if-nar: reduce the value argument
    [(expr-p64-if-nar t nc vc v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-p64-if-nar t nc vc v*))))]

    ;; ---- Quire iota rules ----
    ;; quireW-fma on literals: accumulate exact product
    [(expr-quire8-fma (expr-quire8-val q) (expr-posit8 a) (expr-posit8 b))
     (expr-quire8-val (quire8-fma q a b))]
    [(expr-quire16-fma (expr-quire16-val q) (expr-posit16 a) (expr-posit16 b))
     (expr-quire16-val (quire16-fma q a b))]
    [(expr-quire32-fma (expr-quire32-val q) (expr-posit32 a) (expr-posit32 b))
     (expr-quire32-val (quire32-fma q a b))]
    [(expr-quire64-fma (expr-quire64-val q) (expr-posit64 a) (expr-posit64 b))
     (expr-quire64-val (quire64-fma q a b))]

    ;; quireW-to on literals: convert accumulator to posit
    [(expr-quire8-to (expr-quire8-val q)) (expr-posit8 (quire8-to q))]
    [(expr-quire16-to (expr-quire16-val q)) (expr-posit16 (quire16-to q))]
    [(expr-quire32-to (expr-quire32-val q)) (expr-posit32 (quire32-to q))]
    [(expr-quire64-to (expr-quire64-val q)) (expr-posit64 (quire64-to q))]

    ;; ---- Quire stuck-term reduction ----
    ;; fma: try reducing q, then a, then b
    [(expr-quire8-fma q a b)
     (let ([q* (whnf q)])
       (if (equal? q* q)
           (let ([a* (whnf a)])
             (if (equal? a* a)
                 (let ([b* (whnf b)])
                   (if (equal? b* b) e (whnf (expr-quire8-fma q a b*))))
                 (whnf (expr-quire8-fma q a* b))))
           (whnf (expr-quire8-fma q* a b))))]
    ;; Phase 3e: quire16/32/64 FMA — coerce posit operands a, b (not quire accumulator q)
    [(expr-quire16-fma q a b)
     (let* ([q* (whnf q)] [a* (whnf a)] [b* (whnf b)]
            [ca (or (try-coerce-to-posit 16 a*) a*)]
            [cb (or (try-coerce-to-posit 16 b*) b*)])
       (cond
         [(or (not (eq? ca a*)) (not (eq? cb b*)))
          (whnf (expr-quire16-fma q* ca cb))]
         [(not (equal? q* q)) (whnf (expr-quire16-fma q* a b))]
         [(not (equal? a* a)) (whnf (expr-quire16-fma q a* b))]
         [(not (equal? b* b)) (whnf (expr-quire16-fma q a b*))]
         [else e]))]
    [(expr-quire32-fma q a b)
     (let* ([q* (whnf q)] [a* (whnf a)] [b* (whnf b)]
            [ca (or (try-coerce-to-posit 32 a*) a*)]
            [cb (or (try-coerce-to-posit 32 b*) b*)])
       (cond
         [(or (not (eq? ca a*)) (not (eq? cb b*)))
          (whnf (expr-quire32-fma q* ca cb))]
         [(not (equal? q* q)) (whnf (expr-quire32-fma q* a b))]
         [(not (equal? a* a)) (whnf (expr-quire32-fma q a* b))]
         [(not (equal? b* b)) (whnf (expr-quire32-fma q a b*))]
         [else e]))]
    [(expr-quire64-fma q a b)
     (let* ([q* (whnf q)] [a* (whnf a)] [b* (whnf b)]
            [ca (or (try-coerce-to-posit 64 a*) a*)]
            [cb (or (try-coerce-to-posit 64 b*) b*)])
       (cond
         [(or (not (eq? ca a*)) (not (eq? cb b*)))
          (whnf (expr-quire64-fma q* ca cb))]
         [(not (equal? q* q)) (whnf (expr-quire64-fma q* a b))]
         [(not (equal? a* a)) (whnf (expr-quire64-fma q a* b))]
         [(not (equal? b* b)) (whnf (expr-quire64-fma q a b*))]
         [else e]))]
    ;; to: try reducing q
    [(expr-quire8-to q)
     (let ([q* (whnf q)]) (if (equal? q* q) e (whnf (expr-quire8-to q*))))]
    [(expr-quire16-to q)
     (let ([q* (whnf q)]) (if (equal? q* q) e (whnf (expr-quire16-to q*))))]
    [(expr-quire32-to q)
     (let ([q* (whnf q)]) (if (equal? q* q) e (whnf (expr-quire32-to q*))))]
    [(expr-quire64-to q)
     (let ([q* (whnf q)]) (if (equal? q* q) e (whnf (expr-quire64-to q*))))]

    ;; ---- Generic arithmetic iota rules ----
    ;; Dispatch on concrete operand types at reduction time.

    ;; generic-add: compute when both operands are same-type literals
    [(expr-generic-add (expr-int a) (expr-int b)) (expr-int (+ a b))]
    [(expr-generic-add (expr-rat a) (expr-rat b)) (expr-rat (+ a b))]
    [(expr-generic-add (expr-posit8 a) (expr-posit8 b)) (expr-posit8 (posit8-add a b))]
    [(expr-generic-add (expr-posit16 a) (expr-posit16 b)) (expr-posit16 (posit16-add a b))]
    [(expr-generic-add (expr-posit32 a) (expr-posit32 b)) (expr-posit32 (posit32-add a b))]
    [(expr-generic-add (expr-posit64 a) (expr-posit64 b)) (expr-posit64 (posit64-add a b))]

    ;; generic-sub
    [(expr-generic-sub (expr-int a) (expr-int b)) (expr-int (- a b))]
    [(expr-generic-sub (expr-rat a) (expr-rat b)) (expr-rat (- a b))]
    [(expr-generic-sub (expr-posit8 a) (expr-posit8 b)) (expr-posit8 (posit8-sub a b))]
    [(expr-generic-sub (expr-posit16 a) (expr-posit16 b)) (expr-posit16 (posit16-sub a b))]
    [(expr-generic-sub (expr-posit32 a) (expr-posit32 b)) (expr-posit32 (posit32-sub a b))]
    [(expr-generic-sub (expr-posit64 a) (expr-posit64 b)) (expr-posit64 (posit64-sub a b))]

    ;; generic-mul
    [(expr-generic-mul (expr-int a) (expr-int b)) (expr-int (* a b))]
    [(expr-generic-mul (expr-rat a) (expr-rat b)) (expr-rat (* a b))]
    [(expr-generic-mul (expr-posit8 a) (expr-posit8 b)) (expr-posit8 (posit8-mul a b))]
    [(expr-generic-mul (expr-posit16 a) (expr-posit16 b)) (expr-posit16 (posit16-mul a b))]
    [(expr-generic-mul (expr-posit32 a) (expr-posit32 b)) (expr-posit32 (posit32-mul a b))]
    [(expr-generic-mul (expr-posit64 a) (expr-posit64 b)) (expr-posit64 (posit64-mul a b))]

    ;; generic-div (no Nat — Nat excluded at type level)
    [(expr-generic-div (expr-int a) (expr-int b))
     (if (zero? b) e (expr-int (quotient a b)))]
    [(expr-generic-div (expr-rat a) (expr-rat b))
     (if (zero? b) e (expr-rat (/ a b)))]
    [(expr-generic-div (expr-posit8 a) (expr-posit8 b)) (expr-posit8 (posit8-div a b))]
    [(expr-generic-div (expr-posit16 a) (expr-posit16 b)) (expr-posit16 (posit16-div a b))]
    [(expr-generic-div (expr-posit32 a) (expr-posit32 b)) (expr-posit32 (posit32-div a b))]
    [(expr-generic-div (expr-posit64 a) (expr-posit64 b)) (expr-posit64 (posit64-div a b))]

    ;; generic-lt
    [(expr-generic-lt (expr-int a) (expr-int b))
     (if (< a b) (expr-true) (expr-false))]
    [(expr-generic-lt (expr-rat a) (expr-rat b))
     (if (< a b) (expr-true) (expr-false))]
    [(expr-generic-lt (expr-posit8 a) (expr-posit8 b))
     (if (posit8-lt? a b) (expr-true) (expr-false))]
    [(expr-generic-lt (expr-posit16 a) (expr-posit16 b))
     (if (posit16-lt? a b) (expr-true) (expr-false))]
    [(expr-generic-lt (expr-posit32 a) (expr-posit32 b))
     (if (posit32-lt? a b) (expr-true) (expr-false))]
    [(expr-generic-lt (expr-posit64 a) (expr-posit64 b))
     (if (posit64-lt? a b) (expr-true) (expr-false))]

    ;; generic-le
    [(expr-generic-le (expr-int a) (expr-int b))
     (if (<= a b) (expr-true) (expr-false))]
    [(expr-generic-le (expr-rat a) (expr-rat b))
     (if (<= a b) (expr-true) (expr-false))]
    [(expr-generic-le (expr-posit8 a) (expr-posit8 b))
     (if (posit8-le? a b) (expr-true) (expr-false))]
    [(expr-generic-le (expr-posit16 a) (expr-posit16 b))
     (if (posit16-le? a b) (expr-true) (expr-false))]
    [(expr-generic-le (expr-posit32 a) (expr-posit32 b))
     (if (posit32-le? a b) (expr-true) (expr-false))]
    [(expr-generic-le (expr-posit64 a) (expr-posit64 b))
     (if (posit64-le? a b) (expr-true) (expr-false))]

    ;; generic-eq
    [(expr-generic-eq (expr-int a) (expr-int b))
     (if (= a b) (expr-true) (expr-false))]
    [(expr-generic-eq (expr-rat a) (expr-rat b))
     (if (= a b) (expr-true) (expr-false))]
    [(expr-generic-eq (expr-posit8 a) (expr-posit8 b))
     (if (posit8-eq? a b) (expr-true) (expr-false))]
    [(expr-generic-eq (expr-posit16 a) (expr-posit16 b))
     (if (posit16-eq? a b) (expr-true) (expr-false))]
    [(expr-generic-eq (expr-posit32 a) (expr-posit32 b))
     (if (posit32-eq? a b) (expr-true) (expr-false))]
    [(expr-generic-eq (expr-posit64 a) (expr-posit64 b))
     (if (posit64-eq? a b) (expr-true) (expr-false))]

    ;; generic-negate (no Nat — excluded at type level)
    [(expr-generic-negate (expr-int a)) (expr-int (- a))]
    [(expr-generic-negate (expr-rat a)) (expr-rat (- a))]
    [(expr-generic-negate (expr-posit8 a)) (expr-posit8 (posit8-neg a))]
    [(expr-generic-negate (expr-posit16 a)) (expr-posit16 (posit16-neg a))]
    [(expr-generic-negate (expr-posit32 a)) (expr-posit32 (posit32-neg a))]
    [(expr-generic-negate (expr-posit64 a)) (expr-posit64 (posit64-neg a))]

    ;; generic-abs
    [(expr-generic-abs (expr-int a)) (expr-int (abs a))]
    [(expr-generic-abs (expr-rat a)) (expr-rat (abs a))]
    [(expr-generic-abs (expr-posit8 a)) (expr-posit8 (posit8-abs a))]
    [(expr-generic-abs (expr-posit16 a)) (expr-posit16 (posit16-abs a))]
    [(expr-generic-abs (expr-posit32 a)) (expr-posit32 (posit32-abs a))]
    [(expr-generic-abs (expr-posit64 a)) (expr-posit64 (posit64-abs a))]

    ;; generic-from-int: Int -> TargetType conversion based on target type
    [(expr-generic-from-int (expr-Int) (expr-int v))  (expr-int v)]             ; identity
    [(expr-generic-from-int (expr-Rat) (expr-int v))  (expr-rat v)]             ; Int -> Rat
    [(expr-generic-from-int (expr-Posit8) (expr-int v))  (expr-posit8 (posit8-encode v))]
    [(expr-generic-from-int (expr-Posit16) (expr-int v)) (expr-posit16 (posit16-encode v))]
    [(expr-generic-from-int (expr-Posit32) (expr-int v)) (expr-posit32 (posit32-encode v))]
    [(expr-generic-from-int (expr-Posit64) (expr-int v)) (expr-posit64 (posit64-encode v))]

    ;; generic-from-rat: Rat -> TargetType conversion based on target type
    [(expr-generic-from-rat (expr-Rat) (expr-rat v))  (expr-rat v)]             ; identity
    [(expr-generic-from-rat (expr-Posit8) (expr-rat v))  (expr-posit8 (posit8-encode v))]
    [(expr-generic-from-rat (expr-Posit16) (expr-rat v)) (expr-posit16 (posit16-encode v))]
    [(expr-generic-from-rat (expr-Posit32) (expr-rat v)) (expr-posit32 (posit32-encode v))]
    [(expr-generic-from-rat (expr-Posit64) (expr-rat v)) (expr-posit64 (posit64-encode v))]

    ;; ---- Generic arithmetic stuck-term reduction ----
    ;; Binary ops: reduce operands
    [(expr-generic-add a b) (reduce-generic-binary expr-generic-add a b)]
    [(expr-generic-sub a b) (reduce-generic-binary expr-generic-sub a b)]
    [(expr-generic-mul a b) (reduce-generic-binary expr-generic-mul a b)]
    [(expr-generic-div a b) (reduce-generic-binary expr-generic-div a b)]
    [(expr-generic-lt a b) (reduce-generic-binary expr-generic-lt a b)]
    [(expr-generic-le a b) (reduce-generic-binary expr-generic-le a b)]
    [(expr-generic-eq a b) (reduce-generic-binary expr-generic-eq a b)]
    ;; Unary ops: reduce operand
    [(expr-generic-negate a) (reduce-generic-unary expr-generic-negate a)]
    [(expr-generic-abs a) (reduce-generic-unary expr-generic-abs a)]
    ;; Generic conversion stuck-term: reduce arg, retry
    [(expr-generic-from-int t a)
     (let ([a* (whnf a)])
       (if (equal? a* a) e (whnf (expr-generic-from-int t a*))))]
    [(expr-generic-from-rat t a)
     (let ([a* (whnf a)])
       (if (equal? a* a) e (whnf (expr-generic-from-rat t a*))))]

    ;; Symbol — no reduction (atoms are values)
    ;; (no clauses needed for expr-Symbol or expr-symbol — they're values)

    ;; Keyword — no reduction (atoms are values)
    ;; (no clauses needed for expr-Keyword or expr-keyword — they're values)

    ;; ---- Map iota rules: compute when arguments are champ values ----
    ;; map-empty reduces to champ(champ-empty) — the runtime representation
    [(expr-map-empty _ _) (expr-champ champ-empty)]

    [(expr-map-assoc (expr-champ c) k v)
     (let ([k* (whnf k)] [v* (whnf v)])
       (expr-champ (champ-insert c (equal-hash-code k*) k* v*)))]
    [(expr-map-get (expr-champ c) k)
     (let ([k* (whnf k)])
       (let ([result (champ-lookup c (equal-hash-code k*) k*)])
         (if (eq? result 'none)
             (expr-error)
             (whnf result))))]
    [(expr-map-dissoc (expr-champ c) k)
     (let ([k* (whnf k)])
       (expr-champ (champ-delete c (equal-hash-code k*) k*)))]
    [(expr-map-size (expr-champ c))
     (nat->expr (champ-size c))]
    [(expr-map-has-key (expr-champ c) k)
     (let ([k* (whnf k)])
       (if (champ-has-key? c (equal-hash-code k*) k*)
           (expr-true)
           (expr-false)))]
    [(expr-map-keys (expr-champ c))
     (racket-list->prologos-list (champ-keys c))]
    [(expr-map-vals (expr-champ c))
     (racket-list->prologos-list (champ-vals c))]

    ;; ---- PVec iota rules ----
    [(expr-pvec-empty _) (expr-rrb rrb-empty)]

    [(expr-pvec-push (expr-rrb r) x)
     (let ([x* (whnf x)])
       (expr-rrb (rrb-push r x*)))]

    [(expr-pvec-nth (expr-rrb r) i)
     (let* ([i* (whnf i)]
            [n (nat-value i*)])
       (if n
           (with-handlers ([exn:fail? (lambda (_) e)])
             (whnf (rrb-get r n)))
           e))]

    [(expr-pvec-update (expr-rrb r) i x)
     (let* ([i* (whnf i)]
            [n (nat-value i*)]
            [x* (whnf x)])
       (if n
           (with-handlers ([exn:fail? (lambda (_) e)])
             (expr-rrb (rrb-set r n x*)))
           e))]

    [(expr-pvec-length (expr-rrb r))
     (nat->expr (rrb-size r))]

    [(expr-pvec-to-list (expr-rrb r))
     (racket-list->prologos-list (rrb-to-list r))]

    [(expr-pvec-from-list v)
     (let ([elems (prologos-list->racket-list v)])
       (if elems
           (expr-rrb (rrb-from-list elems))
           ;; try reducing v first
           (let ([v* (whnf v)])
             (if (equal? v* v) e (whnf (expr-pvec-from-list v*))))))]

    [(expr-pvec-pop (expr-rrb r))
     (with-handlers ([exn:fail? (lambda (_) e)])
       (expr-rrb (rrb-pop r)))]

    [(expr-pvec-concat (expr-rrb r1) (expr-rrb r2))
     (expr-rrb (rrb-concat r1 r2))]

    [(expr-pvec-slice (expr-rrb r) lo hi)
     (let* ([lo* (whnf lo)] [hi* (whnf hi)]
            [lo-n (nat-value lo*)] [hi-n (nat-value hi*)])
       (if (and lo-n hi-n)
           (expr-rrb (rrb-slice r lo-n hi-n))
           e))]

    ;; pvec-fold : left fold over RRB — f takes (accumulator, element)
    ;; rrb-fold passes (value, acc), so we call f(acc, elem)
    [(expr-pvec-fold f init (expr-rrb r))
     (let ([init* (whnf init)]
           [f* (whnf f)])
       (rrb-fold r
                 (lambda (elem acc)
                   (whnf (expr-app (expr-app f* acc) elem)))
                 init*))]

    ;; pvec-map : map over RRB via fold + transient push
    [(expr-pvec-map f (expr-rrb r))
     (let ([f* (whnf f)])
       (let ([t (rrb-transient rrb-empty)])
         (rrb-fold r
                   (lambda (elem _acc)
                     (trrb-push! t (whnf (expr-app f* elem))))
                   (void))
         (expr-rrb (trrb-freeze t))))]

    ;; pvec-filter : filter over RRB via fold + conditional transient push
    [(expr-pvec-filter pred (expr-rrb r))
     (let ([pred* (whnf pred)])
       (let ([t (rrb-transient rrb-empty)])
         (rrb-fold r
                   (lambda (elem _acc)
                     (let ([result (whnf (expr-app pred* elem))])
                       (when (expr-true? result)
                         (trrb-push! t elem))))
                   (void))
         (expr-rrb (trrb-freeze t))))]

    ;; set-fold : left fold over CHAMP set — f takes (accumulator, element)
    ;; champ-fold passes (key, #t, acc); for sets we ignore the value
    [(expr-set-fold f init (expr-hset c))
     (let ([init* (whnf init)]
           [f* (whnf f)])
       (champ-fold c
                   (lambda (k _v acc)
                     (whnf (expr-app (expr-app f* acc) k)))
                   init*))]

    ;; set-filter : filter over CHAMP set
    [(expr-set-filter pred (expr-hset c))
     (let ([pred* (whnf pred)])
       (let ([t (champ-transient champ-empty)])
         (champ-fold c
                     (lambda (k _v _acc)
                       (let ([result (whnf (expr-app pred* k))])
                         (when (expr-true? result)
                           (tchamp-insert! t (equal-hash-code k) k #t))))
                     (void))
         (expr-hset (tchamp-freeze t))))]

    ;; map-fold-entries : left fold over CHAMP map — f takes (accumulator, key, value)
    [(expr-map-fold-entries f init (expr-champ c))
     (let ([init* (whnf init)]
           [f* (whnf f)])
       (champ-fold c
                   (lambda (k v acc)
                     (whnf (expr-app (expr-app (expr-app f* acc) k) v)))
                   init*))]

    ;; map-filter-entries : filter map entries via fold + conditional insert
    [(expr-map-filter-entries pred (expr-champ c))
     (let ([pred* (whnf pred)])
       (let ([t (champ-transient champ-empty)])
         (champ-fold c
                     (lambda (k v _acc)
                       (let ([result (whnf (expr-app (expr-app pred* k) v))])
                         (when (expr-true? result)
                           (tchamp-insert! t (equal-hash-code k) k v))))
                     (void))
         (expr-champ (tchamp-freeze t))))]

    ;; map-map-vals : map values via fold + insert with new value
    [(expr-map-map-vals f (expr-champ c))
     (let ([f* (whnf f)])
       (let ([t (champ-transient champ-empty)])
         (champ-fold c
                     (lambda (k v _acc)
                       (tchamp-insert! t (equal-hash-code k) k (whnf (expr-app f* v))))
                     (void))
         (expr-champ (tchamp-freeze t))))]

    ;; ---- PVec stuck-term reduction ----
    [(expr-pvec-push v x)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-pvec-push v* x))))]
    [(expr-pvec-nth v i)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-pvec-nth v* i))))]
    [(expr-pvec-update v i x)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-pvec-update v* i x))))]
    [(expr-pvec-length v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-pvec-length v*))))]
    [(expr-pvec-to-list v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-pvec-to-list v*))))]
    [(expr-pvec-pop v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-pvec-pop v*))))]
    [(expr-pvec-concat v1 v2)
     (let ([v1* (whnf v1)])
       (if (not (equal? v1* v1))
           (whnf (expr-pvec-concat v1* v2))
           (let ([v2* (whnf v2)])
             (if (not (equal? v2* v2))
                 (whnf (expr-pvec-concat v1 v2*))
                 e))))]
    [(expr-pvec-slice v lo hi)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-pvec-slice v* lo hi))))]
    [(expr-pvec-fold f init vec)
     (let ([vec* (whnf vec)])
       (if (equal? vec* vec) e (whnf (expr-pvec-fold f init vec*))))]
    [(expr-pvec-map f vec)
     (let ([vec* (whnf vec)])
       (if (equal? vec* vec) e (whnf (expr-pvec-map f vec*))))]
    [(expr-pvec-filter pred vec)
     (let ([vec* (whnf vec)])
       (if (equal? vec* vec) e (whnf (expr-pvec-filter pred vec*))))]
    [(expr-set-fold f init set)
     (let ([set* (whnf set)])
       (if (equal? set* set) e (whnf (expr-set-fold f init set*))))]
    [(expr-set-filter pred set)
     (let ([set* (whnf set)])
       (if (equal? set* set) e (whnf (expr-set-filter pred set*))))]
    [(expr-map-fold-entries f init map)
     (let ([map* (whnf map)])
       (if (equal? map* map) e (whnf (expr-map-fold-entries f init map*))))]
    [(expr-map-filter-entries pred map)
     (let ([map* (whnf map)])
       (if (equal? map* map) e (whnf (expr-map-filter-entries pred map*))))]
    [(expr-map-map-vals f map)
     (let ([map* (whnf map)])
       (if (equal? map* map) e (whnf (expr-map-map-vals f map*))))]

    ;; ---- Transient Builder iota rules ----
    ;; Generic transient: dispatch on underlying value
    [(expr-transient (expr-rrb r))
     (expr-trrb (rrb-transient r))]
    [(expr-transient (expr-champ c))
     (expr-tchamp (champ-transient c))]
    [(expr-transient (expr-hset c))
     (expr-thset (champ-transient c))]
    ;; Generic persist: dispatch on transient value
    [(expr-persist (expr-trrb t))
     (expr-rrb (trrb-freeze t))]
    [(expr-persist (expr-tchamp t))
     (expr-champ (tchamp-freeze t))]
    [(expr-persist (expr-thset t))
     (expr-hset (tchamp-freeze t))]
    ;; Generic stuck-term reduction
    [(expr-transient c)
     (let ([c* (whnf c)])
       (if (equal? c* c) e (whnf (expr-transient c*))))]
    [(expr-persist c)
     (let ([c* (whnf c)])
       (if (equal? c* c) e (whnf (expr-persist c*))))]
    ;; Vec: transient/persist (specific)
    [(expr-transient-vec (expr-rrb r))
     (expr-trrb (rrb-transient r))]
    [(expr-persist-vec (expr-trrb t))
     (expr-rrb (trrb-freeze t))]
    ;; Vec: mutation
    [(expr-tvec-push! (expr-trrb t) x)
     (let ([x* (whnf x)])
       (expr-trrb (trrb-push! t x*)))]
    [(expr-tvec-update! (expr-trrb t) i x)
     (let* ([i* (whnf i)]
            [n (nat-value i*)]
            [x* (whnf x)])
       (if n
           (with-handlers ([exn:fail? (lambda (_) e)])
             (expr-trrb (trrb-update! t n x*)))
           e))]
    ;; Map: transient/persist
    [(expr-transient-map (expr-champ c))
     (expr-tchamp (champ-transient c))]
    [(expr-persist-map (expr-tchamp t))
     (expr-champ (tchamp-freeze t))]
    ;; Map: mutation
    [(expr-tmap-assoc! (expr-tchamp t) k v)
     (let ([k* (nf k)] [v* (whnf v)])
       (expr-tchamp (tchamp-insert! t (equal-hash-code k*) k* v*)))]
    [(expr-tmap-dissoc! (expr-tchamp t) k)
     (let ([k* (nf k)])
       (expr-tchamp (tchamp-delete! t (equal-hash-code k*) k*)))]
    ;; Set: transient/persist (set uses tchamp with val=#t)
    [(expr-transient-set (expr-hset c))
     (expr-thset (champ-transient c))]
    [(expr-persist-set (expr-thset t))
     (expr-hset (tchamp-freeze t))]
    ;; Set: mutation
    [(expr-tset-insert! (expr-thset t) a)
     (let ([a* (nf a)])
       (expr-thset (tchamp-insert! t (equal-hash-code a*) a* #t)))]
    [(expr-tset-delete! (expr-thset t) a)
     (let ([a* (nf a)])
       (expr-thset (tchamp-delete! t (equal-hash-code a*) a*)))]

    ;; ---- Transient Builder stuck-term reduction ----
    [(expr-transient-vec v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-transient-vec v*))))]
    [(expr-persist-vec t)
     (let ([t* (whnf t)])
       (if (equal? t* t) e (whnf (expr-persist-vec t*))))]
    [(expr-tvec-push! t x)
     (let ([t* (whnf t)])
       (if (equal? t* t) e (whnf (expr-tvec-push! t* x))))]
    [(expr-tvec-update! t i x)
     (let ([t* (whnf t)])
       (if (equal? t* t) e (whnf (expr-tvec-update! t* i x))))]
    [(expr-transient-map m)
     (let ([m* (whnf m)])
       (if (equal? m* m) e (whnf (expr-transient-map m*))))]
    [(expr-persist-map t)
     (let ([t* (whnf t)])
       (if (equal? t* t) e (whnf (expr-persist-map t*))))]
    [(expr-tmap-assoc! t k v)
     (let ([t* (whnf t)])
       (if (equal? t* t) e (whnf (expr-tmap-assoc! t* k v))))]
    [(expr-tmap-dissoc! t k)
     (let ([t* (whnf t)])
       (if (equal? t* t) e (whnf (expr-tmap-dissoc! t* k))))]
    [(expr-transient-set s)
     (let ([s* (whnf s)])
       (if (equal? s* s) e (whnf (expr-transient-set s*))))]
    [(expr-persist-set t)
     (let ([t* (whnf t)])
       (if (equal? t* t) e (whnf (expr-persist-set t*))))]
    [(expr-tset-insert! t a)
     (let ([t* (whnf t)])
       (if (equal? t* t) e (whnf (expr-tset-insert! t* a))))]
    [(expr-tset-delete! t a)
     (let ([t* (whnf t)])
       (if (equal? t* t) e (whnf (expr-tset-delete! t* a))))]

    ;; ---- Map stuck-term reduction (try reducing subexpressions) ----
    [(expr-map-assoc m k v)
     (let ([m* (whnf m)])
       (if (equal? m* m) e (whnf (expr-map-assoc m* k v))))]
    [(expr-map-get m k)
     (let ([m* (whnf m)])
       (cond
         [(not (equal? m* m)) (whnf (expr-map-get m* k))]
         ;; If m* is a concrete non-map value, return none (graceful degradation).
         ;; This handles cases like map-get on an Int from a mixed-type union.
         [(definitely-not-map? m*) (expr-fvar 'none)]
         [else e]))]
    [(expr-map-dissoc m k)
     (let ([m* (whnf m)])
       (if (equal? m* m) e (whnf (expr-map-dissoc m* k))))]
    [(expr-map-size m)
     (let ([m* (whnf m)])
       (if (equal? m* m) e (whnf (expr-map-size m*))))]
    [(expr-map-has-key m k)
     (let ([m* (whnf m)])
       (if (equal? m* m) e (whnf (expr-map-has-key m* k))))]
    [(expr-map-keys m)
     (let ([m* (whnf m)])
       (if (equal? m* m) e (whnf (expr-map-keys m*))))]
    [(expr-map-vals m)
     (let ([m* (whnf m)])
       (if (equal? m* m) e (whnf (expr-map-vals m*))))]

    ;; ---- Set iota rules: compute when arguments are hset (champ with #t sentinel) ----
    ;; set-empty reduces to hset(champ-empty) — the runtime representation
    [(expr-set-empty _) (expr-hset champ-empty)]

    [(expr-set-insert s a)
     (define s* (whnf s))
     (match s*
       [(expr-hset c)
        (define a* (nf a))
        (expr-hset (champ-insert c (equal-hash-code a*) a* #t))]
       [_ (expr-set-insert s* a)])]

    [(expr-set-member s a)
     (define s* (whnf s))
     (match s*
       [(expr-hset c)
        (define a* (nf a))
        (if (champ-has-key? c (equal-hash-code a*) a*)
            (expr-true)
            (expr-false))]
       [_ (expr-set-member s* a)])]

    [(expr-set-delete s a)
     (define s* (whnf s))
     (match s*
       [(expr-hset c)
        (define a* (nf a))
        (expr-hset (champ-delete c (equal-hash-code a*) a*))]
       [_ (expr-set-delete s* a)])]

    [(expr-set-size s)
     (define s* (whnf s))
     (match s*
       [(expr-hset c) (nat->expr (champ-size c))]
       [_ (expr-set-size s*)])]

    [(expr-set-union s1 s2)
     (define s1* (whnf s1))
     (define s2* (whnf s2))
     (match (list s1* s2*)
       [(list (expr-hset c1) (expr-hset c2))
        (expr-hset (champ-fold c2 (lambda (k _v acc) (champ-insert acc (equal-hash-code k) k #t)) c1))]
       [_ (expr-set-union s1* s2*)])]

    [(expr-set-intersect s1 s2)
     (define s1* (whnf s1))
     (define s2* (whnf s2))
     (match (list s1* s2*)
       [(list (expr-hset c1) (expr-hset c2))
        (expr-hset (champ-fold c1
                     (lambda (k _v acc)
                       (if (champ-has-key? c2 (equal-hash-code k) k)
                           (champ-insert acc (equal-hash-code k) k #t)
                           acc))
                     champ-empty))]
       [_ (expr-set-intersect s1* s2*)])]

    [(expr-set-diff s1 s2)
     (define s1* (whnf s1))
     (define s2* (whnf s2))
     (match (list s1* s2*)
       [(list (expr-hset c1) (expr-hset c2))
        (expr-hset (champ-fold c2 (lambda (k _v acc) (champ-delete acc (equal-hash-code k) k)) c1))]
       [_ (expr-set-diff s1* s2*)])]

    [(expr-set-to-list s)
     (define s* (whnf s))
     (match s*
       [(expr-hset c)
        (racket-list->prologos-list (champ-keys c))]  ;; Set stores keys with #t sentinel
       [_ (expr-set-to-list s*)])]

    ;; ---- PropNetwork iota rules ----
    ;; Type constructors are self-values
    [(expr-net-type) e]
    [(expr-cell-id-type) e]
    [(expr-prop-id-type) e]
    ;; Runtime wrappers are self-values
    [(expr-prop-network _) e]
    [(expr-cell-id _) e]
    [(expr-prop-id _) e]

    ;; net-new : Int -> PropNetwork
    [(expr-net-new fuel)
     (let ([fuel* (whnf fuel)])
       (cond
         [(expr-int? fuel*)
          (expr-prop-network (make-prop-network (expr-int-val fuel*)))]
         ;; Nat coercion: try nat-value
         [(nat-value fuel*)
          => (lambda (k) (expr-prop-network (make-prop-network k)))]
         [(equal? fuel* fuel) e]
         [else (whnf (expr-net-new fuel*))]))]

    ;; net-new-cell : PropNetwork -> A -> (A A -> A) -> [PropNetwork * CellId]
    [(expr-net-new-cell net init merge)
     (let ([net* (whnf net)])
       (match net*
         [(expr-prop-network rnet)
          (let* ([init* (whnf init)]
                 ;; Bridge the Prologos merge function to Racket:
                 ;; merge-fn(old, new) = whnf(app(app(merge, old), new))
                 [merge* (whnf merge)]
                 [racket-merge (lambda (old new)
                                 (whnf (expr-app (expr-app merge* old) new)))])
            (let-values ([(net2 cid) (net-new-cell rnet init* racket-merge)])
              (expr-pair (expr-prop-network net2) (expr-cell-id cid))))]
         [_ (if (equal? net* net) e (whnf (expr-net-new-cell net* init merge)))]))]

    ;; net-cell-read : PropNetwork -> CellId -> A
    [(expr-net-cell-read net cell)
     (let ([net* (whnf net)] [cell* (whnf cell)])
       (match* (net* cell*)
         [((expr-prop-network rnet) (expr-cell-id cid))
          (net-cell-read rnet cid)]
         [(_ _)
          (cond
            [(not (equal? net* net)) (whnf (expr-net-cell-read net* cell))]
            [(not (equal? cell* cell)) (whnf (expr-net-cell-read net cell*))]
            [else e])]))]

    ;; net-cell-write : PropNetwork -> CellId -> A -> PropNetwork
    [(expr-net-cell-write net cell val)
     (let ([net* (whnf net)] [cell* (whnf cell)])
       (match* (net* cell*)
         [((expr-prop-network rnet) (expr-cell-id cid))
          (let ([val* (whnf val)])
            (expr-prop-network (net-cell-write rnet cid val*)))]
         [(_ _)
          (cond
            [(not (equal? net* net)) (whnf (expr-net-cell-write net* cell val))]
            [(not (equal? cell* cell)) (whnf (expr-net-cell-write net cell* val))]
            [else e])]))]

    ;; net-add-prop : PropNetwork -> List CellId -> List CellId -> (PropNetwork -> PropNetwork) -> [PropNetwork * PropId]
    [(expr-net-add-prop net ins outs fn)
     (let ([net* (whnf net)])
       (match net*
         [(expr-prop-network rnet)
          (let* ([ins-list (prologos-list->racket-list (whnf ins))]
                 [outs-list (prologos-list->racket-list (whnf outs))])
            (if (and ins-list outs-list)
                (let* ([fn* (whnf fn)]
                       ;; Unwrap cell-ids from Prologos AST wrappers
                       [in-cids (map (lambda (e) (expr-cell-id-cell-id-value (whnf e))) ins-list)]
                       [out-cids (map (lambda (e) (expr-cell-id-cell-id-value (whnf e))) outs-list)]
                       ;; Bridge fire function: unwrap -> apply -> re-wrap
                       [racket-fire (lambda (rnet)
                                      (let ([result (whnf (expr-app fn* (expr-prop-network rnet)))])
                                        (match result
                                          [(expr-prop-network rnet2) rnet2]
                                          [_ rnet])))])  ;; stuck: return unchanged
                  (let-values ([(net2 pid) (net-add-propagator rnet in-cids out-cids racket-fire)])
                    (expr-pair (expr-prop-network net2) (expr-prop-id pid))))
                ;; Lists not yet reduced — try reducing net
                (if (equal? net* net) e (whnf (expr-net-add-prop net* ins outs fn)))))]
         [_ (if (equal? net* net) e (whnf (expr-net-add-prop net* ins outs fn)))]))]

    ;; net-run : PropNetwork -> PropNetwork
    [(expr-net-run net)
     (let ([net* (whnf net)])
       (match net*
         [(expr-prop-network rnet)
          (expr-prop-network (run-to-quiescence rnet))]
         [_ (if (equal? net* net) e (whnf (expr-net-run net*)))]))]

    ;; net-snapshot : PropNetwork -> PropNetwork (identity on persistent data)
    [(expr-net-snapshot net)
     (let ([net* (whnf net)])
       (match net*
         [(expr-prop-network _) net*]
         [_ (if (equal? net* net) e (whnf (expr-net-snapshot net*)))]))]

    ;; net-contradiction : PropNetwork -> Bool
    [(expr-net-contradiction net)
     (let ([net* (whnf net)])
       (match net*
         [(expr-prop-network rnet)
          (if (net-contradiction? rnet) (expr-true) (expr-false))]
         [_ (if (equal? net* net) e (whnf (expr-net-contradiction net*)))]))]

    ;; ---- UnionFind ----
    ;; Type constructor and runtime wrapper are self-values
    [(expr-uf-type) e]
    [(expr-uf-store _) e]

    ;; uf-empty : UnionFind
    [(expr-uf-empty)
     (expr-uf-store (uf-empty))]

    ;; uf-make-set : UnionFind -> Nat -> A -> UnionFind
    [(expr-uf-make-set store id val)
     (let ([store* (whnf store)])
       (match store*
         [(expr-uf-store rstore)
          (let ([id* (whnf id)])
            (cond
              [(nat-value id*)
               => (lambda (n)
                    (let ([val* (whnf val)])
                      (expr-uf-store (uf-make-set rstore n val*))))]
              [(equal? id* id) (if (equal? store* store) e (whnf (expr-uf-make-set store* id val)))]
              [else (whnf (expr-uf-make-set store* id* val))]))]
         [_ (if (equal? store* store) e (whnf (expr-uf-make-set store* id val)))]))]

    ;; uf-find : UnionFind -> Nat -> [Nat * UnionFind]
    [(expr-uf-find store id)
     (let ([store* (whnf store)] [id* (whnf id)])
       (match store*
         [(expr-uf-store rstore)
          (cond
            [(nat-value id*)
             => (lambda (n)
                  (let-values ([(root updated) (uf-find rstore n)])
                    (expr-pair (racket-nat->expr root) (expr-uf-store updated))))]
            [(not (equal? id* id)) (whnf (expr-uf-find store* id*))]
            [else e])]
         [_ (cond
              [(not (equal? store* store)) (whnf (expr-uf-find store* id))]
              [(not (equal? id* id)) (whnf (expr-uf-find store id*))]
              [else e])]))]

    ;; uf-union : UnionFind -> Nat -> Nat -> UnionFind
    [(expr-uf-union store id1 id2)
     (let ([store* (whnf store)])
       (match store*
         [(expr-uf-store rstore)
          (let ([id1* (whnf id1)] [id2* (whnf id2)])
            (cond
              [(and (nat-value id1*) (nat-value id2*))
               (let ([n1 (nat-value id1*)] [n2 (nat-value id2*)])
                 (expr-uf-store (uf-union rstore n1 n2)))]
              [(not (equal? id1* id1)) (whnf (expr-uf-union store* id1* id2))]
              [(not (equal? id2* id2)) (whnf (expr-uf-union store* id1 id2*))]
              [else (if (equal? store* store) e (whnf (expr-uf-union store* id1 id2)))]))]
         [_ (if (equal? store* store) e (whnf (expr-uf-union store* id1 id2)))]))]

    ;; uf-value : UnionFind -> Nat -> A
    [(expr-uf-value store id)
     (let ([store* (whnf store)] [id* (whnf id)])
       (match store*
         [(expr-uf-store rstore)
          (cond
            [(nat-value id*)
             => (lambda (n)
                  (let-values ([(val _updated) (uf-value rstore n)])
                    val))]
            [(not (equal? id* id)) (whnf (expr-uf-value store* id*))]
            [else e])]
         [_ (cond
              [(not (equal? store* store)) (whnf (expr-uf-value store* id))]
              [(not (equal? id* id)) (whnf (expr-uf-value store id*))]
              [else e])]))]

    ;; ---- ATMS ----
    ;; Type constructors and runtime wrappers are self-values
    [(expr-atms-type) e]
    [(expr-assumption-id-type) e]
    [(expr-atms-store _) e]
    [(expr-assumption-id-val _) e]

    ;; atms-new : PropNetwork -> ATMS
    [(expr-atms-new network)
     (let ([network* (whnf network)])
       (match network*
         [(expr-prop-network rnet)
          (expr-atms-store (atms-empty rnet))]
         [_ (if (equal? network* network) e (whnf (expr-atms-new network*)))]))]

    ;; atms-assume : ATMS -> Keyword -> A -> [ATMS * AssumptionId]
    [(expr-atms-assume store name datum)
     (let ([store* (whnf store)])
       (match store*
         [(expr-atms-store rstore)
          (let ([name* (whnf name)] [datum* (whnf datum)])
            (define sym (if (expr-keyword? name*)
                            (expr-keyword-name name*)
                            'unknown))
            (define-values (new-atms aid) (atms-assume rstore sym datum*))
            (expr-pair (expr-atms-store new-atms) (expr-assumption-id-val aid)))]
         [_ (if (equal? store* store) e (whnf (expr-atms-assume store* name datum)))]))]

    ;; atms-retract : ATMS -> AssumptionId -> ATMS
    [(expr-atms-retract store aid)
     (let ([store* (whnf store)] [aid* (whnf aid)])
       (match* (store* aid*)
         [((expr-atms-store rstore) (expr-assumption-id-val raid))
          (expr-atms-store (atms-retract rstore raid))]
         [(_ _)
          (cond
            [(not (equal? store* store)) (whnf (expr-atms-retract store* aid))]
            [(not (equal? aid* aid)) (whnf (expr-atms-retract store aid*))]
            [else e])]))]

    ;; atms-nogood : ATMS -> List AssumptionId -> ATMS
    [(expr-atms-nogood store aids)
     (let ([store* (whnf store)])
       (match store*
         [(expr-atms-store rstore)
          (let ([aset (prologos-list->assumption-set (whnf aids))])
            (if aset
                (expr-atms-store (atms-add-nogood rstore aset))
                ;; List not yet reducible
                (if (equal? store* store) e (whnf (expr-atms-nogood store* aids)))))]
         [_ (if (equal? store* store) e (whnf (expr-atms-nogood store* aids)))]))]

    ;; atms-amb : ATMS -> List A -> [ATMS * List AssumptionId]
    [(expr-atms-amb store alternatives)
     (let ([store* (whnf store)])
       (match store*
         [(expr-atms-store rstore)
          (let ([alt-list (prologos-list->racket-list (whnf alternatives))])
            (if alt-list
                (let-values ([(new-atms hyps) (atms-amb rstore alt-list)])
                  (expr-pair (expr-atms-store new-atms)
                             (racket-list->prologos-list (map expr-assumption-id-val hyps))))
                ;; List not yet reducible
                (if (equal? store* store) e (whnf (expr-atms-amb store* alternatives)))))]
         [_ (if (equal? store* store) e (whnf (expr-atms-amb store* alternatives)))]))]

    ;; atms-solve-all : ATMS -> CellId -> List _
    [(expr-atms-solve-all store goal)
     (let ([store* (whnf store)] [goal* (whnf goal)])
       (match* (store* goal*)
         [((expr-atms-store rstore) (expr-cell-id cid))
          (racket-list->prologos-list (atms-solve-all rstore cid))]
         [(_ _)
          (cond
            [(not (equal? store* store)) (whnf (expr-atms-solve-all store* goal))]
            [(not (equal? goal* goal)) (whnf (expr-atms-solve-all store goal*))]
            [else e])]))]

    ;; atms-read : ATMS -> CellId -> _
    [(expr-atms-read store cell)
     (let ([store* (whnf store)] [cell* (whnf cell)])
       (match* (store* cell*)
         [((expr-atms-store rstore) (expr-cell-id cid))
          (let ([val (atms-read-cell rstore cid)])
            (if (eq? val 'bot) (expr-hole) val))]
         [(_ _)
          (cond
            [(not (equal? store* store)) (whnf (expr-atms-read store* cell))]
            [(not (equal? cell* cell)) (whnf (expr-atms-read store cell*))]
            [else e])]))]

    ;; atms-write : ATMS -> CellId -> A -> List AssumptionId -> ATMS
    [(expr-atms-write store cell val support)
     (let ([store* (whnf store)] [cell* (whnf cell)])
       (match* (store* cell*)
         [((expr-atms-store rstore) (expr-cell-id cid))
          (let ([val* (whnf val)]
                [sup (prologos-list->assumption-set (whnf support))])
            (if sup
                (expr-atms-store (atms-write-cell rstore cid val* sup))
                ;; Support list not yet reducible
                (if (equal? store* store) e (whnf (expr-atms-write store* cell val support)))))]
         [(_ _)
          (cond
            [(not (equal? store* store)) (whnf (expr-atms-write store* cell val support))]
            [(not (equal? cell* cell)) (whnf (expr-atms-write store cell* val support))]
            [else e])]))]

    ;; atms-consistent : ATMS -> List AssumptionId -> Bool
    [(expr-atms-consistent store aids)
     (let ([store* (whnf store)])
       (match store*
         [(expr-atms-store rstore)
          (let ([aset (prologos-list->assumption-set (whnf aids))])
            (if aset
                (if (atms-consistent? rstore aset) (expr-true) (expr-false))
                (if (equal? store* store) e (whnf (expr-atms-consistent store* aids)))))]
         [_ (if (equal? store* store) e (whnf (expr-atms-consistent store* aids)))]))]

    ;; atms-worldview : ATMS -> List AssumptionId -> ATMS
    [(expr-atms-worldview store aids)
     (let ([store* (whnf store)])
       (match store*
         [(expr-atms-store rstore)
          (let ([aset (prologos-list->assumption-set (whnf aids))])
            (if aset
                (expr-atms-store (atms-with-worldview rstore aset))
                (if (equal? store* store) e (whnf (expr-atms-worldview store* aids)))))]
         [_ (if (equal? store* store) e (whnf (expr-atms-worldview store* aids)))]))]

    ;; ---- Tabling (SLG-style memoization) ----

    ;; Type constructor and runtime wrapper are self-values
    [(expr-table-store-type) e]
    [(expr-table-store-val _) e]

    ;; table-new : PropNetwork -> TableStore
    [(expr-table-new network)
     (let ([network* (whnf network)])
       (match network*
         [(expr-prop-network rnet)
          (expr-table-store-val (table-store-empty rnet))]
         [_ (if (equal? network* network) e (whnf (expr-table-new network*)))]))]

    ;; table-register : TableStore -> Keyword -> Keyword -> [TableStore * CellId]
    [(expr-table-register store name mode)
     (let ([store* (whnf store)])
       (match store*
         [(expr-table-store-val rstore)
          (let ([name* (whnf name)] [mode* (whnf mode)])
            (define sym (if (expr-keyword? name*)
                            (expr-keyword-name name*)
                            'unknown))
            (define mode-sym (if (expr-keyword? mode*)
                                 (expr-keyword-name mode*)
                                 'all))
            (define-values (new-ts cid) (table-register rstore sym mode-sym))
            (expr-pair (expr-table-store-val new-ts) (expr-cell-id cid)))]
         [_ (if (equal? store* store) e (whnf (expr-table-register store* name mode)))]))]

    ;; table-add : TableStore -> Keyword -> A -> TableStore
    [(expr-table-add store name answer)
     (let ([store* (whnf store)])
       (match store*
         [(expr-table-store-val rstore)
          (let ([name* (whnf name)] [answer* (whnf answer)])
            (define sym (if (expr-keyword? name*)
                            (expr-keyword-name name*)
                            'unknown))
            (expr-table-store-val (table-add rstore sym answer*)))]
         [_ (if (equal? store* store) e (whnf (expr-table-add store* name answer)))]))]

    ;; table-answers : TableStore -> Keyword -> List _
    [(expr-table-answers store name)
     (let ([store* (whnf store)])
       (match store*
         [(expr-table-store-val rstore)
          (let ([name* (whnf name)])
            (define sym (if (expr-keyword? name*)
                            (expr-keyword-name name*)
                            'unknown))
            (racket-list->prologos-list (table-answers rstore sym)))]
         [_ (if (equal? store* store) e (whnf (expr-table-answers store* name)))]))]

    ;; table-freeze : TableStore -> Keyword -> TableStore
    [(expr-table-freeze store name)
     (let ([store* (whnf store)])
       (match store*
         [(expr-table-store-val rstore)
          (let ([name* (whnf name)])
            (define sym (if (expr-keyword? name*)
                            (expr-keyword-name name*)
                            'unknown))
            (expr-table-store-val (table-freeze rstore sym)))]
         [_ (if (equal? store* store) e (whnf (expr-table-freeze store* name)))]))]

    ;; table-complete? : TableStore -> Keyword -> Bool
    [(expr-table-complete store name)
     (let ([store* (whnf store)])
       (match store*
         [(expr-table-store-val rstore)
          (let ([name* (whnf name)])
            (define sym (if (expr-keyword? name*)
                            (expr-keyword-name name*)
                            'unknown))
            (if (table-complete? rstore sym) (expr-true) (expr-false)))]
         [_ (if (equal? store* store) e (whnf (expr-table-complete store* name)))]))]

    ;; table-run : TableStore -> TableStore
    [(expr-table-run store)
     (let ([store* (whnf store)])
       (match store*
         [(expr-table-store-val rstore)
          (expr-table-store-val (table-run rstore))]
         [_ (if (equal? store* store) e (whnf (expr-table-run store*)))]))]

    ;; table-lookup : TableStore -> Keyword -> A -> Bool
    [(expr-table-lookup store name answer)
     (let ([store* (whnf store)])
       (match store*
         [(expr-table-store-val rstore)
          (let ([name* (whnf name)] [answer* (whnf answer)])
            (define sym (if (expr-keyword? name*)
                            (expr-keyword-name name*)
                            'unknown))
            (if (table-lookup rstore sym answer*) (expr-true) (expr-false)))]
         [_ (if (equal? store* store) e (whnf (expr-table-lookup store* name answer)))]))]

    ;; Union types: pass through (types don't reduce)
    [(expr-union _ _) e]

    ;; Reduce: structural pattern matching.
    ;; Decompose scrutinee as constructor, substitute field values into
    ;; matching arm body. Handles user-defined constructors (fvar applications)
    ;; and built-in constructors (expr-zero, expr-suc, expr-true, expr-false).
    ;; With native constructors, constructor fvars are never unfolded,
    ;; so the scrutinee is always a constructor application (not a lambda).
    [(expr-reduce scrutinee arms _structural?)
     (define scrut-whnf* (whnf scrutinee))
     (define struct-result (or (try-structural-reduce scrutinee arms)
                               (try-structural-reduce scrut-whnf* arms)
                               (try-builtin-reduce scrut-whnf* arms)))
     (if struct-result
         (whnf struct-result)
         e)]  ;; stuck — scrutinee is neutral

    ;; Free variable: unfold global definition if available.
    ;; Constructor and type-name fvars are canonical — do NOT unfold.
    ;; This keeps constructor applications as (fvar 'cons arg1 arg2) in WHNF,
    ;; allowing structural PM (try-structural-reduce) to decompose them.
    [(expr-fvar name)
     (if (or (lookup-ctor name) (lookup-ctor (ctor-short-name name))
             (lookup-type-ctors name) (lookup-type-ctors (ctor-short-name name)))
         e  ;; constructor or type name: canonical, don't unfold
         (let ([val (global-env-lookup-value name)])
           (if val (whnf val) e)))]

    ;; Metavariable: if solved, reduce solution; if unsolved, stuck
    [(expr-meta id)
     (let ([sol (meta-solution id)])
       (if sol (whnf sol) e))]

    ;; Everything else is already in WHNF
    [_ e]))

;; ========================================
;; Full Normalization
;; First reduce to WHNF, then normalize all subterms.
;; Per-command memoization: when current-nf-cache is active,
;; cache nf results keyed by expr (transparent structs → equal?-based hashing).
;; ========================================
(define current-nf-cache (make-parameter #f))

(define (nf e)
  (define cache (current-nf-cache))
  (cond
    [(and cache (hash-ref cache e #f))
     => values]
    [else
     (define result (nf-whnf (whnf e)))
     (when cache
       (hash-set! cache e result))
     result]))

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
    [(expr-Unit) e]
    [(expr-unit) e]
    [(expr-Type _) e]
    [(expr-hole) e]
    [(expr-typed-hole _) e]
    [(expr-meta _) e]
    [(expr-error) e]
    [(expr-tycon _) e]  ;; Unapplied type constructor (HKT) — already normal

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

    ;; Eliminators stuck on neutral — lazy branch normalization
    ;; Only normalize the scrutinee (target/proof); if it resolves, take the
    ;; appropriate branch. Otherwise leave branches unnormalized to avoid
    ;; exponential unfolding of recursive functions.
    [(expr-natrec mot base step target)
     (let ([target* (nf target)])
       (match target*
         [(expr-zero) (nf base)]
         [(expr-suc n) (nf (expr-app (expr-app step n) (expr-natrec mot base step n)))]
         [_ (expr-natrec (nf mot) base step target*)]))]
    [(expr-J mot base left right proof)
     (let ([proof* (nf proof)])
       (match proof*
         [(expr-refl) (nf (expr-app base left))]
         [_ (expr-J (nf mot) (nf base) (nf left) (nf right) proof*)]))]
    [(expr-boolrec mot tc fc target)
     (let ([target* (nf target)])
       (match target*
         [(expr-true)  (nf tc)]
         [(expr-false) (nf fc)]
         [_ (expr-boolrec (nf mot) tc fc target*)]))]

    ;; Vec/Fin normalization
    [(expr-Vec t n) (expr-Vec (nf t) (nf n))]
    [(expr-vnil t) (expr-vnil (nf t))]
    [(expr-vcons t n hd tl) (expr-vcons (nf t) (nf n) (nf hd) (nf tl))]
    [(expr-Fin n) (expr-Fin (nf n))]
    [(expr-fzero n) (expr-fzero (nf n))]
    [(expr-fsuc n i) (expr-fsuc (nf n) (nf i))]
    [(expr-vhead t n v) (expr-vhead (nf t) (nf n) (nf v))]
    [(expr-vtail t n v) (expr-vtail (nf t) (nf n) (nf v))]
    [(expr-vindex t n i v) (expr-vindex (nf t) (nf n) (nf i) (nf v))]

    ;; Int normalization
    [(expr-Int) e]
    [(expr-int _) e]
    [(expr-int-add a b) (expr-int-add (nf a) (nf b))]
    [(expr-int-sub a b) (expr-int-sub (nf a) (nf b))]
    [(expr-int-mul a b) (expr-int-mul (nf a) (nf b))]
    [(expr-int-div a b) (expr-int-div (nf a) (nf b))]
    [(expr-int-mod a b) (expr-int-mod (nf a) (nf b))]
    [(expr-int-neg a) (expr-int-neg (nf a))]
    [(expr-int-abs a) (expr-int-abs (nf a))]
    [(expr-int-lt a b) (expr-int-lt (nf a) (nf b))]
    [(expr-int-le a b) (expr-int-le (nf a) (nf b))]
    [(expr-int-eq a b) (expr-int-eq (nf a) (nf b))]
    [(expr-from-nat n) (expr-from-nat (nf n))]

    ;; Rat normalization
    [(expr-Rat) e]
    [(expr-rat _) e]
    [(expr-rat-add a b) (expr-rat-add (nf a) (nf b))]
    [(expr-rat-sub a b) (expr-rat-sub (nf a) (nf b))]
    [(expr-rat-mul a b) (expr-rat-mul (nf a) (nf b))]
    [(expr-rat-div a b) (expr-rat-div (nf a) (nf b))]
    [(expr-rat-neg a) (expr-rat-neg (nf a))]
    [(expr-rat-abs a) (expr-rat-abs (nf a))]
    [(expr-rat-lt a b) (expr-rat-lt (nf a) (nf b))]
    [(expr-rat-le a b) (expr-rat-le (nf a) (nf b))]
    [(expr-rat-eq a b) (expr-rat-eq (nf a) (nf b))]
    [(expr-from-int n) (expr-from-int (nf n))]
    [(expr-rat-numer a) (expr-rat-numer (nf a))]
    [(expr-rat-denom a) (expr-rat-denom (nf a))]

    ;; Posit8 normalization
    [(expr-Posit8) e]
    [(expr-posit8 _) e]
    [(expr-p8-add a b) (expr-p8-add (nf a) (nf b))]
    [(expr-p8-sub a b) (expr-p8-sub (nf a) (nf b))]
    [(expr-p8-mul a b) (expr-p8-mul (nf a) (nf b))]
    [(expr-p8-div a b) (expr-p8-div (nf a) (nf b))]
    [(expr-p8-neg a) (expr-p8-neg (nf a))]
    [(expr-p8-abs a) (expr-p8-abs (nf a))]
    [(expr-p8-sqrt a) (expr-p8-sqrt (nf a))]
    [(expr-p8-lt a b) (expr-p8-lt (nf a) (nf b))]
    [(expr-p8-le a b) (expr-p8-le (nf a) (nf b))]
    [(expr-p8-eq a b) (expr-p8-eq (nf a) (nf b))]
    [(expr-p8-from-nat n) (expr-p8-from-nat (nf n))]
    [(expr-p8-to-rat a) (expr-p8-to-rat (nf a))]
    [(expr-p8-from-rat a) (expr-p8-from-rat (nf a))]
    [(expr-p8-from-int a) (expr-p8-from-int (nf a))]
    [(expr-p8-if-nar t nc vc v)
     (expr-p8-if-nar (nf t) (nf nc) (nf vc) (nf v))]

    ;; Posit16 normalization
    [(expr-Posit16) e]
    [(expr-posit16 _) e]
    [(expr-p16-add a b) (expr-p16-add (nf a) (nf b))]
    [(expr-p16-sub a b) (expr-p16-sub (nf a) (nf b))]
    [(expr-p16-mul a b) (expr-p16-mul (nf a) (nf b))]
    [(expr-p16-div a b) (expr-p16-div (nf a) (nf b))]
    [(expr-p16-neg a) (expr-p16-neg (nf a))]
    [(expr-p16-abs a) (expr-p16-abs (nf a))]
    [(expr-p16-sqrt a) (expr-p16-sqrt (nf a))]
    [(expr-p16-lt a b) (expr-p16-lt (nf a) (nf b))]
    [(expr-p16-le a b) (expr-p16-le (nf a) (nf b))]
    [(expr-p16-eq a b) (expr-p16-eq (nf a) (nf b))]
    [(expr-p16-from-nat n) (expr-p16-from-nat (nf n))]
    [(expr-p16-to-rat a) (expr-p16-to-rat (nf a))]
    [(expr-p16-from-rat a) (expr-p16-from-rat (nf a))]
    [(expr-p16-from-int a) (expr-p16-from-int (nf a))]
    [(expr-p16-if-nar t nc vc v)
     (expr-p16-if-nar (nf t) (nf nc) (nf vc) (nf v))]

    ;; Posit32 normalization
    [(expr-Posit32) e]
    [(expr-posit32 _) e]
    [(expr-p32-add a b) (expr-p32-add (nf a) (nf b))]
    [(expr-p32-sub a b) (expr-p32-sub (nf a) (nf b))]
    [(expr-p32-mul a b) (expr-p32-mul (nf a) (nf b))]
    [(expr-p32-div a b) (expr-p32-div (nf a) (nf b))]
    [(expr-p32-neg a) (expr-p32-neg (nf a))]
    [(expr-p32-abs a) (expr-p32-abs (nf a))]
    [(expr-p32-sqrt a) (expr-p32-sqrt (nf a))]
    [(expr-p32-lt a b) (expr-p32-lt (nf a) (nf b))]
    [(expr-p32-le a b) (expr-p32-le (nf a) (nf b))]
    [(expr-p32-eq a b) (expr-p32-eq (nf a) (nf b))]
    [(expr-p32-from-nat n) (expr-p32-from-nat (nf n))]
    [(expr-p32-to-rat a) (expr-p32-to-rat (nf a))]
    [(expr-p32-from-rat a) (expr-p32-from-rat (nf a))]
    [(expr-p32-from-int a) (expr-p32-from-int (nf a))]
    [(expr-p32-if-nar t nc vc v)
     (expr-p32-if-nar (nf t) (nf nc) (nf vc) (nf v))]

    ;; Posit64 normalization
    [(expr-Posit64) e]
    [(expr-posit64 _) e]
    [(expr-p64-add a b) (expr-p64-add (nf a) (nf b))]
    [(expr-p64-sub a b) (expr-p64-sub (nf a) (nf b))]
    [(expr-p64-mul a b) (expr-p64-mul (nf a) (nf b))]
    [(expr-p64-div a b) (expr-p64-div (nf a) (nf b))]
    [(expr-p64-neg a) (expr-p64-neg (nf a))]
    [(expr-p64-abs a) (expr-p64-abs (nf a))]
    [(expr-p64-sqrt a) (expr-p64-sqrt (nf a))]
    [(expr-p64-lt a b) (expr-p64-lt (nf a) (nf b))]
    [(expr-p64-le a b) (expr-p64-le (nf a) (nf b))]
    [(expr-p64-eq a b) (expr-p64-eq (nf a) (nf b))]
    [(expr-p64-from-nat n) (expr-p64-from-nat (nf n))]
    [(expr-p64-to-rat a) (expr-p64-to-rat (nf a))]
    [(expr-p64-from-rat a) (expr-p64-from-rat (nf a))]
    [(expr-p64-from-int a) (expr-p64-from-int (nf a))]
    [(expr-p64-if-nar t nc vc v)
     (expr-p64-if-nar (nf t) (nf nc) (nf vc) (nf v))]

    ;; Quire normalization
    [(expr-Quire8) e]
    [(expr-quire8-val _) e]
    [(expr-quire8-fma q a b) (expr-quire8-fma (nf q) (nf a) (nf b))]
    [(expr-quire8-to q) (expr-quire8-to (nf q))]
    [(expr-Quire16) e]
    [(expr-quire16-val _) e]
    [(expr-quire16-fma q a b) (expr-quire16-fma (nf q) (nf a) (nf b))]
    [(expr-quire16-to q) (expr-quire16-to (nf q))]
    [(expr-Quire32) e]
    [(expr-quire32-val _) e]
    [(expr-quire32-fma q a b) (expr-quire32-fma (nf q) (nf a) (nf b))]
    [(expr-quire32-to q) (expr-quire32-to (nf q))]
    [(expr-Quire64) e]
    [(expr-quire64-val _) e]
    [(expr-quire64-fma q a b) (expr-quire64-fma (nf q) (nf a) (nf b))]
    [(expr-quire64-to q) (expr-quire64-to (nf q))]

    ;; Generic arithmetic normalization
    [(expr-generic-add a b) (expr-generic-add (nf a) (nf b))]
    [(expr-generic-sub a b) (expr-generic-sub (nf a) (nf b))]
    [(expr-generic-mul a b) (expr-generic-mul (nf a) (nf b))]
    [(expr-generic-div a b) (expr-generic-div (nf a) (nf b))]
    [(expr-generic-lt a b) (expr-generic-lt (nf a) (nf b))]
    [(expr-generic-le a b) (expr-generic-le (nf a) (nf b))]
    [(expr-generic-eq a b) (expr-generic-eq (nf a) (nf b))]
    [(expr-generic-negate a) (expr-generic-negate (nf a))]
    [(expr-generic-abs a) (expr-generic-abs (nf a))]
    [(expr-generic-from-int t a) (expr-generic-from-int (nf t) (nf a))]
    [(expr-generic-from-rat t a) (expr-generic-from-rat (nf t) (nf a))]

    ;; Symbol normalization
    [(expr-Symbol) e]
    [(expr-symbol _) e]

    ;; Keyword normalization
    [(expr-Keyword) e]
    [(expr-keyword _) e]

    ;; Char normalization
    [(expr-Char) e]
    [(expr-char _) e]

    ;; String normalization
    [(expr-String) e]
    [(expr-string _) e]

    ;; Map normalization
    [(expr-Map k v) (expr-Map (nf k) (nf v))]
    [(expr-champ _) e]
    [(expr-map-empty k v) (expr-map-empty (nf k) (nf v))]
    [(expr-map-assoc m k v) (expr-map-assoc (nf m) (nf k) (nf v))]
    [(expr-map-get m k) (expr-map-get (nf m) (nf k))]
    [(expr-map-dissoc m k) (expr-map-dissoc (nf m) (nf k))]
    [(expr-map-size m) (expr-map-size (nf m))]
    [(expr-map-has-key m k) (expr-map-has-key (nf m) (nf k))]
    [(expr-map-keys m) (expr-map-keys (nf m))]
    [(expr-map-vals m) (expr-map-vals (nf m))]

    ;; Set normalization
    [(expr-Set a) (expr-Set (nf a))]
    [(expr-hset _) e]
    [(expr-set-empty a) (expr-set-empty (nf a))]
    [(expr-set-insert s a) (expr-set-insert (nf s) (nf a))]
    [(expr-set-member s a) (expr-set-member (nf s) (nf a))]
    [(expr-set-delete s a) (expr-set-delete (nf s) (nf a))]
    [(expr-set-size s) (expr-set-size (nf s))]
    [(expr-set-union s1 s2) (expr-set-union (nf s1) (nf s2))]
    [(expr-set-intersect s1 s2) (expr-set-intersect (nf s1) (nf s2))]
    [(expr-set-diff s1 s2) (expr-set-diff (nf s1) (nf s2))]
    [(expr-set-to-list s) (expr-set-to-list (nf s))]

    ;; PVec normalization
    [(expr-PVec a) (expr-PVec (nf a))]
    [(expr-rrb r)
     ;; Normalize all elements inside the RRB tree
     (expr-rrb (rrb-from-list (map nf (rrb-to-list r))))]
    [(expr-pvec-empty a) (expr-pvec-empty (nf a))]
    [(expr-pvec-push v x) (expr-pvec-push (nf v) (nf x))]
    [(expr-pvec-nth v i) (expr-pvec-nth (nf v) (nf i))]
    [(expr-pvec-update v i x) (expr-pvec-update (nf v) (nf i) (nf x))]
    [(expr-pvec-length v) (expr-pvec-length (nf v))]
    [(expr-pvec-to-list v) (expr-pvec-to-list (nf v))]
    [(expr-pvec-from-list v) (expr-pvec-from-list (nf v))]
    [(expr-pvec-pop v) (expr-pvec-pop (nf v))]
    [(expr-pvec-concat v1 v2) (expr-pvec-concat (nf v1) (nf v2))]
    [(expr-pvec-slice v lo hi) (expr-pvec-slice (nf v) (nf lo) (nf hi))]
    [(expr-pvec-fold f init vec) (expr-pvec-fold (nf f) (nf init) (nf vec))]
    [(expr-pvec-map f vec) (expr-pvec-map (nf f) (nf vec))]
    [(expr-pvec-filter pred vec) (expr-pvec-filter (nf pred) (nf vec))]
    [(expr-set-fold f init set) (expr-set-fold (nf f) (nf init) (nf set))]
    [(expr-set-filter pred set) (expr-set-filter (nf pred) (nf set))]
    [(expr-map-fold-entries f init map) (expr-map-fold-entries (nf f) (nf init) (nf map))]
    [(expr-map-filter-entries pred map) (expr-map-filter-entries (nf pred) (nf map))]
    [(expr-map-map-vals f map) (expr-map-map-vals (nf f) (nf map))]

    ;; Transient Builder normalization
    [(expr-transient c) (expr-transient (nf c))]
    [(expr-persist c) (expr-persist (nf c))]
    [(expr-TVec a) (expr-TVec (nf a))]
    [(expr-TMap k v) (expr-TMap (nf k) (nf v))]
    [(expr-TSet a) (expr-TSet (nf a))]
    [(expr-trrb _) e]
    [(expr-tchamp _) e]
    [(expr-thset _) e]
    [(expr-transient-vec v) (expr-transient-vec (nf v))]
    [(expr-persist-vec t) (expr-persist-vec (nf t))]
    [(expr-transient-map m) (expr-transient-map (nf m))]
    [(expr-persist-map t) (expr-persist-map (nf t))]
    [(expr-transient-set s) (expr-transient-set (nf s))]
    [(expr-persist-set t) (expr-persist-set (nf t))]
    [(expr-tvec-push! t x) (expr-tvec-push! (nf t) (nf x))]
    [(expr-tvec-update! t i x) (expr-tvec-update! (nf t) (nf i) (nf x))]
    [(expr-tmap-assoc! t k v) (expr-tmap-assoc! (nf t) (nf k) (nf v))]
    [(expr-tmap-dissoc! t k) (expr-tmap-dissoc! (nf t) (nf k))]
    [(expr-tset-insert! t a) (expr-tset-insert! (nf t) (nf a))]
    [(expr-tset-delete! t a) (expr-tset-delete! (nf t) (nf a))]

    ;; PropNetwork normalization
    ;; Type constructors and runtime wrappers are self-values
    [(expr-net-type) e]
    [(expr-cell-id-type) e]
    [(expr-prop-id-type) e]
    [(expr-prop-network _) e]
    [(expr-cell-id _) e]
    [(expr-prop-id _) e]
    ;; Operations: structural recursion into fields
    [(expr-net-new fuel) (expr-net-new (nf fuel))]
    [(expr-net-new-cell n init merge) (expr-net-new-cell (nf n) (nf init) (nf merge))]
    [(expr-net-cell-read n cell) (expr-net-cell-read (nf n) (nf cell))]
    [(expr-net-cell-write n cell val) (expr-net-cell-write (nf n) (nf cell) (nf val))]
    [(expr-net-add-prop n ins outs fn) (expr-net-add-prop (nf n) (nf ins) (nf outs) (nf fn))]
    [(expr-net-run n) (expr-net-run (nf n))]
    [(expr-net-snapshot n) (expr-net-snapshot (nf n))]
    [(expr-net-contradiction n) (expr-net-contradiction (nf n))]

    ;; UnionFind: type constructor, wrapper, and uf-empty are self-values
    [(expr-uf-type) e]
    [(expr-uf-store _) e]
    [(expr-uf-empty) e]  ;; reduces to (expr-uf-store ...) in whnf, but if stuck, it's a value
    ;; Operations: structural recursion into fields
    [(expr-uf-make-set st id val) (expr-uf-make-set (nf st) (nf id) (nf val))]
    [(expr-uf-find st id) (expr-uf-find (nf st) (nf id))]
    [(expr-uf-union st id1 id2) (expr-uf-union (nf st) (nf id1) (nf id2))]
    [(expr-uf-value st id) (expr-uf-value (nf st) (nf id))]

    ;; ATMS: type constructors and wrappers are self-values
    [(expr-atms-type) e]
    [(expr-assumption-id-type) e]
    [(expr-atms-store _) e]
    [(expr-assumption-id-val _) e]
    ;; Operations: structural recursion into fields
    [(expr-atms-new net) (expr-atms-new (nf net))]
    [(expr-atms-assume st name datum) (expr-atms-assume (nf st) (nf name) (nf datum))]
    [(expr-atms-retract st aid) (expr-atms-retract (nf st) (nf aid))]
    [(expr-atms-nogood st aids) (expr-atms-nogood (nf st) (nf aids))]
    [(expr-atms-amb st alts) (expr-atms-amb (nf st) (nf alts))]
    [(expr-atms-solve-all st goal) (expr-atms-solve-all (nf st) (nf goal))]
    [(expr-atms-read st cell) (expr-atms-read (nf st) (nf cell))]
    [(expr-atms-write st cell val sup) (expr-atms-write (nf st) (nf cell) (nf val) (nf sup))]
    [(expr-atms-consistent st aids) (expr-atms-consistent (nf st) (nf aids))]
    [(expr-atms-worldview st aids) (expr-atms-worldview (nf st) (nf aids))]

    ;; Tabling: type constructor + runtime wrapper are self-values
    [(expr-table-store-type) e]
    [(expr-table-store-val _) e]
    ;; Operations: structural recursion into fields
    [(expr-table-new net) (expr-table-new (nf net))]
    [(expr-table-register st n m) (expr-table-register (nf st) (nf n) (nf m))]
    [(expr-table-add st n a) (expr-table-add (nf st) (nf n) (nf a))]
    [(expr-table-answers st n) (expr-table-answers (nf st) (nf n))]
    [(expr-table-freeze st n) (expr-table-freeze (nf st) (nf n))]
    [(expr-table-complete st n) (expr-table-complete (nf st) (nf n))]
    [(expr-table-run st) (expr-table-run (nf st))]
    [(expr-table-lookup st n a) (expr-table-lookup (nf st) (nf n) (nf a))]

    ;; Foreign function: opaque leaf (already in WHNF)
    [(expr-foreign-fn _ _ _ _ _ _) e]

    ;; Union types: normalize components
    [(expr-union l r) (expr-union (nf l) (nf r))]

    ;; Reduce: if we reach here, whnf couldn't fire any arm (scrutinee is stuck).
    ;; Only normalize the scrutinee. Do NOT normalize arm bodies — they may
    ;; contain recursive function calls that produce infinite unfolding when
    ;; the scrutinee is neutral (e.g., an unresolvable fvar). Since no arm
    ;; will be selected, normalizing arm bodies is wasteful and risks divergence.
    [(expr-reduce scrut arms structural?)
     (expr-reduce (nf scrut) arms structural?)]))

;; ========================================
;; Definitional Equality (conversion)
;; Two terms are definitionally equal iff their normal forms
;; are syntactically identical.
;; (#:transparent structs give us deep structural equal?)
;; ========================================
(define (conv e1 e2)
  (conv-nf (nf e1) (nf e2)))

;; Deep structural equality with hole-as-wildcard.
;; expr-hole on either side matches anything.
;; Uses struct->vector for generic traversal of #:transparent structs.
(define (conv-nf a b)
  (cond
    [(expr-hole? a) #t]
    [(expr-hole? b) #t]
    [(expr-typed-hole? a) #t]
    [(expr-typed-hole? b) #t]
    ;; Unsolved metavariables: equal only if same ID
    ;; (solved metas are already eliminated by nf→whnf)
    [(expr-meta? a)
     (and (expr-meta? b) (eq? (expr-meta-id a) (expr-meta-id b)))]
    [(expr-meta? b) #f]
    [(and (struct? a) (struct? b))
     (let ([va (struct->vector a)]
           [vb (struct->vector b)])
       (and (eq? (vector-ref va 0) (vector-ref vb 0))     ; same struct type
            (= (vector-length va) (vector-length vb))
            (for/and ([i (in-range 1 (vector-length va))]) ; skip struct-name at 0
              (conv-nf (vector-ref va i) (vector-ref vb i)))))]
    [else (equal? a b)]))
