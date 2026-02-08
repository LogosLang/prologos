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

(require racket/match
         "prelude.rkt"
         "syntax.rkt"
         "substitution.rkt"
         "reduction.rkt"
         "typing-core.rkt"
         "sessions.rkt"
         "processes.rkt")

(provide type-proc)

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
;; Main process typing judgment
;; ========================================
(define (type-proc gamma delta proc)
  (match proc
    ;; ---- Stop: all channels must be ended ----
    [(proc-stop)
     (or (= (hash-count delta) 0)
         (chan-ctx-all-ended? delta))]

    ;; ---- Send: send e on c, continue as P ----
    [(proc-send e c p)
     (let ([s (chan-ctx-lookup delta c)])
       (match s
         ;; Simple send: c :: send(A, S)
         [(sess-send a s-cont)
          (and (check gamma e a)
               (type-proc gamma (chan-ctx-update delta c s-cont) p))]
         ;; Dependent send: c :: dsend(A, S)
         [(sess-dsend a s-cont)
          (and (check gamma e a)
               (type-proc gamma (chan-ctx-update delta c (substS s-cont 0 e)) p))]
         [_ #f]))]

    ;; ---- Receive: recv from c into x:A, continue as P ----
    [(proc-recv c a-annot p)
     (let ([s (chan-ctx-lookup delta c)])
       (match s
         ;; Simple recv: c :: recv(A, S)
         [(sess-recv a s-cont)
          (and (or (equal? a a-annot) (conv a a-annot))
               (is-type gamma a)
               (type-proc (ctx-extend gamma a 'mw) (chan-ctx-update delta c s-cont) p))]
         ;; Dependent recv: c :: drecv(A, S)
         [(sess-drecv a s-cont)
          (and (or (equal? a a-annot) (conv a a-annot))
               (is-type gamma a)
               (type-proc (ctx-extend gamma a 'mw) (chan-ctx-update delta c s-cont) p))]
         [_ #f]))]

    ;; ---- Select: select branch l on channel c ----
    [(proc-sel c label p)
     (let ([s (chan-ctx-lookup delta c)])
       (match s
         [(sess-choice branches)
          (let ([branch-s (lookup-branch label branches)])
            (and (not (sess-branch-error? branch-s))
                 (type-proc gamma (chan-ctx-update delta c branch-s) p)))]
         [_ #f]))]

    ;; ---- Case/Offer: handle all branches ----
    [(proc-case c proc-branches)
     (let ([s (chan-ctx-lookup delta c)])
       (match s
         [(sess-offer sess-branches)
          (type-all-branches gamma (chan-ctx-remove delta c) c proc-branches sess-branches)]
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
     (let ([s1 (chan-ctx-lookup delta c1)]
           [s2 (chan-ctx-lookup delta c2)])
       (and s1 s2
            (equal? (dual s1) s2)))]

    ;; ---- Solve (axiomatic) ----
    [(proc-solve a p)
     (and (is-type gamma a)
          (type-proc (ctx-extend gamma a 'mw) delta p))]

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
