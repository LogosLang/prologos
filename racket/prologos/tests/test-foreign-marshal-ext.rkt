#lang racket/base

;;;
;;; Tests for extended FFI marshalling: Int, Posit8/16/32/64, and List.
;;;
;;; Pure unit tests for the marshalling layer in foreign.rkt — they exercise
;;; marshal-prologos->racket / marshal-racket->prologos / parse-foreign-type /
;;; base-type-name without going through the elaborator or propagator network.
;;;
;;; Companion to test-foreign.rkt (which covers the existing Nat/Bool path
;;; plus elaborator integration via process-string).
;;;

(require rackunit
         "../syntax.rkt"
         "../foreign.rkt"
         "../posit-impl.rkt")

;; ========================================
;; Int marshalling
;; ========================================

(test-case "ffi-ext/Int: prologos->racket basic"
  (check-equal? (marshal-prologos->racket 'Int (expr-int 0)) 0)
  (check-equal? (marshal-prologos->racket 'Int (expr-int 42)) 42)
  (check-equal? (marshal-prologos->racket 'Int (expr-int -7)) -7))

(test-case "ffi-ext/Int: racket->prologos basic"
  (check-equal? (marshal-racket->prologos 'Int 0) (expr-int 0))
  (check-equal? (marshal-racket->prologos 'Int 42) (expr-int 42))
  (check-equal? (marshal-racket->prologos 'Int -7) (expr-int -7)))

(test-case "ffi-ext/Int: bignum roundtrip"
  ;; Racket's exact integers are arbitrary-precision; marshal must preserve.
  (define big (expt 2 200))
  (check-equal? (marshal-prologos->racket 'Int (expr-int big)) big)
  (check-equal? (marshal-racket->prologos 'Int big) (expr-int big))
  (check-equal? (marshal-prologos->racket 'Int (marshal-racket->prologos 'Int big)) big))

(test-case "ffi-ext/Int: rejects non-integer on out"
  (check-exn exn:fail? (lambda () (marshal-racket->prologos 'Int 1.5)))
  (check-exn exn:fail? (lambda () (marshal-racket->prologos 'Int "not an int"))))

(test-case "ffi-ext/Int: rejects non-int IR on in"
  (check-exn exn:fail? (lambda () (marshal-prologos->racket 'Int (expr-zero))))
  (check-exn exn:fail? (lambda () (marshal-prologos->racket 'Int (expr-true)))))

;; ========================================
;; Posit8 marshalling
;; ========================================

(test-case "ffi-ext/Posit8: integer roundtrip on representable values"
  ;; 0 and 1 are exactly representable in posit8.
  (define p8-zero (marshal-racket->prologos 'Posit8 0))
  (check-pred expr-posit8? p8-zero)
  (check-equal? (marshal-prologos->racket 'Posit8 p8-zero) 0)
  (define p8-one (marshal-racket->prologos 'Posit8 1))
  (check-pred expr-posit8? p8-one)
  (check-equal? (marshal-prologos->racket 'Posit8 p8-one) 1))

(test-case "ffi-ext/Posit8: negative roundtrip"
  (define p8-neg (marshal-racket->prologos 'Posit8 -1))
  (check-pred expr-posit8? p8-neg)
  (check-equal? (marshal-prologos->racket 'Posit8 p8-neg) -1))

(test-case "ffi-ext/Posit8: rational input encodes via posit8-encode"
  ;; Use a value that's exactly representable: 1/2 fits in posit8.
  (define p8 (marshal-racket->prologos 'Posit8 1/2))
  (check-pred expr-posit8? p8)
  (check-equal? (marshal-prologos->racket 'Posit8 p8) 1/2))

(test-case "ffi-ext/Posit8: NaR contamination raises on marshal-in"
  ;; posit8 NaR bit pattern is 128.
  (check-exn exn:fail?
             (lambda () (marshal-prologos->racket 'Posit8 (expr-posit8 128)))))

(test-case "ffi-ext/Posit8: rejects non-numeric on out"
  (check-exn exn:fail? (lambda () (marshal-racket->prologos 'Posit8 "1.0")))
  (check-exn exn:fail? (lambda () (marshal-racket->prologos 'Posit8 1.5)))) ;; inexact float

(test-case "ffi-ext/Posit8: rejects non-Posit8 IR on in"
  (check-exn exn:fail?
             (lambda () (marshal-prologos->racket 'Posit8 (expr-int 1)))))

;; ========================================
;; Posit16 / Posit32 / Posit64 marshalling
;; ========================================

(test-case "ffi-ext/Posit16: small-integer roundtrip"
  (for ([n (in-list '(0 1 -1 2 -2 16))])
    (define p (marshal-racket->prologos 'Posit16 n))
    (check-pred expr-posit16? p
                (format "Posit16 of ~a should be expr-posit16" n))
    (check-equal? (marshal-prologos->racket 'Posit16 p) n
                  (format "Posit16 roundtrip ~a" n))))

(test-case "ffi-ext/Posit32: small-integer roundtrip"
  (for ([n (in-list '(0 1 -1 2 -2 100 -100))])
    (define p (marshal-racket->prologos 'Posit32 n))
    (check-pred expr-posit32? p)
    (check-equal? (marshal-prologos->racket 'Posit32 p) n
                  (format "Posit32 roundtrip ~a" n))))

(test-case "ffi-ext/Posit64: small-integer roundtrip"
  (for ([n (in-list '(0 1 -1 2 -2 1000 -1000))])
    (define p (marshal-racket->prologos 'Posit64 n))
    (check-pred expr-posit64? p)
    (check-equal? (marshal-prologos->racket 'Posit64 p) n
                  (format "Posit64 roundtrip ~a" n))))

(test-case "ffi-ext/Posit16: rational roundtrip"
  ;; 1/4 is exactly representable across all posit widths.
  (for ([w  (in-list '(Posit16 Posit32 Posit64))])
    (define p (marshal-racket->prologos w 1/4))
    (check-equal? (marshal-prologos->racket w p) 1/4
                  (format "~a 1/4 roundtrip" w))))

(test-case "ffi-ext/Posit16/32/64: NaR raises on in"
  ;; NaR bit patterns: 2^(N-1)
  (check-exn exn:fail?
             (lambda () (marshal-prologos->racket 'Posit16 (expr-posit16 #x8000))))
  (check-exn exn:fail?
             (lambda () (marshal-prologos->racket 'Posit32 (expr-posit32 #x80000000))))
  (check-exn exn:fail?
             (lambda () (marshal-prologos->racket 'Posit64
                                                  (expr-posit64 #x8000000000000000)))))

;; ========================================
;; posit->rational / rational->posit direct API
;; ========================================

(test-case "ffi-ext/posit->rational: dispatches by width on the IR"
  (check-equal? (posit->rational (marshal-racket->prologos 'Posit8  1)) 1)
  (check-equal? (posit->rational (marshal-racket->prologos 'Posit16 1)) 1)
  (check-equal? (posit->rational (marshal-racket->prologos 'Posit32 1)) 1)
  (check-equal? (posit->rational (marshal-racket->prologos 'Posit64 1)) 1))

(test-case "ffi-ext/rational->posit: builds the right IR width"
  (check-pred expr-posit8?  (rational->posit 8  1/2))
  (check-pred expr-posit16? (rational->posit 16 1/2))
  (check-pred expr-posit32? (rational->posit 32 1/2))
  (check-pred expr-posit64? (rational->posit 64 1/2)))

;; ========================================
;; List marshalling
;; ========================================

(define (mk-cons-with-type elem-type head tail)
  ;; Builds (((cons elem-type) head) tail) — the form produced after elaboration
  ;; with implicit type argument resolved.
  (expr-app (expr-app (expr-app (expr-fvar 'cons) elem-type) head) tail))

(define (mk-cons-no-type head tail)
  ;; Builds ((cons head) tail) — the bare form used by foreign.rkt's
  ;; racket-list->prologos-list builder (no implicit type arg).
  (expr-app (expr-app (expr-fvar 'cons) head) tail))

(test-case "ffi-ext/List: marshal-out builds cons/nil chain"
  (define lst (marshal-racket->prologos '(List Int) (list 1 2 3)))
  ;; Expected shape: ((cons (expr-int 1)) ((cons (expr-int 2)) ((cons (expr-int 3)) (expr-nil))))
  (check-equal?
   lst
   (mk-cons-no-type (expr-int 1)
     (mk-cons-no-type (expr-int 2)
       (mk-cons-no-type (expr-int 3)
         (expr-nil))))))

(test-case "ffi-ext/List: marshal-in parses the bare cons/nil form"
  ;; Build the same form that marshal-out produces; marshal-in should round-trip.
  (define lst
    (mk-cons-no-type (expr-int 1)
      (mk-cons-no-type (expr-int 2)
        (mk-cons-no-type (expr-int 3)
          (expr-nil)))))
  (check-equal? (marshal-prologos->racket '(List Int) lst) (list 1 2 3)))

(test-case "ffi-ext/List: marshal-in parses the typed (cons A x xs) form"
  ;; This is the form produced by user code like (cons Int 1 (cons Int 2 (nil Int))).
  (define lst
    (mk-cons-with-type (expr-Int) (expr-int 1)
      (mk-cons-with-type (expr-Int) (expr-int 2)
        (mk-cons-with-type (expr-Int) (expr-int 3)
          (expr-app (expr-fvar 'nil) (expr-Int))))))
  (check-equal? (marshal-prologos->racket '(List Int) lst) (list 1 2 3)))

(test-case "ffi-ext/List: marshal-in accepts qualified ::cons / ::nil names"
  (define cons-q (expr-fvar 'prologos::data::list::cons))
  (define nil-q  (expr-fvar 'prologos::data::list::nil))
  (define lst
    (expr-app (expr-app cons-q (expr-int 10))
              (expr-app (expr-app cons-q (expr-int 20))
                        nil-q)))
  (check-equal? (marshal-prologos->racket '(List Int) lst) (list 10 20)))

(test-case "ffi-ext/List: empty list (expr-nil) roundtrip"
  (check-equal? (marshal-racket->prologos '(List Int) '()) (expr-nil))
  (check-equal? (marshal-prologos->racket '(List Int) (expr-nil)) '()))

(test-case "ffi-ext/List: empty list bare 'nil fvar"
  (check-equal? (marshal-prologos->racket '(List Int) (expr-fvar 'nil)) '()))

(test-case "ffi-ext/List: full roundtrip Int list"
  (for ([xs (in-list '(() (1) (1 2 3) (-5 0 100)))])
    (define ir (marshal-racket->prologos '(List Int) xs))
    (check-equal? (marshal-prologos->racket '(List Int) ir) xs
                  (format "Int list roundtrip ~a" xs))))

(test-case "ffi-ext/List: roundtrip of List Nat"
  (for ([xs (in-list '(() (0) (0 1 2 3 5)))])
    (define ir (marshal-racket->prologos '(List Nat) xs))
    (check-equal? (marshal-prologos->racket '(List Nat) ir) xs
                  (format "Nat list roundtrip ~a" xs))))

(test-case "ffi-ext/List: roundtrip of List String"
  (define xs '("alpha" "beta" "gamma"))
  (define ir (marshal-racket->prologos '(List String) xs))
  (check-equal? (marshal-prologos->racket '(List String) ir) xs))

(test-case "ffi-ext/List: roundtrip of List Bool"
  (define xs '(#t #f #t))
  (define ir (marshal-racket->prologos '(List Bool) xs))
  (check-equal? (marshal-prologos->racket '(List Bool) ir) xs))

(test-case "ffi-ext/List: roundtrip of List Posit8 with rationals"
  (define xs '(0 1 -1 1/2))
  (define ir (marshal-racket->prologos '(List Posit8) xs))
  (check-equal? (marshal-prologos->racket '(List Posit8) ir) xs))

(test-case "ffi-ext/List: nested List (List (List Int))"
  (define xs '((1 2) (3) () (4 5 6)))
  (define ir (marshal-racket->prologos '(List (List Int)) xs))
  (check-equal? (marshal-prologos->racket '(List (List Int)) ir) xs))

(test-case "ffi-ext/List: marshal-out rejects non-list value"
  (check-exn exn:fail?
             (lambda () (marshal-racket->prologos '(List Int) 42))))

(test-case "ffi-ext/List: marshal-in rejects non-list IR"
  (check-exn exn:fail?
             (lambda () (marshal-prologos->racket '(List Int) (expr-int 1)))))

;; ========================================
;; base-type-name with new types
;; ========================================

(test-case "ffi-ext/base-type-name: atomic Int / Posits"
  (check-equal? (base-type-name (expr-Int))     'Int)
  (check-equal? (base-type-name (expr-Posit8))  'Posit8)
  (check-equal? (base-type-name (expr-Posit16)) 'Posit16)
  (check-equal? (base-type-name (expr-Posit32)) 'Posit32)
  (check-equal? (base-type-name (expr-Posit64)) 'Posit64))

(test-case "ffi-ext/base-type-name: (List Int)"
  (define ty (expr-app (expr-fvar 'List) (expr-Int)))
  (check-equal? (base-type-name ty) '(List Int)))

(test-case "ffi-ext/base-type-name: (List Nat)"
  (define ty (expr-app (expr-fvar 'List) (expr-Nat)))
  (check-equal? (base-type-name ty) '(List Nat)))

(test-case "ffi-ext/base-type-name: (List Posit32)"
  (define ty (expr-app (expr-fvar 'List) (expr-Posit32)))
  (check-equal? (base-type-name ty) '(List Posit32)))

(test-case "ffi-ext/base-type-name: nested (List (List Int))"
  (define ty (expr-app (expr-fvar 'List)
                       (expr-app (expr-fvar 'List) (expr-Int))))
  (check-equal? (base-type-name ty) '(List (List Int))))

(test-case "ffi-ext/base-type-name: qualified ::List name"
  (define ty (expr-app (expr-fvar 'prologos::data::list::List) (expr-Int)))
  (check-equal? (base-type-name ty) '(List Int)))

;; ========================================
;; parse-foreign-type with new types
;; ========================================

(test-case "ffi-ext/parse-foreign-type: Int -> Int"
  (define ty (expr-Pi 'w (expr-Int) (expr-Int)))
  (check-equal? (parse-foreign-type ty) (cons '(Int) 'Int)))

(test-case "ffi-ext/parse-foreign-type: Int -> Int -> Int"
  (define ty (expr-Pi 'w (expr-Int) (expr-Pi 'w (expr-Int) (expr-Int))))
  (check-equal? (parse-foreign-type ty) (cons '(Int Int) 'Int)))

(test-case "ffi-ext/parse-foreign-type: Posit8 -> Posit8"
  (define ty (expr-Pi 'w (expr-Posit8) (expr-Posit8)))
  (check-equal? (parse-foreign-type ty) (cons '(Posit8) 'Posit8)))

(test-case "ffi-ext/parse-foreign-type: Posit16 Posit16 -> Posit16"
  (define ty (expr-Pi 'w (expr-Posit16) (expr-Pi 'w (expr-Posit16) (expr-Posit16))))
  (check-equal? (parse-foreign-type ty) (cons '(Posit16 Posit16) 'Posit16)))

(test-case "ffi-ext/parse-foreign-type: (List Int) -> Int"
  (define list-int (expr-app (expr-fvar 'List) (expr-Int)))
  (define ty (expr-Pi 'w list-int (expr-Int)))
  (check-equal? (parse-foreign-type ty) (cons '((List Int)) 'Int)))

(test-case "ffi-ext/parse-foreign-type: Int -> (List Int)"
  (define list-int (expr-app (expr-fvar 'List) (expr-Int)))
  (define ty (expr-Pi 'w (expr-Int) list-int))
  (check-equal? (parse-foreign-type ty) (cons '(Int) '(List Int))))

(test-case "ffi-ext/parse-foreign-type: (List Int) -> (List Int) -> (List Int)"
  (define list-int (expr-app (expr-fvar 'List) (expr-Int)))
  (define ty (expr-Pi 'w list-int (expr-Pi 'w list-int list-int)))
  (check-equal? (parse-foreign-type ty)
                (cons '((List Int) (List Int)) '(List Int))))

;; ========================================
;; make-marshaller-pair: end-to-end via parsed types
;; ========================================

(test-case "ffi-ext/make-marshaller-pair: Int -> Int"
  (define parsed (cons '(Int) 'Int))
  (define-values (ins out) (make-marshaller-pair parsed))
  (check-equal? (length ins) 1)
  (check-equal? ((car ins) (expr-int 5)) 5)
  (check-equal? (out 7) (expr-int 7)))

(test-case "ffi-ext/make-marshaller-pair: Posit8 -> Posit8"
  (define parsed (cons '(Posit8) 'Posit8))
  (define-values (ins out) (make-marshaller-pair parsed))
  (define p (out 1))
  (check-pred expr-posit8? p)
  (check-equal? ((car ins) p) 1))

(test-case "ffi-ext/make-marshaller-pair: (List Int) -> Int (sum semantics)"
  ;; Simulate calling Racket's apply + on a marshalled List Int input.
  (define parsed (cons '((List Int)) 'Int))
  (define-values (ins out) (make-marshaller-pair parsed))
  (define racket-input ((car ins) (marshal-racket->prologos '(List Int) '(1 2 3 4))))
  (check-equal? racket-input '(1 2 3 4))
  (check-equal? (out (apply + racket-input)) (expr-int 10)))

(test-case "ffi-ext/make-marshaller-pair: Int -> (List Int) (range semantics)"
  ;; Simulate calling a Racket range function that returns a List Int.
  (define parsed (cons '(Int) '(List Int)))
  (define-values (ins out) (make-marshaller-pair parsed))
  (define n ((car ins) (expr-int 4)))
  (check-equal? n 4)
  (define racket-result (build-list n (lambda (i) i)))
  (check-equal? racket-result '(0 1 2 3))
  (define ir-result (out racket-result))
  (check-equal? (marshal-prologos->racket '(List Int) ir-result) '(0 1 2 3)))
