#lang racket/base

;;; Regression test for source-file-relative resource path resolution.
;;;
;;; A .prologos program's relative `read-file` path must resolve against the
;;; SOURCE FILE's directory (location-independent), NOT the ambient process CWD.
;;; Before the 2026-06-29 fix, `read-file` fell through to Racket's
;;; `current-directory`, so the same program worked under run-file.rkt (cwd =
;;; repo root) but doubled the path under the LSP/REPL (cwd = the file's dir).
;;; See driver.rkt `process-file` (#:source-dir + current-directory anchor).

(require rackunit
         racket/file
         (only-in "../driver.rkt" process-file)
         (only-in "../errors.rkt" prologos-error? prologos-error-message))

(define (results->string results)
  (apply string-append
         (for/list ([r (in-list (or results '()))])
           (cond
             [(prologos-error? r) (format "ERR:~a; " (prologos-error-message r))]
             [(string? r)         (string-append r "; ")]
             [else                (format "~a; " r)]))))

(test-case "read-file resolves a relative path against the source file's dir, not cwd"
  (define src-dir (make-temporary-file "prologos-relpath-~a" 'directory))
  (dynamic-wind
   void
   (lambda ()
     ;; A sibling resource next to the program.
     (call-with-output-file (build-path src-dir "greeting.txt")
       (lambda (o) (display "HELLO_FROM_SIBLING" o))
       #:exists 'replace)
     ;; A program that reads the sibling via a RELATIVE path.
     (define prog (build-path src-dir "reader.prologos"))
     (call-with-output-file prog
       (lambda (o)
         (display "ns relpath-test\n" o)
         (display "require [prologos::core::io :refer [read-file]]\n" o)
         (display "read-file \"greeting.txt\"\n" o))
       #:exists 'replace)
     ;; Run from a DIFFERENT cwd (the system temp root) where greeting.txt does
     ;; NOT exist. Without source-file anchoring this resolves against cwd and
     ;; fails ("cannot open input file"); with the fix it resolves against src-dir.
     (define other-cwd (find-system-path 'temp-dir))
     (define results
       (parameterize ([current-directory other-cwd])
         (process-file prog)))
     (define joined (results->string results))
     (check-true (regexp-match? #rx"HELLO_FROM_SIBLING" joined)
                 (format "expected sibling content (source-file-relative resolution); got: ~a"
                         joined)))
   (lambda () (delete-directory/files src-dir))))
