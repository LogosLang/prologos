#lang racket/base

;;;
;;; PROLOGOS PARSER
;;; Transforms Racket S-expressions (from read/read-syntax) into surface AST.
;;; Uses Racket's reader for lexing; this module does semantic parsing.
;;;

(require racket/match
         racket/port
         "source-location.rkt"
         "surface-syntax.rkt"
         "errors.rkt"
         "sexp-readtable.rkt")

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
    def defn check eval infer
    ;; Pre-parse macros — should be expanded before reaching parser
    defmacro let do if deftype data match
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
    [(Nat)    (surf-nat-type loc)]
    [(Bool)   (surf-bool-type loc)]
    [(Posit8) (surf-posit8-type loc)]
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

       ;; (fn (x : T) body) or (fn (x :m T) body)
       [(fn)
        (or (check-arity 'fn args 2 loc)
            (let ([bnd (parse-binder (car args) loc)])
              (if (prologos-error? bnd) bnd
                  (let ([body (parse-datum (cadr args))])
                    (if (prologos-error? body) body
                        (surf-lam bnd body loc))))))]

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
  ;; NEW: (defn name [param <T> ...] <ReturnType> body) — typed binders
  ;; OLD: (defn name : type [params...] body) — 5 elements with colon
  (cond
    ;; Detect new syntax: second arg is a bracket form (params with types)
    ;; Detection: either paren-shape property is #\[, or content contains $angle-type markers
    ;; (The latter handles cases where syntax properties were lost during macro expansion)
    [(and (>= (length args) 4)
          (let ([second (cadr args)])
            (or (and (syntax? second)
                     (eq? (syntax-property second 'paren-shape) #\[))
                ;; Content-based detection: list containing $angle-type markers
                (let ([d (if (syntax? second) (syntax->datum second) second)])
                  (and (list? d)
                       (ormap (lambda (x)
                                (and (pair? x) (eq? (car x) '$angle-type)))
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

  ;; rest-args should be: <ReturnType> body
  (cond
    [(prologos-error? binders) binders]
    [(< (length rest-args) 2)
     (parse-error loc "defn: missing return type or body" #f)]
    [else
     (define ret-type-stx (car rest-args))
     (define body-stx (cadr rest-args))
     (cond
       [(not (angle-type-stx? ret-type-stx))
        (parse-error loc (format "defn: expected <ReturnType>, got ~a" (stx->datum ret-type-stx)) #f)]
       [else
        (define ret-type (unwrap-angle-type ret-type-stx loc))
        (define body (parse-datum body-stx))
        (cond
          [(prologos-error? ret-type) ret-type]
          [(prologos-error? body) body]
          [else
           ;; Build the full Pi type from binders and return type
           ;; (Pi [A :0 <(Type 0)>] (Pi [x <A>] ReturnType)) etc.
           (define full-type
             (foldr (lambda (bnd rest-ty)
                      (surf-pi bnd rest-ty loc))
                    ret-type
                    binders))
           ;; Extract just the parameter names for surf-defn
           (define param-names (map binder-info-name binders))
           (surf-defn name full-type param-names body loc)])])]))

;; Parse typed binders from bracket contents: [x <T> y :0 <T2> ...]
;; Returns a list of binder-info structs.
(define (parse-defn-binders stx loc)
  (define parts
    (if (syntax? stx) (syntax->list stx) (stx->datum stx)))
  (cond
    [(not parts)
     (parse-error loc "defn: malformed parameter list" #f)]
    [(null? parts)
     (parse-error loc "defn: parameter list cannot be empty" #f)]
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
