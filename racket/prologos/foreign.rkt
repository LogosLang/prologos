#lang racket/base

;;;
;;; PROLOGOS FOREIGN FUNCTION MARSHALLING
;;; Converts between Prologos values (Church/Peano encoded) and Racket values.
;;;
;;; Supported base types:
;;;   Nat  ↔ exact non-negative integer
;;;   Bool ↔ boolean
;;;   Unit ↔ void
;;;

(require racket/match
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

(define (marshal-prologos->racket base-type val)
  (case base-type
    [(Nat)  (nat->integer val)]
    [(Int)  (int->integer val)]
    [(Rat)  (rat->rational val)]
    [(Bool) (bool->boolean val)]
    [(Unit) (void)]
    [else (error 'foreign "Unsupported marshal-in type: ~a" base-type)]))

;; ========================================
;; Racket → Prologos marshalling
;; ========================================

;; Convert a Racket exact integer to a Prologos Nat (Peano)
(define (integer->nat n)
  (unless (and (exact-integer? n) (>= n 0))
    (error 'foreign "Cannot marshal from Racket: expected non-negative integer, got ~a" n))
  (let loop ([n n])
    (if (zero? n) (expr-zero) (expr-suc (loop (sub1 n))))))

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

(define (marshal-racket->prologos base-type val)
  (case base-type
    [(Nat)  (integer->nat val)]
    [(Int)  (integer->int val)]
    [(Rat)  (rational->rat val)]
    [(Bool) (if val (expr-true) (expr-false))]
    [(Unit) (expr-unit)]
    [else (error 'foreign "Unsupported marshal-out type: ~a" base-type)]))

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
    [(expr-Int)    'Int]
    [(expr-Rat)    'Rat]
    [_ (error 'foreign "Unsupported foreign type component: ~a" e)]))

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
