#lang racket/base
;; Load an arbitrary .prologos snippet file as a library module and report errors.
(require racket/list racket/string racket/port racket/file
         "test-support.rkt"
         "../macros.rkt" "../prelude.rkt" "../syntax.rkt" "../source-location.rkt"
         "../surface-syntax.rkt" "../errors.rkt" "../metavar-store.rkt"
         "../parser.rkt" "../elaborator.rkt" "../pretty-print.rkt"
         "../global-env.rkt" "../driver.rkt" "../namespace.rkt" "../multi-dispatch.rkt")

(define src (vector-ref (current-command-line-arguments) 0))
(define lib-ocapn (build-path prelude-lib-dir "prologos" "ocapn"))
(define tgt (build-path lib-ocapn "zzprobenl.prologos"))
(copy-file src tgt #t)

(define r
  (with-handlers ([(lambda (e) #t)
                   (lambda (e) (if (exn? e) (exn-message e) (format "~s" e)))])
    (parameterize ([current-file-module-network-ref (make-module-network)]
                   [current-ns-context #f]
                   [current-module-registry prelude-module-registry]
                   [current-lib-paths (list prelude-lib-dir)]
                   [current-preparse-registry prelude-preparse-registry]
                   [current-ctor-registry (current-ctor-registry)]
                   [current-type-meta (current-type-meta)]
                   [current-trait-registry prelude-trait-registry]
                   [current-impl-registry prelude-impl-registry]
                   [current-param-impl-registry prelude-param-impl-registry]
                   [current-multi-defn-registry (current-multi-defn-registry)]
                   [current-use-pnet-cache? #f]
                   [current-pnet-write-enabled? #f]
                   [current-spec-store (hasheq)])
      (install-module-loader!)
      (process-string "(ns zzprobetop)\n(imports (prologos::ocapn::zzprobenl :refer-all))\n"))
    #f))
(printf "RESULT: ~a\n" (or r "OK"))
(delete-file tgt)
