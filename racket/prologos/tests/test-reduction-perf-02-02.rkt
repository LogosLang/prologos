#lang racket/base

;;;
;;; Tests for reduction engine performance — heavy computation:
;;; - fib 20 (exponential tree recursion, ~1M reductions)
;;;
;;; Split from test-reduction-perf-02.rkt; the slowest test isolated
;;; here so it doesn't bottleneck faster tests.
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
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    (process-string s)))

(test-case "perf: fib 20 completes (boolrec fix)"
  ;; Previously hung due to exponential branch normalization
  (define results
    (run-ns "(ns test.fib :no-prelude)
(defn fib [n <Int>] <Int>
  (if (int-le n 1) n (int+ (fib (int- n 1)) (fib (int- n 2)))))
(eval (fib 20))"))
  (check-true (ormap (lambda (r) (string-contains? (format "~a" r) "6765 : Int")) results)
              "fib 20 should equal 6765"))
