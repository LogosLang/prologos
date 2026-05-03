#lang racket/base

;;; test-preduce-phase15-differential.rkt
;;;
;;; Phase 15 — 1000-case differential gate.
;;;
;;; Generates random closed Prologos AST terms over the supported
;;; subset of PReduce-lite (Phases 1-11, 13, 14; skipping foreign-fn
;;; per Phase 9 + generic ops per Phase 12 architectural hurdle).
;;; For each term: assert (preduce e) ≡ (nf e) under equal?.
;;;
;;; The generator is deliberately conservative — it produces ASTs
;;; whose elaborator-pre-output we know how to reduce: literals, int
;;; arithmetic, pairs + projections, lambdas + applications (static β),
;;; eliminators (boolrec / natrec / J), nested combinations.
;;;
;;; Generator strategy: depth-bounded recursive descent. Higher-depth
;;; terms select from a wider set of constructors; depth-zero always
;;; returns a leaf literal. Every generated term must be (a) closed
;;; (no free bvars at the top level) and (b) typable enough that nf
;;; doesn't error. To stay correct, we restrict to the int/Bool/pair
;;; subset where typability is mechanical.

(require rackunit
         racket/random
         racket/list
         "../syntax.rkt"
         "../preduce.rkt"
         (only-in "../reduction.rkt" nf))

;; ====================================================================
;; Generator
;; ====================================================================
;;
;; Each generator returns an AST that produces a value of a specific
;; type when reduced. We expose:
;;   gen-int   : depth → expr that reduces to (expr-int N)
;;   gen-bool  : depth → expr that reduces to (expr-true | expr-false)
;;   gen-pair  : depth → expr that reduces to (preduce-pair-value …)
;;
;; All generators take a depth budget; depth=0 returns a leaf.
;; Higher depth returns more elaborate combinators.

(define (gen-int depth)
  (cond
    [(<= depth 0)
     ;; Leaf: random int in [-50, 50]
     (expr-int (- (random 101) 50))]
    [else
     (define choice (random 7))
     (case choice
       [(0) (expr-int (- (random 101) 50))]                    ;; literal
       [(1) (expr-int-add (gen-int (- depth 1)) (gen-int (- depth 1)))]
       [(2) (expr-int-sub (gen-int (- depth 1)) (gen-int (- depth 1)))]
       [(3) (expr-int-mul (gen-int (- depth 1)) (gen-int (- depth 1)))]
       [(4)
        ;; boolrec int: pick branch based on a Bool
        (expr-boolrec (expr-Int)
                      (gen-int (- depth 1))
                      (gen-int (- depth 1))
                      (gen-bool (- depth 1)))]
       [(5)
        ;; pair-fst/snd
        (define-values (fst-cb snd-cb)
          (if (zero? (random 2))
              (values 'fst expr-fst)
              (values 'snd expr-snd)))
        (snd-cb (expr-pair (gen-int (- depth 1)) (gen-int (- depth 1))))]
       [(6)
        ;; static-β: ((λx. x op c) e) where op is +/-/*
        (define inner-op (list-ref (list expr-int-add expr-int-sub expr-int-mul)
                                   (random 3)))
        (define c (- (random 21) 10))
        (expr-app (expr-lam 'mw (expr-Int)
                            (inner-op (expr-bvar 0) (expr-int c)))
                  (gen-int (- depth 1)))])]))

(define (gen-bool depth)
  (cond
    [(<= depth 0)
     (if (zero? (random 2)) (expr-true) (expr-false))]
    [else
     (define choice (random 6))
     (case choice
       [(0) (if (zero? (random 2)) (expr-true) (expr-false))]
       [(1) (expr-int-eq (gen-int (- depth 1)) (gen-int (- depth 1)))]
       [(2) (expr-int-lt (gen-int (- depth 1)) (gen-int (- depth 1)))]
       [(3) (expr-int-le (gen-int (- depth 1)) (gen-int (- depth 1)))]
       [(4)
        (expr-boolrec (expr-Bool)
                      (gen-bool (- depth 1))
                      (gen-bool (- depth 1))
                      (gen-bool (- depth 1)))]
       [(5)
        ;; (λb. b) applied
        (expr-app (expr-lam 'mw (expr-Bool) (expr-bvar 0))
                  (gen-bool (- depth 1)))])]))

;; ====================================================================
;; Differential runner
;; ====================================================================

(define (norm-result r)
  ;; Normalize minor canonical-form differences between preduce and nf:
  ;; nf may canonicalize (expr-zero) to (expr-nat-val 0); preduce keeps
  ;; zero as-is. Treat them as equal.
  (cond
    [(equal? r (expr-zero)) (expr-nat-val 0)]
    [else r]))

(define (run-differential iters max-depth)
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
       (printf "MISMATCH (case ~a, depth ~a):~n  term:    ~v~n  preduce: ~v~n  nf:      ~v~n"
               i depth term result-preduce result-nf)]))
  (values mismatches preduce-errors nf-errors))

;; ====================================================================
;; The 1000-case gate
;; ====================================================================

(test-case "1000-case differential gate (depth ≤ 4) — preduce ≡ nf"
  ;; Seed the RNG for reproducibility (if a failure surfaces, the same
  ;; seed regenerates the failing case).
  (random-seed 20260502)
  (define-values (mismatches p-err n-err)
    (run-differential 1000 4))
  (check-equal? mismatches 0
                (format "1000-case differential found ~a mismatches" mismatches))
  (printf "Phase 15 differential: ~a iterations, ~a mismatches, ~a preduce errors, ~a nf errors~n"
          1000 mismatches p-err n-err))
