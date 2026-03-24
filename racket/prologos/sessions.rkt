#lang racket/base

;;;
;;; PROLOGOS SESSIONS
;;; Session types with dependency, duality, and substitution.
;;; Direct translation of prologos-sessions.maude.
;;;

(require racket/match
         "prelude.rkt"
         "syntax.rkt"
         "substitution.rkt")

(provide
 ;; Session constructors
 (struct-out sess-send) (struct-out sess-recv)
 (struct-out sess-dsend) (struct-out sess-drecv)
 (struct-out sess-async-send) (struct-out sess-async-recv)
 (struct-out sess-choice) (struct-out sess-offer)
 (struct-out sess-mu) (struct-out sess-svar)
 (struct-out sess-end)
 (struct-out sess-meta)
 (struct-out sess-branch-error)
 ;; Operations
 dual substS unfold-session lookup-branch)

;; ========================================
;; Session Type Constructors
;; ========================================

(struct sess-send (type cont) #:transparent #:property prop:ctor-desc-tag '(session . sess-send))
(struct sess-recv (type cont) #:transparent #:property prop:ctor-desc-tag '(session . sess-recv))
(struct sess-dsend (type cont) #:transparent #:property prop:ctor-desc-tag '(session . sess-dsend))
(struct sess-drecv (type cont) #:transparent #:property prop:ctor-desc-tag '(session . sess-drecv))
(struct sess-async-send (type cont) #:transparent #:property prop:ctor-desc-tag '(session . sess-async-send))
(struct sess-async-recv (type cont) #:transparent #:property prop:ctor-desc-tag '(session . sess-async-recv))
(struct sess-choice (branches) #:transparent)      ; internal choice (no ctor-desc yet)
(struct sess-offer (branches) #:transparent)       ; external choice (no ctor-desc yet)
(struct sess-mu (body) #:transparent #:property prop:ctor-desc-tag '(session . sess-mu))
(struct sess-svar (index) #:transparent)           ; session variable (de Bruijn)
(struct sess-end () #:transparent)                 ; session end
(struct sess-meta (id) #:transparent)              ; Sprint 8: unsolved session continuation
(struct sess-branch-error () #:transparent)        ; lookup failure

;; BranchList: assoc list of (cons label session)
;; Example: (list (cons 'left (sess-send ...)) (cons 'right (sess-end)))

;; ========================================
;; Duality: what the other endpoint sees
;; ========================================
(define (dual s)
  (match s
    [(sess-send a cont) (sess-recv a (dual cont))]
    [(sess-recv a cont) (sess-send a (dual cont))]
    [(sess-dsend a cont) (sess-drecv a (dual cont))]
    [(sess-drecv a cont) (sess-dsend a (dual cont))]
    [(sess-async-send a cont) (sess-async-recv a (dual cont))]
    [(sess-async-recv a cont) (sess-async-send a (dual cont))]
    [(sess-choice branches) (sess-offer (dual-branches branches))]
    [(sess-offer branches) (sess-choice (dual-branches branches))]
    [(sess-mu body) (sess-mu (dual body))]
    [(sess-svar _) s]
    [(sess-end) s]
    [(sess-meta _) s]))  ;; Sprint 8: can't dual an unknown session

(define (dual-branches bl)
  (map (lambda (b) (cons (car b) (dual (cdr b)))) bl))

;; ========================================
;; Session substitution (for dependent sessions)
;; Replace bvar(k) in session S with expression E
;; ========================================
(define (substS s k e)
  (match s
    [(sess-send a cont) (sess-send (subst k e a) (substS cont k e))]
    [(sess-recv a cont) (sess-recv (subst k e a) (substS cont k e))]
    ;; dsend/drecv bind a variable in S, so k increases
    [(sess-dsend a cont) (sess-dsend (subst k e a) (substS cont (add1 k) (shift 1 0 e)))]
    [(sess-drecv a cont) (sess-drecv (subst k e a) (substS cont (add1 k) (shift 1 0 e)))]
    [(sess-async-send a cont) (sess-async-send (subst k e a) (substS cont k e))]
    [(sess-async-recv a cont) (sess-async-recv (subst k e a) (substS cont k e))]
    [(sess-choice branches) (sess-choice (substS-branches branches k e))]
    [(sess-offer branches) (sess-offer (substS-branches branches k e))]
    [(sess-mu body) (sess-mu (substS body k e))] ; mu binds session vars, not expr vars
    [(sess-svar _) s]
    [(sess-end) s]
    [(sess-meta _) s]))  ;; Sprint 8: no expression variables in unsolved meta

(define (substS-branches bl k e)
  (map (lambda (b) (cons (car b) (substS (cdr b) k e))) bl))

;; ========================================
;; Session unfolding: unfold(mu(S)) = S[mu(S)/svar(0)]
;; ========================================
(define (unfold-session s)
  (match s
    [(sess-mu body) (unfoldS body 0 s)]
    [_ s]))

(define (unfoldS s k replacement)
  (match s
    [(sess-send a cont) (sess-send a (unfoldS cont k replacement))]
    [(sess-recv a cont) (sess-recv a (unfoldS cont k replacement))]
    [(sess-dsend a cont) (sess-dsend a (unfoldS cont k replacement))]
    [(sess-drecv a cont) (sess-drecv a (unfoldS cont k replacement))]
    [(sess-async-send a cont) (sess-async-send a (unfoldS cont k replacement))]
    [(sess-async-recv a cont) (sess-async-recv a (unfoldS cont k replacement))]
    [(sess-choice branches) (sess-choice (unfoldS-branches branches k replacement))]
    [(sess-offer branches) (sess-offer (unfoldS-branches branches k replacement))]
    [(sess-mu body) (sess-mu (unfoldS body (add1 k) replacement))] ; mu binds, increment
    [(sess-svar n) (if (= n k) replacement (sess-svar n))]
    [(sess-end) s]
    [(sess-meta _) s]))  ;; Sprint 8: can't unfold an unsolved meta

(define (unfoldS-branches bl k replacement)
  (map (lambda (b) (cons (car b) (unfoldS (cdr b) k replacement))) bl))

;; ========================================
;; Branch lookup
;; ========================================
(define (lookup-branch label branches)
  (cond
    [(null? branches) (sess-branch-error)]
    [(equal? (caar branches) label) (cdar branches)]
    [else (lookup-branch label (cdr branches))]))
