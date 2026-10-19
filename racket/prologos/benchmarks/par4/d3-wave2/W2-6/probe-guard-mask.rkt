#lang racket/base
;; C8 probe: BC-2 says "Guards retract by growth" once the worldview is P1a row 1's two-phase set (invalidated bits
;; only grow). The seed's per-binding guard clear (seed :106-113) and today's NAF per-binding mask
;; (relations.rkt:204) compute  mask = (OR failing) & ~(OR passing)  and AND-NOT it out of the worldview.
;; Is that decision monotone in the binding set it reads? Rows share the guard bit G (seed :111-113).
(define G 1) (define B1 2) (define B2 4)
(define row-fail (bitwise-ior G B1))   ; binding 1: condition fails
(define row-pass (bitwise-ior G B2))   ; binding 2: condition passes
(define (mask failing passing) (bitwise-and failing (bitwise-not passing)))
(define (alive? row invalidated) (zero? (bitwise-and row invalidated)))
(define complete (mask row-fail row-pass))          ; both rows materialized
(define partial  (mask row-fail 0))                 ; only the failing row materialized so far
(printf "mask over complete binding set: ~a  (clears B1 only)\n" complete)
(printf "mask over partial binding set:  ~a  (clears G and B1)\n" partial)
;; two-phase set: invalidated = ior of every mask ever written (permanent)
(define inv-correct complete)
(define inv-early (bitwise-ior partial complete))   ; the early write persists, the later correct one joins it
(printf "passing row alive, mask computed at completion: ~a\n" (alive? row-pass inv-correct))
(printf "passing row alive, mask also computed early:   ~a  (premature narrow is permanent under ior)\n" (alive? row-pass inv-early))
(printf "power row: failing row alive after correct mask: ~a (must be #f)\n" (alive? row-fail inv-correct))
