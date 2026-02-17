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
  '(inc fn Pi Sigma -> -0> -1> -w> Eq the the-fn Type
    Vec Fin vnil vcons vhead vtail vindex fzero fsuc
    natrec J pair first second boolrec
    Posit8 posit8 p8+ p8- p8* p8/ p8-neg p8-abs p8-sqrt p8-lt p8-le p8-from-nat p8-if-nar
    def defn check eval infer expand parse elaborate match
    ;; Pre-parse macros — should be expanded before reaching parser
    defmacro let do if deftype data spec trait impl
    ;; Private-suffix forms — consumed in preparse, rewritten to base form
    defn- def- data- deftype- defmacro- spec- trait- impl-
    ;; Pre-parse namespace directives — consumed before reaching parser
    ns require provide foreign))

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
    (binder-info name 'm0 (surf-type #f loc))))

(define (unwrap-angle-type stx loc)
  ;; Extract and parse the type from ($angle-type content...)
  ;; Handles: <Nat>, <Nat -> Nat>, <Nat | Bool>,
  ;;          <(x : A) -> B> (dependent Pi), <(x : A) * B> (dependent Sigma),
  ;;          <x : A -> B> (shorthand dependent Pi)
  (define d (stx->datum stx))
  (define contents (cdr d)) ; skip $angle-type sentinel
  (define parts
    (if (syntax? stx) (cdr (syntax->list stx)) contents))
  (cond
    [(null? contents)
     (parse-error loc "Empty type annotation <>" #f)]
    ;; Dependent Pi/Sigma: <(x : A) -> B> or <(x : A) * B>
    [(and (>= (length parts) 3)
          (paren-binder-group? (car parts))
          (let ([op (stx->datum (cadr parts))])
            (or (arrow-symbol? op) (star-symbol? op))))
     (parse-dependent-angle parts loc)]
    ;; Shorthand: <x : A -> B> (single binder, no inner parens)
    [(and (>= (length parts) 4)
          (symbol? (stx->datum (car parts)))
          (eq? (stx->datum (cadr parts)) ':))
     (parse-shorthand-dependent-angle parts loc)]
    [(= (length contents) 1)
     ;; Single element: <Nat> or <Bool> or <(-> Nat Nat)> etc
     (parse-datum (car parts))]
    [else
     ;; Multiple elements: <Nat -> Nat> reads as ($angle-type Nat -> Nat)
     ;; Use parse-infix-type to handle arrow chains
     (parse-infix-type parts loc)]))

;; Check if a datum looks like a paren-grouped binder: (x : A) or (x :m A)
;; Requires that the list contains a ':' symbol.
(define (paren-binder-group? stx)
  (define d (stx->datum stx))
  (and (list? d) (pair? d)
       (ormap (lambda (x) (eq? (if (syntax? x) (syntax-e x) x) ':))
              (if (syntax? stx) (syntax->list stx) d))))

;; Parse <(x : A, y : B) -> C> or <(x : A) * B> dependent type in angle brackets.
;; parts: list of elements starting with the paren-binder-group.
(define (parse-dependent-angle parts loc)
  (define binder-group-stx (car parts))
  (define op-stx (cadr parts))
  (define op (stx->datum op-stx))
  (define body-atoms (cddr parts))

  ;; Parse binders from the paren group
  (define binders (parse-angle-binder-group binder-group-stx loc))
  (cond
    [(prologos-error? binders) binders]
    [(null? body-atoms)
     (parse-error loc "Missing body after operator in dependent type" #f)]
    [else
     ;; Parse the body (everything after -> or *)
     (define body (if (= (length body-atoms) 1)
                      (parse-datum (car body-atoms))
                      (parse-infix-type body-atoms loc)))
     (cond
       [(prologos-error? body) body]
       [(arrow-symbol? op)
        ;; Dependent Pi: fold binders right-to-left
        (define m (arrow-mult op))
        (foldr (lambda (bnd rest)
                 (surf-pi (binder-info (car bnd) m (cdr bnd)) rest loc))
               body binders)]
       [(star-symbol? op)
        ;; Dependent Sigma: fold binders right-to-left
        (foldr (lambda (bnd rest)
                 (surf-sigma (binder-info (car bnd) #f (cdr bnd)) rest loc))
               body binders)]
       [else (parse-error loc "Expected -> or * after binder group" #f)])]))

;; Parse binder group from paren form: (x : A, y : B) → list of (name . parsed-type)
;; Commas are stripped by both readers. Flat sequence: x : A y : B
(define (parse-angle-binder-group stx loc)
  (define parts (if (syntax? stx) (syntax->list stx) (stx->datum stx)))
  ;; Parse as sequence of name : type binders, separated by commas (already stripped)
  ;; Format: name : type-atoms... [, name : type-atoms...]*
  ;; We split on ':' to find binder boundaries.
  (let loop ([remaining parts] [result '()])
    (cond
      [(null? remaining) (reverse result)]
      [else
       ;; First element should be the name
       (define name-stx (car remaining))
       (define name (stx->datum name-stx))
       (cond
         [(not (symbol? name))
          (parse-error loc (format "Expected variable name in binder, got ~a" name) name)]
         [(null? (cdr remaining))
          (parse-error loc (format "Expected ':' after variable name ~a" name) name)]
         [(not (eq? (stx->datum (cadr remaining)) ':))
          (parse-error loc (format "Expected ':' after variable name ~a, got ~a"
                                   name (stx->datum (cadr remaining))) name)]
         [else
          ;; Collect type atoms until next name-colon pair or end
          (define after-colon (cddr remaining))
          (define-values (type-atoms rest)
            (collect-type-atoms-in-binder after-colon))
          (cond
            [(null? type-atoms)
             (parse-error loc (format "Missing type after ':' for variable ~a" name) name)]
            [else
             (define ty (if (= (length type-atoms) 1)
                            (parse-datum (car type-atoms))
                            (parse-infix-type type-atoms loc)))
             (if (prologos-error? ty) ty
                 (loop rest (cons (cons name ty) result)))])])])))

;; Collect type atoms in a binder group until we hit another name : pattern or end.
;; Returns (values type-atoms remaining-atoms).
(define (collect-type-atoms-in-binder atoms)
  (let loop ([remaining atoms] [acc '()])
    (cond
      [(null? remaining)
       (values (reverse acc) '())]
      ;; Look for "name :" pattern — peek ahead
      [(and (>= (length remaining) 2)
            (symbol? (stx->datum (car remaining)))
            (eq? (stx->datum (cadr remaining)) ':)
            ;; Make sure this isn't an arrow operator being confused
            (not (arrow-symbol? (stx->datum (car remaining))))
            (not (star-symbol? (stx->datum (car remaining)))))
       ;; This is a new binder start
       (values (reverse acc) remaining)]
      [else
       (loop (cdr remaining) (cons (car remaining) acc))])))

;; Parse <x : A -> B> shorthand dependent type (single binder, no inner parens).
;; parts: (x : A-atoms... -> B-atoms...) or (x : A-atoms... * B-atoms...)
(define (parse-shorthand-dependent-angle parts loc)
  (define name (stx->datum (car parts)))
  ;; Skip name and ':'
  (define after-colon (cddr parts))
  ;; Find the operator (-> or $star)
  (define-values (type-atoms op rest-atoms)
    (let loop ([remaining after-colon] [acc '()])
      (cond
        [(null? remaining)
         (values (reverse acc) #f '())]
        [(let ([s (stx->datum (car remaining))])
           (or (arrow-symbol? s) (star-symbol? s)))
         (values (reverse acc) (stx->datum (car remaining)) (cdr remaining))]
        [else
         (loop (cdr remaining) (cons (car remaining) acc))])))
  (cond
    [(not op)
     ;; No operator found — fall through to regular infix type parse
     ;; This handles cases like <x : Nat> which is just a binder annotation
     (parse-infix-type parts loc)]
    [(null? type-atoms)
     (parse-error loc "Missing type after ':' in dependent binder" #f)]
    [(null? rest-atoms)
     (parse-error loc "Missing body after operator in dependent type" #f)]
    [else
     (define binder-type (if (= (length type-atoms) 1)
                             (parse-datum (car type-atoms))
                             (parse-infix-type type-atoms loc)))
     (define body (if (= (length rest-atoms) 1)
                      (parse-datum (car rest-atoms))
                      (parse-infix-type rest-atoms loc)))
     (cond
       [(prologos-error? binder-type) binder-type]
       [(prologos-error? body) body]
       [(arrow-symbol? op)
        (surf-pi (binder-info name (arrow-mult op) binder-type) body loc)]
       [(star-symbol? op)
        (surf-sigma (binder-info name #f binder-type) body loc)]
       [else (parse-error loc "Unexpected operator" #f)])]))

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
    [(Unit)   (surf-unit-type loc)]
    [(Posit8) (surf-posit8-type loc)]
    [(Type)   (surf-type #f loc)]     ;; bare Type → infer level (Sprint 6)
    [(zero)   (surf-zero loc)]
    [(true)   (surf-true loc)]
    [(false)  (surf-false loc)]
    [(unit)   (surf-unit loc)]
    [(refl)   (surf-refl loc)]
    [else
     ;; Check for _N pattern (positional placeholder: _1, _2, etc.)
     (define s (symbol->string sym))
     (if (and (> (string-length s) 1)
              (char=? (string-ref s 0) #\_)
              (for/and ([c (in-string (substring s 1))])
                (char-numeric? c)))
         (surf-numbered-hole (string->number (substring s 1)) loc)
         (surf-var sym loc))]))

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
    ;; $angle-type sentinel: unwrap as type annotation
    [(and (symbol? head) (eq? head '$angle-type))
     (unwrap-angle-type stx loc)]

    ;; $foreign-block sentinel: foreign escape block
    ;; ($foreign-block racket (code-datums...) (captures...) (exports...))
    [(and (symbol? head) (eq? head '$foreign-block))
     (parse-foreign-block args loc)]

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
       ;; (fn [x <T>] <RetType> body) or (fn x y <RetType> body) — with return type
       ;; Also: (fn a b c body) — multi-arg untyped fn (all-but-last are bare symbols)
       [(fn)
        (cond
          [(< (length args) 2)
           (parse-error loc "fn requires at least 2 arguments" #f)]
          ;; NEW: (fn binder-list <RetType> body) — 3 args, first is pair, second is angle-type
          ;; Desugars to: (ann (Pi binders RetType) (lam binders body))
          [(and (= (length args) 3)
                (pair? (stx->datum (car args)))
                (angle-type-stx? (cadr args)))
           (let ([binders (parse-fn-binders (car args) loc)]
                 [ret-type (unwrap-angle-type (cadr args) loc)]
                 [body (parse-datum (caddr args))])
             (cond
               [(prologos-error? binders) binders]
               [(prologos-error? ret-type) ret-type]
               [(prologos-error? body) body]
               [else
                ;; Build full Pi type: (Pi (x : T) ... RetType)
                (define full-type
                  (foldr (lambda (bnd rest-ty) (surf-pi bnd rest-ty loc))
                         ret-type binders))
                ;; Build nested lambdas: (lam (x : T) ... body)
                (define nested-lam
                  (foldr (lambda (bnd inner) (surf-lam bnd inner loc))
                         body binders))
                (surf-ann full-type nested-lam loc)]))]
          ;; NEW: (fn binder-list : RetType body) — 4+ args, first is pair, second is ':'
          ;; Colon-style return type: fn [x : Nat] : Nat body
          ;; or fn [x : Nat] : Nat -> Nat body (multi-token return type)
          [(and (>= (length args) 4)
                (pair? (stx->datum (car args)))
                (eq? (stx->datum (cadr args)) ':))
           (let* ([binders (parse-fn-binders (car args) loc)]
                  ;; Collect type atoms between ':' and body (last arg)
                  [type-atoms (drop-right (cddr args) 1)]
                  [body-stx (last args)]
                  [ret-type (parse-infix-type type-atoms loc)]
                  [body (parse-datum body-stx)])
             (cond
               [(prologos-error? binders) binders]
               [(prologos-error? ret-type) ret-type]
               [(prologos-error? body) body]
               [else
                (define full-type
                  (foldr (lambda (bnd rest-ty) (surf-pi bnd rest-ty loc))
                         ret-type binders))
                (define nested-lam
                  (foldr (lambda (bnd inner) (surf-lam bnd inner loc))
                         body binders))
                (surf-ann full-type nested-lam loc)]))]
          ;; Standard: (fn binder body) — exactly 2 args, first is a binder (pair)
          [(and (= (length args) 2)
                (pair? (stx->datum (car args))))
           (let ([bnd (parse-binder (car args) loc)])
             (if (prologos-error? bnd) bnd
                 (let ([body (parse-datum (cadr args))])
                   (if (prologos-error? body) body
                       (surf-lam bnd body loc)))))]
          ;; Multi-arg with return type: (fn a b ... <RetType> body)
          ;; penultimate arg is angle-type, all before it are bare symbols
          [(and (>= (length args) 3)
                (angle-type-stx? (list-ref args (- (length args) 2))))
           (define params (drop-right args 2))
           (define ret-type-stx (list-ref args (- (length args) 2)))
           (define body-stx (last args))
           (define all-symbols?
             (andmap (lambda (a) (symbol? (stx->datum a))) params))
           (cond
             [(not all-symbols?)
              (parse-error loc "fn: parameters before return type must be bare symbols or a binder [x <T>]" #f)]
             [else
              (define param-names (map stx->datum params))
              (define ret-type (unwrap-angle-type ret-type-stx loc))
              (define body (parse-datum body-stx))
              (cond
                [(prologos-error? ret-type) ret-type]
                [(prologos-error? body) body]
                [else
                 (define binders
                   (map (lambda (name) (binder-info name #f (surf-hole loc)))
                        param-names))
                 ;; Build full Pi type: (Pi (_ : _) ... RetType)
                 (define full-type
                   (foldr (lambda (bnd rest-ty) (surf-pi bnd rest-ty loc))
                          ret-type binders))
                 ;; Build nested lambdas
                 (define nested-lam
                   (foldr (lambda (bnd inner) (surf-lam bnd inner loc))
                          body binders))
                 (surf-ann full-type nested-lam loc)])])]
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
                           (surf-lam (binder-info name #f (surf-hole loc)) inner loc))
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
                [else (surf-arrow #f a b loc)])))]

       ;; (-0> A B) — erased arrow
       [(-0>)
        (or (check-arity '-0> args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond
                [(prologos-error? a) a]
                [(prologos-error? b) b]
                [else (surf-arrow 'm0 a b loc)])))]

       ;; (-1> A B) — linear arrow
       [(-1>)
        (or (check-arity '-1> args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond
                [(prologos-error? a) a]
                [(prologos-error? b) b]
                [else (surf-arrow 'm1 a b loc)])))]

       ;; (-w> A B) — unrestricted arrow
       [(-w>)
        (or (check-arity '-w> args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond
                [(prologos-error? a) a]
                [(prologos-error? b) b]
                [else (surf-arrow 'mw a b loc)])))]

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
                                   (surf-arrow #f (surf-bool-type loc) (surf-type 0 loc) loc)
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
                                   (surf-arrow #f (surf-nat-type loc) (surf-type 0 loc) loc)
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

       ;; (match scrutinee arm1 arm2 ...)
       [(match)
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
       ;; Private-suffix forms — should have been rewritten in preparse
       [(defn- def- data- deftype- defmacro-)
        (parse-error loc (format "~a should have been expanded before parsing" head) #f)]

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

       ;; (expand form) — raw datum, NOT parsed (shows preparse expansion)
       [(expand)
        (or (check-arity 'expand args 1 loc)
            (let ([raw (car args)])
              (surf-expand (if (syntax? raw) (syntax->datum raw) raw) loc)))]

       ;; (parse form) — parsed surface AST
       [(parse)
        (or (check-arity 'parse args 1 loc)
            (let ([e (parse-datum (car args))])
              (if (prologos-error? e) e (surf-parse e loc))))]

       ;; (elaborate form) — elaborated core AST
       [(elaborate)
        (or (check-arity 'elaborate args 1 loc)
            (let ([e (parse-datum (car args))])
              (if (prologos-error? e) e (surf-elaborate e loc))))]

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
       ;; Sprint 7: omitted mult → #f (elaborator will create mult-meta)
       [(and (= (length parts) 2)
             (angle-type-stx? (cadr parts)))
        (let ([name (stx->datum (car parts))])
          (if (symbol? name)
              (let ([ty (unwrap-angle-type (cadr parts) loc)])
                (if (prologos-error? ty) ty
                    (binder-info name #f ty)))
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
       ;; Sprint 7: omitted mult → #f (elaborator will create mult-meta)
       [(and (= (length parts) 3)
             (eq? (stx->datum (cadr parts)) ':))
        (let ([name (stx->datum (car parts))]
              [type-stx (caddr parts)])
          (if (symbol? name)
              (let ([ty (parse-datum type-stx)])
                (if (prologos-error? ty) ty
                    (binder-info name #f ty)))
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

       ;; [x] — 1 element, bare param with inferred type (hole)
       [(and (= (length parts) 1)
             (symbol? (stx->datum (car parts))))
        (binder-info (stx->datum (car parts)) #f (surf-hole loc))]

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
  ;; Sprint 10: (def name body) — 2 args, type inferred from body
  ;; NEW: (def name <type> body) — 3 args where second is ($angle-type ...)
  ;; OLD: (def name : type body) — 4 args with colon
  (cond
    ;; Sprint 10: (def name body) — 2 args, type inferred
    [(= (length args) 2)
     (let ([name (stx->datum (car args))])
       (cond
         [(not (symbol? name))
          (parse-error loc (format "def: expected name, got ~a" name) name)]
         [else
          (let ([bd (parse-datum (cadr args))])
            (if (prologos-error? bd) bd
                (surf-def name #f bd loc)))]))]
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
;; Multi-body defn detection and parsing
;; ========================================

;; Check if defn args contain $pipe clauses (multi-body syntax).
;; args is the list after 'defn' keyword: (name [optional-docstring] ($pipe ...) ($pipe ...) ...)
(define (has-pipe-clauses? args)
  (and (>= (length args) 2)
       (symbol? (stx->datum (car args)))
       (let ([rest (cdr args)])
         ;; Skip optional docstring
         (define check-from
           (if (and (not (null? rest))
                    (string? (stx->datum (car rest))))
               (cdr rest)
               rest))
         (and (not (null? check-from))
              (ormap (lambda (a)
                       (let ([d (stx->datum a)])
                         (and (pair? d)
                              (eq? (let ([h (car d)])
                                     (if (syntax? h) (syntax-e h) h))
                                   '$pipe))))
                     check-from)))))

;; Parse a multi-body defn: defn name "doc" | clause1 | clause2 ...
(define (parse-defn-multi args loc)
  (define name (stx->datum (car args)))
  (unless (symbol? name)
    (parse-error loc (format "defn: expected name, got ~a" name) name))
  ;; Skip optional docstring
  (define-values (docstring clause-args)
    (let ([rest (cdr args)])
      (if (and (not (null? rest))
               (string? (stx->datum (car rest))))
          (values (stx->datum (car rest)) (cdr rest))
          (values #f rest))))
  (when (null? clause-args)
    (parse-error loc (format "defn ~a: multi-body defn requires at least one clause" name) #f))
  ;; Parse each $pipe clause
  (define clauses
    (for/list ([clause-stx (in-list clause-args)])
      (parse-defn-clause clause-stx name loc)))
  (define first-err (findf prologos-error? clauses))
  (if first-err first-err
      (surf-defn-multi name docstring clauses loc)))

;; Parse a single clause of a multi-body defn.
;; Input: ($pipe [params...] : RetType body) or ($pipe [params...] <RetType> body)
(define (parse-defn-clause clause-stx name loc)
  (define d (stx->datum clause-stx))
  (define parts
    (if (syntax? clause-stx) (syntax->list clause-stx)
        (if (list? d) (map (lambda (x) (datum->syntax #f x)) d) #f)))
  (unless parts
    (parse-error loc (format "defn ~a: clause must be a list" name) #f))
  ;; Skip leading $pipe
  (define cleaned
    (if (and (not (null? parts))
             (eq? (stx->datum (car parts)) '$pipe))
        (cdr parts)
        parts))
  (when (null? cleaned)
    (parse-error loc (format "defn ~a: empty clause" name) #f))
  ;; First element should be the params bracket
  (define params-stx (car cleaned))
  (define rest-args (cdr cleaned))
  ;; Detect bare vs typed params (same logic as parse-defn)
  (define binders
    (let ([elems (if (syntax? params-stx) (syntax->list params-stx) #f)])
      (cond
        ;; Bare params: all symbols, no types
        [(and elems (not (null? elems))
              (andmap (lambda (e) (symbol? (syntax-e e))) elems)
              (not (ormap (lambda (e)
                            (let ([dd (syntax-e e)])
                              (or (eq? dd ':) (mult-annot? dd))))
                          elems)))
         (for/list ([e (in-list elems)])
           (binder-info (syntax-e e) #f (surf-hole loc)))]
        ;; Typed params
        [else
         (parse-defn-binders params-stx loc)])))
  (cond
    [(prologos-error? binders) binders]
    [(< (length rest-args) 2)
     (parse-error loc (format "defn ~a: clause missing return type or body" name) #f)]
    [else
     (define ret-type-stx (car rest-args))
     (cond
       ;; <ReturnType> body
       [(angle-type-stx? ret-type-stx)
        (define ret-type (unwrap-angle-type ret-type-stx loc))
        (define body (parse-datum (cadr rest-args)))
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
           (defn-clause full-type param-names body loc)])]
       ;; : ReturnType body
       [(eq? (stx->datum ret-type-stx) ':)
        (cond
          [(< (length rest-args) 3)
           (parse-error loc (format "defn ~a: clause missing return type or body after ':'" name) #f)]
          [else
           (define after-colon (cdr rest-args))
           (define type-atoms (drop-right after-colon 1))
           (define body-stx (last after-colon))
           (when (null? type-atoms)
             (parse-error loc (format "defn ~a: clause missing return type after ':'" name) #f))
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
              (defn-clause full-type param-names body loc)])])]
       [else
        (parse-error loc (format "defn ~a: clause expected <ReturnType> or : ReturnType, got ~a"
                                 name (stx->datum ret-type-stx)) #f)])]))

;; ========================================
;; Parse defn: (defn name : type [params...] body)
;; ========================================
(define (parse-defn args loc)
  ;; NEWEST: (defn name {A B} [param <T> ...] <ReturnType> body) — with implicit type params
  ;; Sprint 10: (defn name [x y z] <ReturnType> body) — bare params, types inferred
  ;; NEW: (defn name [param <T> ...] <ReturnType> body) — typed binders
  ;; OLD: (defn name : type [params...] body) — 5 elements with colon
  (cond
    ;; MULTI-BODY: args contain $pipe children (case-split by arity)
    ;; defn name "docstring" | [params...] : RetType body | [params...] : RetType body
    [(has-pipe-clauses? args)
     (parse-defn-multi args loc)]

    ;; NEWEST: second arg is $brace-params → implicit type parameters
    ;; defn name {A B} [x <T> ...] <ReturnType> body
    ;; OR defn name {A B} [x : T, ...] : ReturnType body
    ;; OR Sprint 10: defn name {A B} [x y z] <ReturnType> body — bare params + implicits
    [(and (>= (length args) 5)
          (brace-params-stx? (cadr args)))
     (parse-defn-with-implicits args loc)]

    ;; Sprint 10: Bare-param syntax: (defn name [x y z] <ReturnType> body)
    ;; Detection: second arg is a list containing ONLY bare symbols
    ;; (no $angle-type markers, no ':', no multiplicity annotations)
    ;; Position-based: second arg of defn is always the param list.
    [(and (>= (length args) 4)
          (let ([second (cadr args)])
            (let ([elems (if (syntax? second) (syntax->list second) #f)])
              (and elems (not (null? elems))
                   (andmap (lambda (e) (symbol? (syntax-e e))) elems)
                   (not (ormap (lambda (e)
                                (let ([d (syntax-e e)])
                                  (or (eq? d ':) (mult-annot? d))))
                               elems))))))
     (parse-defn-bare-params args loc)]

    ;; Detect typed binder syntax: second arg is a list containing typed binders.
    ;; Content-based detection: list containing $angle-type markers or : symbols.
    ;; Position-based: second arg of defn is always the param list.
    [(and (>= (length args) 4)
          (let ([second (cadr args)])
            (let ([d (if (syntax? second) (syntax->datum second) second)])
              (and (list? d)
                   (ormap (lambda (x)
                            (or (and (pair? x) (eq? (car x) '$angle-type))
                                (eq? x ':)))
                          d)))))
     ;; Syntax: name [typed-binders...] <ReturnType> body
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

  ;; Parse explicit binders from the bracket form
  ;; Sprint 10: detect bare params (only symbols, no types) vs typed params
  (define explicit-binders
    (let ([elems (if (syntax? params-stx) (syntax->list params-stx) #f)])
      (if (and elems (not (null? elems))
               (andmap (lambda (e) (symbol? (syntax-e e))) elems)
               (not (ormap (lambda (e)
                             (let ([d (syntax-e e)])
                               (or (eq? d ':) (mult-annot? d))))
                           elems)))
          ;; Bare params: build binders with surf-hole types
          (for/list ([e (in-list elems)])
            (binder-info (syntax-e e) #f (surf-hole loc)))
          ;; Typed params: existing path
          (parse-defn-binders params-stx loc))))
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

;; ========================================
;; Sprint 10: Parse defn with bare (untyped) parameters
;; (defn name [x y z] <ReturnType> body) — parameter types inferred
;; ========================================
(define (parse-defn-bare-params args loc)
  (define name (stx->datum (car args)))
  (when (not (symbol? name))
    (parse-error loc (format "defn: expected name, got ~a" name) name))

  (define params-stx (cadr args))
  (define rest-args (cddr args)) ; <ReturnType> body  OR  : ReturnType body

  ;; Build binders with surf-hole types (to be inferred by bidirectional checking)
  (define param-elems (syntax->list params-stx))
  (define binders
    (for/list ([e (in-list param-elems)])
      (binder-info (syntax-e e) #f (surf-hole loc))))

  ;; rest-args should be: <ReturnType> body  OR  : ReturnType body
  (cond
    [(< (length rest-args) 2)
     (parse-error loc "defn: missing return type or body" #f)]
    [else
     (define ret-type-stx (car rest-args))
     (cond
       ;; <ReturnType> body
       [(angle-type-stx? ret-type-stx)
        (define ret-type (unwrap-angle-type ret-type-stx loc))
        (define body (parse-datum (cadr rest-args)))
        (cond
          [(prologos-error? ret-type) ret-type]
          [(prologos-error? body) body]
          [else
           ;; Build the full Pi type from binders (with hole types) and return type
           (define full-type
             (foldr (lambda (bnd rest-ty)
                      (surf-pi bnd rest-ty loc))
                    ret-type
                    binders))
           (define param-names (map binder-info-name binders))
           (surf-defn name full-type param-names body loc)])]
       ;; : ReturnType body
       [(eq? (stx->datum ret-type-stx) ':)
        (cond
          [(< (length rest-args) 3)
           (parse-error loc "defn: missing return type or body after ':'" #f)]
          [else
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
    ;; Sprint 7: omitted mult → #f (elaborator will create mult-meta)
    [(and (>= (length parts) 2)
          (symbol? (stx->datum (car parts)))
          (angle-type-stx? (cadr parts)))
     (let ([name (stx->datum (car parts))]
           [ty (unwrap-angle-type (cadr parts) loc)])
       (if (prologos-error? ty) ty
           (let ([rest (parse-defn-binder-seq (cddr parts) loc)])
             (if (prologos-error? rest) rest
                 (cons (binder-info name #f ty) rest)))))]
    [else
     (parse-error loc
                  (format "defn: expected 'name <type>' in parameter list, got ~a"
                          (map stx->datum parts))
                  #f)]))

;; Parse fn binder list for return-type-annotated fn expressions.
;; Handles both single-binder (x : T) and multi-binder [x <T>, y <U>] syntax.
;; Returns a list of binder-info structs.
(define (parse-fn-binders stx loc)
  (define d (stx->datum stx))
  (cond
    [(not (pair? d))
     (parse-error loc (format "fn: expected parameter list, got ~a" d) d)]
    [else
     (define parts
       (if (syntax? stx) (syntax->list stx) d))
     (cond
       ;; Single bare param: [x] — 1 element, symbol → hole type
       [(and (= (length parts) 1)
             (symbol? (stx->datum (car parts))))
        (list (binder-info (stx->datum (car parts)) #f (surf-hole loc)))]
       ;; Single binder: (x : T) — 3 elements with colon
       [(and (= (length parts) 3)
             (eq? (stx->datum (cadr parts)) ':))
        (let ([bnd (parse-binder stx loc)])
          (if (prologos-error? bnd) bnd
              (list bnd)))]
       ;; Single binder: (x :m T) — 3 elements with multiplicity
       [(and (= (length parts) 3)
             (mult-annot? (stx->datum (cadr parts))))
        (let ([bnd (parse-binder stx loc)])
          (if (prologos-error? bnd) bnd
              (list bnd)))]
       ;; Single binder: (x ($angle-type T)) — 2 elements
       [(and (= (length parts) 2)
             (angle-type-stx? (cadr parts)))
        (let ([bnd (parse-binder stx loc)])
          (if (prologos-error? bnd) bnd
              (list bnd)))]
       ;; All bare params: [x y z] — all symbols, none are ':' or mults → hole types
       [(and (> (length parts) 1)
             (andmap (lambda (p)
                       (let ([d (stx->datum p)])
                         (and (symbol? d)
                              (not (eq? d ':))
                              (not (mult-annot? d))
                              (not (angle-type? (if (syntax? p) (syntax-e p) d))))))
                     parts))
        (map (lambda (p) (binder-info (stx->datum p) #f (surf-hole loc)))
             parts)]
       ;; Multi-binder: delegate to parse-defn-binders
       [else
        (define result (parse-defn-binders stx loc))
        (if (prologos-error? result) result
            result)])]))

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
       ;; Sprint 7: omitted mult → #f (elaborator will create mult-meta)
       (define-values (mult after-mult)
         (if (and (not (null? after-name))
                  (is-mult? (car after-name)))
             (values (parse-mult-annot (stx->datum (car after-name)))
                     (cdr after-name))
             (values #f after-name)))

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
;; Also handles union types: A | B (lower precedence than ->).
;; ========================================

;; Parse a flat list of type atoms with infix | and -> support.
;; Precedence: | (lowest) < -> (higher) < application (highest)
;; So: A -> B | C -> D  =  (A -> B) | (C -> D)
(define (parse-infix-type atoms loc)
  ;; First, split on | (union, lowest precedence)
  (define union-parts (split-on-pipe atoms))
  (cond
    [(null? union-parts)
     (parse-error loc "Empty type expression" #f)]
    [(= (length union-parts) 1)
     ;; No unions — parse with arrows
     (parse-arrow-type (car union-parts) loc)]
    [else
     ;; Union type: parse each component, then fold into right-associated union
     (define parsed-parts
       (map (lambda (part) (parse-arrow-type part loc)) union-parts))
     (define first-err (findf prologos-error? parsed-parts))
     (if first-err first-err
         ;; Right-associate: A | B | C  →  union(A, union(B, C))
         (foldr (lambda (left right) (surf-union left right loc))
                (last parsed-parts)
                (drop-right parsed-parts 1)))]))

;; Split a list of atoms on '| or '$pipe symbols.
;; Returns a list of lists (segments between pipes).
(define (split-on-pipe atoms)
  (let loop ([remaining atoms] [current '()] [result '()])
    (cond
      [(null? remaining)
       (if (null? current)
           (if (null? result) '() (reverse (cons '() result)))
           (reverse (cons (reverse current) result)))]
      [(eq? (stx->datum (car remaining)) '$pipe)
       (loop (cdr remaining) '() (cons (reverse current) result))]
      [else
       (loop (cdr remaining) (cons (car remaining) current) result)])))

;; Arrow symbol detection and multiplicity extraction.
(define (arrow-symbol? s) (memq s '(-> -0> -1> -w>)))
(define (arrow-mult sym)
  (case sym [(-0>) 'm0] [(-1>) 'm1] [(-w>) 'mw] [(->)  #f] [else #f]))

;; Parse a single union component (handles -> / -0> / -1> / -w> arrows).
(define (parse-arrow-type atoms loc)
  ;; Split the atoms list on arrow symbols into (segment . arrow-sym) pairs.
  ;; The last pair has #f for arrow-sym.
  (define seg+arrows (split-on-arrow-with-mult atoms))
  (define segments (map car seg+arrows))
  (cond
    [(null? segments)
     (parse-error loc "Empty type expression" #f)]
    [(= (length segments) 1)
     ;; No arrows — try product types, then type application
     (parse-product-type (car segments) loc)]
    [else
     ;; Uncurried arrow syntax: non-last segments have each atom parsed individually.
     ;; A B -> C  =  A -> B -> C  (each atom in non-last segment = separate arg)
     ;; [A -> B] C -> D  =  (A->B) -> C -> D  (sub-lists parsed as grouped types)
     ;; Last segment: parsed as type application (multi-atom = app).
     ;;
     ;; Build list of (parsed-arg-type . mult) pairs for all non-last segments.
     ;; Each segment before the last shares the arrow mult from its trailing arrow.
     ;; Within a segment, check for * operators: if present, parse as product type.
     ;; If no *, use uncurried syntax (each atom = separate domain).
     (define non-last (drop-right seg+arrows 1))
     (define (segment-has-star? seg)
       (ormap (lambda (a) (star-symbol? (stx->datum a))) seg))
     (define all-arg-type-mults
       (append-map
        (lambda (seg+arrow)
          (define seg (car seg+arrow))
          (define arr (cdr seg+arrow))
          (if (segment-has-star? seg)
              ;; Segment contains *: parse as single product type domain
              (list (cons (parse-product-type seg loc) arr))
              ;; No *: uncurried syntax — each atom is separate domain
              (map (lambda (atom) (cons (parse-single-type-element atom loc) arr))
                   seg)))
        non-last))
     (define return-type (parse-product-type (last segments) loc))
     ;; Check for errors
     (define all-parsed (append (map car all-arg-type-mults) (list return-type)))
     (define first-err (findf prologos-error? all-parsed))
     (if first-err first-err
         ;; Right-associate: A -1> B -> C → arrow('m1, A, arrow(#f, B, C))
         (foldr (lambda (dom-pair cod)
                  (surf-arrow (arrow-mult (cdr dom-pair)) (car dom-pair) cod loc))
                return-type
                all-arg-type-mults))]))

;; Split a list of atoms on arrow symbols (-> / -0> / -1> / -w>).
;; Returns a list of (segment . arrow-or-#f) pairs.
;; The last segment's arrow is always #f.
(define (split-on-arrow-with-mult atoms)
  (let loop ([remaining atoms] [current '()] [result '()])
    (cond
      [(null? remaining)
       (reverse (cons (cons (reverse current) #f) result))]
      [(arrow-symbol? (stx->datum (car remaining)))
       (define arr-sym (stx->datum (car remaining)))
       (loop (cdr remaining) '() (cons (cons (reverse current) arr-sym) result))]
      [else
       (loop (cdr remaining) (cons (car remaining) current) result)])))

;; ========================================
;; Product type: * operator (higher precedence than ->, lower than application)
;; A * B desugars to Sigma(_, A, B)
;; ========================================

(define (star-symbol? s) (memq s '(* $star)))

;; Parse a product type segment (handles * between arrow segments).
;; Precedence: | < -> < * < application
(define (parse-product-type atoms loc)
  (define segments (split-on-star atoms))
  (cond
    [(null? segments)
     (parse-error loc "Empty type expression" #f)]
    [(= (length segments) 1)
     ;; No products — just parse as type application
     (parse-type-segment (car segments) loc)]
    [else
     ;; Right-associate: A * B * C → Sigma(_, A, Sigma(_, B, C))
     (define parsed (map (lambda (seg) (parse-type-segment seg loc)) segments))
     (define err (findf prologos-error? parsed))
     (if err err
         (foldr (lambda (left right) (surf-sigma (binder-info '_ #f left) right loc))
                (last parsed)
                (drop-right parsed 1)))]))

;; Split a list of atoms on * / $star symbols.
;; Returns a list of lists (segments between stars).
(define (split-on-star atoms)
  (let loop ([remaining atoms] [current '()] [result '()])
    (cond
      [(null? remaining)
       (reverse (cons (reverse current) result))]
      [(star-symbol? (stx->datum (car remaining)))
       (loop (cdr remaining) '() (cons (reverse current) result))]
      [else
       (loop (cdr remaining) (cons (car remaining) current) result)])))

;; Parse a single atom in a non-last arrow segment.
;; - Sub-list (from [...] grouping): recurse parse-infix-type on contents
;; - Atom: parse-datum
(define (parse-single-type-element stx loc)
  (define d (stx->datum stx))
  (cond
    ;; Sub-list (grouped type like [List Nat] or [Nat -> Nat])
    [(list? d)
     ;; Get the elements — they may be syntax objects or plain datums
     (define elems (if (syntax? stx) (syntax->list stx) d))
     (if (null? elems)
         (parse-error loc "Empty grouped type []" #f)
         ;; Parse as infix-type to support arrows within groups
         (parse-infix-type elems loc))]
    ;; Regular atom
    [else (parse-datum stx)]))

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
;; Position-based: callers know this is a parameter list from its position in the form.
(define (parse-param-names-for stx form-name loc)
  (define elems (if (syntax? stx) (syntax->list stx) #f))
  (cond
    [(not elems)
     (parse-error loc (format "~a: malformed parameter list" form-name) (if (syntax? stx) (syntax->datum stx) stx))]
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
         [else (append result (list d))]))]))

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
                [t (if (angle-type-stx? type-stx)
                       (unwrap-angle-type type-stx loc)
                       (parse-datum type-stx))])
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
                   form expected (length args) #f)))

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

;; ========================================
;; Foreign escape block parsing
;; ========================================
;; Parses a ($foreign-block lang (code-datums) (captures) (exports)) form
;; produced by the combining pass in macros.rkt.
;;
;; Capture format: ((name : Type) ...) or () for no captures
;; Export format:  ((name : Type) ...) or () for single-return (type from context)
;;
;; Returns a surf-foreign-block.

(define (parse-foreign-block args loc)
  ;; args = (lang (code-datums...) (captures...) (exports...))
  (unless (and (>= (length args) 4))
    (parse-error loc "Invalid $foreign-block: expected (lang code captures exports)" #f))

  (define lang-stx (car args))
  (define lang (stx->datum lang-stx))
  (define code-datums-stx (cadr args))
  ;; Use syntax->datum (recursive) for code datums — these are raw Racket S-exprs
  ;; that must be fully unwrapped for eval
  (define code-datums
    (let ([d (if (syntax? code-datums-stx) (syntax->datum code-datums-stx) code-datums-stx)])
      d))
  (define captures-stx (caddr args))
  ;; Also recursively unwrap captures and exports
  (define captures-raw
    (let ([d (if (syntax? captures-stx) (syntax->datum captures-stx) captures-stx)])
      d))
  (define exports-stx (cadddr args))
  (define exports-raw
    (let ([d (if (syntax? exports-stx) (syntax->datum exports-stx) exports-stx)])
      d))

  ;; Parse captures: list of (name : Type) specs → list of (name, parsed-type) pairs
  (define captures
    (if (null? captures-raw)
        '()
        (parse-foreign-capture-specs captures-raw loc)))

  ;; Parse return type from exports (single-return = first export's type)
  ;; For now, Phase 1: single-return only; exports spec provides the return type
  (define return-type
    (cond
      [(null? exports-raw)
       ;; No explicit return type — will be inferred from checking context
       #f]
      [else
       ;; Single export: (name : Type) — the type is the return type
       ;; For Phase 1 we only support single return
       (parse-foreign-return-type (car exports-raw) loc)]))

  (if (or (prologos-error? captures) (and return-type (prologos-error? return-type)))
      (or (and (prologos-error? captures) captures)
          return-type)
      (surf-foreign-block lang code-datums captures return-type loc)))

;; Parse a list of capture specs from the combining pass.
;; Input: ((name : Type-tokens...) ...) — a list of spec lists
;; Each spec: (name : Type) or just (name) for untyped
;; Returns: list of (list name surf-type) pairs
(define (parse-foreign-capture-specs specs loc)
  ;; The specs come from the combining pass as a list of bracket contents.
  ;; Typically: ((x : Nat y : Nat)) — one sublist with flat multi-capture tokens.
  ;; Or: ((x : Nat) (y : Nat)) — multiple sublists, one per capture.
  ;; Or empty: ()
  (cond
    ;; Single flat list starts with symbol → treat as flat multi-capture
    [(and (pair? specs) (symbol? (car specs)))
     (parse-foreign-capture-flat specs loc)]
    ;; List containing sublists
    [(and (pair? specs) (pair? (car specs)))
     ;; Check if this is a single sublist containing flat multi-capture tokens
     ;; e.g., ((x : Nat y : Nat)) — one sublist with multiple colon-separated captures
     (if (and (= (length specs) 1)
              (pair? (car specs))
              (symbol? (caar specs))
              ;; Has more than one ':' → multiple captures in one bracket group
              (> (length (filter (lambda (e) (eq? e ':)) (car specs))) 1))
         ;; Flat multi-capture: (x : Nat y : Nat)
         (parse-foreign-capture-flat (car specs) loc)
         ;; Multiple sublists or single simple capture: parse each
         (if (and (= (length specs) 1))
             ;; Single sublist: parse as single capture OR flat
             (let ([sublist (car specs)])
               (if (and (pair? sublist) (symbol? (car sublist)))
                   (parse-foreign-capture-flat sublist loc)
                   (parse-single-capture sublist loc)))
             ;; Multiple sublists: parse each individually
             (let loop ([rest specs] [acc '()])
               (if (null? rest)
                   (reverse acc)
                   (let ([spec (car rest)])
                     (define parsed (parse-single-capture spec loc))
                     (if (prologos-error? parsed) parsed
                         (loop (cdr rest) (cons parsed acc))))))))]
    [else '()]))

;; Parse a flat capture list: (name1 : Type1 name2 : Type2 ...)
;; Returns list of (list name surf-type) pairs
(define (parse-foreign-capture-flat tokens loc)
  ;; Split on ':' boundaries
  (let loop ([rest tokens] [acc '()])
    (cond
      [(null? rest) (reverse acc)]
      ;; name : Type [name : Type ...]
      [(and (symbol? (car rest))
            (pair? (cdr rest))
            (eq? (cadr rest) ':))
       ;; Collect type tokens until next name-colon or end
       (define name (car rest))
       (define type-and-rest (cddr rest))
       ;; Find where the next capture starts (symbol followed by ':')
       (define-values (type-tokens remaining)
         (split-capture-type-tokens type-and-rest))
       (define type-surf (parse-infix-type (map (lambda (t) (datum->syntax #f t)) type-tokens) loc))
       (if (prologos-error? type-surf) type-surf
           (loop remaining (cons (list name type-surf) acc)))]
      ;; Bare name without type
      [(symbol? (car rest))
       (loop (cdr rest) (cons (list (car rest) (surf-hole loc)) acc))]
      [else
       (parse-error loc (format "foreign block: invalid capture spec: ~a" rest) #f)])))

;; Split type tokens from a flat capture list, stopping at the next name : boundary
(define (split-capture-type-tokens tokens)
  (let loop ([rest tokens] [type-acc '()])
    (cond
      [(null? rest)
       (values (reverse type-acc) '())]
      ;; If we see symbol : pattern, it's the start of next capture
      [(and (symbol? (car rest))
            (pair? (cdr rest))
            (eq? (cadr rest) ':))
       (values (reverse type-acc) rest)]
      [else
       (loop (cdr rest) (cons (car rest) type-acc))])))

;; Parse a single capture spec: (name : Type)
(define (parse-single-capture spec loc)
  (cond
    [(and (pair? spec) (>= (length spec) 3)
          (symbol? (car spec))
          (eq? (cadr spec) ':))
     (define name (car spec))
     (define type-tokens (cddr spec))
     (define type-surf (parse-infix-type (map (lambda (t) (datum->syntax #f t)) type-tokens) loc))
     (if (prologos-error? type-surf) type-surf
         (list name type-surf))]
    [(and (pair? spec) (= (length spec) 1) (symbol? (car spec)))
     (list (car spec) (surf-hole loc))]
    [else
     (parse-error loc (format "foreign block: invalid capture spec: ~a" spec) #f)]))

;; Parse return type from an export spec: (name : Type) → just the Type part
(define (parse-foreign-return-type spec loc)
  (cond
    [(and (pair? spec) (>= (length spec) 3)
          (symbol? (car spec))
          (eq? (cadr spec) ':))
     (define type-tokens (cddr spec))
     (parse-infix-type (map (lambda (t) (datum->syntax #f t)) type-tokens) loc)]
    [(and (pair? spec) (= (length spec) 1))
     ;; Bare type name
     (parse-datum (car spec))]
    [else
     (parse-error loc (format "foreign block: invalid export/return spec: ~a" spec) #f)]))

;; Parse all forms from a port (for file loading)
(define (parse-port port [source "<port>"])
  (port-count-lines! port)
  (let loop ([results '()])
    (define stx (prologos-sexp-read-syntax source port))
    (if (eof-object? stx)
        (reverse results)
        (let ([parsed (parse-datum stx)])
          (loop (cons parsed results))))))
