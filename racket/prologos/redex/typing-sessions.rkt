#lang racket/base

;;;
;;; PROLOGOS REDEX — PROCESS TYPING JUDGMENT
;;; Verifies that a process correctly implements the protocol specified
;;; by its channel sessions.
;;;
;;; type-proc(gamma, delta, proc) -> boolean
;;;   gamma : Redex context term (expression typing context)
;;;   delta : Racket hash table (channel -> session s-expression)
;;;   proc  : process s-expression
;;;
;;; This is a plain Racket function (not a metafunction) because it needs
;;; flexible Racket-level matching on process and session s-expressions.
;;; When it needs expression-level type checking, it calls Redex
;;; metafunctions (check, is-type, conv) via (term ...).
;;;
;;; Cross-reference: typing-sessions.rkt (159 lines)
;;;

(require racket/match
         redex/reduction-semantics
         "lang.rkt"
         "subst.rkt"
         "reduce.rkt"
         "typing.rkt"
         "sessions.rkt"
         "processes.rkt")

(provide type-proc)

;; ========================================
;; Context splitting: enumerate all 2^n ways to partition
;; the linear channel context delta into two disjoint halves.
;; Returns a list of (cons delta1 delta2) pairs.
;; ========================================
(define (context-splits delta)
  (define keys (hash-keys delta))
  (define n (length keys))
  (define limit (expt 2 n))
  (for/list ([mask (in-range limit)])
    (define-values (h1 h2)
      (for/fold ([h1 (hasheq)] [h2 (hasheq)])
                ([k (in-list keys)] [i (in-naturals)])
        (if (bitwise-bit-set? mask i)
            (values (hash-set h1 k (hash-ref delta k)) h2)
            (values h1 (hash-set h2 k (hash-ref delta k))))))
    (cons h1 h2)))

;; ========================================
;; Process typing judgment
;; ========================================
(define (type-proc gamma delta proc)
  (match proc
    ;; ---- Stop: all channels must be ended ----
    [`(stop)
     (or (= (hash-count delta) 0)
         (chan-ctx-all-ended? delta))]

    ;; ---- Send: send e on channel c, continue as P ----
    ;; c :: send(A, S)  -> check e : A, continue with S
    ;; c :: dsend(A, S) -> check e : A, continue with substS(S, 0, e)
    [`(psend ,e ,c ,p)
     (let ([s (chan-ctx-lookup delta c)])
       (match s
         [`(send ,a ,s-cont)
          (and (equal? #t (term (check ,gamma ,e ,a)))
               (type-proc gamma (chan-ctx-update delta c s-cont) p))]
         [`(dsend ,a ,s-cont)
          (and (equal? #t (term (check ,gamma ,e ,a)))
               (type-proc gamma (chan-ctx-update delta c (substS s-cont 0 e)) p))]
         [_ #f]))]

    ;; ---- Recv: receive from c into x:A, continue as P ----
    ;; c :: recv(A, S)  -> verify type annotation, extend gamma, continue with S
    ;; c :: drecv(A, S) -> same
    [`(precv ,c ,a-annot ,p)
     (let ([s (chan-ctx-lookup delta c)])
       (match s
         [`(recv ,a ,s-cont)
          (and (or (equal? a a-annot)
                   (equal? #t (term (conv ,a ,a-annot))))
               (equal? #t (term (is-type ,gamma ,a)))
               (type-proc `((,a mw) ,gamma) (chan-ctx-update delta c s-cont) p))]
         [`(drecv ,a ,s-cont)
          (and (or (equal? a a-annot)
                   (equal? #t (term (conv ,a ,a-annot))))
               (equal? #t (term (is-type ,gamma ,a)))
               (type-proc `((,a mw) ,gamma) (chan-ctx-update delta c s-cont) p))]
         [_ #f]))]

    ;; ---- Select: select branch l on channel c ----
    ;; c :: choice(branches) -> look up l, continue with that branch session
    [`(psel ,c ,label ,p)
     (let ([s (chan-ctx-lookup delta c)])
       (match s
         [`(choice ,branches)
          (let ([branch-s (lookup-branch label branches)])
            (and (not (equal? branch-s 'branch-error))
                 (type-proc gamma (chan-ctx-update delta c branch-s) p)))]
         [_ #f]))]

    ;; ---- Case/Offer: handle all offered branches ----
    ;; c :: offer(branches) -> type-check all session branches
    [`(pcase ,c ,proc-branches)
     (let ([s (chan-ctx-lookup delta c)])
       (match s
         [`(offer ,sess-branches)
          (type-all-branches gamma (chan-ctx-remove delta c)
                             c proc-branches sess-branches)]
         [_ #f]))]

    ;; ---- New/Cut: create a new channel with session S ----
    ;; Assigns S to one side, dual(S) to the other
    [`(pnew ,s (ppar ,p1 ,p2))
     (for/or ([split (in-list (context-splits delta))])
       (let ([d1 (car split)] [d2 (cdr split)])
         (and (type-proc gamma (chan-ctx-add d1 'ch s) p1)
              (type-proc gamma (chan-ctx-add d2 'ch (dual s)) p2))))]

    ;; ---- Parallel: split the linear context ----
    [`(ppar ,p1 ,p2)
     (for/or ([split (in-list (context-splits delta))])
       (let ([d1 (car split)] [d2 (cdr split)])
         (and (type-proc gamma d1 p1)
              (type-proc gamma d2 p2))))]

    ;; ---- Link/Forward: c1 and c2 have dual sessions ----
    [`(plink ,c1 ,c2)
     (let ([s1 (chan-ctx-lookup delta c1)]
           [s2 (chan-ctx-lookup delta c2)])
       (and s1 s2 (equal? (dual s1) s2)))]

    [_ #f]))

;; ========================================
;; Type-check all branches: each session branch must have a
;; corresponding process branch that types correctly.
;; ========================================
(define (type-all-branches gamma delta-rest c proc-branches sess-branches)
  (cond
    [(null? sess-branches) #t]
    [else
     (let* ([branch (car sess-branches)]
            [label (car branch)]
            [s (cdr branch)]
            [p (lookup-branch-proc label proc-branches)])
       (and p
            (type-proc gamma (chan-ctx-add delta-rest c s) p)
            (type-all-branches gamma delta-rest c
                               proc-branches (cdr sess-branches))))]))
