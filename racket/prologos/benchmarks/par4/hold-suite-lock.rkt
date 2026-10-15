#lang racket/base
;; hold-suite-lock.rkt <path/to/suite-lock.rkt> <cmd> <arg> ... — run one command while holding the
;; machine-wide suite lock EXCLUSIVELY (the contract bench-ab.rkt uses for timing runs), so no suite
;; starts mid-measurement; waits for current holders first. Exit status = the command's.
(require racket/system racket/list racket/string)
(define args (vector->list (current-command-line-arguments)))
(define sl (list 'file (first args)))
(define cwsl (dynamic-require sl 'call-with-suite-lock))
(define lock-path ((dynamic-require sl 'suite-lock-path)))
(for ([l ((dynamic-require sl 'suite-lock-banner) 'exclusive lock-path)]) (printf "~a\n" l))
(define code
  (cwsl 'exclusive
        (λ () (let* ([exe (second args)]
                     [exe-path (if (absolute-path? exe) exe (or (find-executable-path exe) exe))])
                (apply system*/exit-code exe-path (cddr args))))
        #:path lock-path
        #:command (string-join (cons "hold-suite-lock" (rest args)) " ")
        #:on-wait ((dynamic-require sl 'make-wait-reporter) 'exclusive lock-path)))
(exit code)
