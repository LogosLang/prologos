#lang racket/base
(require rackunit
         racket/list
         racket/path
         racket/string
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../multi-dispatch.rkt")

(define (run-ns s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string s)))

(define (run-file path)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-file path)))

(define (run-ns-last s)
  (last (run-ns s)))

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

(define preamble "(ns foo)\n")

;; Test: PVec literal @[1 2 3] works (needs type annotation for inference)
(test-case "syntax/pvec-literal"
  (define result (run-ns-last (string-append preamble
    "(def v : (PVec Nat) @[1N 2N 3N])
     (eval v)")))
  (check-contains result "PVec"))

;; Test: LSeq literal ~[1 2 3] works
(test-case "syntax/lseq-literal"
  (define result (run-ns-last (string-append preamble
    "(eval ~[1N 2N 3N])")))
  (check-contains result "LSeq"))

;; Test: Map literal {:name 42} works (needs type annotation for inference)
(test-case "syntax/map-literal"
  (define result (run-ns-last (string-append preamble
    "(def m : (Map Keyword Nat) {:name 42N})
     (eval m)")))
  (check-contains result "Map"))

;; Test: Approx literal ~1.5 works (Posit32)
(test-case "syntax/approx-literal"
  (define result (run-ns-last (string-append preamble
    "(infer ~1.5)")))
  (check-contains result "Posit32"))

;; Test: List literal '[1 2 3] works
(test-case "syntax/list-literal"
  (define result (run-ns-last (string-append preamble
    "(eval '[1N 2N 3N])")))
  (check-contains result "List"))
