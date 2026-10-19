#lang racket/base
;; C5 (D.3 Theory) — the fenced half of D.2 §8's "DIRECT ↔ fenced sub-run alternation: each half is a finite run".
;; K-OSC: two MONOTONE fires (constants on a flat lattice {⊥ < a, b}) that both read and write one fenced cell f
;; whose merge is replacement (non-inflationary). Under BSP each round's private diff drops the writer that
;; agrees with the snapshot, so the round applies the other value: f alternates a, b, a, … until fuel runs out.
;; Rounds are counted with the production observer (current-bsp-observer).
(require (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))

(define (kosc bsp? fuel)
  (define rounds (box 0))
  (define n0 (make-prop-network fuel))
  (define-values (n1 s) (net-new-cell n0 0 (λ (a b) (max a b))))
  (define-values (n2 f) (net-new-cell n1 'bot (λ (old new) new)))       ; replacement merge (fenced)
  (define (writer v) (λ (n) (if (zero? (net-cell-read n s)) n (net-cell-write n f v))))
  (define-values (n3 _q1) (net-add-propagator n2 (list s f) (list f) (writer 'a)))
  (define-values (n4 _q2) (net-add-propagator n3 (list s f) (list f) (writer 'b)))
  (define base (parameterize ([current-use-bsp-scheduler? bsp?]) (run-to-quiescence n4)))
  (define r (parameterize ([current-use-bsp-scheduler? bsp?]
                           [current-bsp-observer (λ (rec) (set-box! rounds (add1 (unbox rounds))))])
              (run-to-quiescence (net-cell-write base s 1))))
  (list (net-cell-read r f) (prop-network-contradiction r) (unbox rounds)))

(printf "== K-OSC monotone fires, replacement merge on a fenced cell\n")
(for ([fuel '(200 2000)])
  (for ([bsp? '(#t #f)])
    (define v (kosc bsp? fuel))
    (printf "  ~a fuel=~a  f=~a  contradiction=~a  observer-records=~a\n"
            (if bsp? "BSP" "SEQ") fuel (car v) (cadr v) (caddr v))))
