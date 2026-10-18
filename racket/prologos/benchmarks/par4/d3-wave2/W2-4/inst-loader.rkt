#lang racket/base
;; W2-4 inst-loader: declare the instrumented scratch copy of propagator.rkt under the ORIGINAL module name,
;; before anything else loads it, so every compiled (.zo) dependent links against the instrumented instance.
;; Nothing is written to disk. Usage: (require (file ".../inst-loader.rkt")) FIRST, then dynamic-require driver.
(provide R prop-path inst-loaded?)
(define R "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/")
(define prop-path (simplify-path (string->path (string-append R "propagator.rkt"))))
(define inst-path "/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-4/inst/propagator.rkt")
(define inst-loaded? (and (getenv "W24_INST") #t))
(when inst-loaded?
  (define t0 (current-inexact-milliseconds))
  (parameterize ([current-module-declare-name (make-resolved-module-path prop-path)]
                 [read-accept-reader #t] [read-accept-lang #t])
    ((current-load) inst-path 'propagator))
  (eprintf "W24: instrumented propagator.rkt declared in ~a ms\n" (round (- (current-inexact-milliseconds) t0))))
