#lang racket/base

;;;
;;; PROLOGOS PROCESSES
;;; Process syntax, linear channel contexts, and context operations.
;;; Direct translation of prologos-processes.maude.
;;;
;;; ChanCtx is an immutable hash table (channel -> session) replacing
;;; Maude's AC (associative-commutative) multiset matching.
;;;

(require racket/match
         "sessions.rkt")

(provide
 ;; Process constructors
 (struct-out proc-stop)
 (struct-out proc-send)
 (struct-out proc-recv)
 (struct-out proc-sel)
 (struct-out proc-case)
 (struct-out proc-new)
 (struct-out proc-par)
 (struct-out proc-link)
 (struct-out proc-solve)
 (struct-out proc-no-proc)
 ;; Boundary operations (S5b)
 (struct-out proc-open)
 (struct-out proc-connect)
 (struct-out proc-listen)
 ;; Channel context operations
 chan-ctx-empty chan-ctx-add chan-ctx-lookup chan-ctx-remove
 chan-ctx-update chan-ctx-all-ended? chan-ctx-keys chan-ctx-size
 ;; Branch proc operations
 lookup-branch-proc)

;; ========================================
;; Process Constructors
;; ========================================
(struct proc-stop () #:transparent)
(struct proc-send (expr chan cont) #:transparent)    ; send e on c, continue P
(struct proc-recv (chan type cont) #:transparent)     ; recv from c into x:A, continue P
(struct proc-sel (chan label cont) #:transparent)     ; select branch l on c
(struct proc-case (chan branches) #:transparent)      ; offer branches on c
(struct proc-new (session cont) #:transparent)        ; new channel with session S
(struct proc-par (left right) #:transparent)          ; parallel composition
(struct proc-link (chan1 chan2) #:transparent)         ; link/forward
(struct proc-solve (type cont) #:transparent)         ; proof search (axiomatic)
(struct proc-no-proc () #:transparent)                ; sentinel for failed lookup

;; S5b: Boundary operations — open/connect/listen create single-endpoint channels
;; gated by capability requirements.
(struct proc-open    (path session-type cap-type cont) #:transparent)    ; open path : S {cap}, cont
(struct proc-connect (addr session-type cap-type cont) #:transparent)    ; connect addr : S {cap}, cont
(struct proc-listen  (port session-type cap-type cont) #:transparent)    ; listen port : S {cap}, cont

;; BranchProcList: assoc list of (cons label proc)

;; ========================================
;; Channel Context: immutable hash (channel -> session)
;; ========================================
(define chan-ctx-empty (hasheq))

(define (chan-ctx-add ctx chan session)
  (hash-set ctx chan session))

(define (chan-ctx-lookup ctx chan)
  (hash-ref ctx chan #f))

(define (chan-ctx-remove ctx chan)
  (hash-remove ctx chan))

(define (chan-ctx-update ctx chan session)
  (hash-set ctx chan session))

(define (chan-ctx-all-ended? ctx)
  (for/and ([(c s) (in-hash ctx)])
    (sess-end? s)))

(define (chan-ctx-keys ctx)
  (hash-keys ctx))

(define (chan-ctx-size ctx)
  (hash-count ctx))

;; ========================================
;; Branch lookup in process branches
;; ========================================
(define (lookup-branch-proc label branches)
  (cond
    [(null? branches) (proc-no-proc)]
    [(equal? (caar branches) label) (cdar branches)]
    [else (lookup-branch-proc label (cdr branches))]))
