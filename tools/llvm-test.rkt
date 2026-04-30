#lang racket/base

;; llvm-test.rkt — Run all .prologos files in a directory through the
;; LLVM lowering pipeline and assert their `;; :expect-exit N` directives.
;;
;; Usage:
;;   racket tools/llvm-test.rkt --tier 0 racket/prologos/examples/llvm/tier0
;;
;; Each .prologos file in the directory is lowered, linked via clang, run,
;; and its exit code compared against the file's `:expect-exit` directive.
;; A file with no directive fails fast.

(require racket/cmdline
         racket/file
         racket/system
         racket/path
         racket/string
         racket/port
         racket/runtime-path)

(define-runtime-path llvm-compile-script "llvm-compile.rkt")

(define tier-arg (make-parameter 0))

(define dir-path
  (command-line
   #:program "llvm-test"
   #:once-each
   [("--tier") n "Tier to set on lowering (0|1|2)."
               (tier-arg (string->number n))]
   #:args (dir)
   dir))

(define (parse-expect-exit path)
  ;; Find a `;; :expect-exit N` line. Return N, or #f if absent.
  (define content (file->string path))
  (define lines (string-split content "\n"))
  (let loop ([ls lines])
    (cond
      [(null? ls) #f]
      [else
       (define m (regexp-match #px";;\\s*:expect-exit\\s+(-?[0-9]+)" (car ls)))
       (if m
           (string->number (cadr m))
           (loop (cdr ls)))])))

(define (run-one file)
  (define expected (parse-expect-exit file))
  (unless expected
    (error 'llvm-test "no `;; :expect-exit N` directive in ~a" file))
  (printf ">> ~a (expect ~a) ... " file expected)
  (flush-output)
  ;; Each test gets a fresh subprocess to isolate global-env state.
  (define racket-exe (find-executable-path "racket"))
  (unless racket-exe
    (error 'llvm-test "racket not found on PATH"))
  (define driver-script llvm-compile-script)
  (define out-bin (make-temporary-file "prologos-llvm-~a"))
  (define logs (open-output-string))
  (define ok-link?
    (parameterize ([current-output-port logs]
                   [current-error-port logs]
                   [current-environment-variables
                    (let ([ev (environment-variables-copy
                               (current-environment-variables))])
                      (environment-variables-set! ev #"PROLOGOS_LLVM_TIER"
                       (string->bytes/utf-8 (number->string (tier-arg))))
                      ev)])
      (system* racket-exe driver-script
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
       [(= got expected)
        (printf "OK (exit=~a)\n" got)
        #t]
       [else
        (printf "FAIL (got exit=~a, expected ~a)\n" got expected)
        #f])]))

(define (run-all dir)
  (define files
    (sort (filter (lambda (p)
                    (regexp-match? #rx"\\.prologos$" (path->string p)))
                  (directory-list dir #:build? #t))
          (lambda (a b) (string<? (path->string a) (path->string b)))))
  (when (null? files)
    (error 'llvm-test "no .prologos files in ~a" dir))
  (printf "Running ~a tier-~a tests in ~a~n"
          (length files) (tier-arg) dir)
  (define results (map run-one files))
  (define passed (length (filter values results)))
  (define failed (- (length results) passed))
  (printf "~a passed, ~a failed~n" passed failed)
  (exit (if (zero? failed) 0 1)))

(run-all dir-path)
