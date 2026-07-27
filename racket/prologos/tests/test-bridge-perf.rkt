#lang racket/base
;;
;; Diagnostic for goblin pitfall #31: scaling behavior of decode-op /
;; decode-value across input sizes. If timing is super-linear in
;; input length, the decoder has an algorithmic problem (likely
;; O(n²) from substitution-chain blowup or similar).
;;
;; Tests decode-value (the inner Syrup decoder, no CapTPOp wrapping)
;; on syrup-list inputs of varying length: 1, 5, 10, 20 elements.
;; Each list element is a 5-byte string `5"hello`. So:
;;   N=1:  '[5"hello]'              ≈  9 bytes
;;   N=5:  '[5"hello5"hello...]'    ≈ 37 bytes
;;   N=10: '[...×10]'                ≈ 72 bytes
;;   N=20: '[...×20]'                ≈ 142 bytes
;;
;; Linear:    times scale ~ N.
;; Quadratic: times scale ~ N². So 5x → 25x, 10x → 100x, 20x → 400x.

(require rackunit racket/list racket/string "test-support.rkt"
         "../macros.rkt" "../prelude.rkt" "../syntax.rkt"
         "../source-location.rkt" "../surface-syntax.rkt"
         "../errors.rkt" "../metavar-store.rkt" "../parser.rkt"
         "../elaborator.rkt" "../pretty-print.rkt" "../global-env.rkt"
         "../driver.rkt" "../namespace.rkt" "../multi-dispatch.rkt")

(define preamble
  "(ns test-bridge-perf)
(imports (prologos::ocapn::core :refer-all))
(imports (prologos::ocapn::message :refer-all))
(imports (prologos::ocapn::syrup :refer-all))
(imports (prologos::ocapn::syrup-wire :refer-all))
(imports (prologos::ocapn::captp-wire :refer-all))
(imports (prologos::data::option :refer (Option some none unwrap-or)))
")

(define-values (env nsc mr tr ir pir cr tm)
  (parameterize ([current-file-module-network-ref (make-module-network)]
                 [current-ns-context #f] [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)] [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)] [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry] [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)] [current-spec-store (hasheq)])
    (install-module-loader!) (process-string preamble)
    (values (current-file-module-network-ref) (current-ns-context) (current-module-registry)
            (current-trait-registry) (current-impl-registry) (current-param-impl-registry)
            (current-ctor-registry) (current-type-meta))))

(define (run s)
  (parameterize ([current-file-module-network-ref env] [current-ns-context nsc]
                 [current-module-registry mr] [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry tr] [current-impl-registry ir]
                 [current-param-impl-registry pir] [current-ctor-registry cr] [current-type-meta tm])
    (process-string s)))

(printf "PRELUDE LOADED~n") (flush-output)

(define (timeit label thunk)
  (define start (current-inexact-milliseconds))
  (define r (thunk))
  (define elapsed (- (current-inexact-milliseconds) start))
  (printf "  ~a: ~ams~n" label (real->decimal-string elapsed 0))
  (flush-output)
  r)

(define ELEM "5\"hello")  ;; 7-char Syrup-encoded string

(define (mk-list-bytes n)
  (string-append "[" (apply string-append (build-list n (lambda (_) ELEM))) "]"))

(define (decode-test n)
  (define bytes (mk-list-bytes n))
  (printf "TEST N=~a (input ~a bytes):~n" n (string-length bytes))
  (flush-output)
  (timeit (format "decode-value N=~a" n)
    (lambda () (last (run (format "(eval (decode-value ~s))" bytes))))))

(test-case "perf/decode-value scaling"
  (decode-test 1)
  (decode-test 5)
  (decode-test 10)
  (decode-test 20))
