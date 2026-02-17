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
         "foreign.rkt")

(provide whnf nf nf-whnf conv conv-nf current-nf-cache)

;; ========================================
;; Helpers for Posit8 reduction
;; ========================================

;; Extract a Racket natural number from an expr-zero/expr-suc chain, or #f if not a numeral.
(define (nat-value e)
  (match e
    [(expr-zero) 0]
    [(expr-suc e1) (let ([v (nat-value e1)]) (and v (+ v 1)))]
    [_ #f]))

;; Reduce a binary Int operation: try reducing left, then right.
(define (reduce-int-binary ctor a b)
  (let ([a* (whnf a)])
    (if (equal? a* a)
        (let ([b* (whnf b)])
          (if (equal? b* b)
              (ctor a b)   ; stuck — both operands in WHNF
              (whnf (ctor a b*))))
        (whnf (ctor a* b)))))

;; Reduce a unary Int operation: try reducing the operand.
(define (reduce-int-unary ctor a)
  (let ([a* (whnf a)])
    (if (equal? a* a)
        (ctor a)   ; stuck
        (whnf (ctor a*)))))

;; Reduce a binary Rat operation: try reducing left, then right.
(define (reduce-rat-binary ctor a b)
  (let ([a* (whnf a)])
    (if (equal? a* a)
        (let ([b* (whnf b)])
          (if (equal? b* b)
              (ctor a b)   ; stuck — both operands in WHNF
              (whnf (ctor a b*))))
        (whnf (ctor a* b)))))

;; Reduce a unary Rat operation: try reducing the operand.
(define (reduce-rat-unary ctor a)
  (let ([a* (whnf a)])
    (if (equal? a* a)
        (ctor a)   ; stuck
        (whnf (ctor a*)))))

;; Reduce a binary Posit8 operation: try reducing left, then right.
(define (reduce-p8-binary ctor a b)
  (let ([a* (whnf a)])
    (if (equal? a* a)
        (let ([b* (whnf b)])
          (if (equal? b* b)
              (ctor a b)   ; stuck — both operands in WHNF
              (whnf (ctor a b*))))
        (whnf (ctor a* b)))))

;; Reduce a unary Posit8 operation: try reducing the operand.
(define (reduce-p8-unary ctor a)
  (let ([a* (whnf a)])
    (if (equal? a* a)
        (ctor a)   ; stuck
        (whnf (ctor a*)))))

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
                     [field-values (drop all-args n-type-params)]
                     [short-name (ctor-short-name head-name)]
                     ;; Find matching arm
                     [matching-arm
                      (findf (lambda (arm)
                               (eq? (expr-reduce-arm-ctor-name arm) short-name))
                             arms)])
                (and matching-arm
                     (let ([bc (expr-reduce-arm-binding-count matching-arm)]
                           [body (expr-reduce-arm-body matching-arm)])
                       (if (= (length field-values) bc)
                           ;; Substitute field values for bindings.
                           ;; bindings: bvar(0) = last field, bvar(1) = second-to-last, etc.
                           ;; We substitute bvar(0) first with last field, which decrements
                           ;; higher indices, then repeat for the next.
                           (for/fold ([result body])
                                     ([fv (in-list (reverse field-values))])
                             (subst 0 fv result))
                           #f))))))))

;; Extract the short (bare) name from a potentially FQN symbol.
;; 'prologos.data.list::cons → 'cons, 'cons → 'cons
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
    ;; Nat: suc/inc (one field: the predecessor)
    [(expr-suc? scrut)
     (let ([arm (findf (lambda (a) (eq? (expr-reduce-arm-ctor-name a) 'inc)) arms)])
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

    ;; from-nat: compute when arg is a Nat numeral
    [(expr-p8-from-nat n)
     (let ([n* (whnf n)])
       (let ([k (nat-value n*)])
         (cond
           [k (expr-posit8 (posit8-from-nat k))]
           [(equal? n* n) e]    ; stuck
           [else (whnf (expr-p8-from-nat n*))])))]

    ;; p8-if-nar: branch when val is a literal
    [(expr-p8-if-nar _ nc _ (expr-posit8 128)) (whnf nc)]    ; NaR = 0x80 = 128
    [(expr-p8-if-nar _ _ vc (expr-posit8 _)) (whnf vc)]      ; any non-NaR literal

    ;; ---- Posit8 stuck-term reduction ----

    ;; Binary ops: reduce operands
    [(expr-p8-add a b) (reduce-p8-binary expr-p8-add a b)]
    [(expr-p8-sub a b) (reduce-p8-binary expr-p8-sub a b)]
    [(expr-p8-mul a b) (reduce-p8-binary expr-p8-mul a b)]
    [(expr-p8-div a b) (reduce-p8-binary expr-p8-div a b)]
    [(expr-p8-lt a b) (reduce-p8-binary expr-p8-lt a b)]
    [(expr-p8-le a b) (reduce-p8-binary expr-p8-le a b)]

    ;; Unary ops: reduce operand
    [(expr-p8-neg a) (reduce-p8-unary expr-p8-neg a)]
    [(expr-p8-abs a) (reduce-p8-unary expr-p8-abs a)]
    [(expr-p8-sqrt a) (reduce-p8-unary expr-p8-sqrt a)]

    ;; p8-if-nar: reduce the value argument
    [(expr-p8-if-nar t nc vc v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-p8-if-nar t nc vc v*))))]

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
    [(expr-meta _) e]
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
    [(expr-boolrec mot tc fc target)
     (expr-boolrec (nf mot) (nf tc) (nf fc) (nf target))]

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
    [(expr-p8-from-nat n) (expr-p8-from-nat (nf n))]
    [(expr-p8-if-nar t nc vc v)
     (expr-p8-if-nar (nf t) (nf nc) (nf vc) (nf v))]

    ;; Foreign function: opaque leaf (already in WHNF)
    [(expr-foreign-fn _ _ _ _ _ _) e]

    ;; Union types: normalize components
    [(expr-union l r) (expr-union (nf l) (nf r))]

    ;; Reduce: should be desugared by type checker before reaching nf,
    ;; but handle it defensively by normalizing sub-terms
    [(expr-reduce scrut arms structural?)
     (expr-reduce (nf scrut)
                  (map (lambda (arm)
                         (expr-reduce-arm
                          (expr-reduce-arm-ctor-name arm)
                          (expr-reduce-arm-binding-count arm)
                          (nf (expr-reduce-arm-body arm))))
                       arms)
                  structural?)]))

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
