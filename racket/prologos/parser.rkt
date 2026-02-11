#lang racket/base

;;;
;;; PROLOGOS PARSER
;;; Transforms Racket S-expressions (from read/read-syntax) into surface AST.
;;; Uses Racket's reader for lexing; this module does semantic parsing.
;;;

(require racket/match
         racket/port
         racket/list
         "source-location.rkt"
         "surface-syntax.rkt"
         "errors.rkt"
         "sexp-readtable.rkt"
         "macros.rkt")

(provide parse-datum
         parse-string
         parse-port)

;; ========================================
;; Keywords: forms with special parsing rules
;; ========================================
(define keywords
  '(inc fn Pi Sigma -> Eq the the-fn Type
    Vec Fin vnil vcons vhead vtail vindex fzero fsuc
    natrec J pair first second boolrec
    Posit8 posit8 p8+ p8- p8* p8/ p8-neg p8-abs p8-sqrt p8-lt p8-le p8-from-nat p8-if-nar
    def defn check eval infer reduce match
    ;; Pre-parse macros — should be expanded before reaching parser
    defmacro let do if deftype data
    ;; Pre-parse namespace directives — consumed before reaching parser
    ns require provide))

(define (keyword? sym)
  (and (symbol? sym) (memq sym keywords)))

;; ========================================
;; Source location extraction
;; ========================================

;; Extract srcloc from a syntax object or datum
(define (datum-srcloc stx)
  (if (syntax? stx)
      (srcloc (or (syntax-source stx) "<unknown>")
              (or (syntax-line stx) 0)
              (or (syntax-column stx) 0)
              (or (syntax-span stx) 0))
      srcloc-unknown))

;; Unwrap syntax to datum, preserving nested syntax for sub-parsing
(define (stx->datum stx)
  (if (syntax? stx)
      (syntax-e stx)
      stx))

;; ========================================
;; $angle-type helpers
;; ========================================
;; Both readers emit <content> as ($angle-type content...) in the datum tree.
;; These helpers detect and unwrap angle-type nodes.

