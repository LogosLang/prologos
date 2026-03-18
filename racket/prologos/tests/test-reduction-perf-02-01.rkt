#lang racket/base

;;;
;;; Tests for reduction engine performance — heavy computation:
;;; - fact 20
;;; - collatz-len 27 (111 steps)
;;;
;;; Split from test-reduction-perf-02.rkt; the slowest test (fib 20)
;;; is isolated in test-reduction-perf-02-02.rkt.
;;;

(require rackunit
         racket/string
         racket/path
         "test-support.rkt"
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

;; Helper: run prologos code with namespace system active
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    (process-string s)))

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
