#lang racket/base
(require racket/list racket/string
         "test-support.rkt"
         "../macros.rkt" "../prelude.rkt" "../syntax.rkt" "../source-location.rkt"
         "../surface-syntax.rkt" "../errors.rkt" "../metavar-store.rkt"
         "../parser.rkt" "../elaborator.rkt" "../pretty-print.rkt"
         "../global-env.rkt" "../driver.rkt" "../namespace.rkt" "../multi-dispatch.rkt")

(define mods (vector->list (current-command-line-arguments)))

(for ([m (in-list mods)])
  (with-handlers ([(lambda (e) #t)
                   (lambda (e)
                     (printf "~a => FAIL: ~a\n" m
                             (if (exn? e) (exn-message e) (format "~s" e))))])
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
                   [current-spec-store (hasheq)])
      (install-module-loader!)
      (process-string (format "(ns zzprobe)\n(imports (~a :refer-all))\n" m)))
    (printf "~a => OK\n" m)))
