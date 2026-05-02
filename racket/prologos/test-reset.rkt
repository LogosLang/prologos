#lang racket/base
(require "low-pnet-ir.rkt"
         "low-pnet-to-llvm.rkt"
         racket/system)
(define lp (parse-low-pnet
            '(low-pnet
              :version (1 1)
              (domain-decl 0 int kernel-merge-int 0 never)
              (cell-decl 0 0 0)
              (write-decl 0 73 0 reset)
              (entry-decl 0))))
(define ir (lower-low-pnet-to-llvm lp))
(call-with-output-file "/tmp/test-reset.ll" #:exists 'replace
  (lambda (p) (display ir p)))
(displayln "wrote /tmp/test-reset.ll")
