#lang racket/base

;;;
;;; PROLOGOS FOREIGN FUNCTION MARSHALLING
;;; Converts between Prologos values (Church/Peano encoded) and Racket values.
;;;
;;; Supported base types:
;;;   Nat    ↔ exact non-negative integer
;;;   Bool   ↔ boolean
;;;   Unit   ↔ void
;;;   Char   ↔ char
;;;   String ↔ string
;;;

(require racket/match
         racket/string
         "syntax.rkt")

(provide marshal-prologos->racket
         marshal-racket->prologos
         nat->integer
         integer->nat
         bool->boolean
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

;; Convert a Prologos Posit{32,64} to its raw bit-pattern integer.
;; This is a passthrough at the Racket level — posit-impl.rkt operates on the
;; same bit-pattern representation, so foreign-imported posit ops work directly.
;; FFI consumers that want rationals call posit{32,64}-to-rational themselves.
(define (posit32->bits e)
  (match e
    [(expr-posit32 bits) bits]
    [_ (error 'foreign "Cannot marshal to Posit32 — not a Posit32 literal: ~a" e)]))

(define (posit64->bits e)
  (match e
    [(expr-posit64 bits) bits]
    [_ (error 'foreign "Cannot marshal to Posit64 — not a Posit64 literal: ~a" e)]))

(define (marshal-prologos->racket base-type val)
  (case base-type
    [(Nat)     (nat->integer val)]
    [(Int)     (int->integer val)]
    [(Rat)     (rat->rational val)]
    [(Bool)    (bool->boolean val)]
    [(Unit)    (void)]
    [(Char)    (char->rkt-char val)]
    [(String)  (string->rkt-string val)]
    [(Posit32) (posit32->bits val)]
    [(Posit64) (posit64->bits val)]
    ;; Passthrough types: the Prologos IR value IS the Racket value
    [(Path Keyword Passthrough) val]
    [else
     (define type-str (symbol->string base-type))
     (if (string-prefix? type-str "Opaque:")
         (if (expr-opaque? val) (expr-opaque-value val) val)
         (error 'foreign "Unsupported marshal-in type: ~a" base-type))]))

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

;; Convert a Racket value to a Prologos Posit{32,64} expression.
;; The carrier representation is the raw bit-pattern integer — same as
;; posit-impl.rkt. So the input is expected to be an exact integer (the bit
;; pattern). FFI consumers wanting to return a rational can compose with
;; posit{32,64}-encode themselves.
(define (bits->posit-expr width val ctor)
  (unless (exact-integer? val)
    (error 'foreign "Cannot marshal Racket value to Posit~a (expected bit-pattern integer): ~a" width val))
  (ctor val))

(define (marshal-racket->prologos base-type val)
  (case base-type
    [(Nat)     (integer->nat val)]
    [(Int)     (integer->int val)]
    [(Rat)     (rational->rat val)]
    [(Bool)    (if val (expr-true) (expr-false))]
    [(Unit)    (expr-unit)]
    [(Char)    (expr-char val)]
    [(String)  (expr-string val)]
    [(Posit32) (bits->posit-expr 32 val expr-posit32)]
    [(Posit64) (bits->posit-expr 64 val expr-posit64)]
    ;; Passthrough types: result is already a Prologos IR value
    [(Path Keyword Passthrough) val]
    [else
     (define type-str (symbol->string base-type))
     (if (string-prefix? type-str "Opaque:")
         (expr-opaque val (string->symbol (substring type-str 7)))
         (error 'foreign "Unsupported marshal-out type: ~a" base-type))]))

;; ========================================
;; Type parsing for marshalling
;; ========================================

;; Extract base type symbol from a core type expression.
;; Returns one of: 'Nat, 'Bool, 'Unit, 'Posit8
(define (base-type-name e)
  (match e
    [(expr-Nat)    'Nat]
    [(expr-Bool)   'Bool]
    [(expr-Unit)   'Unit]
    [(expr-Posit8) 'Posit8]
    [(expr-Posit16) 'Posit16]
    [(expr-Posit32) 'Posit32]
    [(expr-Posit64) 'Posit64]
    [(expr-Int)    'Int]
    [(expr-Rat)    'Rat]
    [(expr-Char)   'Char]
    [(expr-String) 'String]
    ;; Passthrough types: Path, Keyword — Racket functions operate on IR values directly
    [(expr-Path) 'Path]
    [(expr-Keyword) 'Keyword]
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