(define (angle-type? d)
  ;; Check if datum is ($angle-type ...)
  ;; d could be a plain list or a list of syntax objects
  (and (pair? d)
       (let ([head (car d)])
         (cond
           [(symbol? head) (eq? head '$angle-type)]
           [(syntax? head) (eq? (syntax-e head) '$angle-type)]
           [else #f]))))

(define (angle-type-stx? stx)
  ;; Check if a syntax object wraps an ($angle-type ...) form
  (define d (stx->datum stx))
  (cond
    ;; If stx->datum returned syntax-e, the car might be a syntax object
    [(pair? d) (angle-type? d)]
    [else #f]))

;; ========================================
;; Brace params: {A B C} → ($brace-params A B C)
;; Used for implicit type parameters in defn and data.
;; ========================================

(define (brace-params? d)
  ;; Check if datum is ($brace-params ...)
  (and (pair? d)
       (let ([head (car d)])
         (cond
           [(symbol? head) (eq? head '$brace-params)]
           [(syntax? head) (eq? (syntax-e head) '$brace-params)]
           [else #f]))))

(define (brace-params-stx? stx)
  ;; Check if a syntax object wraps a ($brace-params ...) form
  (define d (stx->datum stx))
  (cond
    [(pair? d) (brace-params? d)]
    [else #f]))

(define (unwrap-brace-params stx loc)
  ;; Extract the symbols from ($brace-params A B C)
  ;; Returns a list of binder-info structs, each with :0 multiplicity and Type 0
  (define d (stx->datum stx))
  (define contents (cdr d)) ; skip $brace-params sentinel
  (define parts
    (if (syntax? stx) (cdr (syntax->list stx)) contents))
  (for/list ([p (in-list parts)])
    (define name (if (syntax? p) (syntax-e p) p))
    (unless (symbol? name)
      (parse-error loc (format "Implicit type parameter must be a symbol, got ~a" name) name))
    (binder-info name 'm0 (surf-type 0 loc))))

(define (unwrap-angle-type stx loc)
  ;; Extract and parse the type from ($angle-type content...)
  ;; If single content element: parse it directly
  ;; If multiple elements: wrap in a list and parse as application
  (define d (stx->datum stx))
  (define contents (cdr d)) ; skip $angle-type sentinel
  (define parts
    (if (syntax? stx) (cdr (syntax->list stx)) contents))
  (cond
    [(null? contents)
     (parse-error loc "Empty type annotation <>" #f)]
    [(= (length contents) 1)
     ;; Single element: <Nat> or <Bool> etc
     (parse-datum (car parts))]
    [else
     ;; Multiple elements: <(-> Nat Nat)> reads as ($angle-type (-> Nat Nat))
     ;; which is single. But <A B> would be two elements — treat as (A B) application
     (parse-datum (car parts))]))  ; For now, only use first element

;; ========================================
;; Main parser: datum -> surface AST
;; ========================================

;; Parse a single datum (syntax object or plain datum) into surface AST.
;; Returns either a surface AST node or a prologos-error.
(define (parse-datum stx)
  (define loc (datum-srcloc stx))
  (define d (stx->datum stx))
  (cond
    ;; Bare symbol
    [(symbol? d)
     (parse-symbol d loc)]

    ;; Bare number (natural literal)
    [(and (exact-nonnegative-integer? d) (integer? d))
     (if (= d 0)
         (surf-zero loc)
         (surf-nat-lit d loc))]

    ;; List form
    [(pair? d)
     (parse-list d loc stx)]

    [else
     (parse-error loc (format "Unexpected datum: ~a" d) d)]))

;; ========================================
;; Parse bare symbols
;; ========================================
(define (parse-symbol sym loc)
  (case sym
    [(_)      (surf-hole loc)]
    [(Nat)    (surf-nat-type loc)]
    [(Bool)   (surf-bool-type loc)]
    [(Posit8) (surf-posit8-type loc)]
    [(Type)   (surf-type 0 loc)]      ;; bare Type defaults to (Type 0)
    [(zero)   (surf-zero loc)]
    [(true)   (surf-true loc)]
    [(false)  (surf-false loc)]
    [(refl)   (surf-refl loc)]
    [else     (surf-var sym loc)]))

;; ========================================
;; Parse list forms: (op arg ...)
;; ========================================
(define (parse-list elems loc stx)
  ;; elems is either a list of syntax objects or plain datums
  ;; Normalize: if stx is a syntax object, get the list of syntax children
  (define parts
    (if (syntax? stx)
        (syntax->list stx)
        (map (lambda (x) x) elems)))

  (when (null? parts)
    (parse-error loc "Empty form" '()))

  (define head-stx (car parts))
  (define head (stx->datum head-stx))
  (define args (cdr parts))

  (cond
    ;; Keyword-headed forms
    [(symbol? head)
     (case head
       ;; (inc e)
       [(inc)
        (or (check-arity 'inc args 1 loc)
            (let ([e (parse-datum (car args))])
              (if (prologos-error? e) e
                  (surf-suc e loc))))]

       ;; (fn (x : T) body) or (fn (x :m T) body) or (fn [x <T>] body)
       ;; Also: (fn a b c body) — multi-arg untyped fn (all-but-last are bare symbols)
       [(fn)
        (cond
          [(< (length args) 2)
           (parse-error loc "fn requires at least 2 arguments" #f)]
          ;; Standard: (fn binder body) — exactly 2 args, first is a binder (pair)
          [(and (= (length args) 2)
                (pair? (stx->datum (car args))))
           (let ([bnd (parse-binder (car args) loc)])
             (if (prologos-error? bnd) bnd
                 (let ([body (parse-datum (cadr args))])
                   (if (prologos-error? body) body
                       (surf-lam bnd body loc)))))]
          ;; Multi-arg untyped: (fn a body) or (fn a b c body) — all-but-last are bare symbols
          [else
           (define params (drop-right args 1))
           (define body-stx (last args))
           (define all-symbols?
             (andmap (lambda (a) (symbol? (stx->datum a))) params))
           (cond
             [all-symbols?
              ;; Desugar: (fn a b c body) → nested surf-lam with surf-hole types
              (define param-names (map stx->datum params))
              (define body (parse-datum body-stx))
              (if (prologos-error? body) body
                  (foldr (lambda (name inner)
                           (surf-lam (binder-info name 'mw (surf-hole loc)) inner loc))
                         body param-names))]
             [else
              (parse-error loc "fn: all parameters except body must be bare symbols or a binder (x : T)" #f)])])]

       ;; (Pi (x : T) body) or (Pi (x :m T) body)
       [(Pi)
        (or (check-arity 'Pi args 2 loc)
            (let ([bnd (parse-binder (car args) loc)])
              (if (prologos-error? bnd) bnd
                  (let ([body (parse-datum (cadr args))])
                    (if (prologos-error? body) body
                        (surf-pi bnd body loc))))))]

       ;; (Sigma (x : T) body)
       [(Sigma)
        (or (check-arity 'Sigma args 2 loc)
            (let ([bnd (parse-binder (car args) loc)])
              (if (prologos-error? bnd) bnd
                  (let ([body (parse-datum (cadr args))])
                    (if (prologos-error? body) body
                        (surf-sigma bnd body loc))))))]

       ;; (-> A B)
       [(->)
        (or (check-arity '-> args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond
                [(prologos-error? a) a]
                [(prologos-error? b) b]
                [else (surf-arrow a b loc)])))]

       ;; (Eq A a b)
       [(Eq)
        (or (check-arity 'Eq args 3 loc)
            (let ([a (parse-datum (car args))]
                  [lhs (parse-datum (cadr args))]
                  [rhs (parse-datum (caddr args))])
              (cond
                [(prologos-error? a) a]
                [(prologos-error? lhs) lhs]
                [(prologos-error? rhs) rhs]
                [else (surf-eq a lhs rhs loc)])))]

       ;; (the T e) or (the <T> e)
       [(the)
        (or (check-arity 'the args 2 loc)
            (let ([t (if (angle-type-stx? (car args))
                         (unwrap-angle-type (car args) loc)
                         (parse-datum (car args)))]
                  [e (parse-datum (cadr args))])
              (cond
                [(prologos-error? t) t]
                [(prologos-error? e) e]
                [else (surf-ann t e loc)])))]

       ;; (Type n)
       [(Type)
        (or (check-arity 'Type args 1 loc)
            (let ([n (stx->datum (car args))])
              (if (and (exact-nonnegative-integer? n) (integer? n))
                  (surf-type n loc)
                  (parse-error loc (format "Type level must be a natural number, got ~a" n) n))))]

       ;; (pair a b)
       [(pair)
        (or (check-arity 'pair args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond
                [(prologos-error? a) a]
                [(prologos-error? b) b]
                [else (surf-pair a b loc)])))]

       ;; (first e), (second e)
       [(first)
        (or (check-arity 'first args 1 loc)
            (let ([e (parse-datum (car args))])
              (if (prologos-error? e) e (surf-fst e loc))))]
       [(second)
        (or (check-arity 'second args 1 loc)
            (let ([e (parse-datum (car args))])
              (if (prologos-error? e) e (surf-snd e loc))))]

       ;; (boolrec motive true-case false-case target)
       ;; Constant motive shorthand: if motive is not (fn ...) or (the ...),
       ;; treat it as a constant return type and wrap:
       ;;   TYPE → (the (-> Bool (Type 0)) (fn [_ <Bool>] TYPE))
       [(boolrec)
        (or (check-arity 'boolrec args 4 loc)
            (let* ([mot-raw (stx->datum (car args))]
                   [mot-head (and (pair? mot-raw)
                                  (let ([h (car mot-raw)])
                                    (if (syntax? h) (syntax-e h) h)))]
                   [explicit-motive? (and mot-head (symbol? mot-head)
                                          (memq mot-head '(fn the)))]
                   [mot (if explicit-motive?
                            (parse-datum (car args))
                            (let ([type-expr (parse-datum (car args))])
                              (if (prologos-error? type-expr) type-expr
                                  (surf-ann
                                   (surf-arrow (surf-bool-type loc) (surf-type 0 loc) loc)
                                   (surf-lam (binder-info '_ 'mw (surf-bool-type loc))
                                             type-expr loc)
                                   loc))))]
                   [tc (parse-datum (cadr args))]
                   [fc (parse-datum (caddr args))]
                   [tgt (parse-datum (cadddr args))])
              (cond
                [(prologos-error? mot) mot]
                [(prologos-error? tc) tc]
                [(prologos-error? fc) fc]
                [(prologos-error? tgt) tgt]
                [else (surf-boolrec mot tc fc tgt loc)])))]

       ;; (natrec motive base step target)
       ;; Constant motive shorthand: if motive is not (fn ...) or (the ...),
       ;; treat it as a constant return type and wrap:
       ;;   TYPE → (the (-> Nat (Type 0)) (fn [_ <Nat>] TYPE))
       [(natrec)
        (or (check-arity 'natrec args 4 loc)
            (let* ([mot-raw (stx->datum (car args))]
                   [mot-head (and (pair? mot-raw)
                                  (let ([h (car mot-raw)])
                                    (if (syntax? h) (syntax-e h) h)))]
                   [explicit-motive? (and mot-head (symbol? mot-head)
                                          (memq mot-head '(fn the)))]
                   [mot (if explicit-motive?
                            (parse-datum (car args))
                            (let ([type-expr (parse-datum (car args))])
                              (if (prologos-error? type-expr) type-expr
                                  (surf-ann
                                   (surf-arrow (surf-nat-type loc) (surf-type 0 loc) loc)
                                   (surf-lam (binder-info '_ 'mw (surf-nat-type loc))
                                             type-expr loc)
                                   loc))))]
                   [base (parse-datum (cadr args))]
                   [step (parse-datum (caddr args))]
                   [tgt (parse-datum (cadddr args))])
              (cond
                [(prologos-error? mot) mot]
                [(prologos-error? base) base]
                [(prologos-error? step) step]
                [(prologos-error? tgt) tgt]
                [else (surf-natrec mot base step tgt loc)])))]

       ;; (J motive base left right proof)
       [(J)
        (or (check-arity 'J args 5 loc)
            (let ([mot (parse-datum (list-ref args 0))]
                  [base (parse-datum (list-ref args 1))]
                  [left (parse-datum (list-ref args 2))]
                  [right (parse-datum (list-ref args 3))]
                  [proof (parse-datum (list-ref args 4))])
              (cond
                [(prologos-error? mot) mot]
                [(prologos-error? base) base]
                [(prologos-error? left) left]
                [(prologos-error? right) right]
                [(prologos-error? proof) proof]
                [else (surf-J mot base left right proof loc)])))]

       ;; Vec/Fin forms
       [(Vec)
        (or (check-arity 'Vec args 2 loc)
            (let ([a (parse-datum (car args))]
                  [n (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? n) n]
                    [else (surf-vec-type a n loc)])))]
       [(vnil)
        (or (check-arity 'vnil args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-vnil a loc))))]
       [(vcons)
        (or (check-arity 'vcons args 4 loc)
            (let ([a (parse-datum (car args))]
                  [n (parse-datum (cadr args))]
                  [hd (parse-datum (caddr args))]
                  [tl (parse-datum (cadddr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? n) n]
                    [(prologos-error? hd) hd]
                    [(prologos-error? tl) tl]
                    [else (surf-vcons a n hd tl loc)])))]
       [(Fin)
        (or (check-arity 'Fin args 1 loc)
            (let ([n (parse-datum (car args))])
              (if (prologos-error? n) n (surf-fin-type n loc))))]
       [(fzero)
        (or (check-arity 'fzero args 1 loc)
            (let ([n (parse-datum (car args))])
              (if (prologos-error? n) n (surf-fzero n loc))))]
       [(fsuc)
        (or (check-arity 'fsuc args 2 loc)
            (let ([n (parse-datum (car args))]
                  [i (parse-datum (cadr args))])
              (cond [(prologos-error? n) n]
                    [(prologos-error? i) i]
                    [else (surf-fsuc n i loc)])))]
       [(vhead)
        (or (check-arity 'vhead args 3 loc)
            (let ([a (parse-datum (car args))]
                  [n (parse-datum (cadr args))]
                  [v (parse-datum (caddr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? n) n]
                    [(prologos-error? v) v]
                    [else (surf-vhead a n v loc)])))]
       [(vtail)
        (or (check-arity 'vtail args 3 loc)
            (let ([a (parse-datum (car args))]
                  [n (parse-datum (cadr args))]
                  [v (parse-datum (caddr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? n) n]
                    [(prologos-error? v) v]
                    [else (surf-vtail a n v loc)])))]
       [(vindex)
        (or (check-arity 'vindex args 4 loc)
            (let ([a (parse-datum (car args))]
                  [n (parse-datum (cadr args))]
                  [i (parse-datum (caddr args))]
                  [v (parse-datum (cadddr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? n) n]
                    [(prologos-error? i) i]
                    [(prologos-error? v) v]
                    [else (surf-vindex a n i v loc)])))]

       ;; ---- Posit8 operations ----
       [(Posit8)
        (or (check-arity 'Posit8 args 0 loc)
            (surf-posit8-type loc))]
       [(posit8)
        (or (check-arity 'posit8 args 1 loc)
            (let ([v (stx->datum (car args))])
              (if (and (exact-integer? v) (<= 0 v 255))
                  (surf-posit8 v loc)
                  (parse-error loc "posit8 literal must be an integer 0–255, got ~a" v))))]
       [(p8+)
        (or (check-arity 'p8+ args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p8-add a b loc)])))]
       [(p8-)
        (or (check-arity 'p8- args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p8-sub a b loc)])))]
       [(p8*)
        (or (check-arity 'p8* args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p8-mul a b loc)])))]
       [(p8/)
        (or (check-arity 'p8/ args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p8-div a b loc)])))]
       [(p8-neg)
        (or (check-arity 'p8-neg args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p8-neg a loc))))]
       [(p8-abs)
        (or (check-arity 'p8-abs args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p8-abs a loc))))]
       [(p8-sqrt)
        (or (check-arity 'p8-sqrt args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p8-sqrt a loc))))]
       [(p8-lt)
        (or (check-arity 'p8-lt args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p8-lt a b loc)])))]
       [(p8-le)
        (or (check-arity 'p8-le args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p8-le a b loc)])))]
       [(p8-from-nat)
        (or (check-arity 'p8-from-nat args 1 loc)
            (let ([n (parse-datum (car args))])
              (if (prologos-error? n) n (surf-p8-from-nat n loc))))]
       [(p8-if-nar)
        (or (check-arity 'p8-if-nar args 4 loc)
            (let ([tp (parse-datum (car args))]
                  [nc (parse-datum (cadr args))]
                  [vc (parse-datum (caddr args))]
                  [v (parse-datum (cadddr args))])
              (cond [(prologos-error? tp) tp]
                    [(prologos-error? nc) nc]
                    [(prologos-error? vc) vc]
                    [(prologos-error? v) v]
                    [else (surf-p8-if-nar tp nc vc v loc)])))]

       ;; (the-fn type [params...] body)
       [(the-fn)
        (parse-the-fn args loc)]

       ;; (reduce scrutinee arm1 arm2 ...) or (match scrutinee arm1 arm2 ...)
       [(reduce match)
        (parse-reduce args loc)]

       ;; Pre-parse macro forms — should have been expanded before parsing
       [(defmacro)
        (parse-error loc "defmacro should have been expanded before parsing" #f)]
       [(let)
        (parse-error loc "let should have been expanded before parsing" #f)]
       [(do)
        (parse-error loc "do should have been expanded before parsing" #f)]
       [(if)
        (parse-error loc "if should have been expanded before parsing" #f)]
       [(deftype)
        (parse-error loc "deftype should have been expanded before parsing" #f)]
       [(ns)
        (parse-error loc "ns should have been processed before parsing" #f)]
       [(require)
        (parse-error loc "require should have been processed before parsing" #f)]
       [(provide)
        (parse-error loc "provide should have been processed before parsing" #f)]

       ;; Top-level commands
       ;; (def name : type body)
       [(def)
        (parse-def args loc)]
       ;; (defn name : type [params...] body)
       [(defn)
        (parse-defn args loc)]
       ;; (check expr : type)
       [(check)
        (parse-check-cmd args loc)]
       ;; (eval expr)
       [(eval)
        (or (check-arity 'eval args 1 loc)
            (let ([e (parse-datum (car args))])
              (if (prologos-error? e) e (surf-eval e loc))))]
       ;; (infer expr)
       [(infer)
        (or (check-arity 'infer args 1 loc)
            (let ([e (parse-datum (car args))])
              (if (prologos-error? e) e (surf-infer e loc))))]

       ;; Not a keyword -> function application
       [else
        (parse-application head-stx args loc)])]

    ;; Head is not a symbol -> application of a compound expression
    [else
     (parse-application head-stx args loc)]))

;; ========================================
;; Parse function application: (f a b c) -> surf-app
;; ========================================
(define (parse-application func-stx arg-stxs loc)
  (define func (parse-datum func-stx))
  (if (prologos-error? func) func
      (let ([parsed-args (parse-all-args arg-stxs)])
        (if (prologos-error? parsed-args) parsed-args
            (surf-app func parsed-args loc)))))

(define (parse-all-args stxs)
  (if (null? stxs) '()
      (let ([first (parse-datum (car stxs))])
        (if (prologos-error? first) first
            (let ([rest (parse-all-args (cdr stxs))])
              (if (prologos-error? rest) rest
                  (cons first rest)))))))

;; ========================================
;; Parse binder: (x : T) or (x :m T)
;; ========================================
(define (parse-binder stx loc)
  (define d (stx->datum stx))
  (cond
    [(not (pair? d))
     (parse-error loc (format "Expected binder [x <T>], got ~a" d) d)]
    [else
     (define parts
       (if (syntax? stx) (syntax->list stx) d))
     (cond
       ;; NEW: [x <T>] — 2 elements where second is ($angle-type ...)
       [(and (= (length parts) 2)
             (angle-type-stx? (cadr parts)))
        (let ([name (stx->datum (car parts))])
          (if (symbol? name)
              (let ([ty (unwrap-angle-type (cadr parts) loc)])
                (if (prologos-error? ty) ty
                    (binder-info name 'mw ty)))
              (parse-error loc (format "Expected variable name, got ~a" name) name)))]

       ;; NEW: [x :m <T>] — 3 elements where second is mult, third is ($angle-type ...)
       [(and (= (length parts) 3)
             (mult-annot? (stx->datum (cadr parts)))
             (angle-type-stx? (caddr parts)))
        (let ([name (stx->datum (car parts))]
              [mult (parse-mult-annot (stx->datum (cadr parts)))])
          (if (symbol? name)
              (let ([ty (unwrap-angle-type (caddr parts) loc)])
                (if (prologos-error? ty) ty
                    (binder-info name mult ty)))
              (parse-error loc (format "Expected variable name, got ~a" name) name)))]

       ;; OLD: (x : T) — 3 elements (backward compat)
       [(and (= (length parts) 3)
             (eq? (stx->datum (cadr parts)) ':))
        (let ([name (stx->datum (car parts))]
              [type-stx (caddr parts)])
          (if (symbol? name)
              (let ([ty (parse-datum type-stx)])
                (if (prologos-error? ty) ty
                    (binder-info name 'mw ty)))
              (parse-error loc (format "Expected variable name, got ~a" name) name)))]

       ;; OLD: (x :m T) — 3 elements where second is :0, :1, :w (backward compat)
       [(and (= (length parts) 3)
             (mult-annot? (stx->datum (cadr parts))))
        (let ([name (stx->datum (car parts))]
              [mult (parse-mult-annot (stx->datum (cadr parts)))]
              [type-stx (caddr parts)])
          (if (symbol? name)
              (let ([ty (parse-datum type-stx)])
                (if (prologos-error? ty) ty
                    (binder-info name mult ty)))
              (parse-error loc (format "Expected variable name, got ~a" name) name)))]

       [else
        (parse-error loc
                     (format "Expected binder [x <T>] or (x : T), got ~a" d)
                     d)])]))

;; Check if a symbol is a multiplicity annotation
(define (mult-annot? s)
  (memq s '(:0 :1 :w)))

;; Parse multiplicity annotation symbol to internal mult
(define (parse-mult-annot s)
  (case s
    [(:0) 'm0]
    [(:1) 'm1]
    [(:w) 'mw]
    [else 'mw]))

;; ========================================
;; Parse def: (def name : type body)
;; ========================================
(define (parse-def args loc)
  ;; NEW: (def name <type> body) — 3 args where second is ($angle-type ...)
  ;; OLD: (def name : type body) — 4 args with colon
  (cond
    ;; NEW: name <type> body — 3 elements
    [(and (= (length args) 3)
          (angle-type-stx? (cadr args)))
     (let ([name (stx->datum (car args))])
       (cond
         [(not (symbol? name))
          (parse-error loc (format "def: expected name, got ~a" name) name)]
         [else
          (let ([ty (unwrap-angle-type (cadr args) loc)]
                [bd (parse-datum (caddr args))])
            (cond
              [(prologos-error? ty) ty]
              [(prologos-error? bd) bd]
              [else (surf-def name ty bd loc)]))]))]
    ;; OLD: name : type body — 4 elements (backward compat)
    [(>= (length args) 4)
     (let ([name     (stx->datum (car args))]
           [colon    (stx->datum (cadr args))]
           [type-stx (caddr args)]
           [body-stx (cadddr args)])
       (cond
         [(not (symbol? name))
          (parse-error loc (format "def: expected name, got ~a" name) name)]
         [(not (eq? colon ':))
          (parse-error loc (format "def: expected ':', got ~a" colon) colon)]
         [else
          (let ([ty (parse-datum type-stx)]
                [bd (parse-datum body-stx)])
            (cond
              [(prologos-error? ty) ty]
              [(prologos-error? bd) bd]
              [else (surf-def name ty bd loc)]))]))]
    [else
     (parse-error loc "def requires: (def name <type> body) or (def name : type body)" #f)]))

;; ========================================
;; Parse defn: (defn name : type [params...] body)
;; ========================================
(define (parse-defn args loc)
  ;; NEWEST: (defn name {A B} [param <T> ...] <ReturnType> body) — with implicit type params
  ;; NEW: (defn name [param <T> ...] <ReturnType> body) — typed binders
  ;; OLD: (defn name : type [params...] body) — 5 elements with colon
  (cond
    ;; NEWEST: second arg is $brace-params → implicit type parameters
    ;; defn name {A B} [x <T> ...] <ReturnType> body
    ;; OR defn name {A B} [x : T, ...] : ReturnType body
    [(and (>= (length args) 5)
          (brace-params-stx? (cadr args)))
     (parse-defn-with-implicits args loc)]

    ;; NEW: Detect typed binder syntax: second arg is a bracket form (params with types)
    ;; Detection: either paren-shape property is #\[, or content contains $angle-type markers
    ;; (The latter handles cases where syntax properties were lost during macro expansion)
    [(and (>= (length args) 4)
          (let ([second (cadr args)])
            (or (and (syntax? second)
                     (eq? (syntax-property second 'paren-shape) #\[))
                ;; Content-based detection: list containing $angle-type markers or : symbols
                (let ([d (if (syntax? second) (syntax->datum second) second)])
                  (and (list? d)
                       (ormap (lambda (x)
                                (or (and (pair? x) (eq? (car x) '$angle-type))
                                    (eq? x ':)))
                              d))))))
     ;; New syntax: name [typed-binders...] <ReturnType> body
     (parse-defn-new args loc)]

    ;; OLD: name : type [params...] body — 5 elements (backward compat)
    [(>= (length args) 5)
     (let ([name       (stx->datum (car args))]
           [colon      (stx->datum (cadr args))]
           [type-stx   (caddr args)]
           [params-stx (cadddr args)]
           [body-stx   (list-ref args 4)])
       (cond
         [(not (symbol? name))
          (parse-error loc (format "defn: expected name, got ~a" name) name)]
         [(not (eq? colon ':))
          (parse-error loc (format "defn: expected ':', got ~a" colon) colon)]
         [else
          (let ([ty (parse-datum type-stx)]
                [params (parse-param-names params-stx loc)]
                [bd (parse-datum body-stx)])
            (cond
              [(prologos-error? ty) ty]
              [(prologos-error? params) params]
              [(prologos-error? bd) bd]
              [else (surf-defn name ty params bd loc)]))]))]

    [else
     (parse-error loc "defn requires: (defn name [x <T> ...] <ReturnType> body) or (defn name : type [params] body)" #f)]))

;; ========================================
;; Parse defn with implicit type params: (defn name {A B} [params...] <RetType> body)
;; ========================================
(define (parse-defn-with-implicits args loc)
  (define name (stx->datum (car args)))
  (when (not (symbol? name))
    (parse-error loc (format "defn: expected name, got ~a" name) name))

  ;; Extract implicit binders from {A B}
  (define implicit-binders (unwrap-brace-params (cadr args) loc))
  (when (prologos-error? implicit-binders)
    (values implicit-binders))

  ;; Remaining args after {A B}: [params...] <RetType> body (or [params...] : RetType body)
  (define rest-after-braces (cddr args))

  ;; The next arg should be the explicit params bracket
  (define params-stx (car rest-after-braces))
  (define rest-args (cdr rest-after-braces)) ; <ReturnType> body  OR  : RetType body

  ;; Parse explicit typed binders from the bracket form
  (define explicit-binders (parse-defn-binders params-stx loc))
  (when (prologos-error? explicit-binders)
    (values explicit-binders))

  ;; Combine implicit + explicit binders
  (define all-binders (append implicit-binders explicit-binders))

  (cond
    [(prologos-error? implicit-binders) implicit-binders]
    [(prologos-error? explicit-binders) explicit-binders]
    [(< (length rest-args) 2)
     (parse-error loc "defn: missing return type or body" #f)]
    [else
     (define ret-type-stx (car rest-args))
     (define body-stx (cadr rest-args))
     (cond
       ;; Return type in angle brackets: <RetType>
       [(angle-type-stx? ret-type-stx)
        (define ret-type (unwrap-angle-type ret-type-stx loc))
        (define body (parse-datum body-stx))
        (cond
          [(prologos-error? ret-type) ret-type]
          [(prologos-error? body) body]
          [else
           ;; Build the full Pi type from all binders and return type
           (define full-type
             (foldr (lambda (bnd rest-ty)
                      (surf-pi bnd rest-ty loc))
                    ret-type
                    all-binders))
           ;; Extract parameter names
           (define param-names (map binder-info-name all-binders))
           (surf-defn name full-type param-names body loc)])]
       ;; Return type with colon: : RetType body
       ;; Collect type atoms between ':' and the body (last element).
       [(eq? (stx->datum ret-type-stx) ':)
        (cond
          [(< (length rest-args) 3)
           (parse-error loc "defn: missing return type or body after ':'" #f)]
          [else
           (define after-colon (cdr rest-args))
           (define type-atoms (drop-right after-colon 1))
           (define actual-body-stx (last after-colon))
           (when (null? type-atoms)
             (parse-error loc "defn: missing return type after ':'" #f))
           (define ret-type (parse-infix-type type-atoms loc))
           (define body (parse-datum actual-body-stx))
           (cond
             [(prologos-error? ret-type) ret-type]
             [(prologos-error? body) body]
             [else
              (define full-type
                (foldr (lambda (bnd rest-ty)
                         (surf-pi bnd rest-ty loc))
                       ret-type
                       all-binders))
              (define param-names (map binder-info-name all-binders))
              (surf-defn name full-type param-names body loc)])])]
       [else
        (parse-error loc (format "defn: expected <ReturnType> or : ReturnType, got ~a"
                                 (stx->datum ret-type-stx)) #f)])]))

;; ========================================
;; Parse new-style defn: (defn name [param <T> param :m <T> ...] <ReturnType> body)
;; ========================================
(define (parse-defn-new args loc)
  (define name (stx->datum (car args)))
  (when (not (symbol? name))
    (parse-error loc (format "defn: expected name, got ~a" name) name))

  (define params-stx (cadr args))
  (define rest-args (cddr args)) ; <ReturnType> body

  ;; Parse typed binders from the bracket form
  (define binders (parse-defn-binders params-stx loc))
  (when (prologos-error? binders)
    (values binders))

  ;; rest-args should be: <ReturnType> body  OR  : ReturnType body
  (cond
    [(prologos-error? binders) binders]
    [(< (length rest-args) 2)
     (parse-error loc "defn: missing return type or body" #f)]
    [else
     (define ret-type-stx (car rest-args))
     (cond
       ;; OLD: <ReturnType> body
       [(angle-type-stx? ret-type-stx)
        (define ret-type (unwrap-angle-type ret-type-stx loc))
        (define body (parse-datum (cadr rest-args)))
        (cond
          [(prologos-error? ret-type) ret-type]
          [(prologos-error? body) body]
          [else
           ;; Build the full Pi type from binders and return type
           (define full-type
             (foldr (lambda (bnd rest-ty)
                      (surf-pi bnd rest-ty loc))
                    ret-type
                    binders))
           (define param-names (map binder-info-name binders))
           (surf-defn name full-type param-names body loc)])]
       ;; NEW: : ReturnType body — colon followed by type atoms then body
       [(eq? (stx->datum ret-type-stx) ':)
        (cond
          [(< (length rest-args) 3)
           (parse-error loc "defn: missing return type or body after ':'" #f)]
          [else
           ;; Collect type atoms between ':' and the body.
           ;; The body is the last element.
           ;; Type atoms are everything between ':' and the last element.
           (define after-colon (cdr rest-args))
           (define type-atoms (drop-right after-colon 1))
           (define body-stx (last after-colon))
           (when (null? type-atoms)
             (parse-error loc "defn: missing return type after ':'" #f))
           (define ret-type (parse-infix-type type-atoms loc))
           (define body (parse-datum body-stx))
           (cond
             [(prologos-error? ret-type) ret-type]
             [(prologos-error? body) body]
             [else
              (define full-type
                (foldr (lambda (bnd rest-ty)
                         (surf-pi bnd rest-ty loc))
                       ret-type
                       binders))
              (define param-names (map binder-info-name binders))
              (surf-defn name full-type param-names body loc)])])]
       [else
        (parse-error loc (format "defn: expected <ReturnType> or : ReturnType, got ~a"
                                 (stx->datum ret-type-stx)) #f)])]))

;; Parse typed binders from bracket contents: [x <T> y :0 <T2> ...]
;; Also supports colon syntax: [f : A -> B, z : B]
;; Returns a list of binder-info structs.
(define (parse-defn-binders stx loc)
  (define parts
    (if (syntax? stx) (syntax->list stx) (stx->datum stx)))
  (cond
    [(not parts)
     (parse-error loc "defn: malformed parameter list" #f)]
    [(null? parts)
     (parse-error loc "defn: parameter list cannot be empty" #f)]
    ;; Detect colon-based syntax: check if any element is a bare ': symbol
    ;; (not :0/:1/:w multiplicities, and not inside $angle-type)
    [(ormap (lambda (p)
              (let ([d (stx->datum p)])
                (eq? d ':)))
            parts)
     (parse-colon-binder-seq parts loc)]
    [else
     (parse-defn-binder-seq parts loc)]))

;; Walk a flat sequence: name <type> | name :m <type>
(define (parse-defn-binder-seq parts loc)
  (cond
    [(null? parts) '()]
    ;; name :m <type> — 3 elements consumed
    [(and (>= (length parts) 3)
          (symbol? (stx->datum (car parts)))
          (mult-annot? (stx->datum (cadr parts)))
          (angle-type-stx? (caddr parts)))
     (let ([name (stx->datum (car parts))]
           [mult (parse-mult-annot (stx->datum (cadr parts)))]
           [ty (unwrap-angle-type (caddr parts) loc)])
       (if (prologos-error? ty) ty
           (let ([rest (parse-defn-binder-seq (cdddr parts) loc)])
             (if (prologos-error? rest) rest
                 (cons (binder-info name mult ty) rest)))))]
    ;; name <type> — 2 elements consumed
    [(and (>= (length parts) 2)
          (symbol? (stx->datum (car parts)))
          (angle-type-stx? (cadr parts)))
     (let ([name (stx->datum (car parts))]
           [ty (unwrap-angle-type (cadr parts) loc)])
       (if (prologos-error? ty) ty
           (let ([rest (parse-defn-binder-seq (cddr parts) loc)])
             (if (prologos-error? rest) rest
                 (cons (binder-info name 'mw ty) rest)))))]
    [else
     (parse-error loc
                  (format "defn: expected 'name <type>' in parameter list, got ~a"
                          (map stx->datum parts))
                  #f)]))

;; ========================================
;; Colon-based parameter parsing: [f : A -> B -> B, z : B, xs : List A]
;; Commas are already stripped by the reader. So the flat sequence is:
;; (f : A -> B -> B z : B xs : List A)
;; We split on ':' boundaries to get individual binders.
;; ========================================

;; Parse colon-based binder sequence from flat parts list.
;; Format: name [mult] : type-atoms... name [mult] : type-atoms... ...
;; Returns a list of binder-info structs.
(define (parse-colon-binder-seq parts loc)
  ;; Strategy: Walk through parts, collecting binders.
  ;; A binder starts with a symbol name, optionally followed by a multiplicity (:0/:1/:w),
  ;; then a colon ':' , then type atoms until the next binder or end of list.
  ;; The "next binder" is detected by: a symbol followed by ':' (with or without mult in between).
  (define (is-colon? p) (eq? (stx->datum p) ':))
  (define (is-mult? p) (mult-annot? (stx->datum p)))
  (define (is-sym? p) (symbol? (stx->datum p)))

  ;; Find the index of the next colon that starts a new binder.
  ;; A colon starts a new binder if it's preceded by a symbol name
  ;; (possibly with a multiplicity in between).
  ;; We skip the first colon (which belongs to the current binder).
  (define (find-next-binder-start type-atoms)
    ;; type-atoms is the list of atoms after the current binder's ':'
    ;; Look for a pattern: ... sym : ... or ... sym mult : ...
    ;; where sym starts a new binder.
    (let loop ([i 0] [remaining type-atoms])
      (cond
        [(null? remaining) i] ; end of list — all atoms belong to current binder
        ;; sym : pattern — the sym starts a new binder, and everything before it is type
        [(and (is-sym? (car remaining))
              (>= (length remaining) 2)
              (is-colon? (cadr remaining)))
         i]
        ;; sym mult : pattern — the sym starts a new binder
        [(and (is-sym? (car remaining))
              (>= (length remaining) 3)
              (is-mult? (cadr remaining))
              (is-colon? (caddr remaining)))
         i]
        [else (loop (+ i 1) (cdr remaining))])))

  (let loop ([parts parts] [result '()])
    (cond
      [(null? parts) (reverse result)]
      [else
       ;; Expect: name [mult] : type-atoms...
       (define name-stx (car parts))
       (define name (stx->datum name-stx))
       (unless (symbol? name)
         (parse-error loc (format "defn: expected parameter name, got ~a" name) name))

       (define after-name (cdr parts))
       ;; Check for multiplicity
       (define-values (mult after-mult)
         (if (and (not (null? after-name))
                  (is-mult? (car after-name)))
             (values (parse-mult-annot (stx->datum (car after-name)))
                     (cdr after-name))
             (values 'mw after-name)))

       ;; Expect colon
       (when (or (null? after-mult) (not (is-colon? (car after-mult))))
         (parse-error loc (format "defn: expected ':' after parameter name ~a" name) name))

       (define after-colon (cdr after-mult))

       ;; Collect type atoms until the next binder start
       (define split-idx (find-next-binder-start after-colon))
       (define type-atoms (take after-colon split-idx))
       (define rest-parts (drop after-colon split-idx))

       (when (null? type-atoms)
         (parse-error loc (format "defn: missing type after ':' for parameter ~a" name) name))

       ;; Parse the type atoms with infix -> support
       (define ty (parse-infix-type type-atoms loc))
       (if (prologos-error? ty) ty
           (loop rest-parts (cons (binder-info name mult ty) result)))])))

;; ========================================
;; Infix type parser: A -> B -> C, List A, Nat, (Option A)
;; Handles right-associative -> and type application (juxtaposition).
;; ========================================

;; Parse a flat list of type atoms with infix -> support.
;; Splits on '-> symbols, right-associates the arrow, and parses each segment.
(define (parse-infix-type atoms loc)
  ;; Split the atoms list on '-> into segments
  (define segments (split-on-arrow atoms))
  (cond
    [(null? segments)
     (parse-error loc "Empty type expression" #f)]
    [(= (length segments) 1)
     ;; No arrows — just parse as a type application or single type
     (parse-type-segment (car segments) loc)]
    [else
     ;; Right-fold with surf-arrow
     (define parsed-segments
       (for/list ([seg (in-list segments)])
         (parse-type-segment seg loc)))
     ;; Check for errors
     (define first-err (findf prologos-error? parsed-segments))
     (if first-err first-err
         (foldr (lambda (dom cod) (surf-arrow dom cod loc))
                (last parsed-segments)
                (drop-right parsed-segments 1)))]))

;; Split a list of atoms on the '-> symbol.
;; Returns a list of lists (segments between arrows).
(define (split-on-arrow atoms)
  (let loop ([remaining atoms] [current '()] [result '()])
    (cond
      [(null? remaining)
       (reverse (cons (reverse current) result))]
      [(eq? (stx->datum (car remaining)) '->)
       (loop (cdr remaining) '() (cons (reverse current) result))]
      [else
       (loop (cdr remaining) (cons (car remaining) current) result)])))

;; Parse a single type segment (atoms between arrows).
;; A segment like (List A) is type application; (Nat) is a single type.
;; For multi-atom segments, we first construct a list datum and run pre-parse
;; expansion on it, so that deftype macros (e.g., Eq A → (-> A (-> A Bool)))
;; are expanded correctly.
(define (parse-type-segment atoms loc)
  (cond
    [(null? atoms)
     (parse-error loc "Empty type segment in arrow type" #f)]
    [(= (length atoms) 1)
     ;; Single atom — just parse it
     (parse-datum (car atoms))]
    [else
     ;; Multiple atoms — construct a list datum and run pre-parse expansion
     (define datums (map stx->datum atoms))
     (define expanded (preparse-expand-form datums))
     ;; If expansion changed the form (macro was applied), parse the expanded result
     (if (not (equal? expanded datums))
         ;; Macro expanded — wrap in syntax and parse
         (parse-datum (datum->syntax #f expanded))
         ;; No expansion — treat as type application
         (let ([func (parse-datum (car atoms))]
               [args (map (lambda (a) (parse-datum a)) (cdr atoms))])
           (let ([first-err (findf prologos-error? (cons func args))])
             (if first-err first-err
                 (surf-app func args loc)))))]))

;; ========================================
;; Parse the-fn: (the-fn type [params...] body)
;; ========================================
(define (parse-the-fn args loc)
  ;; args should be: type [params...] body  (3 elements)
  (cond
    [(< (length args) 3)
     (parse-error loc "the-fn requires: (the-fn type [params...] body)" #f)]
    [else
     (let ([type-stx   (car args)]
           [params-stx (cadr args)]
           [body-stx   (caddr args)])
       (let ([ty (parse-datum type-stx)]
             [params (parse-param-names-for params-stx 'the-fn loc)]
             [bd (parse-datum body-stx)])
         (cond
           [(prologos-error? ty) ty]
           [(prologos-error? params) params]
           [(prologos-error? bd) bd]
           [else (surf-the-fn ty params bd loc)])))]))

;; ========================================
;; Parse parameter name list: [x y z]
;; ========================================
(define (parse-param-names stx loc)
  (parse-param-names-for stx 'defn loc))

;; Generalized parameter name parser (used by defn and the-fn)
(define (parse-param-names-for stx form-name loc)
  ;; stx should be a syntax list with 'paren-shape #\[
  (define shape (syntax-property stx 'paren-shape))
  (cond
    [(not (eq? shape #\[))
     (parse-error loc (format "~a: parameter list must use square brackets [...]" form-name) (syntax->datum stx))]
    [else
     (define elems (syntax->list stx))
     (cond
       [(not elems)
        (parse-error loc (format "~a: malformed parameter list" form-name) (syntax->datum stx))]
       [(null? elems)
        (parse-error loc (format "~a: parameter list cannot be empty" form-name) '())]
       [else
        (for/fold ([result '()])
                  ([e (in-list elems)])
          (define d (syntax->datum e))
          (cond
            [(prologos-error? result) result]
            [(not (symbol? d))
             (parse-error loc (format "~a: expected parameter name, got ~a" form-name d) d)]
            [else (append result (list d))]))])]))

;; ========================================
;; Parse check command: (check expr : type)
;; ========================================
(define (parse-check-cmd args loc)
  ;; NEW: (check expr <type>) — 2 args where second is ($angle-type ...)
  ;; OLD: (check expr : type) — 3 args with colon
  (cond
    ;; NEW: expr <type> — 2 elements
    [(and (= (length args) 2)
          (angle-type-stx? (cadr args)))
     (let ([e (parse-datum (car args))]
           [t (unwrap-angle-type (cadr args) loc)])
       (cond
         [(prologos-error? e) e]
         [(prologos-error? t) t]
         [else (surf-check e t loc)]))]
    ;; OLD: expr : type — 3 elements (backward compat)
    [(>= (length args) 3)
     (let ([expr-stx (car args)]
           [colon    (stx->datum (cadr args))]
           [type-stx (caddr args)])
       (cond
         [(not (eq? colon ':))
          (parse-error loc (format "check: expected ':', got ~a" colon) colon)]
         [else
          (let ([e (parse-datum expr-stx)]
                [t (parse-datum type-stx)])
            (cond
              [(prologos-error? e) e]
              [(prologos-error? t) t]
              [else (surf-check e t loc)]))]))]
    [else
     (parse-error loc "check requires: (check expr <type>) or (check expr : type)" #f)]))

;; ========================================
;; Arity checking helper
;; Returns #f on success, or a prologos-error on failure.
;; ========================================
(define (check-arity form args expected loc)
  (if (= (length args) expected)
      #f
      (arity-error loc
                   (format "~a expects ~a argument~a, got ~a"
                           form expected (if (= expected 1) "" "s") (length args))
                   form expected (length args))))

;; ========================================
;; Parse reduce: (reduce scrutinee arm1 arm2 ...)
;; ========================================
;; WS mode (pipe syntax):
;;   (reduce scrutinee ($pipe nil -> default) ($pipe cons a acc -> body))
;; Sexp mode (arrow syntax):
;;   (reduce scrutinee (nil -> default) (cons a acc -> body))

(define (parse-reduce args loc)
  (when (< (length args) 2)
    (parse-error loc "reduce requires scrutinee and at least one arm" #f))
  (define scrutinee (parse-datum (car args)))
  (if (prologos-error? scrutinee) scrutinee
      (let ([arms (parse-reduce-arms (cdr args) loc)])
        (if (prologos-error? arms) arms
            (surf-reduce scrutinee arms loc)))))

(define (parse-reduce-arms arm-stxs loc)
  (define result
    (for/list ([arm-stx (in-list arm-stxs)])
      (parse-reduce-arm arm-stx loc)))
  (define first-err (findf prologos-error? result))
  (if first-err first-err result))

(define (parse-reduce-arm arm-stx loc)
  ;; arm-stx is a syntax object or datum wrapping a list like:
  ;; ($pipe nil -> default) or (cons a acc -> body)
  (define d (stx->datum arm-stx))
  (define parts
    (if (syntax? arm-stx) (syntax->list arm-stx)
        (if (list? d) (map (lambda (x) (datum->syntax #f x)) d) #f)))
  (unless parts
    (parse-error loc "reduce arm must be a list" #f))

  ;; Skip leading $pipe if present (WS mode)
  (define cleaned
    (if (and (not (null? parts))
             (eq? (stx->datum (car parts)) '$pipe))
        (cdr parts)
        parts))

  ;; Find -> in the arm
  (define arrow-idx
    (for/or ([p (in-list cleaned)] [i (in-naturals)])
      (and (eq? (stx->datum p) '->) i)))
  (unless arrow-idx
    (parse-error loc "reduce arm missing -> separator" #f))

  (define pattern (take cleaned arrow-idx))
  (define body-parts (drop cleaned (+ arrow-idx 1)))

  (when (null? pattern)
    (parse-error loc "reduce arm missing constructor name" #f))
  (when (null? body-parts)
    (parse-error loc "reduce arm missing body after ->" #f))

  ;; Body: may be a single expression or multiple tokens forming one expression
  ;; For WS mode, each arm is a sub-list, so body-parts should have exactly 1 element
  ;; For sexp mode, body should also be a single form
  ;; But we need to handle (ctor args -> (f x)) where body is one list
  ;; If multiple body parts, wrap them as an application
  (define body-stx
    (if (= (length body-parts) 1)
        (car body-parts)
        ;; Multiple body parts: treat as application
        (datum->syntax #f
                       (map stx->datum body-parts)
                       (car body-parts))))

  (define ctor-name (stx->datum (car pattern)))
  (define binding-names
    (for/list ([p (in-list (cdr pattern))])
      (stx->datum p)))

  (unless (symbol? ctor-name)
    (parse-error loc (format "reduce arm: constructor name must be a symbol, got ~a" ctor-name) #f))
  (unless (andmap symbol? binding-names)
    (parse-error loc "reduce arm: all bindings must be bare symbols" #f))

  (define body (parse-datum body-stx))
  (if (prologos-error? body) body
      (reduce-arm ctor-name binding-names body loc)))

;; ========================================
;; Convenience: parse from string
;; ========================================
(define (parse-string s)
  (define in (open-input-string s))
  (port-count-lines! in)
  (define stx (prologos-sexp-read-syntax "<string>" in))
  (if (eof-object? stx)
      (parse-error srcloc-unknown "Empty input" #f)
      (parse-datum stx)))

;; Parse all forms from a port (for file loading)
(define (parse-port port [source "<port>"])
  (port-count-lines! port)
  (let loop ([results '()])
    (define stx (prologos-sexp-read-syntax source port))
    (if (eof-object? stx)
        (reverse results)
        (let ([parsed (parse-datum stx)])
          (loop (cons parsed results))))))
