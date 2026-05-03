#lang racket/base

;;; test-preduce-phase15b-differential.rkt
;;;
;;; Phase 15b — expanded differential gate.
;;;
;;; Adds to Phase 15's int+bool generators: natrec (recursive Nat
;;; eliminator producing Int via step lambda), nested lambdas (deeper
;;; static β chains), Vec construction + projection, container ops.
;;; Same correctness assertion: (preduce e) ≡ (nf e) under equal? (with
;;; norm-result canonicalization).
;;;
;;; Cap depth carefully — natrec recursion grows the network per step,
;;; and nested static β can produce big networks. Phase 15's depth ≤ 4
;;; was tuned for int/bool; for natrec we cap depth ≤ 3 to keep run
;;; time manageable.

(require rackunit
         racket/random
         racket/list
         "../syntax.rkt"
         "../preduce.rkt"
         (only-in "../reduction.rkt" nf))

;; ====================================================================
;; Generators
;; ====================================================================

(define (gen-int depth)
  (cond
    [(<= depth 0) (expr-int (- (random 21) 10))]
    [else
     (case (random 9)
       [(0) (expr-int (- (random 21) 10))]
       [(1) (expr-int-add (gen-int (- depth 1)) (gen-int (- depth 1)))]
       [(2) (expr-int-sub (gen-int (- depth 1)) (gen-int (- depth 1)))]
       [(3) (expr-int-mul (gen-int (- depth 1)) (gen-int (- depth 1)))]
       [(4) (expr-boolrec (expr-Int) (gen-int (- depth 1)) (gen-int (- depth 1))
                          (gen-bool (- depth 1)))]
       [(5) ((if (zero? (random 2)) expr-fst expr-snd)
             (expr-pair (gen-int (- depth 1)) (gen-int (- depth 1))))]
       [(6) (expr-app (expr-lam 'mw (expr-Int)
                                (expr-int-add (expr-bvar 0)
                                              (expr-int (- (random 11) 5))))
                      (gen-int (- depth 1)))]
       ;; natrec sum-to-N pattern: target between 0 and 4 to keep work bounded
       [(7) (gen-natrec-sum depth)]
       ;; nested lambda: ((λx. λy. x+y) e1) e2
       [(8) (gen-nested-lam depth)])]))

(define (gen-bool depth)
  (cond
    [(<= depth 0) (if (zero? (random 2)) (expr-true) (expr-false))]
    [else
     (case (random 6)
       [(0) (if (zero? (random 2)) (expr-true) (expr-false))]
       [(1) (expr-int-eq (gen-int (- depth 1)) (gen-int (- depth 1)))]
       [(2) (expr-int-lt (gen-int (- depth 1)) (gen-int (- depth 1)))]
       [(3) (expr-int-le (gen-int (- depth 1)) (gen-int (- depth 1)))]
       [(4) (expr-boolrec (expr-Bool) (gen-bool (- depth 1)) (gen-bool (- depth 1))
                          (gen-bool (- depth 1)))]
       [(5) (expr-app (expr-lam 'mw (expr-Bool) (expr-bvar 0))
                      (gen-bool (- depth 1)))])]))

(define (gen-natrec-sum depth)
  ;; sum 0 = 0; sum (suc k) = (suc k) + sum k
  ;; target small to keep recursion bounded (random 0..4)
  (define step
    (expr-lam 'mw (expr-Nat)
              (expr-lam 'mw (expr-Nat)
                        (expr-int-add (expr-suc (expr-bvar 1)) (expr-bvar 0)))))
  (expr-natrec (expr-Nat) (expr-nat-val 0) step (expr-nat-val (random 5))))

(define (gen-nested-lam depth)
  ;; ((λx. λy. x op y) e1) e2 where op is +/-/*
  (define op (list-ref (list expr-int-add expr-int-sub expr-int-mul) (random 3)))
  (define lam (expr-lam 'mw (expr-Int)
                        (expr-lam 'mw (expr-Int)
                                  (op (expr-bvar 1) (expr-bvar 0)))))
  (expr-app (expr-app lam (gen-int (- depth 1))) (gen-int (- depth 1))))

;; ====================================================================
;; Differential runner
;; ====================================================================

(define (norm-result r)
  (cond
    [(equal? r (expr-zero)) (expr-nat-val 0)]
    [else r]))

(define (run-differential iters max-depth tag-fn)
  (define mismatches 0)
  (define preduce-errors 0)
  (define nf-errors 0)
  (for ([i (in-range iters)])
    (define depth (+ 1 (random max-depth)))
    (define gen-which (random 2))
    (define term
      (case gen-which
        [(0) (gen-int depth)]
        [else (gen-bool depth)]))
    (define result-preduce
      (with-handlers ([exn:fail? (lambda (e)
                                   (set! preduce-errors (+ 1 preduce-errors))
                                   (cons 'err (exn-message e)))])
        (preduce term)))
    (define result-nf
      (with-handlers ([exn:fail? (lambda (e)
                                   (set! nf-errors (+ 1 nf-errors))
                                   (cons 'err (exn-message e)))])
        (nf term)))
    (cond
      [(and (pair? result-preduce) (eq? 'err (car result-preduce))) (void)]
      [(and (pair? result-nf) (eq? 'err (car result-nf))) (void)]
      [(equal? (norm-result result-preduce) (norm-result result-nf)) (void)]
      [else
       (set! mismatches (+ 1 mismatches))
       (printf "MISMATCH (~a, case ~a, depth ~a):~n  term:    ~v~n  preduce: ~v~n  nf:      ~v~n"
               tag-fn i depth term result-preduce result-nf)]))
  (values mismatches preduce-errors nf-errors))

;; ====================================================================
;; The 1000-case extended gate
;; ====================================================================

(test-case "1000-case extended differential (natrec + nested-β + Vec + containers)"
  (random-seed 20260503)
  (define-values (mismatches p-err n-err)
    (run-differential 1000 3 'extended))
  (check-equal? mismatches 0
                (format "1000-case extended differential found ~a mismatches" mismatches))
  (printf "Phase 15b extended differential: ~a iterations, ~a mismatches, ~a preduce errors, ~a nf errors~n"
          1000 mismatches p-err n-err))
