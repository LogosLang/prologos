#lang racket/base
;; CIU 6 1b-vi verify, finding VI-10 (lens VI), re-run on the main thread: can the star
;; arrival instrument tell a ONE-token `*-` from `*` followed by `-`? (DEFERRED 180)
;; Writes its measurement to v9-arrival.out beside this file (stdout stays clean for the
;; pre-commit hook's check-stdout-clean).
(require racket/runtime-path
         (file "../../../../../../../../racket/prologos/tools/star-arrival-matrix.rkt"))
(define-runtime-path out "v9-arrival.out")
(with-output-to-file out #:exists 'truncate
  (lambda ()
    (for ([src (in-list '("c{a}*-\n" "c{a}* -\n" "c{a}*-_\n" "c{a}* -_\n" "c{a}*\n"))])
      (printf "~s => last-star-type ~s  mints? ~s\n" src (star-last-token-type src) (star-mints? src)))))
