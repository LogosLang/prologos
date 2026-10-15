#lang racket/base
;; PAR 4 O-9 evidence — POWER CHECK for the merge-order census (propagator.rkt, PAR4_MERGE_ORDER_CENSUS).
;;
;; A census that reports "0 divergences" is evidence only if it can report a non-zero one. Each row
;; is a two-writer network whose writers are triggered by the SAME source cell, so both fire in ONE
;; BSP round and the round has two fire results; the census then applies them flat (F), flat again
;; (C, control), tree-combined (T: the threshold-256 path) and reversed (R).
;;
;;   power-R   two UNDECLARED writers of an ior cell, read-modify-write of their own bit (Q1's M3).
;;             Undeclared writes are applied by replacement, so the LAST applied wins and F and R end
;;             on different bits. Predicted: R differs, T does not (the tree keeps the order).
;;   power-T   writer A writes C := 1 UNDECLARED; writer B writes 3 DECLARED into a max cell.
;;             F applies A's replacement, then B's join: max(1,3) = 3. T applies every declared write
;;             first, then every undeclared one: max(0,3) = 3, then replace by 1 → 1.
;;             Predicted: T differs and R differs. B is installed FIRST: in these networks a round's
;;             results arrive in reverse installation order (measured: power-R ends at 2, not 4), and
;;             T can only differ when the undeclared write's result precedes the declared one.
;;   power-T0  the same writers installed A first, so B's result comes first: F = T = 1 (the tree
;;             keeps the order); only R differs. Shows T's sensitivity is to the ORDER, not the cells.
;;   neg-join  two DECLARED writers, max merge (a join). Predicted: nothing differs.
;;   neg-ior   two DECLARED writers of an ior cell, own bit (M3 declared). Predicted: nothing differs.
;;
;; Run one row per process (the census aggregates per process):
;;   PAR4_MERGE_ORDER_CENSUS=<file> PAR4_MC_LABEL=<row> racket benchmarks/par4/o9-merge-order-power.rkt <row>
;; Prints the row's BSP result; the census line goes to <file> at exit.
(require "../../propagator.rkt")

(define (run net) (parameterize ([current-use-bsp-scheduler? #t]) (run-to-quiescence net)))
(define maxm (λ (a b) (max a b)))
(define iorm (λ (a b) (bitwise-ior a b)))

;; writers : list of (declared? . (old-C -> new-C))
(define (net-with merge init writers)
  (define net0 (make-prop-network 100000))
  (define-values (net1 s) (net-new-cell net0 0 maxm))
  (define-values (net2 c) (net-new-cell net1 init merge))
  (define net3
    (for/fold ([n net2]) ([w (in-list writers)])
      (define declared? (car w))
      (define step (cdr w))
      (define-values (n* _p)
        (net-add-propagator n (list s) (if declared? (list c) '())
                            (λ (n) (if (zero? (net-cell-read n s)) n
                                       (net-cell-write n c (step (net-cell-read n c)))))))
      n*))
  (net-cell-read (run (net-cell-write net3 s 1)) c))

(define own-bit (λ (i) (λ (old) (bitwise-ior old (arithmetic-shift 1 i)))))
(define row (vector-ref (current-command-line-arguments) 0))
(define result
  (case (string->symbol row)
    [(power-R)  (net-with iorm 0 (list (cons #f (own-bit 1)) (cons #f (own-bit 2))))]
    [(power-T)  (net-with maxm 0 (list (cons #t (λ (old) 3)) (cons #f (λ (old) 1))))]
    [(power-T0) (net-with maxm 0 (list (cons #f (λ (old) 1)) (cons #t (λ (old) 3))))]
    [(neg-join) (net-with maxm 0 (list (cons #t (λ (old) 1)) (cons #t (λ (old) 3))))]
    [(neg-ior)  (net-with iorm 0 (list (cons #t (own-bit 1)) (cons #t (own-bit 2))))]
    [else (error 'o9-power "unknown row ~a" row)]))
(printf "~a BSP C = ~a\n" row result)
