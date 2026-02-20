#lang info

;; These files are example #lang prologos programs, not test suites.
;; They are exercised by ../test-lang-*.rkt and ../test-lang-errors-*.rkt.
;; Some (type-error.rkt, unbound-var.rkt) intentionally raise errors.
(define test-omit-paths '("hello.rkt"
                          "identity.rkt"
                          "vectors.rkt"
                          "pairs.rkt"
                          "type-error.rkt"
                          "unbound-var.rkt"
                          "hello-ws.rkt"
                          "identity-ws.rkt"
                          "vectors-ws.rkt"
                          "pairs-ws.rkt"
                          "type-error-ws.rkt"
                          "unbound-var-ws.rkt"))
