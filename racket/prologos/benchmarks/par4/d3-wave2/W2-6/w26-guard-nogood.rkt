#lang racket/base
;; W2-6 (PAR 4 D.3 wave 2, CL-6 (b)×(d)) — C8-5 showed the per-binding guard / NAF mask
;;   mask = (OR failing) & ~(OR passing)        (seed :106-113; relations.rkt:204)
;; is anti-monotone in the set of passing rows, so under a grow-only invalidated set (D.2's two-phase set) an early
;; write kills a passing row for good. Adapted from C8's probe-guard-mask.rkt.
;; Question: is the anti-monotonicity in the DECISION, or in the ENCODING of nogoods as single worldview bits?
;; Under (b) the guard writes the primary instead of cell-1: a nogood ENVIRONMENT (a set of assumptions; atms.rkt's
;; nogood cell, solver-state-consistent?) = {G} ∪ label of the row it read.  Exhaustive over 3 rows sharing G,
;; every pass/fail pattern (8), every arrival order (6), the guard deciding after EVERY arrival (prefix).
;; Run: racket w26-guard-nogood.rkt
(require racket/list)
(define G 1)
(define (row-bit i) (arithmetic-shift 2 i))          ;; B1=2, B2=4, B3=8
(define (row i) (bitwise-ior G (row-bit i)))
(define (subset? a b) (= (bitwise-and a b) a))
(define (run-encoding enc pattern order)
  ;; pattern: vector of #t (passes) / #f (fails); order: arrival permutation of row indices
  (define-values (inv nogoods)
    (for/fold ([inv 0] [ngs '()]) ([k (in-range 1 (add1 (length order)))])
      (define prefix (take order k))
      (case enc
        [(bits) (define failing (for/fold ([m 0]) ([i prefix] #:unless (vector-ref pattern i)) (bitwise-ior m (row i))))
                (define passing (for/fold ([m 0]) ([i prefix] #:when (vector-ref pattern i)) (bitwise-ior m (row i))))
                (values (bitwise-ior inv (bitwise-and failing (bitwise-not passing))) ngs)]   ;; ior: permanent (2P-set)
        [(env)  (values inv (remove-duplicates (append ngs (for/list ([i prefix] #:unless (vector-ref pattern i)) (row i)))))])))
  (for/list ([i 3])
    (case enc
      [(bits) (zero? (bitwise-and (row i) inv))]
      [(env)  (not (for/or ([ng nogoods]) (subset? ng (row i))))])))
(define patterns (for/list ([m 8]) (for/vector ([i 3]) (bitwise-bit-set? m i))))
(for ([enc '(bits env)])
  (define-values (premature missed cases)
    (for*/fold ([p 0] [ms 0] [c 0]) ([pat patterns] [ord (permutations '(0 1 2))])
      (define alive (run-encoding enc pat ord))
      (values (+ p (for/sum ([i 3]) (if (and (vector-ref pat i) (not (list-ref alive i))) 1 0)))
              (+ ms (for/sum ([i 3]) (if (and (not (vector-ref pat i)) (list-ref alive i)) 1 0)))
              (+ c 3))))
  (printf "~a: passing rows killed (premature narrow, permanent) ~a/~a ; failing rows left alive (POWER: must be 0) ~a/~a\n"
          (if (eq? enc 'bits) "bit mask AND-NOT into a grow-only invalidated set (C8-5)" "nogood environments {G} ∪ row label      ")
          premature cases missed cases))
;; C8's exact case: row-fail = G|B1, row-pass = G|B2, the failing row materialises first
(printf "C8's case (fail row first, then pass row): bits -> pass row alive ~a ; env -> pass row alive ~a\n"
        (list-ref (run-encoding 'bits (vector #f #t #t) '(0 1 2)) 1) (list-ref (run-encoding 'env (vector #f #t #t) '(0 1 2)) 1))
