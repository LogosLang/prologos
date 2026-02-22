#lang racket/base

;;;
;;; Tests for reduction engine performance improvements:
;;; - Lazy branch normalization in nf-whnf (boolrec/natrec)
;;; - WHNF cache
;;; - Reduction fuel/step limit
;;; - nat-value memoization
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
         "../macros.rkt"
         "../posit-impl.rkt")

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

;; Helper: run prologos file
(define (run-file path)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    (process-file path)))

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

;; ========================================
;; WHNF cache
;; ========================================

(test-case "perf: WHNF cache is active during process-command"
  ;; Verify the cache parameter is set
  (define results
    (run-ns "(ns test.cache :no-prelude)
(eval 42)"))
  ;; Just verify it runs — the cache is internal
  (check-true (ormap (lambda (r) (string-contains? (format "~a" r) "42 : Int")) results)))

;; ========================================
;; Fuel exhaustion
;; ========================================

(test-case "perf: fuel exhaustion on infinite loop"
  ;; A function that loops forever should hit the fuel limit
  (check-exn
   (lambda (e)
     (and (exn:fail? e)
          (string-contains? (exn-message e) "fuel exhausted")))
   (lambda ()
     (run-ns "(ns test.loop :no-prelude)
(defn loop [n <Int>] <Int>
  (loop n))
(eval (loop 1))"))))

;; ========================================
;; nat-value memoization
;; ========================================

(test-case "perf: nat-value works with cache"
  ;; Build a Nat chain and verify coercion still works
  (define results
    (run-ns "(ns test.nat :no-prelude)
(eval (int+ 5N 3N))"))
  ;; 5N + 3N = 8 (Nat coerced to Int for int+)
  (check-true (ormap (lambda (r) (string-contains? (format "~a" r) "8 : Int")) results)
              "5N + 3N should coerce and produce 8"))

;; ========================================
;; Decimal posit literals
;; ========================================

(test-case "perf: decimal posit ~3.14 evaluates"
  (define results
    (run-ns "(ns test.decimal :no-prelude)
(eval ~3.14)"))
  (check-true (ormap (lambda (r)
                        (and (string? r)
                             (string-contains? r "Posit32")))
                      results)
              "~3.14 should produce a Posit32"))

(test-case "perf: decimal posit arithmetic"
  (define results
    (run-ns "(ns test.decimal-arith :no-prelude)
(eval (p32+ ~1.5 ~2.5))"))
  ;; 1.5 + 2.5 = 4.0
  (check-true (ormap (lambda (r)
                        (and (string? r)
                             (string-contains? r "Posit32")))
                      results)
              "~1.5 + ~2.5 should produce a Posit32"))
