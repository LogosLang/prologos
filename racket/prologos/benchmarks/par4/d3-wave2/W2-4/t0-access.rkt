#lang racket/base
;; W2-4 t0: can a probe reach propagator.rkt internals (stratum-handlers box) through module->namespace,
;; with the repository's compiled .zo (no rebuild)?
(define R "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/")
(define prop-path (string->path (string-append R "propagator.rkt")))
(dynamic-require prop-path #f)
(define ns (module->namespace prop-path))
(define sh (eval 'stratum-handlers ns))
(printf "stratum-handlers box? ~a, entries ~a\n" (box? sh) (length (unbox sh)))
(for ([e (in-list (unbox sh))]) (printf "  cell ~a tier ~a\n" (car e) (caddr e)))
(dynamic-require (string->path (string-append R "driver.rkt")) #f)
(printf "after driver load: entries ~a\n" (length (unbox sh)))
(for ([e (in-list (unbox sh))]) (printf "  cell ~a tier ~a fn ~a\n" (car e) (caddr e) (cadr e)))
