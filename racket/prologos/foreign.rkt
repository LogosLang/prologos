#lang racket/base

;;;
;;; PROLOGOS FOREIGN FUNCTION MARSHALLING
;;; Converts between Prologos values (Church/Peano encoded) and Racket values.
;;;
;;; Supported base types:
;;;   Nat              ↔ exact non-negative integer
;;;   Int              ↔ exact integer
;;;   Rat              ↔ exact rational
;;;   Bool             ↔ boolean
;;;   Unit             ↔ void
;;;   Char             ↔ char
;;;   String           ↔ string
;;;   Posit8/16/32/64  ↔ exact rational (semantic value; NaR raises an error)
;;;   List <T>         ↔ list of marshalled elements (recursive in T)
;;;

(require racket/match
         racket/string
         "syntax.rkt"
         "posit-impl.rkt")

(provide marshal-prologos->racket
         marshal-racket->prologos
         nat->integer
         integer->nat
         bool->boolean
         int->integer
         integer->int
         posit->rational
         rational->posit
         prologos-list->racket-list
         racket-list->prologos-list
         parse-foreign-type
         make-marshaller-pair
         base-type-name)

;; ========================================
;; Prologos → Racket marshalling
;; ========================================

;; Convert a Prologos Nat (Peano) to a Racket exact integer
(define (nat->integer e)
  (let loop ([e e] [acc 0])
    (match e
      [(expr-nat-val n) (+ acc n)]
      [(expr-zero) acc]
      [(expr-suc n) (loop n (add1 acc))]
      [_ (error 'foreign "Cannot marshal to integer — not a Nat numeral: ~a" e)])))

;; Convert a Prologos Bool to a Racket boolean
(define (bool->boolean e)
  (match e
    [(expr-true) #t]
    [(expr-false) #f]
    [_ (error 'foreign "Cannot marshal to boolean — not a Bool: ~a" e)]))

;; Dispatch marshal-out by base type symbol
;; Convert a Prologos Int to a Racket exact integer
(define (int->integer e)
  (match e
    [(expr-int v) v]
    [_ (error 'foreign "Cannot marshal to integer — not an Int literal: ~a" e)]))

;; Convert a Prologos Rat to a Racket exact rational
(define (rat->rational e)
  (match e
    [(expr-rat v) v]
    [_ (error 'foreign "Cannot marshal to rational — not a Rat literal: ~a" e)]))

;; Convert a Prologos Char to a Racket char
(define (char->rkt-char e)
  (match e
    [(expr-char v) v]
    [_ (error 'foreign "Cannot marshal to char — not a Char literal: ~a" e)]))

;; Convert a Prologos String to a Racket string
(define (string->rkt-string e)
  (match e
    [(expr-string v) v]
    [_ (error 'foreign "Cannot marshal to string — not a String literal: ~a" e)]))

;; Convert a Prologos Posit (any width) to a Racket exact rational.
;; NaR contamination raises an error since rationals cannot represent NaR.
(define (posit->rational e)
  (define-values (width bits)
    (match e
      [(expr-posit8  v) (values 8  v)]
      [(expr-posit16 v) (values 16 v)]
      [(expr-posit32 v) (values 32 v)]
      [(expr-posit64 v) (values 64 v)]
      [_ (error 'foreign "Cannot marshal to rational — not a Posit literal: ~a" e)]))
  (define r
    (case width
      [(8)  (posit8-to-rational  bits)]
      [(16) (posit16-to-rational bits)]
      [(32) (posit32-to-rational bits)]
      [(64) (posit64-to-rational bits)]))
  (when (eq? r 'nar)
    (error 'foreign "Cannot marshal Posit~a NaR to rational" width))
  r)

;; Helpers: recognize cons/nil names regardless of namespace qualification.
(define (list-cons-name? name)
  (and (symbol? name)
       (let ([s (symbol->string name)])
         (or (string=? s "cons")
             (let ([len (string-length s)])
               (and (>= len 6)
                    (string=? (substring s (- len 6)) "::cons")))))))

(define (list-nil-name? name)
  (and (symbol? name)
       (let ([s (symbol->string name)])
         (or (string=? s "nil")
             (let ([len (string-length s)])
               (and (>= len 5)
                    (string=? (substring s (- len 5)) "::nil")))))))

;; Walk a Prologos List value (cons/nil chain) into a Racket list of element exprs.
;; Recognizes both forms:
;;   - (cons head tail)         — 2-arg form, no type argument
;;   - (cons A head tail)       — 3-arg form with implicit type argument
;;   - nil  /  (expr-nil)       — bare nil
;;   - (nil A)                  — nil applied to type argument
;; Errors on a stuck or non-list expression.
(define (prologos-list->racket-list e)
  (let loop ([cur e] [acc '()])
    (cond
      ;; (expr-nil) — built-in nil node
      [(expr-nil? cur)
       (reverse acc)]
      ;; bare 'nil / qualified ::nil fvar
      [(and (expr-fvar? cur) (list-nil-name? (expr-fvar-name cur)))
       (reverse acc)]
      ;; (nil A) — nil with type argument
      [(and (expr-app? cur)
            (let ([f (expr-app-func cur)])
              (and (expr-fvar? f) (list-nil-name? (expr-fvar-name f)))))
       (reverse acc)]
      ;; cons applications: 2-arg ((cons head) tail) or 3-arg (((cons A) head) tail)
      [(expr-app? cur)
       (define head-app (expr-app-func cur))
       (define tail (expr-app-arg cur))
       (cond
         ;; ((cons head) tail) — 2-arg
         [(and (expr-app? head-app)
               (let ([f (expr-app-func head-app)])
                 (and (expr-fvar? f) (list-cons-name? (expr-fvar-name f)))))
          (loop tail (cons (expr-app-arg head-app) acc))]
         ;; (((cons A) head) tail) — 3-arg with type
         [(and (expr-app? head-app)
               (expr-app? (expr-app-func head-app))
               (let ([f (expr-app-func (expr-app-func head-app))])
                 (and (expr-fvar? f) (list-cons-name? (expr-fvar-name f)))))
          (loop tail (cons (expr-app-arg head-app) acc))]
         [else
          (error 'foreign "Cannot marshal to list — not a cons/nil chain: ~a" e)])]
      [else
       (error 'foreign "Cannot marshal to list — not a cons/nil chain: ~a" e)])))

(define (marshal-prologos->racket base-type val)
  (cond
    ;; Compound List type: (List <inner>)
    [(and (pair? base-type) (eq? (car base-type) 'List))
     (define inner (cadr base-type))
     (map (lambda (e) (marshal-prologos->racket inner e))
          (prologos-list->racket-list val))]
    ;; Atomic types
    [(symbol? base-type)
     (case base-type
       [(Nat)     (nat->integer val)]
       [(Int)     (int->integer val)]
       [(Rat)     (rat->rational val)]
       [(Bool)    (bool->boolean val)]
       [(Unit)    (void)]
       [(Char)    (char->rkt-char val)]
       [(String)  (string->rkt-string val)]
       [(Posit8 Posit16 Posit32 Posit64) (posit->rational val)]
       ;; Passthrough types: the Prologos IR value IS the Racket value
       [(Path Keyword Passthrough) val]
       [else
        (define type-str (symbol->string base-type))
        (if (string-prefix? type-str "Opaque:")
            (if (expr-opaque? val) (expr-opaque-value val) val)
            (error 'foreign "Unsupported marshal-in type: ~a" base-type))])]
    [else
     (error 'foreign "Unsupported marshal-in type: ~a" base-type)]))

;; ========================================
;; Racket → Prologos marshalling
;; ========================================

;; Convert a Racket exact integer to a Prologos Nat (Peano)
(define (integer->nat n)
  (unless (and (exact-integer? n) (>= n 0))
    (error 'foreign "Cannot marshal from Racket: expected non-negative integer, got ~a" n))
  (expr-nat-val n))

;; Dispatch marshal-in by base type symbol
;; Convert a Racket exact integer to a Prologos Int
(define (integer->int n)
  (unless (exact-integer? n)
    (error 'foreign "Cannot marshal from Racket: expected exact integer, got ~a" n))
  (expr-int n))

;; Convert a Racket exact rational to a Prologos Rat
(define (rational->rat n)
  (unless (and (exact? n) (rational? n))
    (error 'foreign "Cannot marshal from Racket: expected exact rational, got ~a" n))
  (expr-rat n))

;; Convert a Racket exact rational (or integer) to a Prologos Posit literal of the given width.
(define (rational->posit width n)
  (unless (or (exact-integer? n) (and (exact? n) (rational? n)))
    (error 'foreign
           "Cannot marshal to Posit~a: expected exact integer or rational, got ~a"
           width n))
  (case width
    [(8)  (expr-posit8  (posit8-encode  n))]
    [(16) (expr-posit16 (posit16-encode n))]
    [(32) (expr-posit32 (posit32-encode n))]
    [(64) (expr-posit64 (posit64-encode n))]
    [else (error 'foreign "Unknown Posit width: ~a" width)]))

;; Build a Prologos List value from a Racket list of element exprs.
;; Uses the bare 'cons / (expr-nil) form (no implicit type argument), which the
;; reducer/elaborator accepts and pretty-printer recognizes.
(define (racket-list->prologos-list elems)
  (foldr (lambda (e acc)
           (expr-app (expr-app (expr-fvar 'cons) e) acc))
         (expr-nil)
         elems))

(define (marshal-racket->prologos base-type val)
  (cond
    ;; Compound List type: (List <inner>)
    [(and (pair? base-type) (eq? (car base-type) 'List))
     (define inner (cadr base-type))
     (unless (list? val)
       (error 'foreign "Cannot marshal to List — expected Racket list, got ~a" val))
     (racket-list->prologos-list
      (map (lambda (e) (marshal-racket->prologos inner e)) val))]
    ;; Atomic types
    [(symbol? base-type)
     (case base-type
       [(Nat)     (integer->nat val)]
       [(Int)     (integer->int val)]
       [(Rat)     (rational->rat val)]
       [(Bool)    (if val (expr-true) (expr-false))]
       [(Unit)    (expr-unit)]
       [(Char)    (expr-char val)]
       [(String)  (expr-string val)]
       [(Posit8)  (rational->posit 8  val)]
       [(Posit16) (rational->posit 16 val)]
       [(Posit32) (rational->posit 32 val)]
       [(Posit64) (rational->posit 64 val)]
       ;; Passthrough types: result is already a Prologos IR value
       [(Path Keyword Passthrough) val]
       [else
        (define type-str (symbol->string base-type))
        (if (string-prefix? type-str "Opaque:")
            (expr-opaque val (string->symbol (substring type-str 7)))
            (error 'foreign "Unsupported marshal-out type: ~a" base-type))])]
    [else
     (error 'foreign "Unsupported marshal-out type: ~a" base-type)]))

;; ========================================
;; Type parsing for marshalling
;; ========================================

;; Extract base type descriptor from a core type expression.
;; Returns either:
;;   - a symbol for atomic types: 'Nat, 'Int, 'Rat, 'Bool, 'Unit, 'Char, 'String,
;;     'Posit8, 'Posit16, 'Posit32, 'Posit64, 'Path, 'Keyword, 'Passthrough,
;;     'Opaque:<tag>
;;   - a list (List <inner>) for the polymorphic List type, where <inner> is
;;     itself a base-type descriptor (atomic or nested List).
(define (base-type-name e)
  (match e
    [(expr-Nat)     'Nat]
    [(expr-Bool)    'Bool]
    [(expr-Unit)    'Unit]
    [(expr-Posit8)  'Posit8]
    [(expr-Posit16) 'Posit16]
    [(expr-Posit32) 'Posit32]
    [(expr-Posit64) 'Posit64]
    [(expr-Int)     'Int]
    [(expr-Rat)     'Rat]
    [(expr-Char)    'Char]
    [(expr-String)  'String]
    ;; Passthrough types: Path, Keyword — Racket functions operate on IR values directly
    [(expr-Path)    'Path]
    [(expr-Keyword) 'Keyword]
    ;; (List A) — recognize bare and namespace-qualified List names
    [(expr-app (? (lambda (f)
                    (and (expr-fvar? f)
                         (let* ([n (symbol->string (expr-fvar-name f))]
                                [len (string-length n)])
                           (or (string=? n "List")
                               (and (>= len 6)
                                    (string=? (substring n (- len 6)) "::List")))))))
               inner)
     (list 'List (base-type-name inner))]
    ;; Any other type: passthrough (the Racket function handles IR values directly)
    [_ 'Passthrough]))

;; Parse a Prologos core type expression into a marshalling descriptor.
;; Returns (cons arg-base-types return-base-type) where arg-base-types
;; is a list of symbols and return-base-type is a symbol.
;;
;; Examples:
;;   (expr-Nat) → '(() . Nat)                        ;; constant, 0 args
;;   (expr-Pi _ (expr-Nat) (expr-Nat)) → '((Nat) . Nat)   ;; Nat -> Nat
;;   (expr-Pi _ (expr-Nat) (expr-Pi _ (expr-Nat) (expr-Bool)))
;;     → '((Nat Nat) . Bool)                         ;; Nat -> Nat -> Bool
(define (parse-foreign-type type-expr)
  (let loop ([t type-expr] [args '()])
    (match t
      [(expr-Pi _ dom cod)
       ;; Arrow type: extract domain's base type, recurse on codomain
       (loop cod (cons (base-type-name dom) args))]
      [_ (cons (reverse args) (base-type-name t))])))

;; Build a pair of (marshal-in-list, marshal-out-fn) from a parsed type descriptor.
;; marshal-in-list: list of (Prologos-value -> Racket-value) functions
;; marshal-out-fn:  (Racket-value -> Prologos-value) function
(define (make-marshaller-pair parsed-type)
  (define arg-types (car parsed-type))
  (define ret-type (cdr parsed-type))
  (values
    (map (lambda (t) (lambda (v) (marshal-prologos->racket t v))) arg-types)
    (lambda (v) (marshal-racket->prologos ret-type v))))
