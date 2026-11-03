#lang racket/base
;; retire-dump.rkt — CIU 6 1b-vi close, item 3: the equivalence check for retiring the stage table.
;; Dumps test-path-selection.rkt's 1b-vi table as one line per row: id, spelling, and the
;; row's EFFECTIVE expectation, plus the parity law's domain (row ids) on the last line.
;;   racket retire-dump.rkt OUT old   — at a commit BEFORE 3f2db4ca (5-tuple rows:
;;                                      TARGET for a flipping row, PRE for a control;
;;                                      domain = the rows that flipped at D)
;;   racket retire-dump.rkt OUT new   — at 3f2db4ca or later (EXPECT; domain = `1bvi-parity-rows`)
;; Requiring the test module runs its tests (~15 s); their output is discarded.
;; Outputs: retire-table-before.txt (old, at 04e3c5c5 + a7dcde7d) and retire-table-after.txt
;; (new, at 3f2db4ca). Rows identical: 346 / 346; domain 81 ⊆ 113.
(module+ main
  (require racket/list racket/port)
  (define T '(file "../../../../../../../../racket/prologos/tests/test-path-selection.rkt"))
  (define out (vector-ref (current-command-line-arguments) 0))
  (define mode (vector-ref (current-command-line-arguments) 1))
  (parameterize ([current-namespace (make-base-namespace)])
    (parameterize ([current-output-port (open-output-nowhere)]
                   [current-error-port (open-output-nowhere)])
      (namespace-require T))
    (define ns (module->namespace T))
    (define (ev e) (eval e ns))
    (define rows (ev '1bvi-all-rows))
    (with-output-to-file out #:exists 'truncate
      (lambda ()
        (for ([r (in-list rows)])
          (if (equal? mode "old")
              (let ([fl (list-ref r 2)])
                (printf "~s ~s ~s\n" (list-ref r 0) (list-ref r 1) (if fl (list-ref r 4) (list-ref r 3))))
              (printf "~s ~s ~s\n" (list-ref r 0) (list-ref r 1) (list-ref r 2))))
        (printf "PARITY ~s\n"
                (map (lambda (r) (list-ref r 0))
                     (if (equal? mode "old")
                         (filter (ev '1bvi-injectable?) rows)
                         (ev '(1bvi-parity-rows)))))))))
