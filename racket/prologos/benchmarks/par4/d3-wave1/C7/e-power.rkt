#lang racket/base
;; C7 probe: does D.2 §6.3's E power check ("a seeded non-join that must be caught") detect a
;; sample generator that cannot reach the failing arm?  Law counts over exhaustive triples.
;;  rows: the installed type merge (type-unify-or-top); a GENERIC seeded non-join (last-writer-wins);
;;        an ARM-LOCAL mutant (= type-unify-or-top, but returns its 2nd argument whenever either side
;;        contains a meta: a non-join reachable only through the meta arm)
;;  sample sets: (A) tests/test-sre-algebraic.rkt:111's six ground atoms, no callback;
;;               (B) + unsolved metas + binder types, callback installed (merge-laws note §3)
(require racket/list)
(define root "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos")
(define (get f id) (dynamic-require (list 'file (string-append root "/" f)) id))
(define expr-Nat (get "syntax.rkt" 'expr-Nat)) (define expr-Bool (get "syntax.rkt" 'expr-Bool))
(define expr-Int (get "syntax.rkt" 'expr-Int)) (define expr-String (get "syntax.rkt" 'expr-String))
(define expr-Unit (get "syntax.rkt" 'expr-Unit))
(define expr-Pi (get "syntax.rkt" 'expr-Pi)) (define expr-meta (get "syntax.rkt" 'expr-meta))
(define expr-meta? (get "syntax.rkt" 'expr-meta?))
(define type-unify-or-top (get "type-lattice.rkt" 'type-unify-or-top))
(define cb (get "type-lattice.rkt" 'current-lattice-meta-solution-fn))
(define m1 (expr-meta 'pm1 #f)) (define m2 (expr-meta 'pm2 #f))

(define (has-meta? t) (or (expr-meta? t) (and (struct? t) (for/or ([x (in-vector (struct->vector t))]) (has-meta? x)))))
(define (lww a b) b)
(define (arm-mutant a b) (if (or (has-meta? a) (has-meta? b)) b (type-unify-or-top a b)))

(define (laws name merge samples)
  (define (count pred) (for*/sum ([x samples] [y samples] [z samples]) (if (pred x y z) 0 1)))
  (printf "  ~a: C ~a  A ~a  I ~a   (~a samples)\n" name
          (count (λ (x y z) (equal? (merge x y) (merge y x))))
          (count (λ (x y z) (equal? (merge (merge x y) z) (merge x (merge y z)))))
          (count (λ (x y z) (equal? (merge x x) x)))
          (length samples)))

(define sre-samples (list 'type-bot 'type-top (expr-Int) (expr-Nat) (expr-String) (expr-Bool)))
(define rep-samples (list 'type-bot 'type-top (expr-Nat) (expr-Bool) (expr-Unit) m1 m2
                          (expr-Pi 'mw (expr-Nat) m1) (expr-Pi 'mw (expr-Nat) (expr-Unit))))
(printf "(A) SRE test samples, no callback\n")
(laws "type-unify-or-top (installed)" type-unify-or-top sre-samples)
(laws "seeded generic non-join (LWW)" lww sre-samples)
(laws "arm-local mutant (meta arm)  " arm-mutant sre-samples)
(printf "(B) representative samples, callback installed (all metas unsolved)\n")
(parameterize ([cb (λ (id) #f)])
  (laws "type-unify-or-top (installed)" type-unify-or-top rep-samples)
  (laws "seeded generic non-join (LWW)" lww rep-samples)
  (laws "arm-local mutant (meta arm)  " arm-mutant rep-samples))
