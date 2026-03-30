#lang racket/base

;;;
;;; Test for reduction engine performance — fuel exhaustion:
;;; - An infinite loop that exercises the 1M-step fuel limit
;;;
;;; This single test takes ~112s (the loop runs 1M WHNF reductions
;;; before hitting the fuel limit). Isolated from the lightweight tests
;;; in test-reduction-perf-01-01.rkt so it doesn't bottleneck the
;;; parallel test runner.
;;;

(require rackunit
         racket/string
         racket/path
         "test-support.rkt"
         "../syntax.rkt"
         "../prelude.rkt"
         "../surface-syntax.rkt"
         "../parse-reader.rkt"
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
