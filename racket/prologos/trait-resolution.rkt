#lang racket/base

;;;
;;; PROLOGOS TRAIT RESOLUTION
;;; Resolves trait-constraint metavariables to concrete dictionary expressions.
;;; After type-checking, walks the trait-constraint map and solves metas
;;; whose type arguments are fully ground.
;;;

(require racket/match
         racket/list
         racket/string
         "syntax.rkt"
         "prelude.rkt"
         "metavar-store.rkt"
         "macros.rkt"
         "zonk.rkt"
         "unify.rkt"
         "errors.rkt"
         "source-location.rkt")

(provide resolve-trait-constraints!
         check-unresolved-trait-constraints
         ;; Exposed for testing
         try-monomorphic-resolve
         try-parametric-resolve
         expr->impl-key-str
         ground-expr?
         match-type-pattern
         match-one
         build-parametric-dict-expr)

;; ========================================
;; Ground expression check
;; ========================================

;; Check whether an expression contains no unsolved metavariables.
;; Uses structural recursion on the common expression forms.
(define (ground-expr? e)
  (match e
    [(expr-meta id) (and (meta-solved? id) (ground-expr? (meta-solution id)))]
    [(expr-app f a) (and (ground-expr? f) (ground-expr? a))]
    [(expr-Pi m d c) (and (ground-expr? d) (ground-expr? c))]
    [(expr-lam m d b) (and (ground-expr? d) (ground-expr? b))]
    [(expr-Sigma d c) (and (ground-expr? d) (ground-expr? c))]
    [(expr-pair e1 e2) (and (ground-expr? e1) (ground-expr? e2))]
    [(expr-fvar _) #t]
    [(expr-bvar _) #t]
    [(expr-tycon _) #t]
    [(expr-Nat) #t]
    [(expr-Bool) #t]
    [(expr-Int) #t]
    [(expr-Rat) #t]
    [(expr-Posit8) #t]
    [(expr-Posit16) #t]
    [(expr-Posit32) #t]
    [(expr-Posit64) #t]
    [(expr-Keyword) #t]
    [(expr-Char) #t]
    [(expr-String) #t]
    [(expr-zero) #t]
    [(expr-true) #t]
    [(expr-false) #t]
    [(expr-Type _) #t]
    [(expr-hole) #t]
    ;; Built-in parameterized types: check their sub-expressions
    [(expr-PVec a) (ground-expr? a)]
    [(expr-Set a) (ground-expr? a)]
    [(expr-Map k v) (and (ground-expr? k) (ground-expr? v))]
    [_ #t]))  ;; conservative: treat unknown nodes as ground

;; ========================================
;; Core expression → impl key string
;; ========================================

;; Convert a core expression to the string format used by process-impl's
;; key generation (e.g., expr-Nat → "Nat", (app (fvar List) Nat) → "List-Nat")
(define (expr->impl-key-str e)
  (match e
    [(expr-Nat) "Nat"]
    [(expr-Bool) "Bool"]
    [(expr-Int) "Int"]
    [(expr-Rat) "Rat"]
    [(expr-Posit8) "Posit8"]
    [(expr-Posit16) "Posit16"]
    [(expr-Posit32) "Posit32"]
    [(expr-Posit64) "Posit64"]
    [(expr-Keyword) "Keyword"]
    [(expr-Char) "Char"]
    [(expr-String) "String"]
    ;; HKT: unapplied type constructor
    [(expr-tycon name) (symbol->string name)]
    ;; Built-in parameterized types: extract constructor name
    [(expr-PVec _) "PVec"]
    [(expr-Set _) "Set"]
    [(expr-Map _ _) "Map"]
    [(expr-fvar name) (symbol->string (strip-ns name))]
    [(expr-app f a)
     (string-append (expr->impl-key-str f) "-" (expr->impl-key-str a))]
    [(expr-meta id)
     ;; If solved, chase the solution
     (if (meta-solved? id)
         (expr->impl-key-str (meta-solution id))
         (format "?~a" id))]
    [_ (format "~a" e)]))

;; ========================================
;; Monomorphic resolution
;; ========================================

;; Try to resolve a trait constraint to a concrete (monomorphic) impl dict.
;; Returns (expr-fvar dict-name) on success, #f on failure.
(define (try-monomorphic-resolve trait-name type-args)
  (define type-arg-str
    (string-join (map expr->impl-key-str type-args) "-"))
  (define impl-key
    (string->symbol (string-append type-arg-str "--" (symbol->string trait-name))))
  (define entry (lookup-impl impl-key))
  (and entry (expr-fvar (impl-entry-dict-name entry))))

;; ========================================
;; Parametric resolution (pattern matching)
;; ========================================

;; Helper: decompose a core expression application into head + args.
(define (decompose-app-core e acc)
  (match e
    [(expr-app f a) (decompose-app-core f (cons a acc))]
    [_ (values e acc)]))

;; Strip namespace qualifier from a symbol: 'ns::name → 'name
(define (strip-ns sym)
  (define s (symbol->string sym))
  (define idx (let loop ([i (- (string-length s) 1)])
                (cond [(< i 1) #f]
                      [(and (char=? (string-ref s i) #\:)
                            (char=? (string-ref s (sub1 i)) #\:))
                       i]
                      [else (loop (sub1 i))])))
  (if idx (string->symbol (substring s (add1 idx))) sym))

;; Match a symbol against a pattern symbol, considering namespace qualifiers.
;; 'prologos::data::list::List matches pattern 'List
(define (symbol-matches? pattern name)
  (or (eq? pattern name)
      (eq? pattern (strip-ns name))))

;; Match a single core expression against a single datum pattern.
;; pvars: list of pattern variable symbols.
;; bindings: hasheq of pattern-var → core-expr.
;; Returns updated bindings on success, #f on failure.
(define (match-one core-expr pattern pvars bindings)
  (cond
    ;; Pattern variable: bind or check consistency
    [(and (symbol? pattern) (memq pattern pvars))
     (define existing (hash-ref bindings pattern #f))
     (if existing
         (and (expr-equal? existing core-expr) bindings)
         (hash-set bindings pattern core-expr))]
    ;; Concrete symbol: match builtin or fvar or tycon
    [(symbol? pattern)
     (match core-expr
       [(expr-Nat) (and (eq? pattern 'Nat) bindings)]
       [(expr-Bool) (and (eq? pattern 'Bool) bindings)]
       [(expr-Int) (and (eq? pattern 'Int) bindings)]
       [(expr-Rat) (and (eq? pattern 'Rat) bindings)]
       [(expr-Posit8) (and (eq? pattern 'Posit8) bindings)]
       [(expr-Posit16) (and (eq? pattern 'Posit16) bindings)]
       [(expr-Posit32) (and (eq? pattern 'Posit32) bindings)]
       [(expr-Posit64) (and (eq? pattern 'Posit64) bindings)]
       [(expr-Keyword) (and (eq? pattern 'Keyword) bindings)]
       [(expr-Char) (and (eq? pattern 'Char) bindings)]
       [(expr-String) (and (eq? pattern 'String) bindings)]
       ;; HKT: unapplied type constructor matches its name
       [(expr-tycon name) (and (symbol-matches? pattern name) bindings)]
       [(expr-fvar n) (and (symbol-matches? pattern n) bindings)]
       [_ #f])]
    ;; Compound pattern: (Constructor Args...)
    [(list? pattern)
     (define-values (head args) (decompose-app-core core-expr '()))
     (define phead (car pattern))
     (define pargs (cdr pattern))
     (and (= (length args) (length pargs))
          (let ([hb (match-one head phead pvars bindings)])
            (and hb
                 (let loop ([as args] [ps pargs] [bs hb])
                   (cond
                     [(null? as) bs]
                     [else
                      (define nb (match-one (car as) (car ps) pvars bs))
                      (and nb (loop (cdr as) (cdr ps) nb))])))))]
    [else #f]))

;; Structural expression equality (simple, no alpha-equivalence needed here
;; since we're comparing ground types).
(define (expr-equal? a b)
  (equal? a b))  ;; #:transparent structs → structural equality via equal?

;; Match core type-arg expressions against a param-impl-entry's type patterns.
;; Returns hasheq of (pattern-var → core-expr) on success, #f on failure.
(define (match-type-pattern type-args pentry)
  (define patterns (param-impl-entry-type-pattern pentry))
  (define pvars (param-impl-entry-pattern-vars pentry))
  (and (= (length type-args) (length patterns))
       (let loop ([cs type-args] [ps patterns] [bindings (hasheq)])
         (cond
           [(null? cs) bindings]
           [else
            (define nb (match-one (car cs) (car ps) pvars bindings))
            (and nb (loop (cdr cs) (cdr ps) nb))]))))

;; Resolve sub-constraints from a parametric impl's where clause.
;; Returns (listof dict-expr) or #f if any unresolvable.
(define (resolve-sub-constraints where-constraints bindings)
  (let loop ([remaining where-constraints] [acc '()])
    (cond
      [(null? remaining) (reverse acc)]
      [else
       (define c (car remaining))
       (define trait (car c))
       (define type-vars (cdr c))
       ;; Look up concrete type args from bindings
       (define concrete-args
         (for/list ([tv (in-list type-vars)])
           (hash-ref bindings tv #f)))
       ;; If any binding is missing, can't resolve
       (if (ormap not concrete-args)
           #f
           (let ([resolved
                  (or (try-monomorphic-resolve trait concrete-args)
                      (try-parametric-resolve trait concrete-args))])
             (if resolved
                 (loop (cdr remaining) (cons resolved acc))
                 #f)))])))

;; Build the parametric dict expression:
;; (app (app ... (app (fvar dict-fn) type-arg1) type-arg2) ... sub-dict1) ... sub-dictN)
(define (build-parametric-dict-expr pentry bindings sub-dicts)
  (define base (expr-fvar (param-impl-entry-dict-name pentry)))
  ;; Apply pattern-var bindings as type args
  (define with-types
    (for/fold ([acc base]) ([pv (in-list (param-impl-entry-pattern-vars pentry))])
      (expr-app acc (hash-ref bindings pv))))
  ;; Apply sub-constraint dicts
  (for/fold ([acc with-types]) ([sd (in-list sub-dicts)])
    (expr-app acc sd)))

;; Try to resolve a trait constraint using parametric impl entries.
;; Returns a dict expression on success, #f on failure.
;; HKT-4: Most-specific-wins resolution for parametric impls.
;; Collects ALL matching entries and picks the most specific (fewest pattern vars).
;; If multiple matches have the same specificity, picks the first (future: ambiguity error in HKT-7).
(define (try-parametric-resolve trait-name type-args)
  (define param-impls (lookup-param-impls trait-name))
  ;; Collect ALL matching entries with their bindings and sub-dicts
  (define matches
    (for/fold ([acc '()])
              ([pentry (in-list param-impls)])
      (define bindings (match-type-pattern type-args pentry))
      (if (not bindings)
          acc
          (let ([sub-dicts (resolve-sub-constraints
                             (param-impl-entry-where-constraints pentry)
                             bindings)])
            (if (not sub-dicts)
                acc
                (cons (list pentry bindings sub-dicts) acc))))))
  (cond
    [(null? matches) #f]
    [(= (length matches) 1)
     (apply build-parametric-dict-expr (car matches))]
    [else
     ;; Multiple matches: pick most specific (fewest pattern vars)
     (define sorted
       (sort matches <
         #:key (lambda (m)
                 (length (param-impl-entry-pattern-vars (car m))))))
     (apply build-parametric-dict-expr (car sorted))]))

;; ========================================
;; Main resolution entry point
;; ========================================

;; Walk all trait-constraint metas and resolve those with ground type args.
;; HKT: normalize type args via normalize-for-resolution so that built-in
;; types like (expr-PVec A) are converted to (expr-app (expr-tycon 'PVec) A)
;; and type constructor fvars like (expr-fvar 'List) become (expr-tycon 'List).
(define (resolve-trait-constraints!)
  (for ([(meta-id tc-info) (in-hash (current-trait-constraint-map))])
    (unless (meta-solved? meta-id)
      (define trait-name (trait-constraint-info-trait-name tc-info))
      (define type-args (map (lambda (e) (normalize-for-resolution (zonk e)))
                             (trait-constraint-info-type-arg-exprs tc-info)))
      (when (andmap ground-expr? type-args)
        (define dict-expr
          (or (try-monomorphic-resolve trait-name type-args)
              (try-parametric-resolve trait-name type-args)))
        (when dict-expr
          (solve-meta! meta-id dict-expr))))))

;; ========================================
;; Unresolved constraint checking
;; ========================================

;; Return a list of no-instance-error structs for trait constraints that
;; have ground type args but remain unsolved (i.e., no matching impl found).
;; Each error includes the source location from the meta that created it.
;; Enhanced with available instance listing, kind mismatch detection, and hints.
(define (check-unresolved-trait-constraints)
  (for/list ([(meta-id tc-info) (in-hash (current-trait-constraint-map))]
             #:when (not (meta-solved? meta-id))
             #:when (andmap ground-expr?
                           (map (lambda (e) (normalize-for-resolution (zonk e)))
                                (trait-constraint-info-type-arg-exprs tc-info))))
    (define trait-name (trait-constraint-info-trait-name tc-info))
    (define type-args (map (lambda (e) (normalize-for-resolution (zonk e)))
                           (trait-constraint-info-type-arg-exprs tc-info)))
    (define type-args-str
      (string-join (map expr->impl-key-str type-args) " "))
    ;; Recover source location from the meta's source info
    (define minfo (meta-lookup meta-id))
    (define src (and minfo (meta-info-source minfo)))
    (define loc
      (if (and src (meta-source-info? src))
          (meta-source-info-loc src)
          srcloc-unknown))

    ;; Enhanced error: detect kind mismatch and list available instances
    (define kind-mismatch (detect-kind-mismatch trait-name type-args))
    (define available (collect-available-instances trait-name))

    (define message
      (cond
        ;; Kind mismatch — e.g., (Seqable Int) when Seqable expects Type -> Type
        [kind-mismatch
         (format "Kind mismatch in constraint (~a ~a): ~a"
                 trait-name type-args-str kind-mismatch)]
        ;; No instance — list available instances and provide hint
        [else
         (define avail-str
           (if (null? available)
               ""
               (format "\n  Available instances: ~a"
                       (string-join
                        (map (lambda (i) (format "~a ~a" trait-name i))
                             available)
                        ", "))))
         (define hint
           (let ([tm (lookup-trait trait-name)])
             (if tm
                 (let ([methods (trait-meta-methods tm)])
                   (format "\n  Hint: Define 'impl ~a ~a' with method~a ~a."
                           trait-name type-args-str
                           (if (> (length methods) 1) "s" "")
                           (string-join (map (lambda (m) (format "'~a'" (trait-method-name m))) methods)
                                        ", ")))
                 "")))
         (format "No instance of ~a for ~a~a~a"
                 trait-name type-args-str avail-str hint)]))

    (no-instance-error loc message trait-name type-args-str)))

;; Collect all registered instances for a trait, returning short display strings.
;; Checks both monomorphic registry (e.g., "Nat--Eq" → "Nat") and
;; parametric registry (e.g., param-impl for "(List A)" → "(List A)").
(define (collect-available-instances trait-name)
  (define trait-str (symbol->string trait-name))
  (define suffix (string-append "--" trait-str))
  ;; Monomorphic instances: extract type name from "TypeName--TraitName" keys
  (define mono-instances
    (for/list ([(k _v) (in-hash (current-impl-registry))]
               #:when (let ([ks (symbol->string k)])
                        (and (> (string-length ks) (string-length suffix))
                             (string-suffix? ks suffix))))
      (define ks (symbol->string k))
      (substring ks 0 (- (string-length ks) (string-length suffix)))))
  ;; Parametric instances: show the type pattern
  (define param-instances
    (for/list ([pe (in-list (lookup-param-impls trait-name))])
      (define pat (param-impl-entry-type-pattern pe))
      (if (and (list? pat) (= (length pat) 1))
          (format "~a" (car pat))
          (format "(~a)" (string-join (map (lambda (x) (format "~a" x)) pat) " ")))))
  (append mono-instances param-instances))

;; Detect kind mismatch: returns a descriptive string or #f.
;; A kind mismatch occurs when a trait expects a higher-kinded argument
;; (e.g., Type -> Type) but receives a ground type (e.g., Nat, Int).
(define (detect-kind-mismatch trait-name type-args)
  (define tm (lookup-trait trait-name))
  (and tm
       (not (null? (trait-meta-params tm)))
       (let ([expected-kind (cdr (car (trait-meta-params tm)))])
         ;; Check if trait expects a type constructor (kind includes ->)
         (and (list? expected-kind)
              (memq '-> expected-kind)
              (not (null? type-args))
              (let ([ta (car type-args)])
                ;; Ground types that are NOT type constructors
                (and (not (expr-tycon? ta))
                     (not (expr-fvar? ta))
                     (not (expr-app? ta))
                     ;; It's a concrete ground type like Nat, Int, Bool
                     (let ([ta-str (expr->impl-key-str ta)]
                           [expected-str (format "~a" expected-kind)])
                       (format "~a expects a type constructor (kind ~a), but ~a has kind Type"
                               trait-name expected-str ta-str))))))))
