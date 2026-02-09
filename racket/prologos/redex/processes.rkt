#lang racket/base

;; Process syntax and channel contexts for the PLT Redex formalization of Prologos.
;;
;; Process s-expressions:
;;   (stop)                          — terminated process
;;   (psend e c P)                   — send expression e on channel c, continue as P
;;   (precv c A P)                   — receive from c (binding of type A), continue as P
;;   (psel c label P)                — select branch label on channel c
;;   (pcase c ((l1 . P1) (l2 . P2) ...)) — offer branches on channel c
;;   (pnew S (ppar P1 P2))           — create new channel with session S
;;   (ppar P1 P2)                    — parallel composition
;;   (plink c1 c2)                   — link/forward two channels
;;
;; Channel context: hasheq mapping channel symbols to session s-expressions.

(require racket/match)

(provide chan-ctx-empty
         chan-ctx-add
         chan-ctx-lookup
         chan-ctx-remove
         chan-ctx-update
         chan-ctx-all-ended?
         chan-ctx-keys
         chan-ctx-size
         lookup-branch-proc)

;; Channel Context: immutable hash (channel -> session)
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
    (equal? s 'endS)))

(define (chan-ctx-keys ctx)
  (hash-keys ctx))

(define (chan-ctx-size ctx)
  (hash-count ctx))

;; Branch lookup in process branches
(define (lookup-branch-proc label branches)
  (cond
    [(null? branches) #f]
    [(equal? (caar branches) label) (cdar branches)]
    [else (lookup-branch-proc label (cdr branches))]))
