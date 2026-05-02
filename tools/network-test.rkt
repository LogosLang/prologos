#lang racket/base

;; network-test.rkt — Run every .prologos in a directory through the
;; network-lowering pipeline, assert their `;; :expect-exit N` directives.
;;
;; Mirrors tools/llvm-test.rkt for the network-lowering path.

(require racket/cmdline
         racket/file
         racket/system
         racket/path
         racket/string
         racket/port
         racket/runtime-path)

(define-runtime-path network-compile-script "network-compile.rkt")

(define tier-arg (make-parameter 0))

(define dir-path
  (command-line
   #:program "network-test"
   #:once-each
   [("--tier") n "Tier to set on lowering (currently 0)."
               (tier-arg (string->number n))]
   #:args (dir)
   dir))

(define (parse-expect-exit path)
  (define content (file->string path))
  (define lines (string-split content "\n"))
  (let loop ([ls lines])
    (cond
      [(null? ls) #f]
      [else
       (define m (regexp-match #px";;\\s*:expect-exit\\s+(-?[0-9]+)" (car ls)))
       (if m (string->number (cadr m)) (loop (cdr ls)))])))

(define (run-one file)
  (define expected (parse-expect-exit file))
  (unless expected
    (error 'network-test "no `;; :expect-exit N` directive in ~a" file))
  (printf ">> ~a (expect ~a) ... " file expected)
  (flush-output)
  (define racket-exe (find-executable-path "racket"))
  (unless racket-exe
    (error 'network-test "racket not found on PATH"))
  (define out-bin (make-temporary-file "prologos-network-~a"))
  (define logs (open-output-string))
  (define ok-link?
    (parameterize ([current-output-port logs]
                   [current-error-port logs]
                   [current-environment-variables
                    (let ([ev (environment-variables-copy
                               (current-environment-variables))])
                      (environment-variables-set! ev #"PROLOGOS_NETWORK_TIER"
                       (string->bytes/utf-8 (number->string (tier-arg))))
                      ev)])
      (system* racket-exe network-compile-script
               "--no-run"
               "-o" (path->string out-bin)
               (path->string file))))
  (cond
    [(not ok-link?)
     (printf "LINK-FAIL\n~a\n" (get-output-string logs))
     (delete-file out-bin)
     #f]
    [else
     (define got (system*/exit-code out-bin))
     (delete-file out-bin)
     (cond
       [(= got expected) (printf "OK (exit=~a)\n" got) #t]
       [else (printf "FAIL (got exit=~a, expected ~a)\n" got expected) #f])]))

(define (run-all dir)
  (define files
    (sort (filter (lambda (p) (regexp-match? #rx"\\.prologos$" (path->string p)))
                  (directory-list dir #:build? #t))
          (lambda (a b) (string<? (path->string a) (path->string b)))))
  (when (null? files)
    (error 'network-test "no .prologos files in ~a" dir))
  (printf "Running ~a network-tier-~a tests in ~a~n"
          (length files) (tier-arg) dir)
  (define results (map run-one files))
  (define passed (length (filter values results)))
  (define failed (- (length results) passed))
  (printf "~a passed, ~a failed~n" passed failed)
  (exit (if (zero? failed) 0 1)))

(run-all dir-path)
