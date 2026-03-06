#lang racket/base

;;;
;;; PROLOGOS TYPING-SESSIONS
;;; Process typing judgment for session-typed processes.
;;; Direct translation of prologos-typing-sessions.maude.
;;;
;;; type-proc(gamma, delta, P) -> Bool
;;;   gamma : unrestricted context (types)
;;;   delta : linear channel context (hash: channel -> session)
;;;   P     : process
;;;
;;; The judgment verifies that process P correctly implements the protocol
;;; specified by the channel sessions in delta.
;;;
;;; The key challenge is replacing Maude's AC matching for context splits.
;;; We use explicit enumeration of all 2^n ways to partition a hash into
;;; two disjoint subsets. This is correct but exponential. All test cases
;;; have 1-3 channels, so it's fine.
;;;
;;; Sprint 8: Session continuation inference via sess-meta.
;;; When a channel's session type is a sess-meta (unknown), the process
;;; operation determines the session shape and solves the meta.
;;;

(require racket/match
         "prelude.rkt"
         "syntax.rkt"
         "substitution.rkt"
         "reduction.rkt"
         "typing-core.rkt"
         "sessions.rkt"
         "processes.rkt"
         "metavar-store.rkt")

(provide type-proc unify-session)

;; ========================================
;; S5b: Capability type check in unrestricted context
;; ========================================
;; Check if an unrestricted context (gamma) contains a binding for a given type.
;; Gamma is a list of (cons type mult) pairs. Returns #t if any entry's type
;; matches the given type expression (by equal?).
(define (ctx-has-type? gamma ty)
  (ormap (lambda (entry) (equal? (car entry) ty)) gamma))

;; ========================================
;; Context splits: generate all 2^n partitions
;; of a hash into two disjoint subsets
;; ========================================
(define (context-splits delta)
  (define keys (hash-keys delta))
  (define n (length keys))
  ;; Enumerate all 2^n bitmasks
  (define limit (expt 2 n))
  (for/list ([mask (in-range limit)])
    (define-values (h1 h2)
      (for/fold ([h1 (hasheq)]
                 [h2 (hasheq)])
                ([k (in-list keys)]
                 [i (in-naturals)])
        (if (bitwise-bit-set? mask i)
            (values (hash-set h1 k (hash-ref delta k)) h2)
            (values h1 (hash-set h2 k (hash-ref delta k))))))
    (cons h1 h2)))

;; ========================================
;; Sprint 8: Session unification
;; ========================================
;; Unify two session types, solving sess-metas as side effects.
;; Returns #t if sessions are equal (possibly after solving), #f otherwise.

