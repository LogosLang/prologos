#lang racket/base
;; C8 probe: is make-tagged-merge (decision-cell.rkt:526) commutative under equal? (the equivalence an unqualified
;; E check would use), or only modulo entry order (the readers' equivalence, comment at :535-537)?
(define dc (string->path "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/decision-cell.rkt"))
(define make-tagged-merge (dynamic-require dc 'make-tagged-merge))
(define tcv (dynamic-require dc 'tagged-cell-value))
(define tcv-entries (dynamic-require dc 'tagged-cell-value-entries))
(define m (make-tagged-merge (lambda (a b) (max a b))))
(define base (tcv 0 '()))
(define x (tcv 0 (list (cons 2 5))))   ; entry: worldview bit 1 -> 5
(define y (tcv 0 (list (cons 4 7))))   ; entry: worldview bit 2 -> 7
(define xy (m (m base x) y))
(define yx (m (m base y) x))
(printf "x then y entries: ~s\n" (tcv-entries xy))
(printf "y then x entries: ~s\n" (tcv-entries yx))
(printf "equal? ~a ; equal as sets? ~a\n" (equal? xy yx)
        (and (= (length (tcv-entries xy)) (length (tcv-entries yx)))
             (for/and ([e (tcv-entries xy)]) (and (member e (tcv-entries yx)) #t))))
(printf "power row (same order twice): equal? ~a\n" (equal? xy (m (m base x) y)))
