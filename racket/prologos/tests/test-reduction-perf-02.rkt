#lang racket/base

;;;
;;; Tests for reduction engine performance — heavy computation:
;;; - fib 20 (exponential tree recursion, ~1M reductions)
;;; - fact 20
;;; - collatz-len 27 (111 steps)
;;;
;;; These tests exercise the lazy branch normalization fix
;;; that prevents exponential blowup in nf-whnf boolrec/natrec.
;;;

(require rackunit
         racket/string
         racket/path
         "../syntax.rkt"
         "../prelude.rkt"
         "../surface-syntax.rkt"
         "../reader.rkt"
         "../parser.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../reduction.rkt"
         "../namespace.rkt"
         "../macros.rkt")

;; Compute the lib directory path
(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Helper: run prologos code with namespace system active
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    (process-string s)))

;; ========================================
;; Lazy branch normalization (boolrec)
;; ========================================

(test-case "perf: fib 20 completes (boolrec fix)"
  ;; Previously hung due to exponential branch normalization
  (define results
    (run-ns "(ns test.fib :no-prelude)
(defn fib [n <Int>] <Int>
  (if (int-le n 1) n (int+ (fib (int- n 1)) (fib (int- n 2)))))
(eval (fib 20))"))
  (check-true (ormap (lambda (r) (string-contains? (format "~a" r) "6765 : Int")) results)
              "fib 20 should equal 6765"))

(test-case "perf: fact 20 completes (boolrec fix)"
  (define results
    (run-ns "(ns test.fact :no-prelude)
(defn fact [n <Int>] <Int>
  (if (int-le n 1) 1 (int* n (fact (int- n 1)))))
(eval (fact 20))"))
  (check-true (ormap (lambda (r) (string-contains? (format "~a" r) "2432902008176640000 : Int")) results)
              "fact 20 should equal 2432902008176640000"))

(test-case "perf: collatz-len 27 completes (boolrec fix)"
  ;; 27 takes 111 steps in the Collatz sequence
  (define results
    (run-ns "(ns test.collatz :no-prelude)
(defn collatz-len [n <Int> acc <Int>] <Int>
  (if (int-eq n 1) acc
    (if (int-eq (int-mod n 2) 0)
        (collatz-len (int/ n 2) (int+ acc 1))
        (collatz-len (int+ (int* 3 n) 1) (int+ acc 1)))))
(eval (collatz-len 27 0))"))
  (check-true (ormap (lambda (r) (string-contains? (format "~a" r) "111 : Int")) results)
              "collatz-len 27 should be 111"))
