#lang racket/base
;; CIU 6 P4e-2 mini-audit (RA-1, RA-2, RA-6, RA-7): what the reader + preparse build for every spelling the slice
;; touches, and what `parse-datum` makes of it. One block per spelling: the source, PRE (the datum after
;; preparse-expand-all), PAR (the parser's result, srclocs kept so glued vs spaced is visible).
;; Run:  racket reader-dump.rkt   (writes reader-dump.out beside this file)
(require racket/runtime-path)
(define-runtime-path out-path "reader-dump.out")
(module+ main
  (require (file "../../../../../../../racket/prologos/parse-reader.rkt") (file "../../../../../../../racket/prologos/macros.rkt") (file "../../../../../../../racket/prologos/parser.rkt"))
  (define srcs
    '("values:*" "values:*_" "values:*-" "values:*-_" "values:*:*" "values:*:name" "values.0:*" "values:k*" "values:k*_" "values:k*-" "values:k*-_" "values:k:*" "values:k*:name" "values:k*.0" "values:k*{a b}" "values:k**" "values:k*^" "values:k*x" "values:*.0" "values:*{a b}" "values:**:name" "values:*-_:k" "values{a:*}" "values{a:k*}" "y{a.0:*}" "values.a:*" "values{a}:*" "values{a}:k*" "x.y:*" "(values):*" "[f x]:*" "[f values:*]" "values:* x" "values.*" "values.*name" "values.*:name" "x.*{a}" "values.**" "values.**:name" "values: *" "values :*" "values :k" "values:**" "values:.*" "values:" "values*" "values:*->" "values:*.*" "vhm.0*" "vhm.0*_" "y.a.0*" "y.a.0*-" "y{a.0*}" "vhm{0*}" "vv:0*" "vhm.0:*" "vv:0:*" "y.a.0:*" "#p(a.*)" "#p(a.**)" "#p(a:*)" "{:* 1}" ":*" "values:name" "values:{a b}" "values:0" "values{a b}*" "values{0 1}*"))
  (with-output-to-file out-path #:exists 'truncate
    (lambda ()
      (for ([src (in-list srcs)])
        (define r
          (with-handlers ([exn:fail? (lambda (e) (list (list 'READ-RAISE (exn-message e)) '()))])
            (define stxs (prologos-read-syntax-all "<p>" (open-input-string (string-append src "\n"))))
            (define pp (preparse-expand-all stxs))
            (list (map (lambda (x) (if (syntax? x) (syntax->datum x) x)) pp)
                  (for/list ([x (in-list pp)])
                    (with-handlers ([exn:fail? (lambda (e) (list 'PARSE-RAISE (exn-message e)))])
                      (format "~s" (parse-datum (if (syntax? x) x (datum->syntax #f x)))))))))
        (printf "~a\n  PRE  ~s\n  PAR  ~a\n" src (car r) (cadr r))))))
