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
  '(suc fn Pi Sigma -> -0> -1> -w> Eq the the-fn Type
    Vec Fin vnil vcons vhead vtail vindex fzero fsuc
    natrec J pair first second boolrec
    Int int int+ int- int* int/ int-mod int-neg int-abs int-lt int-le int-eq from-nat
    Rat rat rat+ rat- rat* rat/ rat-neg rat-abs rat-lt rat-le rat-eq from-int rat-numer rat-denom
    Posit8 posit8 p8+ p8- p8* p8/ p8-neg p8-abs p8-sqrt p8-lt p8-le p8-eq p8-from-nat p8-to-rat p8-from-rat p8-from-int p8-if-nar
    Posit16 posit16 p16+ p16- p16* p16/ p16-neg p16-abs p16-sqrt p16-lt p16-le p16-eq p16-from-nat p16-to-rat p16-from-rat p16-from-int p16-if-nar
    Posit32 posit32 p32+ p32- p32* p32/ p32-neg p32-abs p32-sqrt p32-lt p32-le p32-eq p32-from-nat p32-to-rat p32-from-rat p32-from-int p32-if-nar
    Posit64 posit64 p64+ p64- p64* p64/ p64-neg p64-abs p64-sqrt p64-lt p64-le p64-eq p64-from-nat p64-to-rat p64-from-rat p64-from-int p64-if-nar
    Quire8 q8-zero q8-fma q8-to
    Quire16 q16-zero q16-fma q16-to
    Quire32 q32-zero q32-fma q32-to
    Quire64 q64-zero q64-fma q64-to
    ;; Generic arithmetic operators
    + - * / < <= = negate abs
    Symbol symbol-lit
    Keyword Char String
    Map map-empty map-assoc map-get map-dissoc map-size map-has-key? map-keys map-vals
    Set set-empty set-insert set-member? set-delete set-size set-union set-intersect set-diff set-to-list
    PVec pvec-empty pvec-push pvec-nth pvec-update pvec-length pvec-pop pvec-concat pvec-slice pvec-to-list pvec-from-list pvec-fold pvec-map pvec-filter
    set-fold set-filter
    map-fold-entries map-filter-entries map-map-vals
    TVec TMap TSet transient persist! tvec-push! tvec-update! tmap-assoc! tmap-dissoc! tset-insert! tset-delete!
    def defn check eval infer expand expand-1 expand-full parse elaborate match
    ;; Pre-parse macros — should be expanded before reaching parser
    defmacro let do if deftype data spec trait impl where bundle with-transient
    ;; Private-suffix forms — consumed in preparse, rewritten to base form
    defn- def- data- deftype- defmacro- spec- trait- impl- bundle-
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
  ;; Extract implicit type parameters from ($brace-params ...)
  ;; Supports:
  ;;   {A B C}           → all with :0 multiplicity and Type 0
  ;;   {A : Type}        → A with :0 and parsed Type
  ;;   {A :0 Type}       → A with :0 and parsed Type (explicit mult)
  ;;   {A B : Type}      → both A, B with :0 and parsed Type
  ;;   {A B : Type -> Type} → both A, B with :0 and parsed (Type -> Type)
  ;; Returns a list of binder-info structs
  (define d (stx->datum stx))
  (define contents (cdr d)) ; skip $brace-params sentinel
  (define parts
    (if (syntax? stx) (cdr (syntax->list stx)) contents))
  ;; Check if contents contain ':' or multiplicity annotations
  (define has-colon?
    (ormap (lambda (p) (let ([v (if (syntax? p) (syntax-e p) p)])
                         (eq? v ':)))
           parts))
  (define has-mult?
    (ormap (lambda (p) (let ([v (if (syntax? p) (syntax-e p) p)])
                         (memq v '(:0 :1 :w))))
           parts))
  (cond
    ;; Simple case: all bare symbols {A B C} — existing behavior
    [(and (not has-colon?) (not has-mult?))
     (for/list ([p (in-list parts)])
       (define name (if (syntax? p) (syntax-e p) p))
       (unless (symbol? name)
         (parse-error loc (format "Implicit type parameter must be a symbol, got ~a" name) name))
       (binder-info name 'm0 (surf-type #f loc)))]
    ;; Typed binders: parse name(s), optional multiplicity, colon, type
    [else
     (parse-brace-typed-binders parts loc)]))

;; Parse typed implicit binder contents: A : Type, A :0 Type, A B : Type, etc.
;; Format: names... [:mult] : type-atoms...
;; Returns a list of binder-info structs, one per name.
(define (parse-brace-typed-binders parts loc)
  (define datums (map (lambda (p) (if (syntax? p) (syntax-e p) p)) parts))
  (define stx-parts (if (andmap syntax? parts) parts
                        (map (lambda (d) (if (syntax? d) d (datum->syntax #f d))) parts)))
  ;; Find the position of ':' (not :0/:1/:w)
  (define colon-idx
    (for/or ([i (in-naturals)]
             [d (in-list datums)])
      (and (eq? d ':) i)))
  ;; Find multiplicity annotation (:0, :1, :w) — must be right before ':'
  (define-values (mult names-end)
    (cond
      [(and colon-idx (> colon-idx 0)
            (memq (list-ref datums (- colon-idx 1)) '(:0 :1 :w)))
       (values (list-ref datums (- colon-idx 1))
               (- colon-idx 1))]
      [colon-idx
       (values ':0 colon-idx)]  ;; default multiplicity for implicits
      [else
       ;; No colon found — check for mult followed by type atoms
       ;; e.g., {A :0 Type} without explicit ':'
       (define mult-idx
         (for/or ([i (in-naturals)]
                  [d (in-list datums)])
           (and (memq d '(:0 :1 :w)) i)))
       (if mult-idx
           (values (list-ref datums mult-idx) mult-idx)
           (parse-error loc "Implicit binder must have ':' or multiplicity annotation" #f))]))
  ;; Extract names (everything before multiplicity/colon)
  (define name-datums (take datums names-end))
  ;; Extract type atoms (everything after ':')
  (define type-start (if colon-idx (+ colon-idx 1) (+ names-end 1)))
  (define type-atoms-stx (drop stx-parts type-start))
  ;; Validate names
  (for ([n (in-list name-datums)])
    (unless (symbol? n)
      (parse-error loc (format "Implicit binder name must be a symbol, got ~a" n) n)))
  ;; Parse the type
  (define parsed-type
    (cond
      [(null? type-atoms-stx)
       (surf-type #f loc)]  ;; default to Type
      [(= (length type-atoms-stx) 1)
       (parse-datum (car type-atoms-stx))]
      [else
       (parse-infix-type type-atoms-stx loc)]))
  (when (prologos-error? parsed-type)
    (values parsed-type))
  ;; Convert multiplicity symbol to binder-info format
  (define m (case mult
              [(:0) 'm0]
              [(:1) 'm1]
              [(:w) 'mw]
              [else 'm0]))
  ;; Build binder-info for each name
  (for/list ([n (in-list name-datums)])
    (binder-info n m parsed-type)))

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
;; Requires that the list contains a ':' or multiplicity annotation (:0, :1, :w).
(define (paren-binder-group? stx)
  (define d (stx->datum stx))
  (and (list? d) (pair? d)
       (ormap (lambda (x)
                (let ([v (if (syntax? x) (syntax-e x) x)])
                  (or (eq? v ':)
                      (memq v '(:0 :1 :w)))))
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
        ;; Each bnd is (name . type) or (name mult-sym type)
        (define default-m (arrow-mult op))
        (foldr (lambda (bnd rest)
                 (cond
                   ;; 3-element list: (name mult-sym type) — explicit multiplicity
                   [(and (list? bnd) (= (length bnd) 3))
                    (define bnd-m (case (cadr bnd)
                                    [(:0) 'm0] [(:1) 'm1] [(:w) 'mw]
                                    [else default-m]))
                    (surf-pi (binder-info (car bnd) bnd-m (caddr bnd)) rest loc)]
                   ;; Pair: (name . type) — use arrow's multiplicity
                   [else
                    (surf-pi (binder-info (car bnd) default-m (cdr bnd)) rest loc)]))
               body binders)]
       [(star-symbol? op)
        ;; Dependent Sigma: fold binders right-to-left
        (foldr (lambda (bnd rest)
                 (cond
                   [(and (list? bnd) (= (length bnd) 3))
                    (surf-sigma (binder-info (car bnd) #f (caddr bnd)) rest loc)]
                   [else
                    (surf-sigma (binder-info (car bnd) #f (cdr bnd)) rest loc)]))
               body binders)]
       [else (parse-error loc "Expected -> or * after binder group" #f)])]))

;; Parse binder group from paren form: (x : A, y : B) or (x :0 A) → list of (name . parsed-type)
;; Also returns multiplicity info when :0/:1/:w is used instead of plain :.
;; Commas are stripped by both readers. Flat sequence: x : A y : B
(define (parse-angle-binder-group stx loc)
  (define parts (if (syntax? stx) (syntax->list stx) (stx->datum stx)))
  ;; Parse as sequence of name : type binders, separated by commas (already stripped)
  ;; Format: name :[:0|:1|:w] type-atoms... [, name :[:0|:1|:w] type-atoms...]*
  ;; We split on ':' or mult annotations to find binder boundaries.
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
         ;; Plain colon: name : type-atoms...
         [(eq? (stx->datum (cadr remaining)) ':)
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
                 (loop rest (cons (cons name ty) result)))])]
         ;; Multiplicity annotation: name :0/:1/:w type-atoms...
         [(memq (stx->datum (cadr remaining)) '(:0 :1 :w))
          (define mult-sym (stx->datum (cadr remaining)))
          (define after-mult (cddr remaining))
          (define-values (type-atoms rest)
            (collect-type-atoms-in-binder after-mult))
          (cond
            [(null? type-atoms)
             (parse-error loc (format "Missing type after '~a' for variable ~a" mult-sym name) name)]
            [else
             (define ty (if (= (length type-atoms) 1)
                            (parse-datum (car type-atoms))
                            (parse-infix-type type-atoms loc)))
             (if (prologos-error? ty) ty
                 ;; Store multiplicity: use a pair where car = name, cdr = type
                 ;; but also record mult. We'll use a 3-element list: (name mult . type)
                 ;; Actually, to keep compat, we return (name . type) and let parse-dependent-angle
                 ;; extract mult from the original stx. OR we extend the return format.
                 ;; Simplest: return (cons name ty) and use mult in the Pi construction.
                 ;; We need to thread mult into the binder-info. Let's use a struct-like triple.
                 (loop rest (cons (list name mult-sym ty) result)))])]
         [else
          (parse-error loc (format "Expected ':' or multiplicity after variable name ~a, got ~a"
                                   name (stx->datum (cadr remaining))) name)])])))

;; Collect type atoms in a binder group until we hit another name : or name :m pattern or end.
;; Returns (values type-atoms remaining-atoms).
(define (collect-type-atoms-in-binder atoms)
  (let loop ([remaining atoms] [acc '()])
    (cond
      [(null? remaining)
       (values (reverse acc) '())]
      ;; Look for "name :" or "name :0/:1/:w" pattern — peek ahead
      [(and (>= (length remaining) 2)
            (symbol? (stx->datum (car remaining)))
            (let ([next (stx->datum (cadr remaining))])
              (or (eq? next ':)
                  (memq next '(:0 :1 :w))))
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

    ;; Bare number → Int (integer literal)
    ;; Note: 42N → Nat is handled via $nat-literal sentinel (WS) or symbol pattern (sexp)
    [(and (exact-nonnegative-integer? d) (integer? d))
     (surf-int-lit d loc)]

    ;; Bare fraction (rational literal, e.g. 3/7)
    [(and (number? d) (exact? d) (rational? d) (not (integer? d)))
     (surf-rat-lit d loc)]

    ;; Inexact number (e.g. 3.14 from sexp mode) → Posit32 (approximate)
    ;; Racket's reader produces inexact floats for decimals; convert to exact for Posit encoding.
    [(and (number? d) (inexact? d))
     (surf-approx-literal (inexact->exact d) loc)]

    ;; String literal → surf-string
    [(string? d)
     (surf-string d loc)]

    ;; Char literal → surf-char
    [(char? d)
     (surf-char d loc)]

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
    [(Int)    (surf-int-type loc)]
    [(Rat)    (surf-rat-type loc)]
    [(Bool)   (surf-bool-type loc)]
    [(Unit)   (surf-unit-type loc)]
    [(Posit8) (surf-posit8-type loc)]
    [(Posit16) (surf-posit16-type loc)]
    [(Posit32) (surf-posit32-type loc)]
    [(Posit64) (surf-posit64-type loc)]
    [(Quire8) (surf-quire8-type loc)]
    [(Quire16) (surf-quire16-type loc)]
    [(Quire32) (surf-quire32-type loc)]
    [(Quire64) (surf-quire64-type loc)]
    [(q8-zero) (surf-quire8-zero loc)]
    [(q16-zero) (surf-quire16-zero loc)]
    [(q32-zero) (surf-quire32-zero loc)]
    [(q64-zero) (surf-quire64-zero loc)]
    [(Symbol) (surf-symbol-type loc)]
    [(Keyword) (surf-keyword-type loc)]
    [(Char) (surf-char-type loc)]
    [(String) (surf-string-type loc)]
    [(Type)   (surf-type #f loc)]     ;; bare Type → infer level (Sprint 6)
    [(zero)   (surf-zero loc)]
    [(true)   (surf-true loc)]
    [(false)  (surf-false loc)]
    [(unit)   (surf-unit loc)]
    [(refl)   (surf-refl loc)]
    [else
     (define s (symbol->string sym))
     (cond
       ;; Keyword literal: :name (colon-prefixed symbol, at least 2 chars)
       [(and (> (string-length s) 1)
             (char=? (string-ref s 0) #\:))
        (surf-keyword (string->symbol (substring s 1)) loc)]
       ;; Numbered placeholder: _N where N is a positive integer
       [(and (> (string-length s) 1)
             (char=? (string-ref s 0) #\_)
             (for/and ([c (in-string (substring s 1))])
               (char-numeric? c)))
        (surf-numbered-hole (string->number (substring s 1)) loc)]
       ;; Nat literal: 42N (digits followed by N suffix) — for sexp mode
       [(and (> (string-length s) 1)
             (char=? (string-ref s (- (string-length s) 1)) #\N)
             (for/and ([c (in-string (substring s 0 (- (string-length s) 1)))])
               (char-numeric? c)))
        (let ([v (string->number (substring s 0 (- (string-length s) 1)))])
          (if (= v 0)
              (surf-zero loc)
              (surf-nat-lit v loc)))]
       [else (surf-var sym loc)])]))

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

    ;; $nat-literal sentinel: 42N → surf-nat-lit (Nat suc-chain)
    [(and (symbol? head) (eq? head '$nat-literal))
     (if (= (length args) 1)
         (let ([v (stx->datum (car args))])
           (if (and (exact-nonnegative-integer? v) (integer? v))
               (if (= v 0)
                   (surf-zero loc)
                   (surf-nat-lit v loc))
               (parse-error loc (format "N suffix requires a non-negative integer, got: ~a" v) #f)))
         (parse-error loc "N suffix requires exactly one argument" #f))]

    ;; $approx-literal sentinel: ~N → surf-approx-literal
    [(and (symbol? head) (eq? head '$approx-literal))
     (if (= (length args) 1)
         (let ([v (stx->datum (car args))])
           (if (and (number? v) (or (exact? v) (inexact? v)))
               (surf-approx-literal (if (exact? v) v (inexact->exact v)) loc)
               (parse-error loc (format "~~ requires a numeric argument, got: ~a" v) #f)))
         (parse-error loc "~~ requires exactly one argument" #f))]

    ;; $decimal-literal sentinel: 3.14 → surf-approx-literal (bare decimal = Posit32)
    [(and (symbol? head) (eq? head '$decimal-literal))
     (if (= (length args) 1)
         (let ([v (stx->datum (car args))])
           (if (and (number? v) (exact? v) (rational? v))
               (surf-approx-literal v loc)
               (parse-error loc (format "decimal literal requires a numeric argument, got: ~a" v) #f)))
         (parse-error loc "decimal literal requires exactly one argument" #f))]

    ;; $foreign-block sentinel: foreign escape block
    ;; ($foreign-block racket (code-datums...) (captures...) (exports...))
    [(and (symbol? head) (eq? head '$foreign-block))
     (parse-foreign-block args loc)]

    ;; $brace-params sentinel: map literal {k1 v1 k2 v2 ...}
    [(and (symbol? head) (eq? head '$brace-params))
     (parse-map-literal args loc)]

    ;; $set-literal sentinel: Set literal #{e1 e2 ...}
    [(and (symbol? head) (eq? head '$set-literal))
     (parse-set-literal args loc)]

    ;; $vec-literal sentinel: PVec literal @[e1 e2 ...]
    [(and (symbol? head) (eq? head '$vec-literal))
     (parse-pvec-literal args loc)]

    ;; $typed-hole sentinel: ?? or ??name → surf-typed-hole
    [(and (symbol? head) (eq? head '$typed-hole))
     (define hole-name (if (pair? args) (stx->datum (car args)) #f))
     (surf-typed-hole hole-name loc)]

    ;; Keyword-headed forms
    [(symbol? head)
     (case head
       ;; (suc e)
       [(suc)
        (or (check-arity 'suc args 1 loc)
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
          ;; Multi-binder-group: (fn [binders1] [binders2] ... body)
          ;; ≥3 args, all-but-last are bracket-group binder lists, last is body.
          ;; Desugars to nested lambdas: (fn [b1] (fn [b2] ... body))
          ;; Each bracket group is parsed via parse-fn-binders.
          [(and (>= (length args) 3)
                (let ([params (drop-right args 1)])
                  (andmap (lambda (a) (pair? (stx->datum a))) params))
                ;; Exclude the case where second arg is angle-type (already handled above)
                (not (and (= (length args) 3) (angle-type-stx? (cadr args))))
                ;; Exclude the colon-return-type case (already handled above)
                (not (and (>= (length args) 4) (eq? (stx->datum (cadr args)) ':))))
           (let ()
             (define param-groups (drop-right args 1))
             (define body-stx (last args))
             ;; Parse each bracket group as a binder list
             (define all-binders
               (let loop ([groups param-groups] [acc '()])
                 (cond
                   [(null? groups) (reverse acc)]
                   [else
                    (define binders (parse-fn-binders (car groups) loc))
                    (if (prologos-error? binders)
                        binders
                        (loop (cdr groups) (cons binders acc)))])))
             (cond
               [(prologos-error? all-binders) all-binders]
               [else
                (define body (parse-datum body-stx))
                (if (prologos-error? body) body
                    ;; Flatten all binder groups and fold into nested lambdas
                    (let ([flat-binders (apply append all-binders)])
                      (foldr (lambda (bnd inner) (surf-lam bnd inner loc))
                             body flat-binders)))]))]
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

       ;; ---- Int literal and operations ----
       [(int)
        (or (check-arity 'int args 1 loc)
            (let ([v (stx->datum (car args))])
              (cond
                ;; Bare positive integer: (int 42)
                [(and (exact-integer? v) (integer? v))
                 (surf-int-lit v loc)]
                ;; Symbol like -42: (int -42)
                [(symbol? v)
                 (let ([n (string->number (symbol->string v))])
                   (if (and n (exact-integer? n))
                       (surf-int-lit n loc)
                       (parse-error loc "int literal must be an integer, got ~a" v)))]
                [else
                 (parse-error loc "int literal must be an integer, got ~a" v)])))]
       [(int+)
        (or (check-arity 'int+ args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-int-add a b loc)])))]
       [(int-)
        (or (check-arity 'int- args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-int-sub a b loc)])))]
       [(int*)
        (or (check-arity 'int* args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-int-mul a b loc)])))]
       [(int/)
        (or (check-arity 'int/ args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-int-div a b loc)])))]
       [(int-mod)
        (or (check-arity 'int-mod args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-int-mod a b loc)])))]
       [(int-neg)
        (or (check-arity 'int-neg args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-int-neg a loc))))]
       [(int-abs)
        (or (check-arity 'int-abs args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-int-abs a loc))))]
       [(int-lt)
        (or (check-arity 'int-lt args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-int-lt a b loc)])))]
       [(int-le)
        (or (check-arity 'int-le args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-int-le a b loc)])))]
       [(int-eq)
        (or (check-arity 'int-eq args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-int-eq a b loc)])))]
       [(from-nat)
        (or (check-arity 'from-nat args 1 loc)
            (let ([n (parse-datum (car args))])
              (if (prologos-error? n) n (surf-from-nat n loc))))]

       ;; ---- Rat literal and operations ----
       [(rat)
        (or (check-arity 'rat args 1 loc)
            (let ([v (stx->datum (car args))])
              (cond
                ;; Bare rational: (rat 3/7) or (rat 42)
                [(and (exact? v) (rational? v))
                 (surf-rat-lit v loc)]
                ;; Symbol like -3/7: (rat -3/7)
                [(symbol? v)
                 (let ([n (string->number (symbol->string v))])
                   (if (and n (exact? n) (rational? n))
                       (surf-rat-lit n loc)
                       (parse-error loc "rat literal must be an exact rational, got ~a" v)))]
                [else
                 (parse-error loc "rat literal must be an exact rational, got ~a" v)])))]
       [(rat+)
        (or (check-arity 'rat+ args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-rat-add a b loc)])))]
       [(rat-)
        (or (check-arity 'rat- args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-rat-sub a b loc)])))]
       [(rat*)
        (or (check-arity 'rat* args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-rat-mul a b loc)])))]
       [(rat/)
        (or (check-arity 'rat/ args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-rat-div a b loc)])))]
       [(rat-neg)
        (or (check-arity 'rat-neg args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-rat-neg a loc))))]
       [(rat-abs)
        (or (check-arity 'rat-abs args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-rat-abs a loc))))]
       [(rat-lt)
        (or (check-arity 'rat-lt args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-rat-lt a b loc)])))]
       [(rat-le)
        (or (check-arity 'rat-le args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-rat-le a b loc)])))]
       [(rat-eq)
        (or (check-arity 'rat-eq args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-rat-eq a b loc)])))]
       [(from-int)
        (or (check-arity 'from-int args 1 loc)
            (let ([n (parse-datum (car args))])
              (if (prologos-error? n) n (surf-from-int n loc))))]
       [(rat-numer)
        (or (check-arity 'rat-numer args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-rat-numer a loc))))]
       [(rat-denom)
        (or (check-arity 'rat-denom args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-rat-denom a loc))))]

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
       [(p8-eq)
        (or (check-arity 'p8-eq args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p8-eq a b loc)])))]
       [(p8-from-nat)
        (or (check-arity 'p8-from-nat args 1 loc)
            (let ([n (parse-datum (car args))])
              (if (prologos-error? n) n (surf-p8-from-nat n loc))))]
       [(p8-to-rat)
        (or (check-arity 'p8-to-rat args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p8-to-rat a loc))))]
       [(p8-from-rat)
        (or (check-arity 'p8-from-rat args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p8-from-rat a loc))))]
       [(p8-from-int)
        (or (check-arity 'p8-from-int args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p8-from-int a loc))))]
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

       ;; ---- Posit16 operations ----
       [(Posit16)
        (or (check-arity 'Posit16 args 0 loc)
            (surf-posit16-type loc))]
       [(posit16)
        (or (check-arity 'posit16 args 1 loc)
            (let ([v (stx->datum (car args))])
              (if (and (exact-integer? v) (<= 0 v 65535))
                  (surf-posit16 v loc)
                  (parse-error loc "posit16 literal must be an integer 0–65535, got ~a" v))))]
       [(p16+)
        (or (check-arity 'p16+ args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p16-add a b loc)])))]
       [(p16-)
        (or (check-arity 'p16- args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p16-sub a b loc)])))]
       [(p16*)
        (or (check-arity 'p16* args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p16-mul a b loc)])))]
       [(p16/)
        (or (check-arity 'p16/ args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p16-div a b loc)])))]
       [(p16-neg)
        (or (check-arity 'p16-neg args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p16-neg a loc))))]
       [(p16-abs)
        (or (check-arity 'p16-abs args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p16-abs a loc))))]
       [(p16-sqrt)
        (or (check-arity 'p16-sqrt args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p16-sqrt a loc))))]
       [(p16-lt)
        (or (check-arity 'p16-lt args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p16-lt a b loc)])))]
       [(p16-le)
        (or (check-arity 'p16-le args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p16-le a b loc)])))]
       [(p16-eq)
        (or (check-arity 'p16-eq args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p16-eq a b loc)])))]
       [(p16-from-nat)
        (or (check-arity 'p16-from-nat args 1 loc)
            (let ([n (parse-datum (car args))])
              (if (prologos-error? n) n (surf-p16-from-nat n loc))))]
       [(p16-to-rat)
        (or (check-arity 'p16-to-rat args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p16-to-rat a loc))))]
       [(p16-from-rat)
        (or (check-arity 'p16-from-rat args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p16-from-rat a loc))))]
       [(p16-from-int)
        (or (check-arity 'p16-from-int args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p16-from-int a loc))))]
       [(p16-if-nar)
        (or (check-arity 'p16-if-nar args 4 loc)
            (let ([tp (parse-datum (car args))]
                  [nc (parse-datum (cadr args))]
                  [vc (parse-datum (caddr args))]
                  [v (parse-datum (cadddr args))])
              (cond [(prologos-error? tp) tp]
                    [(prologos-error? nc) nc]
                    [(prologos-error? vc) vc]
                    [(prologos-error? v) v]
                    [else (surf-p16-if-nar tp nc vc v loc)])))]

       ;; ---- Posit32 operations ----
       [(Posit32)
        (or (check-arity 'Posit32 args 0 loc)
            (surf-posit32-type loc))]
       [(posit32)
        (or (check-arity 'posit32 args 1 loc)
            (let ([v (stx->datum (car args))])
              (if (and (exact-integer? v) (<= 0 v 4294967295))
                  (surf-posit32 v loc)
                  (parse-error loc "posit32 literal must be an integer 0–4294967295, got ~a" v))))]
       [(p32+)
        (or (check-arity 'p32+ args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p32-add a b loc)])))]
       [(p32-)
        (or (check-arity 'p32- args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p32-sub a b loc)])))]
       [(p32*)
        (or (check-arity 'p32* args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p32-mul a b loc)])))]
       [(p32/)
        (or (check-arity 'p32/ args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p32-div a b loc)])))]
       [(p32-neg)
        (or (check-arity 'p32-neg args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p32-neg a loc))))]
       [(p32-abs)
        (or (check-arity 'p32-abs args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p32-abs a loc))))]
       [(p32-sqrt)
        (or (check-arity 'p32-sqrt args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p32-sqrt a loc))))]
       [(p32-lt)
        (or (check-arity 'p32-lt args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p32-lt a b loc)])))]
       [(p32-le)
        (or (check-arity 'p32-le args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p32-le a b loc)])))]
       [(p32-eq)
        (or (check-arity 'p32-eq args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p32-eq a b loc)])))]
       [(p32-from-nat)
        (or (check-arity 'p32-from-nat args 1 loc)
            (let ([n (parse-datum (car args))])
              (if (prologos-error? n) n (surf-p32-from-nat n loc))))]
       [(p32-to-rat)
        (or (check-arity 'p32-to-rat args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p32-to-rat a loc))))]
       [(p32-from-rat)
        (or (check-arity 'p32-from-rat args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p32-from-rat a loc))))]
       [(p32-from-int)
        (or (check-arity 'p32-from-int args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p32-from-int a loc))))]
       [(p32-if-nar)
        (or (check-arity 'p32-if-nar args 4 loc)
            (let ([tp (parse-datum (car args))]
                  [nc (parse-datum (cadr args))]
                  [vc (parse-datum (caddr args))]
                  [v (parse-datum (cadddr args))])
              (cond [(prologos-error? tp) tp]
                    [(prologos-error? nc) nc]
                    [(prologos-error? vc) vc]
                    [(prologos-error? v) v]
                    [else (surf-p32-if-nar tp nc vc v loc)])))]

       ;; ---- Posit64 operations ----
       [(Posit64)
        (or (check-arity 'Posit64 args 0 loc)
            (surf-posit64-type loc))]
       [(posit64)
        (or (check-arity 'posit64 args 1 loc)
            (let ([v (stx->datum (car args))])
              (if (and (exact-integer? v) (<= 0 v 18446744073709551615))
                  (surf-posit64 v loc)
                  (parse-error loc "posit64 literal must be an integer 0–18446744073709551615, got ~a" v))))]
       [(p64+)
        (or (check-arity 'p64+ args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p64-add a b loc)])))]
       [(p64-)
        (or (check-arity 'p64- args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p64-sub a b loc)])))]
       [(p64*)
        (or (check-arity 'p64* args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p64-mul a b loc)])))]
       [(p64/)
        (or (check-arity 'p64/ args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p64-div a b loc)])))]
       [(p64-neg)
        (or (check-arity 'p64-neg args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p64-neg a loc))))]
       [(p64-abs)
        (or (check-arity 'p64-abs args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p64-abs a loc))))]
       [(p64-sqrt)
        (or (check-arity 'p64-sqrt args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p64-sqrt a loc))))]
       [(p64-lt)
        (or (check-arity 'p64-lt args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p64-lt a b loc)])))]
       [(p64-le)
        (or (check-arity 'p64-le args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p64-le a b loc)])))]
       [(p64-eq)
        (or (check-arity 'p64-eq args 2 loc)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-p64-eq a b loc)])))]
       [(p64-from-nat)
        (or (check-arity 'p64-from-nat args 1 loc)
            (let ([n (parse-datum (car args))])
              (if (prologos-error? n) n (surf-p64-from-nat n loc))))]
       [(p64-to-rat)
        (or (check-arity 'p64-to-rat args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p64-to-rat a loc))))]
       [(p64-from-rat)
        (or (check-arity 'p64-from-rat args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p64-from-rat a loc))))]
       [(p64-from-int)
        (or (check-arity 'p64-from-int args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-p64-from-int a loc))))]
       [(p64-if-nar)
        (or (check-arity 'p64-if-nar args 4 loc)
            (let ([tp (parse-datum (car args))]
                  [nc (parse-datum (cadr args))]
                  [vc (parse-datum (caddr args))]
                  [v (parse-datum (cadddr args))])
              (cond [(prologos-error? tp) tp]
                    [(prologos-error? nc) nc]
                    [(prologos-error? vc) vc]
                    [(prologos-error? v) v]
                    [else (surf-p64-if-nar tp nc vc v loc)])))]

       ;; ---- Quire operations ----
       ;; Quire types (bare symbol parsed above; list form for consistency)
       [(Quire8)
        (or (check-arity 'Quire8 args 0 loc) (surf-quire8-type loc))]
       [(Quire16)
        (or (check-arity 'Quire16 args 0 loc) (surf-quire16-type loc))]
       [(Quire32)
        (or (check-arity 'Quire32 args 0 loc) (surf-quire32-type loc))]
       [(Quire64)
        (or (check-arity 'Quire64 args 0 loc) (surf-quire64-type loc))]
       ;; Quire zero constructors (nullary)
       [(q8-zero)
        (or (check-arity 'q8-zero args 0 loc) (surf-quire8-zero loc))]
       [(q16-zero)
        (or (check-arity 'q16-zero args 0 loc) (surf-quire16-zero loc))]
       [(q32-zero)
        (or (check-arity 'q32-zero args 0 loc) (surf-quire32-zero loc))]
       [(q64-zero)
        (or (check-arity 'q64-zero args 0 loc) (surf-quire64-zero loc))]
       ;; Quire FMA: (qW-fma q a b)
       [(q8-fma)
        (or (check-arity 'q8-fma args 3 loc)
            (let ([q (parse-datum (car args))]
                  [a (parse-datum (cadr args))]
                  [b (parse-datum (caddr args))])
              (cond [(prologos-error? q) q]
                    [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-quire8-fma q a b loc)])))]
       [(q16-fma)
        (or (check-arity 'q16-fma args 3 loc)
            (let ([q (parse-datum (car args))]
                  [a (parse-datum (cadr args))]
                  [b (parse-datum (caddr args))])
              (cond [(prologos-error? q) q]
                    [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-quire16-fma q a b loc)])))]
       [(q32-fma)
        (or (check-arity 'q32-fma args 3 loc)
            (let ([q (parse-datum (car args))]
                  [a (parse-datum (cadr args))]
                  [b (parse-datum (caddr args))])
              (cond [(prologos-error? q) q]
                    [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-quire32-fma q a b loc)])))]
       [(q64-fma)
        (or (check-arity 'q64-fma args 3 loc)
            (let ([q (parse-datum (car args))]
                  [a (parse-datum (cadr args))]
                  [b (parse-datum (caddr args))])
              (cond [(prologos-error? q) q]
                    [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-quire64-fma q a b loc)])))]
       ;; Quire TO: (qW-to q)
       [(q8-to)
        (or (check-arity 'q8-to args 1 loc)
            (let ([q (parse-datum (car args))])
              (if (prologos-error? q) q (surf-quire8-to q loc))))]
       [(q16-to)
        (or (check-arity 'q16-to args 1 loc)
            (let ([q (parse-datum (car args))])
              (if (prologos-error? q) q (surf-quire16-to q loc))))]
       [(q32-to)
        (or (check-arity 'q32-to args 1 loc)
            (let ([q (parse-datum (car args))])
              (if (prologos-error? q) q (surf-quire32-to q loc))))]
       [(q64-to)
        (or (check-arity 'q64-to args 1 loc)
            (let ([q (parse-datum (car args))])
              (if (prologos-error? q) q (surf-quire64-to q loc))))]

       ;; ---- Generic arithmetic operators ----

       ;; Binary: (+ a b), (- a b), (* a b), (/ a b)
       ;; When arity doesn't match (e.g., foreign + with 1 or 3 args),
       ;; fall through to regular function application.
       [(+)
        (if (= (length args) 2)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-generic-add a b loc)]))
            (parse-application head-stx args loc))]
       [(-)
        (if (= (length args) 2)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-generic-sub a b loc)]))
            (parse-application head-stx args loc))]
       [(*)
        (if (= (length args) 2)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-generic-mul a b loc)]))
            (parse-application head-stx args loc))]
       [(/)
        (if (= (length args) 2)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-generic-div a b loc)]))
            (parse-application head-stx args loc))]

       ;; Comparison: (lt a b), (le a b), (eq a b)
       ;; Note: < and <= conflict with angle-bracket syntax in both reader modes.
       ;; Use lt/le/eq matching the existing int-lt/int-le/int-eq naming pattern.
       [(lt)
        (if (= (length args) 2)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-generic-lt a b loc)]))
            (parse-application head-stx args loc))]
       [(le)
        (if (= (length args) 2)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-generic-le a b loc)]))
            (parse-application head-stx args loc))]
       [(eq)
        (if (= (length args) 2)
            (let ([a (parse-datum (car args))]
                  [b (parse-datum (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-generic-eq a b loc)]))
            (parse-application head-stx args loc))]

       ;; Unary: (negate a), (abs a)
       ;; When arity doesn't match, fall through to regular function application.
       [(negate)
        (if (= (length args) 1)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-generic-negate a loc)))
            (parse-application head-stx args loc))]
       [(abs)
        (if (= (length args) 1)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a (surf-generic-abs a loc)))
            (parse-application head-stx args loc))]

       ;; Generic conversion: (from-integer TargetType val), (from-rational TargetType val)
       [(from-integer)
        (or (check-arity 'from-integer args 2 loc)
            (let ([target (parse-datum (car args))]
                  [a (parse-datum (cadr args))])
              (cond [(prologos-error? target) target]
                    [(prologos-error? a) a]
                    [else (surf-generic-from-int target a loc)])))]
       [(from-rational)
        (or (check-arity 'from-rational args 2 loc)
            (let ([target (parse-datum (car args))]
                  [a (parse-datum (cadr args))])
              (cond [(prologos-error? target) target]
                    [(prologos-error? a) a]
                    [else (surf-generic-from-rat target a loc)])))]

       ;; ---- Symbol operations ----

       ;; Symbol type: (Symbol)
       [(Symbol)
        (if (null? args)
            (surf-symbol-type loc)
            (parse-error loc "Symbol takes no arguments" #f))]

       ;; Symbol literal: (symbol-lit name)
       [(symbol-lit)
        (or (check-arity 'symbol-lit args 1 loc)
            (let ([raw (car args)])
              (define name (if (syntax? raw) (syntax-e raw) raw))
              (if (symbol? name)
                  (surf-symbol name loc)
                  (parse-error loc (format "symbol-lit expects a symbol, got ~a" name) #f))))]

       ;; ---- Keyword / Map operations ----

       ;; Keyword type: (Keyword)
       [(Keyword)
        (if (null? args)
            (surf-keyword-type loc)
            (parse-error loc "Keyword takes no arguments" #f))]

       ;; Map type: (Map K V)
       [(Map)
        (or (check-arity 'Map args 2 loc)
            (let ([k (parse-datum (car args))]
                  [v (parse-datum (cadr args))])
              (cond [(prologos-error? k) k]
                    [(prologos-error? v) v]
                    [else (surf-map-type k v loc)])))]

       ;; map-empty: (map-empty K V)
       [(map-empty)
        (or (check-arity 'map-empty args 2 loc)
            (let ([k (parse-datum (car args))]
                  [v (parse-datum (cadr args))])
              (cond [(prologos-error? k) k]
                    [(prologos-error? v) v]
                    [else (surf-map-empty k v loc)])))]

       ;; map-assoc: (map-assoc m k v)
       [(map-assoc)
        (or (check-arity 'map-assoc args 3 loc)
            (let ([m (parse-datum (car args))]
                  [k (parse-datum (cadr args))]
                  [v (parse-datum (caddr args))])
              (cond [(prologos-error? m) m]
                    [(prologos-error? k) k]
                    [(prologos-error? v) v]
                    [else (surf-map-assoc m k v loc)])))]

       ;; map-get: (map-get m k)
       [(map-get)
        (or (check-arity 'map-get args 2 loc)
            (let ([m (parse-datum (car args))]
                  [k (parse-datum (cadr args))])
              (cond [(prologos-error? m) m]
                    [(prologos-error? k) k]
                    [else (surf-map-get m k loc)])))]

       ;; map-dissoc: (map-dissoc m k)
       [(map-dissoc)
        (or (check-arity 'map-dissoc args 2 loc)
            (let ([m (parse-datum (car args))]
                  [k (parse-datum (cadr args))])
              (cond [(prologos-error? m) m]
                    [(prologos-error? k) k]
                    [else (surf-map-dissoc m k loc)])))]

       ;; map-size: (map-size m)
       [(map-size)
        (or (check-arity 'map-size args 1 loc)
            (let ([m (parse-datum (car args))])
              (if (prologos-error? m) m
                  (surf-map-size m loc))))]

       ;; map-has-key?: (map-has-key? m k)
       [(|map-has-key?|)
        (or (check-arity 'map-has-key? args 2 loc)
            (let ([m (parse-datum (car args))]
                  [k (parse-datum (cadr args))])
              (cond [(prologos-error? m) m]
                    [(prologos-error? k) k]
                    [else (surf-map-has-key m k loc)])))]

       ;; map-keys: (map-keys m)
       [(map-keys)
        (or (check-arity 'map-keys args 1 loc)
            (let ([m (parse-datum (car args))])
              (if (prologos-error? m) m
                  (surf-map-keys m loc))))]

       ;; map-vals: (map-vals m)
       [(map-vals)
        (or (check-arity 'map-vals args 1 loc)
            (let ([m (parse-datum (car args))])
              (if (prologos-error? m) m
                  (surf-map-vals m loc))))]

       ;; ---- Set type and operations ----
       ;; (Set A)
       [(Set)
        (or (check-arity 'Set args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a
                  (surf-set-type a loc))))]

       ;; (set-empty A)
       [(set-empty)
        (or (check-arity 'set-empty args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a
                  (surf-set-empty a loc))))]

       ;; (set-insert s a)
       [(set-insert)
        (or (check-arity 'set-insert args 2 loc)
            (let ([s (parse-datum (car args))]
                  [a (parse-datum (cadr args))])
              (cond [(prologos-error? s) s]
                    [(prologos-error? a) a]
                    [else (surf-set-insert s a loc)])))]

       ;; (set-member? s a)
       [(|set-member?|)
        (or (check-arity 'set-member? args 2 loc)
            (let ([s (parse-datum (car args))]
                  [a (parse-datum (cadr args))])
              (cond [(prologos-error? s) s]
                    [(prologos-error? a) a]
                    [else (surf-set-member s a loc)])))]

       ;; (set-delete s a)
       [(set-delete)
        (or (check-arity 'set-delete args 2 loc)
            (let ([s (parse-datum (car args))]
                  [a (parse-datum (cadr args))])
              (cond [(prologos-error? s) s]
                    [(prologos-error? a) a]
                    [else (surf-set-delete s a loc)])))]

       ;; (set-size s)
       [(set-size)
        (or (check-arity 'set-size args 1 loc)
            (let ([s (parse-datum (car args))])
              (if (prologos-error? s) s
                  (surf-set-size s loc))))]

       ;; (set-union s1 s2)
       [(set-union)
        (or (check-arity 'set-union args 2 loc)
            (let ([s1 (parse-datum (car args))]
                  [s2 (parse-datum (cadr args))])
              (cond [(prologos-error? s1) s1]
                    [(prologos-error? s2) s2]
                    [else (surf-set-union s1 s2 loc)])))]

       ;; (set-intersect s1 s2)
       [(set-intersect)
        (or (check-arity 'set-intersect args 2 loc)
            (let ([s1 (parse-datum (car args))]
                  [s2 (parse-datum (cadr args))])
              (cond [(prologos-error? s1) s1]
                    [(prologos-error? s2) s2]
                    [else (surf-set-intersect s1 s2 loc)])))]

       ;; (set-diff s1 s2)
       [(set-diff)
        (or (check-arity 'set-diff args 2 loc)
            (let ([s1 (parse-datum (car args))]
                  [s2 (parse-datum (cadr args))])
              (cond [(prologos-error? s1) s1]
                    [(prologos-error? s2) s2]
                    [else (surf-set-diff s1 s2 loc)])))]

       ;; (set-to-list s)
       [(set-to-list)
        (or (check-arity 'set-to-list args 1 loc)
            (let ([s (parse-datum (car args))])
              (if (prologos-error? s) s
                  (surf-set-to-list s loc))))]

       ;; ---- PVec type and operations ----
       ;; (PVec A)
       [(PVec)
        (or (check-arity 'PVec args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a
                  (surf-pvec-type a loc))))]
       ;; (pvec-empty A)
       [(pvec-empty)
        (or (check-arity 'pvec-empty args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a
                  (surf-pvec-empty a loc))))]
       ;; (pvec-push v x)
       [(pvec-push)
        (or (check-arity 'pvec-push args 2 loc)
            (let ([v (parse-datum (car args))]
                  [x (parse-datum (cadr args))])
              (cond [(prologos-error? v) v]
                    [(prologos-error? x) x]
                    [else (surf-pvec-push v x loc)])))]
       ;; (pvec-nth v i)
       [(pvec-nth)
        (or (check-arity 'pvec-nth args 2 loc)
            (let ([v (parse-datum (car args))]
                  [i (parse-datum (cadr args))])
              (cond [(prologos-error? v) v]
                    [(prologos-error? i) i]
                    [else (surf-pvec-nth v i loc)])))]
       ;; (pvec-update v i x)
       [(pvec-update)
        (or (check-arity 'pvec-update args 3 loc)
            (let ([v (parse-datum (car args))]
                  [i (parse-datum (cadr args))]
                  [x (parse-datum (caddr args))])
              (cond [(prologos-error? v) v]
                    [(prologos-error? i) i]
                    [(prologos-error? x) x]
                    [else (surf-pvec-update v i x loc)])))]
       ;; (pvec-length v)
       [(pvec-length)
        (or (check-arity 'pvec-length args 1 loc)
            (let ([v (parse-datum (car args))])
              (if (prologos-error? v) v
                  (surf-pvec-length v loc))))]
       ;; (pvec-pop v)
       [(pvec-pop)
        (or (check-arity 'pvec-pop args 1 loc)
            (let ([v (parse-datum (car args))])
              (if (prologos-error? v) v
                  (surf-pvec-pop v loc))))]
       ;; (pvec-concat v1 v2)
       [(pvec-concat)
        (or (check-arity 'pvec-concat args 2 loc)
            (let ([v1 (parse-datum (car args))]
                  [v2 (parse-datum (cadr args))])
              (cond [(prologos-error? v1) v1]
                    [(prologos-error? v2) v2]
                    [else (surf-pvec-concat v1 v2 loc)])))]
       ;; (pvec-slice v lo hi)
       [(pvec-slice)
        (or (check-arity 'pvec-slice args 3 loc)
            (let ([v (parse-datum (car args))]
                  [lo (parse-datum (cadr args))]
                  [hi (parse-datum (caddr args))])
              (cond [(prologos-error? v) v]
                    [(prologos-error? lo) lo]
                    [(prologos-error? hi) hi]
                    [else (surf-pvec-slice v lo hi loc)])))]
       ;; (pvec-to-list v)
       [(pvec-to-list)
        (or (check-arity 'pvec-to-list args 1 loc)
            (let ([v (parse-datum (car args))])
              (if (prologos-error? v) v
                  (surf-pvec-to-list v loc))))]
       ;; (pvec-from-list v)
       [(pvec-from-list)
        (or (check-arity 'pvec-from-list args 1 loc)
            (let ([v (parse-datum (car args))])
              (if (prologos-error? v) v
                  (surf-pvec-from-list v loc))))]
       ;; (pvec-fold f init vec)
       [(pvec-fold)
        (or (check-arity 'pvec-fold args 3 loc)
            (let ([f    (parse-datum (car args))]
                  [init (parse-datum (cadr args))]
                  [vec  (parse-datum (caddr args))])
              (cond [(prologos-error? f)    f]
                    [(prologos-error? init) init]
                    [(prologos-error? vec)  vec]
                    [else (surf-pvec-fold f init vec loc)])))]
       ;; (pvec-map f vec)
       [(pvec-map)
        (or (check-arity 'pvec-map args 2 loc)
            (let ([f   (parse-datum (car args))]
                  [vec (parse-datum (cadr args))])
              (cond [(prologos-error? f)   f]
                    [(prologos-error? vec) vec]
                    [else (surf-pvec-map f vec loc)])))]
       ;; (pvec-filter pred vec)
       [(pvec-filter)
        (or (check-arity 'pvec-filter args 2 loc)
            (let ([pred (parse-datum (car args))]
                  [vec  (parse-datum (cadr args))])
              (cond [(prologos-error? pred) pred]
                    [(prologos-error? vec)  vec]
                    [else (surf-pvec-filter pred vec loc)])))]
       ;; (set-fold f init set)
       [(set-fold)
        (or (check-arity 'set-fold args 3 loc)
            (let ([f    (parse-datum (car args))]
                  [init (parse-datum (cadr args))]
                  [s    (parse-datum (caddr args))])
              (cond [(prologos-error? f)    f]
                    [(prologos-error? init) init]
                    [(prologos-error? s)    s]
                    [else (surf-set-fold f init s loc)])))]
       ;; (set-filter pred set)
       [(set-filter)
        (or (check-arity 'set-filter args 2 loc)
            (let ([pred (parse-datum (car args))]
                  [s    (parse-datum (cadr args))])
              (cond [(prologos-error? pred) pred]
                    [(prologos-error? s)    s]
                    [else (surf-set-filter pred s loc)])))]
       ;; (map-fold-entries f init map)
       [(map-fold-entries)
        (or (check-arity 'map-fold-entries args 3 loc)
            (let ([f    (parse-datum (car args))]
                  [init (parse-datum (cadr args))]
                  [m    (parse-datum (caddr args))])
              (cond [(prologos-error? f)    f]
                    [(prologos-error? init) init]
                    [(prologos-error? m)    m]
                    [else (surf-map-fold-entries f init m loc)])))]
       ;; (map-filter-entries pred map)
       [(map-filter-entries)
        (or (check-arity 'map-filter-entries args 2 loc)
            (let ([pred (parse-datum (car args))]
                  [m    (parse-datum (cadr args))])
              (cond [(prologos-error? pred) pred]
                    [(prologos-error? m)    m]
                    [else (surf-map-filter-entries pred m loc)])))]
       ;; (map-map-vals f map)
       [(map-map-vals)
        (or (check-arity 'map-map-vals args 2 loc)
            (let ([f (parse-datum (car args))]
                  [m (parse-datum (cadr args))])
              (cond [(prologos-error? f) f]
                    [(prologos-error? m) m]
                    [else (surf-map-map-vals f m loc)])))]

       ;; ---- Transient Builder types ----
       ;; (TVec A)
       [(TVec)
        (or (check-arity 'TVec args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a
                  (surf-transient-type 'TVec a loc))))]
       ;; (TMap K V)
       [(TMap)
        (or (check-arity 'TMap args 2 loc)
            (let ([k (parse-datum (car args))]
                  [v (parse-datum (cadr args))])
              (cond [(prologos-error? k) k]
                    [(prologos-error? v) v]
                    [else (surf-transient-type 'TMap (list k v) loc)])))]
       ;; (TSet A)
       [(TSet)
        (or (check-arity 'TSet args 1 loc)
            (let ([a (parse-datum (car args))])
              (if (prologos-error? a) a
                  (surf-transient-type 'TSet a loc))))]

       ;; ---- Transient Builder keywords ----
       ;; (transient coll)
       [(transient)
        (or (check-arity 'transient args 1 loc)
            (let ([c (parse-datum (car args))])
              (if (prologos-error? c) c
                  (surf-transient c loc))))]
       ;; (persist! coll)
       [(|persist!|)
        (or (check-arity '|persist!| args 1 loc)
            (let ([c (parse-datum (car args))])
              (if (prologos-error? c) c
                  (surf-persist c loc))))]
       ;; (tvec-push! t x)
       [(|tvec-push!|)
        (or (check-arity '|tvec-push!| args 2 loc)
            (let ([t (parse-datum (car args))]
                  [x (parse-datum (cadr args))])
              (cond [(prologos-error? t) t]
                    [(prologos-error? x) x]
                    [else (surf-tvec-push! t x loc)])))]
       ;; (tvec-update! t i x)
       [(|tvec-update!|)
        (or (check-arity '|tvec-update!| args 3 loc)
            (let ([t (parse-datum (car args))]
                  [i (parse-datum (cadr args))]
                  [x (parse-datum (caddr args))])
              (cond [(prologos-error? t) t]
                    [(prologos-error? i) i]
                    [(prologos-error? x) x]
                    [else (surf-tvec-update! t i x loc)])))]
       ;; (tmap-assoc! t k v)
       [(|tmap-assoc!|)
        (or (check-arity '|tmap-assoc!| args 3 loc)
            (let ([t (parse-datum (car args))]
                  [k (parse-datum (cadr args))]
                  [v (parse-datum (caddr args))])
              (cond [(prologos-error? t) t]
                    [(prologos-error? k) k]
                    [(prologos-error? v) v]
                    [else (surf-tmap-assoc! t k v loc)])))]
       ;; (tmap-dissoc! t k)
       [(|tmap-dissoc!|)
        (or (check-arity '|tmap-dissoc!| args 2 loc)
            (let ([t (parse-datum (car args))]
                  [k (parse-datum (cadr args))])
              (cond [(prologos-error? t) t]
                    [(prologos-error? k) k]
                    [else (surf-tmap-dissoc! t k loc)])))]
       ;; (tset-insert! t a)
       [(|tset-insert!|)
        (or (check-arity '|tset-insert!| args 2 loc)
            (let ([t (parse-datum (car args))]
                  [a (parse-datum (cadr args))])
              (cond [(prologos-error? t) t]
                    [(prologos-error? a) a]
                    [else (surf-tset-insert! t a loc)])))]
       ;; (tset-delete! t a)
       [(|tset-delete!|)
        (or (check-arity '|tset-delete!| args 2 loc)
            (let ([t (parse-datum (car args))]
                  [a (parse-datum (cadr args))])
              (cond [(prologos-error? t) t]
                    [(prologos-error? a) a]
                    [else (surf-tset-delete! t a loc)])))]

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
       [(with-transient)
        (parse-error loc "with-transient should have been expanded before parsing" #f)]
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

       ;; (expand-1 form) — single-step preparse expansion
       [(expand-1)
        (or (check-arity 'expand-1 args 1 loc)
            (let ([raw (car args)])
              (surf-expand-1 (if (syntax? raw) (syntax->datum raw) raw) loc)))]

       ;; (expand-full form) — all preparse transforms with labels
       [(expand-full)
        (or (check-arity 'expand-full args 1 loc)
            (let ([raw (car args)])
              (surf-expand-full (if (syntax? raw) (syntax->datum raw) raw) loc)))]

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
              (and elems
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

  ;; Extract implicit binders from one or more leading {A B} {C : Type -> Type} groups
  (define-values (implicit-binders rest-after-braces)
    (let loop ([remaining (cdr args)] [binders '()])
      (cond
        [(and (pair? remaining) (brace-params-stx? (car remaining)))
         (define parsed (unwrap-brace-params (car remaining) loc))
         (when (prologos-error? parsed)
           (values parsed '()))
         (loop (cdr remaining) (append binders parsed))]
        [else
         (values binders remaining)])))

  ;; The next arg should be the explicit params bracket
  (define params-stx (car rest-after-braces))
  (define rest-args (cdr rest-after-braces)) ; <ReturnType> body  OR  : RetType body

  ;; Parse explicit binders from the bracket form
  ;; Sprint 10: detect bare params (only symbols, no types) vs typed params
  (define explicit-binders
    (let ([elems (if (syntax? params-stx) (syntax->list params-stx) #f)])
      (cond
        ;; Zero-arg: empty brackets → no binders
        [(and elems (null? elems)) '()]
        ;; Bare params: only symbols, no type annotations
        [(and elems
              (andmap (lambda (e) (symbol? (syntax-e e))) elems)
              (not (ormap (lambda (e)
                            (let ([d (syntax-e e)])
                              (or (eq? d ':) (mult-annot? d))))
                          elems)))
         (for/list ([e (in-list elems)])
           (binder-info (syntax-e e) #f (surf-hole loc)))]
        ;; Typed params: existing path
        [else (parse-defn-binders params-stx loc)])))

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
    [(null? parts) '()]
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
     ;; Parse as a full form via parse-datum, which correctly dispatches
     ;; native type keywords (Set, Map, PVec, List, etc.) as well as
     ;; user-defined type constructors via application.
     (parse-datum (datum->syntax #f (if (not (equal? expanded datums))
                                        expanded
                                        datums)))]))

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
  (cond
    [first-err first-err]
    ;; If any arms have numeric ctor-names, desugar them
    [(ormap (lambda (a) (integer? (reduce-arm-ctor-name a))) result)
     (desugar-numeric-arms result)]
    [else result]))

;; Desugar numeric literal patterns in a list of reduce-arms.
;; Numeric arms have integer ctor-names (produced by parse-reduce-arm).
;; Strategy: collect all numeric arms, convert to a cascading nested match tree,
;; then splice the desugared arm(s) back into the arm list at the position of
;; the first numeric arm.
;;
;; Example: | 0 -> A | 1 -> B | 2 -> C | suc k -> D
;; Desugars to: | zero -> A | suc $v -> (match $v | zero -> B | suc $v2 -> (match $v2 | zero -> C | suc k -> D))
;;
;; The cascading match peels one layer of `suc` per numeric level, trying the
;; numeric arms from smallest to largest before falling through to user-written
;; `suc` arms.
(define (desugar-numeric-arms arms)
  ;; Separate numeric-literal arms from normal arms
  (define numeric-arms
    (filter (lambda (a) (integer? (reduce-arm-ctor-name a))) arms))
  (when (null? numeric-arms) (error 'desugar-numeric-arms "no numeric arms"))

  ;; Non-numeric arms, preserving order
  (define normal-arms
    (filter (lambda (a) (not (integer? (reduce-arm-ctor-name a)))) arms))

  ;; Sort numeric arms by value (ascending) for cascading dispatch
  (define sorted-numeric
    (sort numeric-arms < #:key reduce-arm-ctor-name))

  ;; Find the existing 'suc arm and 'zero arm from normal arms (if any)
  (define user-zero-arm
    (findf (lambda (a) (eq? (reduce-arm-ctor-name a) 'zero)) normal-arms))
  (define user-suc-arm
    (findf (lambda (a) (eq? (reduce-arm-ctor-name a) 'suc)) normal-arms))

  ;; Normal arms that are NOT zero or suc (e.g., for other types — shouldn't
  ;; happen for Nat, but be safe)
  (define other-arms
    (filter (lambda (a)
              (and (not (integer? (reduce-arm-ctor-name a)))
                   (not (eq? (reduce-arm-ctor-name a) 'zero))
                   (not (eq? (reduce-arm-ctor-name a) 'suc))))
            arms))

  ;; Build the desugared arm list.
  ;; Numeric arms produce: zero arms (for N=0) and a cascading suc arm (for N>0)
  (define zero-numeric (filter (lambda (a) (= (reduce-arm-ctor-name a) 0)) sorted-numeric))
  (define positive-numeric (filter (lambda (a) (> (reduce-arm-ctor-name a) 0)) sorted-numeric))

  ;; The zero arm: either from numeric | 0 -> ... or from user | zero -> ...
  ;; Numeric takes priority (it appears in the arm list position)
  (define final-zero-arm
    (cond
      [(not (null? zero-numeric))
       (let ([a (car zero-numeric)])
         (reduce-arm 'zero '() (reduce-arm-body a) (reduce-arm-srcloc a)))]
      [user-zero-arm user-zero-arm]
      [else #f]))

  ;; Build cascading nested match for positive numeric patterns.
  ;; Each level peels one `suc` and dispatches on the predecessor.
  ;; At the bottom, fall through to the user's `suc k -> ...` arm if present.
  ;;
  ;; For N=1: match pred | zero -> body1 | suc k -> <user-suc-body or next-level>
  ;; For N=2 after peeling to pred:
  ;;   match pred | zero -> body1 | suc $v -> match $v | zero -> body2 | suc k -> ...
  ;;
  ;; We build this inside-out: start with the deepest level and work outward.
  (define final-suc-arm
    (if (null? positive-numeric)
        user-suc-arm  ;; no positive numeric arms, keep user's suc arm
        (let ()
          ;; Group positive-numeric by depth (value - 1 = depth of predecessor match)
          ;; Build a tree: at depth d, match the d-th predecessor
          ;; Approach: recursively build from the highest numeric value down
          ;;
          ;; We organize by value: for each N, at nesting depth N-1, we match zero.
          ;; Between levels, we match suc and recurse.
          ;;
          ;; Build a function that creates the nested match for a range of values.
          ;; Given a list of (value . body) pairs sorted ascending and a fallthrough arm,
          ;; produce a reduce-arm for 'suc that dispatches.

          (define (build-dispatch remaining-pairs fallthrough-suc-arm depth loc)
            ;; remaining-pairs: list of (value . body) sorted ascending, all > depth
            ;; depth: current nesting depth (0 = matching pred of outermost suc)
            ;; fallthrough-suc-arm: user's suc arm to use when no numeric match
            (cond
              [(null? remaining-pairs)
               ;; No more numeric patterns at this level or deeper
               ;; Use the user's suc arm if available, else no arm
               fallthrough-suc-arm]
              [else
               (define next-val (car (car remaining-pairs)))
               (define next-body (cdr (car remaining-pairs)))
               (define rest-pairs (cdr remaining-pairs))
               (cond
                 [(= next-val (+ depth 1))
                  ;; This pattern matches zero at this level (i.e., value = depth+1
                  ;; means after peeling depth+1 incs total, we find zero at this pred)
                  ;; Build: match pred | zero -> body | suc $v -> <recurse>
                  (define var (gensym '$np-))
                  (define deeper
                    (build-dispatch rest-pairs fallthrough-suc-arm (+ depth 1) loc))
                  (define inner-arms
                    (append
                     (list (reduce-arm 'zero '() next-body loc))
                     (if deeper (list deeper) '())))
                  ;; Return an suc arm at this level
                  (reduce-arm 'suc (list var)
                              (surf-reduce (surf-var var loc) inner-arms loc)
                              loc)]
                 [else
                  ;; next-val > depth+1: no pattern at this level, just peel and recurse
                  (define var (gensym '$np-))
                  (define deeper
                    (build-dispatch remaining-pairs fallthrough-suc-arm (+ depth 1) loc))
                  (define inner-arms
                    (if deeper (list deeper) '()))
                  (if (null? inner-arms)
                      fallthrough-suc-arm  ;; nothing to dispatch, fall through
                      (reduce-arm 'suc (list var)
                                  (surf-reduce (surf-var var loc) inner-arms loc)
                                  loc))])]))

          (define pairs
            (map (lambda (a) (cons (reduce-arm-ctor-name a) (reduce-arm-body a)))
                 positive-numeric))
          (define loc (reduce-arm-srcloc (car positive-numeric)))

          (build-dispatch pairs user-suc-arm 0 loc))))

  ;; Assemble final arm list: zero arm, suc arm, then other arms
  (append
   (if final-zero-arm (list final-zero-arm) '())
   (if final-suc-arm (list final-suc-arm) '())
   other-arms))

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

  ;; Flatten single-element list patterns from $mixfix expansion:
  ;; If pattern is ((cons h t)), flatten to (cons h t) for ctor-name + bindings.
  ;; This handles .{h :: t} in match arms.
  ;; Note: stx->datum (syntax-e) does shallow unwrap — use syntax->datum for deep.
  (define effective-pattern
    (let* ([first-stx (car pattern)]
           [first-deep (if (syntax? first-stx) (syntax->datum first-stx) first-stx)])
      (if (and (= (length pattern) 1) (pair? first-deep) (symbol? (car first-deep)))
          ;; Single list element that is a constructor application: flatten it
          ;; Get inner syntax objects via syntax->list, or reconstruct
          (or (and (syntax? first-stx) (syntax->list first-stx))
              (map (lambda (x) (datum->syntax #f x)) first-deep))
          pattern)))
  (define ctor-name (stx->datum (car effective-pattern)))
  (define binding-names
    (for/list ([p (in-list (cdr effective-pattern))])
      (stx->datum p)))

  ;; Parse body first (needed by all paths)
  (define body (parse-datum body-stx))
  (cond
    [(prologos-error? body) body]

    ;; Numeric literal pattern: validate and produce tagged reduce-arm
    ;; Actual desugaring happens in desugar-numeric-arms (called from parse-reduce-arms)
    [(and (exact-nonnegative-integer? ctor-name) (integer? ctor-name))
     (cond
       ;; Numeric patterns cannot have bindings: | 2 k -> ... is invalid
       [(not (null? binding-names))
        (parse-error loc
          (format "reduce arm: numeric literal pattern ~a cannot have bindings" ctor-name) #f)]
       ;; Reject unreasonably large patterns to avoid deep nesting
       [(> ctor-name 20)
        (parse-error loc
          (format "reduce arm: numeric literal pattern ~a is too large (max 20)" ctor-name) #f)]
       ;; Tag with the numeric value as ctor-name (integer, not symbol)
       ;; desugar-numeric-arms will convert these to proper constructor arms
       [else
        (reduce-arm ctor-name '() body loc)])]

    ;; Nat-suffix literal pattern: 0N, 3N, etc. (sexp mode reads these as symbols)
    [(and (symbol? ctor-name)
          (let ([s (symbol->string ctor-name)])
            (and (> (string-length s) 1)
                 (char=? (string-ref s (- (string-length s) 1)) #\N)
                 (for/and ([c (in-string (substring s 0 (- (string-length s) 1)))])
                   (char-numeric? c)))))
     (let ([v (string->number
               (substring (symbol->string ctor-name) 0
                          (- (string-length (symbol->string ctor-name)) 1)))])
       (cond
         [(not (null? binding-names))
          (parse-error loc
            (format "reduce arm: numeric literal pattern ~aN cannot have bindings" v) #f)]
         [(> v 20)
          (parse-error loc
            (format "reduce arm: numeric literal pattern ~aN is too large (max 20)" v) #f)]
         [else
          (reduce-arm v '() body loc)]))]

    ;; Non-numeric, non-symbol constructor name: error (fixes latent unless bug)
    [(not (symbol? ctor-name))
     (parse-error loc
       (format "reduce arm: constructor name must be a symbol, got ~a" ctor-name) #f)]

    ;; Non-symbol bindings: error (fixes latent unless bug)
    [(not (andmap symbol? binding-names))
     (parse-error loc "reduce arm: all bindings must be bare symbols" #f)]

    ;; Normal constructor pattern
    [else
     (reduce-arm ctor-name binding-names body loc)]))

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
;; Map literal parsing
;; ========================================
;; Parse a map literal from $brace-params contents.
;; args = list of alternating key-value datums: (k1 v1 k2 v2 ...)
;; Keys must be: keyword (:name), string, number, or [expr].
;; Bare symbols are not allowed as keys.
(define (parse-map-literal args loc)
  (when (odd? (length args))
    (parse-error loc "Map literal requires an even number of elements (key-value pairs)" #f))
  (define entries
    (let loop ([remaining args] [acc '()])
      (cond
        [(null? remaining) (reverse acc)]
        [else
         (define key-stx (car remaining))
         (define val-stx (cadr remaining))
         (define key-datum (stx->datum key-stx))
         (define parsed-key
           (cond
             ;; Keyword: symbol starting with :
             [(and (symbol? key-datum)
                   (let ([s (symbol->string key-datum)])
                     (and (> (string-length s) 1)
                          (char=? (string-ref s 0) #\:))))
              (surf-keyword (string->symbol (substring (symbol->string key-datum) 1)) loc)]
             ;; String key
             [(string? key-datum)
              (parse-datum key-stx)]
             ;; Number key
             [(number? key-datum)
              (parse-datum key-stx)]
             ;; Bracket form [expr] — computed key
             [(pair? key-datum)
              (parse-datum key-stx)]
             ;; Bare symbol — error
             [(symbol? key-datum)
              (parse-error loc
                (format "Bare symbol '~a' not allowed as map key; use :~a for keyword" key-datum key-datum)
                #f)]
             [else
              (parse-error loc
                (format "Invalid map key: ~a" key-datum) #f)]))
         (define parsed-val (parse-datum val-stx))
         (cond
           [(prologos-error? parsed-key) parsed-key]
           [(prologos-error? parsed-val) parsed-val]
           [else (loop (cddr remaining) (cons (cons parsed-key parsed-val) acc))])])))
  (if (prologos-error? entries)
      entries
      (surf-map-literal entries loc)))

;; ========================================
;; PVec literal parsing
;; ========================================
;; Parse a PVec literal from $vec-literal contents.
;; args = list of element datums: (e1 e2 e3 ...)
(define (parse-set-literal args loc)
  ;; #{e1 e2 ...} — elements are just expressions (not key-value pairs)
  (define parsed-elems
    (let loop ([remaining args] [acc '()])
      (cond
        [(null? remaining) (reverse acc)]
        [else
         (define parsed (parse-datum (car remaining)))
         (if (prologos-error? parsed)
             parsed  ; propagate error immediately
             (loop (cdr remaining) (cons parsed acc)))])))
  (if (prologos-error? parsed-elems)
      parsed-elems
      (surf-set-literal parsed-elems loc)))

(define (parse-pvec-literal args loc)
  (define parsed-elems
    (let loop ([remaining args] [acc '()])
      (cond
        [(null? remaining) (reverse acc)]
        [else
         (define parsed (parse-datum (car remaining)))
         (if (prologos-error? parsed)
             parsed  ; propagate error immediately
             (loop (cdr remaining) (cons parsed acc)))])))
  (if (prologos-error? parsed-elems)
      parsed-elems
      (surf-pvec-literal parsed-elems loc)))

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
