#lang racket/base

;;;
;;; PROLOGOS REDEX — SESSION TYPES
;;; Session types with dependency, duality, substitution, and unfolding.
;;; Plain Racket functions operating on s-expression representations.
;;;
;;; Session type s-expressions:
;;;   (send A S)   — send type A, continue with S
;;;   (recv A S)   — receive type A, continue with S
;;;   (dsend A S)  — dependent send (binds in S)
;;;   (drecv A S)  — dependent receive (binds in S)
;;;   (choice ((l1 . S1) (l2 . S2) ...)) — internal choice
;;;   (offer  ((l1 . S1) (l2 . S2) ...)) — external choice
;;;   (mu S)       — recursive session type
;;;   (svar n)     — session variable (de Bruijn index)
;;;   endS         — session end
;;;
;;; Cross-reference: sessions.rkt (112 lines)
;;;

(require racket/match
         redex/reduction-semantics
         "lang.rkt"
         "subst.rkt")

(provide dual substS unfold-session lookup-branch)

;; ========================================
;; Duality: what the other endpoint sees
;; send <-> recv, dsend <-> drecv, choice <-> offer
;; ========================================
(define (dual s)
  (match s
    [`(send ,a ,cont) `(recv ,a ,(dual cont))]
    [`(recv ,a ,cont) `(send ,a ,(dual cont))]
    [`(dsend ,a ,cont) `(drecv ,a ,(dual cont))]
    [`(drecv ,a ,cont) `(dsend ,a ,(dual cont))]
    [`(choice ,branches) `(offer ,(dual-branches branches))]
    [`(offer ,branches) `(choice ,(dual-branches branches))]
    [`(mu ,body) `(mu ,(dual body))]
    [`(svar ,_) s]
    ['endS s]))

(define (dual-branches bl)
  (map (lambda (b) (cons (car b) (dual (cdr b)))) bl))

;; ========================================
;; Session substitution (for dependent sessions)
;; Replace bvar(k) in expression terms inside session S with expression E.
;; Uses Redex metafunctions subst and shift for the expression-level operations.
;; ========================================
(define (substS s k e)
  (match s
    [`(send ,a ,cont)
     `(send ,(term (subst ,k ,e ,a))
            ,(substS cont k e))]
    [`(recv ,a ,cont)
     `(recv ,(term (subst ,k ,e ,a))
            ,(substS cont k e))]
    ;; dsend/drecv bind a variable in S, so k increases and e is shifted
    [`(dsend ,a ,cont)
     `(dsend ,(term (subst ,k ,e ,a))
             ,(substS cont (add1 k) (term (shift 1 0 ,e))))]
    [`(drecv ,a ,cont)
     `(drecv ,(term (subst ,k ,e ,a))
             ,(substS cont (add1 k) (term (shift 1 0 ,e))))]
    [`(choice ,branches)
     `(choice ,(substS-branches branches k e))]
    [`(offer ,branches)
     `(offer ,(substS-branches branches k e))]
    ;; mu binds session vars, not expr vars — no change to k
    [`(mu ,body)
     `(mu ,(substS body k e))]
    [`(svar ,_) s]
    ['endS s]))

(define (substS-branches bl k e)
  (map (lambda (b) (cons (car b) (substS (cdr b) k e))) bl))

;; ========================================
;; Session unfolding: unfold(mu(S)) = S[mu(S)/svar(0)]
;; ========================================
(define (unfold-session s)
  (match s
    [`(mu ,body) (unfoldS body 0 s)]
    [_ s]))

(define (unfoldS s k replacement)
  (match s
    [`(send ,a ,cont)
     `(send ,a ,(unfoldS cont k replacement))]
    [`(recv ,a ,cont)
     `(recv ,a ,(unfoldS cont k replacement))]
    [`(dsend ,a ,cont)
     `(dsend ,a ,(unfoldS cont k replacement))]
    [`(drecv ,a ,cont)
     `(drecv ,a ,(unfoldS cont k replacement))]
    [`(choice ,branches)
     `(choice ,(unfoldS-branches branches k replacement))]
    [`(offer ,branches)
     `(offer ,(unfoldS-branches branches k replacement))]
    ;; mu binds a session variable, so increment k
    [`(mu ,body)
     `(mu ,(unfoldS body (add1 k) replacement))]
    [`(svar ,n) (if (= n k) replacement `(svar ,n))]
    ['endS s]))

(define (unfoldS-branches bl k replacement)
  (map (lambda (b) (cons (car b) (unfoldS (cdr b) k replacement))) bl))

;; ========================================
;; Branch lookup
;; ========================================
(define (lookup-branch label branches)
  (cond
    [(null? branches) 'branch-error]
    [(equal? (caar branches) label) (cdar branches)]
    [else (lookup-branch label (cdr branches))]))