(define (unify-session s1 s2)
  (cond
    [(equal? s1 s2) #t]
    ;; sess-meta on left: follow or solve
    [(sess-meta? s1)
     (let ([sol (sess-meta-solution (sess-meta-id s1))])
       (if sol (unify-session sol s2)
           (begin (solve-sess-meta! (sess-meta-id s1) s2) #t)))]
    ;; sess-meta on right: follow or solve
    [(sess-meta? s2)
     (let ([sol (sess-meta-solution (sess-meta-id s2))])
       (if sol (unify-session s1 sol)
           (begin (solve-sess-meta! (sess-meta-id s2) s1) #t)))]
    ;; Structural cases
    [(and (sess-send? s1) (sess-send? s2))
     (and (conv (sess-send-type s1) (sess-send-type s2))
          (unify-session (sess-send-cont s1) (sess-send-cont s2)))]
    [(and (sess-recv? s1) (sess-recv? s2))
     (and (conv (sess-recv-type s1) (sess-recv-type s2))
          (unify-session (sess-recv-cont s1) (sess-recv-cont s2)))]
    [(and (sess-dsend? s1) (sess-dsend? s2))
     (and (conv (sess-dsend-type s1) (sess-dsend-type s2))
          (unify-session (sess-dsend-cont s1) (sess-dsend-cont s2)))]
    [(and (sess-drecv? s1) (sess-drecv? s2))
     (and (conv (sess-drecv-type s1) (sess-drecv-type s2))
          (unify-session (sess-drecv-cont s1) (sess-drecv-cont s2)))]
    [(and (sess-end? s1) (sess-end? s2)) #t]
    [(and (sess-svar? s1) (sess-svar? s2)) (= (sess-svar-index s1) (sess-svar-index s2))]
    [(and (sess-mu? s1) (sess-mu? s2)) (unify-session (sess-mu-body s1) (sess-mu-body s2))]
    [(and (sess-choice? s1) (sess-choice? s2))
     (unify-session-branches (sess-choice-branches s1) (sess-choice-branches s2))]
    [(and (sess-offer? s1) (sess-offer? s2))
     (unify-session-branches (sess-offer-branches s1) (sess-offer-branches s2))]
    [else #f]))

(define (unify-session-branches b1 b2)
  (and (= (length b1) (length b2))
       (andmap (lambda (a b)
                 (and (equal? (car a) (car b))
                      (unify-session (cdr a) (cdr b))))
               b1 b2)))

;; ========================================
;; Sprint 8: Zonk channel context
;; ========================================
;; Walk a channel context and resolve solved sess-metas.
(define (zonk-chan-ctx delta)
  (for/hasheq ([(c s) (in-hash delta)])
    (values c (zonk-session s))))

;; ========================================
;; Main process typing judgment
;; ========================================
(define (type-proc gamma delta proc)
  (match proc
    ;; ---- Stop: all channels must be ended ----
    [(proc-stop)
     ;; Sprint 8: solve any remaining sess-metas to sess-end
     (for ([(c s) (in-hash delta)])
       (let ([zs (zonk-session s)])
         (when (sess-meta? zs)
           (solve-sess-meta! (sess-meta-id zs) (sess-end)))))
     (or (= (hash-count delta) 0)
         (chan-ctx-all-ended? (zonk-chan-ctx delta)))]

    ;; ---- Send: send e on c, continue as P ----
    [(proc-send e c p)
     (let ([s (zonk-session (chan-ctx-lookup delta c))])
       (match s
         ;; Simple send: c :: send(A, S)
         [(sess-send a s-cont)
          (and (check gamma e a)
               (type-proc gamma (chan-ctx-update delta c s-cont) p))]
         ;; Dependent send: c :: dsend(A, S)
         [(sess-dsend a s-cont)
          (and (check gamma e a)
               (type-proc gamma (chan-ctx-update delta c (substS s-cont 0 e)) p))]
         ;; Async send: c :: async-send(A, S)
         [(sess-async-send a s-cont)
          (and (check gamma e a)
               (type-proc gamma (chan-ctx-update delta c s-cont) p))]
         ;; Sprint 8: sess-meta → infer session from operation
         [(sess-meta id)
          (let ([ty (infer gamma e)])
            (and ty
                 (let ([cont-meta (fresh-sess-meta (format "send-cont-~a" c))])
                   (solve-sess-meta! id (sess-send ty cont-meta))
                   (type-proc gamma (chan-ctx-update delta c cont-meta) p))))]
         [_ #f]))]

    ;; ---- Receive: recv from c into x:A, continue as P ----
    ;; a-annot is the type annotation from the process; #f means "infer from session".
    [(proc-recv c _binding a-annot p)
     (let ([s (zonk-session (chan-ctx-lookup delta c))])
       (match s
         ;; Simple recv: c :: recv(A, S)
         [(sess-recv a s-cont)
          (and (or (not a-annot) (equal? a a-annot) (conv a a-annot))
               (is-type gamma a)
               (type-proc (ctx-extend gamma a 'mw) (chan-ctx-update delta c s-cont) p))]
         ;; Dependent recv: c :: drecv(A, S)
         [(sess-drecv a s-cont)
          (and (or (not a-annot) (equal? a a-annot) (conv a a-annot))
               (is-type gamma a)
               (type-proc (ctx-extend gamma a 'mw) (chan-ctx-update delta c s-cont) p))]
         ;; Async recv: c :: async-recv(A, S)
         [(sess-async-recv a s-cont)
          (and (or (not a-annot) (equal? a a-annot) (conv a a-annot))
               (is-type gamma a)
               (type-proc (ctx-extend gamma a 'mw) (chan-ctx-update delta c s-cont) p))]
         ;; Sprint 8: sess-meta → infer session from operation
         ;; Requires explicit annotation to solve the meta (can't infer from nothing).
         [(sess-meta id)
          (and a-annot  ; can't solve meta without annotation
               (is-type gamma a-annot)
               (let ([cont-meta (fresh-sess-meta (format "recv-cont-~a" c))])
                 (solve-sess-meta! id (sess-recv a-annot cont-meta))
                 (type-proc (ctx-extend gamma a-annot 'mw)
                            (chan-ctx-update delta c cont-meta) p)))]
         [_ #f]))]

    ;; ---- Select: select branch l on channel c ----
    [(proc-sel c label p)
     (let ([s (zonk-session (chan-ctx-lookup delta c))])
       (match s
         [(sess-choice branches)
          (let ([branch-s (lookup-branch label branches)])
            (and (not (sess-branch-error? branch-s))
                 (type-proc gamma (chan-ctx-update delta c branch-s) p)))]
         ;; Sprint 8: sess-meta → construct choice with this branch
         [(sess-meta id)
          (let ([cont-meta (fresh-sess-meta (format "sel-~a-~a" label c))])
            (solve-sess-meta! id (sess-choice (list (cons label cont-meta))))
            (type-proc gamma (chan-ctx-update delta c cont-meta) p))]
         [_ #f]))]

    ;; ---- Case/Offer: handle all branches ----
    [(proc-case c proc-branches)
     (let ([s (zonk-session (chan-ctx-lookup delta c))])
       (match s
         [(sess-offer sess-branches)
          (type-all-branches gamma (chan-ctx-remove delta c) c proc-branches sess-branches)]
         ;; Sprint 8: sess-meta → construct offer from process branch labels
         [(sess-meta id)
          (let* ([branch-metas (map (lambda (pb)
                                      (cons (car pb) (fresh-sess-meta (format "case-~a-~a" (car pb) c))))
                                    proc-branches)]
                 [offer (sess-offer branch-metas)])
            (solve-sess-meta! id offer)
            (type-all-branches gamma (chan-ctx-remove delta c) c proc-branches branch-metas))]
         [_ #f]))]

    ;; ---- New/Cut: create a new channel ----
    [(proc-new s (proc-par p1 p2))
     ;; Try all context splits; give ch::S to P1 and ch::dual(S) to P2
     (for/or ([split (in-list (context-splits delta))])
       (let ([d1 (car split)]
             [d2 (cdr split)])
         (and (type-proc gamma (chan-ctx-add d1 'ch s) p1)
              (type-proc gamma (chan-ctx-add d2 'ch (dual s)) p2))))]

    ;; ---- Parallel composition: split the linear context ----
    [(proc-par p1 p2)
     (for/or ([split (in-list (context-splits delta))])
       (let ([d1 (car split)]
             [d2 (cdr split)])
         (and (type-proc gamma d1 p1)
              (type-proc gamma d2 p2))))]

    ;; ---- Link/Forward: c1 and c2 have dual sessions ----
    [(proc-link c1 c2)
     (let ([s1 (zonk-session (chan-ctx-lookup delta c1))]
           [s2 (zonk-session (chan-ctx-lookup delta c2))])
       (cond
         ;; Sprint 8: sess-meta on one side → solve to dual of the other
         [(and (sess-meta? s1) (not (sess-meta? s2)))
          (solve-sess-meta! (sess-meta-id s1) (dual s2)) #t]
         [(and (not (sess-meta? s1)) (sess-meta? s2))
          (solve-sess-meta! (sess-meta-id s2) (dual s1)) #t]
         [(and s1 s2)
          (equal? (dual s1) s2)]
         [else #f]))]

    ;; ---- Solve (axiomatic) ----
    [(proc-solve a p)
     (and (is-type gamma a)
          (type-proc (ctx-extend gamma a 'mw) delta p))]

    ;; ---- S5b: Boundary operations ----
    ;; open/connect/listen create a single channel endpoint with the declared session type.
    ;; The capability type must be present in gamma (at any multiplicity).
    [(proc-open _path session-type cap-type cont)
     (and (or (not cap-type) (ctx-has-type? gamma cap-type))
          (type-proc gamma (chan-ctx-add delta 'ch session-type) cont))]

    [(proc-connect _addr session-type cap-type cont)
     (and (or (not cap-type) (ctx-has-type? gamma cap-type))
          (type-proc gamma (chan-ctx-add delta 'ch session-type) cont))]

    [(proc-listen _port session-type cap-type cont)
     (and (or (not cap-type) (ctx-has-type? gamma cap-type))
          (type-proc gamma (chan-ctx-add delta 'ch session-type) cont))]

    ;; ---- Fallback ----
    [_ #f]))

;; ========================================
;; Helper: check all branches of a case/offer
;; Walk session branches; for each, look up the corresponding process branch
;; ========================================
(define (type-all-branches gamma delta-rest c proc-branches sess-branches)
  (cond
    ;; All session branches checked
    [(null? sess-branches) #t]
    [else
     (let* ([branch (car sess-branches)]
            [label (car branch)]
            [s (cdr branch)]
            [p (lookup-branch-proc label proc-branches)])
       (and (not (proc-no-proc? p))
            (type-proc gamma (chan-ctx-add delta-rest c s) p)
            (type-all-branches gamma delta-rest c proc-branches (cdr sess-branches))))]))
