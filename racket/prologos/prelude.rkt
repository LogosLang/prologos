#lang racket/base

;;;
;;; PROLOGOS PRELUDE
;;; Utility types and operations for the Prologos formal specification.
;;; Direct translation of prologos-prelude.maude.
;;;

(require racket/match)

(provide
 ;; Multiplicities
 m0 m1 mw mult? (struct-out mult-meta)
 mult-add mult-mul mult-join mult-leq compatible
 ;; Universe levels
 (struct-out lzero) (struct-out lsuc) (struct-out level-meta)
 level? lmax level<=?)

;; ========================================
;; Multiplicity Semiring: {0, 1, omega}
;; ========================================

;; Multiplicities are symbols: 'm0, 'm1, 'mw
(define m0 'm0)
(define m1 'm1)
(define mw 'mw)

(struct mult-meta (id) #:transparent)  ;; Sprint 7: unsolved multiplicity

(define (mult? x)
  (or (memq x '(m0 m1 mw)) (mult-meta? x)))

;; Addition (join in the semiring)
;; Commutative: we enumerate all ordered pairs
;; mult-meta treated as 'mw (unsolved → unrestricted)
(define (mult-add a b)
  (let ([a (if (mult-meta? a) 'mw a)]
        [b (if (mult-meta? b) 'mw b)])
    (match* (a b)
      [('m0 'm0) 'm0]
      [('m0 'm1) 'm1]
      [('m1 'm0) 'm1]
      [('m0 'mw) 'mw]
      [('mw 'm0) 'mw]
      [('m1 'm1) 'mw]
      [('m1 'mw) 'mw]
      [('mw 'm1) 'mw]
      [('mw 'mw) 'mw])))

;; Multiplication (scaling)
;; Commutative: enumerate all ordered pairs
;; mult-meta treated as 'mw (unsolved → unrestricted)
(define (mult-mul a b)
  (let ([a (if (mult-meta? a) 'mw a)]
        [b (if (mult-meta? b) 'mw b)])
    (match* (a b)
      [('m0 'm0) 'm0]
      [('m0 'm1) 'm0]
      [('m1 'm0) 'm0]
      [('m0 'mw) 'm0]
      [('mw 'm0) 'm0]
      [('m1 'm1) 'm1]
      [('m1 'mw) 'mw]
      [('mw 'm1) 'mw]
      [('mw 'mw) 'mw])))

;; ========================================
;; Join (least upper bound) — the ALTERNATION operator
;; ========================================
;; `mult-add` is SEQUENTIAL/parallel composition: both usages happen, so
;; m1 + m1 = mw. That is right for `f x x` and it is the semiring addition QTT
;; is built on — PPN 4C Phase 2 analysed it and accepted `:usage` as a
;; commutative MONOID (see qtt.rkt § ":usage facet SRE domain registration").
;;
;; ALTERNATION is a DIFFERENT operation, and until now the tree had no operator
;; for it. When an eliminator picks exactly ONE branch — `boolrec`, the four
;; posit `if-nar`s, and a pattern-match's arms — the branches are alternatives,
;; not co-occurrences, so their usages combine with the least upper bound in the
;; order `mult-leq` already defines (m0 <= m1 <= mw), i.e. `max`. Adding them
;; instead OVER-COUNTS: a linear variable used once in each branch is used
;; exactly once on every execution path, but m1 + m1 = mw rejects it.
;;
;; So this is not a correction of `mult-add` — both operators are needed, and
;; `:usage` carries both a tensor and a join. The D2 note in qtt.rkt that
;; "REFUTE[d] idempotence" was right about ADDITION and is not overturned; it
;; simply was not about alternation.
;;
;; DIFFERS FROM `mult-add` IN EXACTLY ONE CELL: m1 ⊔ m1 = m1 (add gives mw).
;; Every other cell is identical, which is what makes swapping add→join at an
;; alternation site MONOTONE-PERMISSIVE: it can only accept more programs, never
;; reject more, so no currently-passing program can break.
;;
;; Identity = bottom = m0 (same as `mult-add`'s identity), which is why
;; `join-usage` can safely clone `add-usage`'s "shorter vector is all-m0" null
;; shortcuts.
;;
;; ⚠ NOT `mult-lattice-merge` (mult-lattice.rkt) — that is the FLAT agreement
;; lattice used for meta SOLUTION agreement, where m0 ⊔ m1 = 'mult-top, a symbol
;; `compatible` has no clause for. Feeding it here would raise a Racket match
;; error rather than produce a diagnostic.
;;
;; mult-meta treated as 'mw (unsolved → unrestricted), as in every sibling.
(define (mult-join a b)
  (let ([a (if (mult-meta? a) 'mw a)]
        [b (if (mult-meta? b) 'mw b)])
    (match* (a b)
      [('m0 'm0) 'm0]
      [('m0 'm1) 'm1]
      [('m1 'm0) 'm1]
      [('m0 'mw) 'mw]
      [('mw 'm0) 'mw]
      [('m1 'm1) 'm1]     ;; ← the one cell where this differs from mult-add
      [('m1 'mw) 'mw]
      [('mw 'm1) 'mw]
      [('mw 'mw) 'mw])))

;; Ordering: m0 <= m1 <= mw
;; mult-meta treated as 'mw (unsolved → unrestricted)
(define (mult-leq a b)
  (let ([a (if (mult-meta? a) 'mw a)]
        [b (if (mult-meta? b) 'mw b)])
    (match* (a b)
      [('m0 _)   #t]
      [('m1 'm0) #f]
      [('m1 _)   #t]
      [('mw 'mw) #t]
      [('mw _)   #f])))

;; Compatibility: actual usage p is compatible with declared multiplicity q
;; m0: must use 0 times; m1: exactly 1; mw: any number
;; mult-meta treated as 'mw (unsolved → unrestricted)
(define (compatible declared actual)
  (let ([declared (if (mult-meta? declared) 'mw declared)]
        [actual (if (mult-meta? actual) 'mw actual)])
    (match* (declared actual)
      [('m0 'm0) #t]
      [('m0 'm1) #f]
      [('m0 'mw) #f]
      [('m1 'm0) #f]
      [('m1 'm1) #t]
      [('m1 'mw) #f]
      [('mw 'm0) #t]
      [('mw 'm1) #t]
      [('mw 'mw) #t])))

;; ========================================
;; Universe Levels
;; ========================================

(struct lzero () #:transparent)
(struct lsuc (pred) #:transparent)
(struct level-meta (id) #:transparent)  ;; Sprint 6: unsolved universe level

(define (level? x)
  (or (lzero? x) (level-meta? x) (and (lsuc? x) (level? (lsuc-pred x)))))

;; lmax: maximum of two levels
;; lmax(lzero, L) = L
;; lmax(L, lzero) = L
;; lmax(L, L) = L
;; lmax(lsuc(L1), lsuc(L2)) = lsuc(lmax(L1, L2))
(define (lmax l1 l2)
  (cond
    [(lzero? l1) l2]
    [(lzero? l2) l1]
    [(equal? l1 l2) l1]
    [(and (lsuc? l1) (lsuc? l2))
     (lsuc (lmax (lsuc-pred l1) (lsuc-pred l2)))]
    ;; Sprint 6: level-meta handling — concrete level wins (conservative)
    [(level-meta? l1) l2]
    [(level-meta? l2) l1]
    [else (error 'lmax "cannot compute lmax of ~a and ~a" l1 l2)]))

;; level<=?: universe level comparison
;; lzero <= anything
;; lsuc(L1) <= lsuc(L2) iff L1 <= L2
;; lsuc(_) <= lzero is false
(define (level<=? l1 l2)
  (cond
    [(lzero? l1) #t]
    [(and (lsuc? l1) (lzero? l2)) #f]
    [(and (lsuc? l1) (lsuc? l2))
     (level<=? (lsuc-pred l1) (lsuc-pred l2))]
    ;; Sprint 6: optimistic with level-metas (unsolved defaults to 0)
    [(level-meta? l1) #t]
    [(level-meta? l2) #t]
    [else #f]))
