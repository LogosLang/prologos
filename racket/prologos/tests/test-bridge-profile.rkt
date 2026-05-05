#lang racket/base
;;
;; Profile decode-value to identify the real bottleneck for pitfall #31.
;; Three negative-result interventions targeted cache lookup; none helped.
;; This profiles the actual hot path with profile-lib (Racket's profile
;; package) to identify where the time goes.
;;
;; Requires `raco pkg install profile-lib` if not already installed.
;; Listed in .skip-tests; run manually when investigating perf:
;;   racket tests/test-bridge-profile.rkt
;;

(require rackunit racket/list racket/string racket/profile
         "test-support.rkt"
         "../macros.rkt" "../prelude.rkt" "../syntax.rkt"
         "../source-location.rkt" "../surface-syntax.rkt"
         "../errors.rkt" "../metavar-store.rkt" "../parser.rkt"
         "../elaborator.rkt" "../pretty-print.rkt" "../global-env.rkt"
         "../driver.rkt" "../namespace.rkt" "../multi-dispatch.rkt")

(define preamble
  "(ns test-bridge-perf-profile)
(imports (prologos::ocapn::core :refer-all))
(imports (prologos::ocapn::syrup :refer-all))
(imports (prologos::ocapn::syrup-wire :refer-all))
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

(printf "PRELUDE LOADED~n") (flush-output)

;; N=3 is small enough to profile but should show super-linear effects.
(define ELEM "5\"hello")
(define BYTES (string-append "[" (apply string-append (build-list 3 (lambda (_) ELEM))) "]"))

(printf "BYTES (~a chars): ~s~n" (string-length BYTES) BYTES) (flush-output)

(profile-thunk
 (lambda ()
   (last (run (format "(eval (decode-value ~s))" BYTES))))
 #:order 'self
 #:delay 0.001)
