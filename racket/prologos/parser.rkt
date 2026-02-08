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
         "errors.rkt")

(provide parse-datum
         parse-string
         parse-port)

;; ========================================
;; Keywords: forms with special parsing rules
;; ========================================
(define keywords
  '(suc lam Pi Sigma -> Eq the Type
    Vec Fin vnil vcons vhead vtail vindex fzero fsuc
    natrec J pair fst snd
    def check eval infer))

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
    [(Nat)   (surf-nat-type loc)]
    [(Bool)  (surf-bool-type loc)]
    [(zero)  (surf-zero loc)]
    [(true)  (surf-true loc)]
    [(false) (surf-false loc)]
    [(refl)  (surf-refl loc)]
    [else    (surf-var sym loc)]))

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
       ;; (suc e)
       [(suc)
        (or (check-arity 'suc args 1 loc)
            (let ([e (parse-datum (car args))])
              (if (prologos-error? e) e
                  (surf-suc e loc))))]

       ;; (lam (x : T) body) or (lam (x :m T) body)
       [(lam)
        (or (check-arity 'lam args 2 loc)
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

       ;; (the T e)
       [(the)
        (or (check-arity 'the args 2 loc)
            (let ([t (parse-datum (car args))]
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

       ;; (fst e), (snd e)
       [(fst)
        (or (check-arity 'fst args 1 loc)
            (let ([e (parse-datum (car args))])
              (if (prologos-error? e) e (surf-fst e loc))))]
       [(snd)
        (or (check-arity 'snd args 1 loc)
            (let ([e (parse-datum (car args))])
              (if (prologos-error? e) e (surf-snd e loc))))]

       ;; (natrec motive base step target)
       [(natrec)
        (or (check-arity 'natrec args 4 loc)
            (let ([mot (parse-datum (car args))]
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

       ;; Top-level commands
       ;; (def name : type body)
       [(def)
        (parse-def args loc)]
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
     (parse-error loc (format "Expected binder (x : T), got ~a" d) d)]
    [else
     (define parts
       (if (syntax? stx) (syntax->list stx) d))
     (cond
       ;; (x : T) — 3 elements
       [(and (= (length parts) 3)
             (eq? (stx->datum (cadr parts)) ':))
        (let ([name (stx->datum (car parts))]
              [type-stx (caddr parts)])
          (if (symbol? name)
              (let ([ty (parse-datum type-stx)])
                (if (prologos-error? ty) ty
                    (binder-info name 'mw ty)))
              (parse-error loc (format "Expected variable name, got ~a" name) name)))]

       ;; (x :m T) — 3 elements where second is :0, :1, :w
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
                     (format "Expected binder (x : T) or (x :m T), got ~a" d)
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
  ;; args should be: name : type body
  (cond
    [(< (length args) 4)
     (parse-error loc "def requires: (def name : type body)" #f)]
    [else
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
              [else (surf-def name ty bd loc)]))]))]))

;; ========================================
;; Parse check command: (check expr : type)
;; ========================================
(define (parse-check-cmd args loc)
  ;; args should be: expr : type
  (cond
    [(< (length args) 3)
     (parse-error loc "check requires: (check expr : type)" #f)]
    [else
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
              [else (surf-check e t loc)]))]))]))

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
  (define stx (read-syntax "<string>" in))
  (if (eof-object? stx)
      (parse-error srcloc-unknown "Empty input" #f)
      (parse-datum stx)))

;; Parse all forms from a port (for file loading)
(define (parse-port port [source "<port>"])
  (port-count-lines! port)
  (let loop ([results '()])
    (define stx (read-syntax source port))
    (if (eof-object? stx)
        (reverse results)
        (let ([parsed (parse-datum stx)])
          (loop (cons parsed results))))))
