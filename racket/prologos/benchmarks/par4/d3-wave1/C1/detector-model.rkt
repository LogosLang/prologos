#lang racket/base
;; C1 probe (D.3 wave 1): a deterministic model of D.2 §6.7's quiescence detector.
;; D.2: "per executor, padded: prod, cons, idle-epoch. The detector declares quiescence of epoch e
;; when Σprod = Σcons and every idle-epoch = e, stable across two scans"; idle-epoch "replaces D.1's
;; reset flag" (§9) and is a max-counter (cannot go back when the executor becomes busy again).
;; D.2: "the owner drains its K−1 lanes at the top of each loop iteration and joins" — cons is counted
;; at drain. Local (owned-cell) writes enqueue local dependents and send no message.
;;
;; The trace (K = 2, epoch e = 1):
;;  t1  exec1 has nothing to do: idle-epoch1 := 1
;;  t2  exec0 fires p, which writes a cell owned by exec1: lane[1][0] += d ; prod0 := 1
;;  t3  exec0's worklist is empty: idle-epoch0 := 1
;;  t4  exec1 drains lane[1][0]: cons1 := 1 ; the join changes c ; c's 3 local dependents enqueue
;;  t5  detector scan 1        t6  detector scan 2        (exec1 is still working through 3 fires)
;;  t7  exec1 fires its dependents, writing owned cells tagged with epoch 1
;; Four encodings of "executor i is passive" are evaluated at t5/t6:
;;  A  D.2: idle-epoch_i max-counter, cons counted at drain
;;  B  D.1 / P0 detect.rkt: idle_i reset flag (cleared on becoming busy)
;;  C  D.2's counters but cons counted only after the local cascade completes (detect.rkt :117-121 order)
;;  D  monotone activation counters: busy_i, done_i (both max-counters); passive iff busy_i = done_i;
;;     the busy vector must be unchanged across the two scans
;;  E  credit recovery (Mattern 1989 / Huang 1989): a busy executor holds credit; recovered credit is a
;;     monotone sum; quiescence iff recovered = 1 (a threshold on one monotone cell; no scan)
(struct st (prod cons idle-epoch idle-flag busy done credit recovered worklist) #:transparent)

(define e 1)
;; state at t5 (after t4), per encoding
(define t5
  (st (vector 1 0)          ; prod
      (vector 0 1)          ; cons (counted at drain — encodings A, B, D)
      (vector 1 1)          ; idle-epoch (sticky: exec1 set it at t1)
      (vector 1 0)          ; reset flag: exec1 cleared it at t4
      (vector 1 1)          ; busy count: exec0 busy at epoch start (p), exec1 became busy at t4
      (vector 1 0)          ; done count: exec0 finished at t3; exec1 has not finished
      (vector 0 1/2)        ; credit held: exec0 returned its, exec1 holds the delta's credit
      1/2                   ; recovered credit
      (vector 0 3)))        ; worklists (ground truth)

(define (sum v) (for/sum ([x v]) x))
(define truly-quiescent? (and (= 0 (sum (st-worklist t5)))))

;; A: D.2 as written
(define (detA s) (and (= (sum (st-prod s)) (sum (st-cons s)))
                      (for/and ([x (st-idle-epoch s)]) (= x e))))
;; B: reset flag
(define (detB s) (and (= (sum (st-prod s)) (sum (st-cons s)))
                      (for/and ([x (st-idle-flag s)]) (= x 1))))
;; C: cons counted after the cascade: exec1's cons is still 0 during t5/t6
(define (detC s) (and (= (sum (st-prod s)) (sum (vector 0 0)))
                      (for/and ([x (st-idle-epoch s)]) (= x e))))
;; D: activation counters (exec1: busy 1 at t4, done 0)
(define (detD s) (and (= (sum (st-prod s)) (sum (st-cons s)))
                      (for/and ([b (st-busy s)] [d (st-done s)]) (= b d))))
;; E: credit recovery
(define (detE s) (= (st-recovered s) 1))

(printf "ground truth at t5/t6: worklists = ~a, quiescent? = ~a\n" (st-worklist t5) truly-quiescent?)
(for ([name '(A-D2-idle-epoch B-D1-reset-flag C-cons-after-cascade D-activation-counters E-credit-recovery)]
      [det (list detA detB detC detD detE)])
  ;; two scans over the same state (nothing changes between t5 and t6 in any counter)
  (define s1 (det t5)) (define s2 (det t5))
  (printf "~a: scan1 ~a scan2 ~a -> declares quiescence: ~a~a\n" name s1 s2 (and s1 s2)
          (if (and s1 s2 (not truly-quiescent?)) "   <-- PREMATURE: t7 writes tagged epoch 1 <= boundary-epoch => 'late-s0-write" "")))

;; Power row: after t7 exec1 finishes (worklist empty). Every correct encoding must now declare
;; quiescence (a detector that never fires would otherwise pass the row above).
(define t8 (st (vector 1 0) (vector 0 1) (vector 1 1) (vector 1 1) (vector 1 1) (vector 1 1)
               (vector 0 0) 1 (vector 0 0)))
(define (detC* s) (and (= (sum (st-prod s)) (sum (st-cons s))) (for/and ([x (st-idle-epoch s)]) (= x e))))
(printf "POWER (t8, truly quiescent):")
(for ([name '(A B C D E)] [det (list detA detB detC* detD detE)])
  (printf " ~a=~a" name (and (det t8) (det t8))))
(newline)
