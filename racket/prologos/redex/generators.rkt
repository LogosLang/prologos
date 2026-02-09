#lang racket/base

;;;
;;; PROLOGOS REDEX — TERM GENERATORS
;;; Custom generators for redex-check property testing.
;;; Produces well-scoped and well-typed terms for metatheoretic property checking.
;;;
;;; gen-closed-expr : fuel -> expr
;;; gen-type        : fuel -> type-expr
;;; gen-well-typed  : fuel -> (values type-expr term-expr)
;;;
;;; Cross-reference: generators.rkt in plan
;;;

(require racket/match
         redex/reduction-semantics
         "lang.rkt"
         "subst.rkt")

(provide gen-closed-expr gen-type gen-well-typed gen-session)

;; ========================================
;; Random helpers
;; ========================================
(define (pick-one lst)
  (list-ref lst (random (length lst))))

;; ========================================
;; Generate a well-formed type (closed)
;; fuel controls size/depth
;; ========================================
(define (gen-type fuel)
  (if (<= fuel 0)
      (pick-one (list (term Nat) (term Bool) (term (Type lzero))))
      (let ([choice (random 7)])
        (case choice
          [(0) (term Nat)]
          [(1) (term Bool)]
          [(2) (term (Type lzero))]
          [(3) ;; Pi(mw, A, B) — non-dependent function type
           (let ([dom (gen-type (sub1 fuel))]
                 [cod (gen-type (sub1 fuel))])
             (term (Pi mw ,dom ,cod)))]
          [(4) ;; Sigma(A, B) — non-dependent pair type
           (let ([a (gen-type (sub1 fuel))]
                 [b (gen-type (sub1 fuel))])
             (term (Sigma ,a ,b)))]
          [(5) ;; Eq(A, e1, e2) — with e1=e2 for well-formedness
           (let* ([a (gen-type (sub1 fuel))]
                  [e (gen-closed-expr-of-type a (sub1 fuel))])
             (term (Eq ,a ,e ,e)))]
          [(6) ;; Vec(A, n) — with n a Nat literal
           (let ([a (gen-type (sub1 fuel))]
                 [n (gen-nat (sub1 fuel))])
             (term (Vec ,a ,n)))]
          [else (term Nat)]))))

;; ========================================
;; Generate a closed expression (no free variables)
;; depth is the current binding depth (number of enclosing binders)
;; fuel controls size
;; ========================================
(define (gen-closed-expr fuel [depth 0])
  (if (<= fuel 0)
      ;; Base cases
      (let ([choices (append
                      (list (term zero) (term Nat) (term Bool)
                            (term true) (term false) (term refl)
                            (term (Type lzero)))
                      ;; Include valid bound variables
                      (for/list ([i (in-range depth)])
                        (term (bvar ,i))))])
        (pick-one choices))
      ;; Recursive cases
      (let ([choice (random 8)])
        (case choice
          [(0) (term zero)]
          [(1) (term (suc ,(gen-closed-expr (sub1 fuel) depth)))]
          [(2) ;; lam
           (let ([ty (gen-type (quotient fuel 2))]
                 [body (gen-closed-expr (sub1 fuel) (add1 depth))])
             (term (lam mw ,ty ,body)))]
          [(3) ;; app
           (let ([f (gen-closed-expr (sub1 fuel) depth)]
                 [a (gen-closed-expr (sub1 fuel) depth)])
             (term (app ,f ,a)))]
          [(4) ;; pair
           (let ([a (gen-closed-expr (sub1 fuel) depth)]
                 [b (gen-closed-expr (sub1 fuel) depth)])
             (term (pair ,a ,b)))]
          [(5) ;; ann
           (let ([e (gen-closed-expr (sub1 fuel) depth)]
                 [t (gen-type (quotient fuel 2))])
             (term (ann ,e ,t)))]
          [(6) ;; Pi type
           (let ([dom (gen-type (quotient fuel 2))]
                 [cod (gen-type (quotient fuel 2))])
             (term (Pi mw ,dom ,cod)))]
          [(7) ;; bound variable if available
           (if (> depth 0)
               (term (bvar ,(random depth)))
               (term zero))]
          [else (term zero)]))))

;; ========================================
;; Generate a Nat literal of bounded size
;; ========================================
(define (gen-nat fuel)
  (if (<= fuel 0)
      (term zero)
      (if (zero? (random 2))
          (term zero)
          (term (suc ,(gen-nat (sub1 fuel)))))))

;; ========================================
;; Generate a closed expression known to have a specific type
;; This is a simple directed generator: for base types, produce constructors
;; ========================================
(define (gen-closed-expr-of-type type fuel)
  (match type
    ;; Nat: zero or suc(...)
    ['Nat
     (if (<= fuel 0) (term zero)
         (if (zero? (random 2))
             (term zero)
             (term (suc ,(gen-closed-expr-of-type (term Nat) (sub1 fuel))))))]
    ;; Bool: true or false
    ['Bool (pick-one (list (term true) (term false)))]
    ;; Type: just return Type(lzero)
    [`(Type ,_) (term (Type lzero))]
    ;; Fallback: use zero (wrong type, but avoids infinite loops)
    [_ (term zero)]))

;; ========================================
;; Generate a (type, term) pair where term : type in empty context
;; Returns (values type term)
;; ========================================
(define (gen-well-typed fuel)
  (let ([choice (random 6)])
    (case choice
      [(0) ;; zero : Nat
       (values (term Nat) (term zero))]
      [(1) ;; suc(n) : Nat
       (let-values ([(t e) (gen-well-typed (sub1 fuel))])
         (if (equal? t (term Nat))
             (values (term Nat) (term (suc ,e)))
             (values (term Nat) (term (suc zero)))))]
      [(2) ;; true/false : Bool
       (values (term Bool) (pick-one (list (term true) (term false))))]
      [(3) ;; pair : Sigma
       (let-values ([(t1 e1) (gen-well-typed (quotient fuel 2))]
                    [(t2 e2) (gen-well-typed (quotient fuel 2))])
         (values (term (Sigma ,t1 ,t2))
                 (term (pair ,e1 ,e2))))]
      [(4) ;; identity lambda : Pi(mw, A, A)
       (let ([a (gen-type (quotient fuel 2))])
         (values (term (Pi mw ,a ,a))
                 (term (lam mw ,a (bvar 0)))))]
      [(5) ;; constant lambda : Pi(mw, A, B)
       (let-values ([(t e) (gen-well-typed (quotient fuel 2))])
         (let ([dom (gen-type (quotient fuel 2))])
           ;; need to shift e since it goes under a binder
           (values (term (Pi mw ,dom ,(term (shift 1 0 ,t))))
                   (term (lam mw ,dom ,(term (shift 1 0 ,e)))))))]
      [else (values (term Nat) (term zero))])))

;; ========================================
;; Generate a session type
;; ========================================
(define (gen-session fuel)
  (if (<= fuel 0)
      'endS
      (let ([choice (random 4)])
        (case choice
          [(0) 'endS]
          [(1) `(send ,(gen-type (quotient fuel 2)) ,(gen-session (sub1 fuel)))]
          [(2) `(recv ,(gen-type (quotient fuel 2)) ,(gen-session (sub1 fuel)))]
          [(3) `(choice ((left . ,(gen-session (sub1 fuel)))
                         (right . ,(gen-session (sub1 fuel)))))]
          [else 'endS]))))
