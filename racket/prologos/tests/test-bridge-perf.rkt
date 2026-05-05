#lang racket/base
;;
;; Diagnostic for goblin pitfall #31: timing decode-op in isolation.
;; If decode-op alone is slow, the bottleneck is in the syrup
;; decoder. If decode-op is fast but combined chain is slow, the
;; bottleneck is the bridge processing decoded values.
;;

(require rackunit racket/list "test-support.rkt"
         "../macros.rkt" "../prelude.rkt" "../syntax.rkt"
         "../source-location.rkt" "../surface-syntax.rkt"
         "../errors.rkt" "../metavar-store.rkt" "../parser.rkt"
         "../elaborator.rkt" "../pretty-print.rkt" "../global-env.rkt"
         "../driver.rkt" "../namespace.rkt" "../multi-dispatch.rkt")

(define preamble
  "(ns test-bridge-perf)
(imports (prologos::ocapn::core :refer-all))
(imports (prologos::ocapn::message :refer-all))
(imports (prologos::ocapn::captp-wire :refer-all))
(imports (prologos::data::option :refer (Option some none unwrap-or)))
")

(define-values (env nsc mr tr ir pir cr tm)
  (parameterize ([current-prelude-env (hasheq)] [current-module-definitions-content (hasheq)]
                 [current-ns-context #f] [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)] [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)] [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry] [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)] [current-spec-store (hasheq)])
    (install-module-loader!) (process-string preamble)
    (values (current-prelude-env) (current-ns-context) (current-module-registry)
            (current-trait-registry) (current-impl-registry) (current-param-impl-registry)
            (current-ctor-registry) (current-type-meta))))

(define (run s)
  (parameterize ([current-prelude-env env] [current-ns-context nsc]
                 [current-module-registry mr] [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry tr] [current-impl-registry ir]
                 [current-param-impl-registry pir] [current-ctor-registry cr] [current-type-meta tm])
    (process-string s)))

(printf "PRELUDE LOADED~n")
(flush-output)

(define BYTES "<10'op:deliver<11'desc:export0+>5\"hello<11'desc:answer7+>f>")

(define (timeit label thunk)
  (define start (current-inexact-milliseconds))
  (define r (thunk))
  (define elapsed (- (current-inexact-milliseconds) start))
  (printf "~a: ~ams~n" label (real->decimal-string elapsed 0))
  (flush-output)
  r)

(test-case "perf/decode-op alone"
  ;; This test EXISTS to measure pitfall #31. We expect decode-op
  ;; on a ~50-byte op:deliver to take well under 100ms in a sane
  ;; world; it currently takes ~150,000ms (150s). The test is a
  ;; PERF GUARD, not a regression check — we record the timing in
  ;; stdout so a future fix can be measured against this baseline.
  (printf "TEST 1 start~n") (flush-output)
  (define result
    (timeit "decode-op alone (BYTES len = 50)"
      (lambda () (last (run (format "(eval (decode-op ~s))" BYTES))))))
  (printf "  result (truncated): ~a~n"
          (substring result 0 (min 80 (string-length result))))
  (flush-output)
  (check-pred string? result)
  ;; Result must be a successful decode (not a "none" wrapped in Option):
  (check-true (regexp-match? #rx"some.*op-deliver" result)
              "decode-op should produce Some op-deliver"))
