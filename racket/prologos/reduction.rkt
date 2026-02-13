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
         "metavar-store.rkt")

(provide whnf nf nf-whnf conv conv-nf)

;; ========================================
;; Helpers for Posit8 reduction
;; ========================================

;; Extract a Racket natural number from an expr-zero/expr-suc chain, or #f if not a numeral.
(define (nat-value e)
  (match e
    [(expr-zero) 0]
    [(expr-suc e1) (let ([v (nat-value e1)]) (and v (+ v 1)))]
    [_ #f]))

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
;; 'prologos.data.list/cons → 'cons, 'cons → 'cons
(define (ctor-short-name fqn)
  (define parts (string-split (symbol->string fqn) "/"))
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
    [else #f]))

;; Reify a Church-encoded value into constructor-application form.
;; Church-fold the lambda with constructors as branch arguments so that
;; structural PM can decompose the result.
;; scrut is a lambda (Church encoding), arms give us the constructor names.
;; Returns a reified expression (constructor applications) or #f.
(define (try-reify-church scrut arms)
  ;; Find the constructor metadata from the first arm
  (define first-ctor-name (expr-reduce-arm-ctor-name (car arms)))
  (define meta (or (lookup-ctor first-ctor-name)
                   ;; Try FQN lookup through global env constructors
                   (for/or ([arm (in-list arms)])
                     (define name (expr-reduce-arm-ctor-name arm))
                     (or (lookup-ctor name)
                         ;; Search ctor registry for a name ending with this short name
                         (for/or ([(k v) (in-hash (current-ctor-registry))])
                           (and (eq? (ctor-short-name k) name) v))))))
  (and meta
       (let* ([type-name (ctor-meta-type-name meta)]
              [type-ctors (lookup-type-ctors type-name)])
         (and type-ctors
              ;; Build Church fold: scrut (hole) ctor1-wrapper ctor2-wrapper ...
              ;; Each ctor-wrapper wraps the constructor fvar in lambdas for its fields,
              ;; applying the fvar to holes (for type params) and bvars (for fields).
              (let ([branch-args
                     (for/list ([ctor-name (in-list type-ctors)])
                       (define cmeta (or (lookup-ctor ctor-name)
                                        (for/or ([(k v) (in-hash (current-ctor-registry))])
                                          (and (eq? (ctor-short-name k) ctor-name) v))))
                       (if (not cmeta)
                           (expr-hole) ;; shouldn't happen, but be defensive
                           (let* ([n-params (length (ctor-meta-params cmeta))]
                                  [n-fields (length (ctor-meta-field-types cmeta))]
                                  ;; Build the fvar name — prefer FQN if available
                                  [fvar-name
                                   (or (for/or ([(k v) (in-hash (current-ctor-registry))])
                                         (and (eq? v cmeta) k))
                                       ctor-name)]
                                  ;; Build inner application: (fvar-name hole ... bvar(n-1) ... bvar(0))
                                  [inner
                                   (let* ([base (expr-fvar fvar-name)]
                                          ;; Apply type params as holes
                                          [with-params
                                           (for/fold ([app base])
                                                     ([_ (in-range n-params)])
                                             (expr-app app (expr-hole)))]
                                          ;; Apply field bvars: bvar(n-1), bvar(n-2), ..., bvar(0)
                                          [with-fields
                                           (for/fold ([app with-params])
                                                     ([i (in-range n-fields)])
                                             (expr-app app (expr-bvar (- n-fields 1 i))))])
                                     with-fields)])
                             ;; Wrap in lambdas for each field
                             (for/fold ([e inner])
                                       ([_ (in-range n-fields)])
                               (expr-lam 'mw (expr-hole) e)))))])
                ;; Build Church fold application: (((...(scrut (hole)) ctor1) ctor2) ...)
                (let ([app (foldl (lambda (branch acc)
                                   (expr-app acc branch))
                                 (expr-app scrut (expr-hole))
                                 branch-args)])
                  ;; Beta-reduce only (no fvar unfolding) to get constructor apps
                  (whnf-no-unfold app)))))))

;; ========================================
;; Beta-only WHNF — no global definition unfolding
;; Used by try-reify-church to Church-fold a value into
;; constructor applications without re-unfolding the constructors.
;; ========================================
(define (whnf-no-unfold e)
  (match e
    [(expr-app (expr-lam _ _ body) arg)
     (whnf-no-unfold (subst 0 arg body))]
    [(expr-app f arg)
     (let ([f* (whnf-no-unfold f)])
       (if (equal? f* f)
           e
           (whnf-no-unfold (expr-app f* arg))))]
    [(expr-fst (expr-pair e1 _)) (whnf-no-unfold e1)]
    [(expr-snd (expr-pair _ e2)) (whnf-no-unfold e2)]
    [(expr-ann e1 _) (whnf-no-unfold e1)]
    [_ e]))

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

    ;; Reduce: dispatch based on structural? flag
    ;; structural? = #f → Church fold (fold semantics, recursive fields are accumulators)
    ;; structural? = #t → True structural PM (recursive fields are raw values)
    [(expr-reduce scrutinee arms #f)
     ;; Church fold desugaring
     (define scrut-whnf (whnf scrutinee))
     (define branch-lams
       (for/list ([arm (in-list arms)])
         (define bc (expr-reduce-arm-binding-count arm))
         (define body (expr-reduce-arm-body arm))
         (if (= bc 0)
             body
             (for/fold ([inner body])
                       ([_ (in-range bc)])
               (expr-lam 'mw (expr-hole) inner)))))
     (define church-app
       (foldl (lambda (branch app-so-far)
                (expr-app app-so-far branch))
              (expr-app scrut-whnf (expr-hole))
              branch-lams))
     (whnf church-app)]

    [(expr-reduce scrutinee arms #t)
     ;; True structural pattern matching: decompose scrutinee as constructor,
     ;; substitute field values into matching arm body.
     ;; Try user-defined constructors (fvar applications) first, then built-in
     ;; constructors (expr-zero, expr-suc, expr-true, expr-false).
     (define scrut-whnf* (whnf scrutinee))
     (define struct-result (or (try-structural-reduce scrutinee arms)
                               (try-structural-reduce scrut-whnf* arms)
                               (try-builtin-reduce scrut-whnf* arms)))
     (cond
       [struct-result (whnf struct-result)]
       ;; Structural PM stuck on a Church-encoded value (lambda).
       ;; Reify: Church-fold the scrutinee with the actual constructors
       ;; to produce constructor applications, then retry structural PM.
       [(expr-lam? scrut-whnf*)
        (define reified (try-reify-church scrut-whnf* arms))
        (if reified
            (whnf (expr-reduce reified arms #t))
            e)]
       [else e])]

    ;; Free variable: unfold global definition if available
    [(expr-fvar name)
     (let ([val (global-env-lookup-value name)])
       (if val (whnf val) e))]

    ;; Metavariable: if solved, reduce solution; if unsolved, stuck
    [(expr-meta id)
     (let ([sol (meta-solution id)])
       (if sol (whnf sol) e))]

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
