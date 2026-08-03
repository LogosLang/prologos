#lang racket/base

;;; test-reader-robustness.rkt — a reader failure must not cost the whole file.
;;;
;;; Everything the reader does happens BEFORE any command runs: `read-all-syntax-ws`
;;; tokenizes and groups the entire file up front. So a raise anywhere in it is
;;; a whole-file abort by construction — no results, no per-command error count,
;;; and (when it is a raw Racket contract violation) no source location either.
;;;
;;; That is the silence class the loud-tier work exists to prevent, sitting in
;;; the one place that runs first.

(require rackunit
         racket/list
         racket/file
         racket/string
         "test-support.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../macros.rkt"
         "../errors.rkt")

(define (run-file-lines src)
  (define f (make-prologos-temp-file))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file f #:exists 'truncate (lambda (o) (display src o)))
      (parameterize ([current-module-registry prelude-module-registry]
                     [current-lib-paths (list prelude-lib-dir)]
                     [current-preparse-registry prelude-preparse-registry]
                     [current-trait-registry prelude-trait-registry]
                     [current-impl-registry prelude-impl-registry]
                     [current-param-impl-registry prelude-param-impl-registry])
        (install-module-loader!)
        (process-file (path->string f))))
    (lambda () (with-handlers ([void void]) (delete-file f)))))

(test-case "reader/a bare top-level [] does not take the file with it"
  ;; It used to die inside the reader with
  ;;   >: contract violation  expected: real?  given: #f
  ;; and nothing else — every command in the file lost, including the ones
  ;; before it. The chain: a `'()` element gets a syntax object with line 0,
  ;; `make-stx` maps 0 to #f, and re-wrapping that element read the #f back and
  ;; compared it with `>`.
  ;;
  ;; What this pins is the FILE surviving. `[]` alone is not meaningful and is
  ;; entitled to be an error -- it just has to be one error, in one command.
  (define results (run-file-lines "ns rr\ndef a := 1\na\n[]\ndef b := 2\nb\n"))
  (check-true (list? results))
  (define text (string-join (map (lambda (r) (format "~a" r)) results) "\n"))
  (check-true (string-contains? text "a")
              (format "commands BEFORE the bad form were lost: ~v" results))
  (check-true (string-contains? text "b")
              (format "commands AFTER the bad form were lost: ~v" results)))

(test-case "reader/an empty bracket in a value position still means the empty list"
  ;; The fix must not have made `[]` unreadable where it was already fine.
  (define results (run-file-lines "ns rr2\ndef x := []\nx\n"))
  (check-true (list? results))
  (check-false (ormap prologos-error? results)
               (format "expected no errors, got: ~v" results)))

(test-case "reader/[] alone in a file is a per-command error, not an abort"
  (define results (run-file-lines "ns rr3\n[]\n"))
  (check-true (list? results))
  (check-true (>= (length results) 1)
              "an aborted file returns nothing at all"))
