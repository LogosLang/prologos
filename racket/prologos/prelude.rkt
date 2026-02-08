#lang racket/base

;;;
;;; PROLOGOS PRELUDE
;;; Utility types and operations for the Prologos formal specification.
;;; Direct translation of prologos-prelude.maude.
;;;

(require racket/match)

(provide
 ;; Multiplicities
 m0 m1 mw mult?
 mult-add mult-mul mult-leq compatible
 ;; Universe levels
 (struct-out lzero) (struct-out lsuc)
 level? lmax)

;; ========================================
;; Multiplicity Semiring: {0, 1, omega}
;; ========================================

;; Multiplicities are symbols: 'm0, 'm1, 'mw
(define m0 'm0)
(define m1 'm1)
(define mw 'mw)

(define (mult? x)
  (memq x '(m0 m1 mw)))

;; Addition (join in the semiring)
;; Commutative: we enumerate all ordered pairs
(define (mult-add a b)
  (match* (a b)
    [('m0 'm0) 'm0]
    [('m0 'm1) 'm1]
    [('m1 'm0) 'm1]
    [('m0 'mw) 'mw]
    [('mw 'm0) 'mw]
    [('m1 'm1) 'mw]
    [('m1 'mw) 'mw]
    [('mw 'm1) 'mw]
    [('mw 'mw) 'mw]))

;; Multiplication (scaling)
;; Commutative: enumerate all ordered pairs
(define (mult-mul a b)
  (match* (a b)
    [('m0 'm0) 'm0]
    [('m0 'm1) 'm0]
    [('m1 'm0) 'm0]
    [('m0 'mw) 'm0]
    [('mw 'm0) 'm0]
    [('m1 'm1) 'm1]
    [('m1 'mw) 'mw]
    [('mw 'm1) 'mw]
    [('mw 'mw) 'mw]))

;; Ordering: m0 <= m1 <= mw
(define (mult-leq a b)
  (match* (a b)
    [('m0 _)   #t]
    [('m1 'm0) #f]
    [('m1 _)   #t]
    [('mw 'mw) #t]
    [('mw _)   #f]))

;; Compatibility: actual usage p is compatible with declared multiplicity q
;; m0: must use 0 times; m1: exactly 1; mw: any number
(define (compatible declared actual)
  (match* (declared actual)
    [('m0 'm0) #t]
    [('m0 'm1) #f]
    [('m0 'mw) #f]
    [('m1 'm0) #f]
    [('m1 'm1) #t]
    [('m1 'mw) #f]
    [('mw 'm0) #t]
    [('mw 'm1) #t]
    [('mw 'mw) #t]))

;; ========================================
;; Universe Levels
;; ========================================

(struct lzero () #:transparent)
(struct lsuc (pred) #:transparent)

(define (level? x)
  (or (lzero? x) (and (lsuc? x) (level? (lsuc-pred x)))))

;; lmax: maximum of two levels
;; lmax(lzero, L) = L
;; lmax(L, lzero) = L
;; lmax(L, L) = L
;; lmax(lsuc(L1), lsuc(L2)) = lsuc(lmax(L1, L2))
(define (lmax l1 l2)
  (cond
    [(lzero? l1) l2]
    [(lzero? l2) l1]
    [(equal? l1 l2) l1]
    [(and (lsuc? l1) (lsuc? l2))
     (lsuc (lmax (lsuc-pred l1) (lsuc-pred l2)))]
    [else (error 'lmax "cannot compute lmax of ~a and ~a" l1 l2)]))
