#lang racket/base

;;; test-redex-model.rkt — run the Redex model from the ordinary suite.
;;;
;;; The model in `redex/` is the project's SPEC, and until 2026-08-03 nothing
;;; ran it. Three independent reasons, all silent:
;;;
;;;   - `tools/run-affected-tests.rkt` discovers tests by scanning `tests/`
;;;     only (`--all` reads `(directory-list tests-dir)`), so `redex/tests/`
;;;     was never in the set.
;;;   - no workflow mentions redex — `grep -rn redex .github/workflows/` is
;;;     empty.
;;;   - the `redex` package was not even installed in the dev container.
;;;
;;; So the spec could have drifted arbitrarily far from the kernel with a green
;;; suite the whole time. That is worse than a spec-unbacked rule: it is an
;;; oracle nobody consults. This file closes the first two by putting the model
;;; where the runner already looks.
;;;
;;; ⚠ WHAT THIS FILE DOES NOT DO. If the `redex` package is absent it SKIPS,
;;; loudly, rather than failing — making it mandatory would put a package on
;;; every contributor's machine, which is a dependency decision and the owner's
;;; to make. So a green suite still does not PROVE the model was checked. The
;;; skip prints a banner naming the install command; the honest fix (pin redex
;;; as a project dependency, or install it in CI) is filed in DEFERRED.md.
;;;
;;; Failure detection is by OUTPUT, not by exception. Redex's `test-equal`
;;; RECORDS a mismatch and `test-results` PRINTS the tally — neither raises, so
;;; `raco test` exits 0 on a model that fails every case. The observed strings
;;; are "All N tests passed." on success and "N test(s) failed (out of M
;;; total)." on failure, so this asserts the success shape rather than the
;;; absence of a raise.

(require rackunit
         racket/port
         racket/list
         racket/runtime-path
         racket/path)

(define-runtime-path redex-tests-dir "../redex/tests")

(define redex-available?
  (with-handlers ([(lambda (_) #t) (lambda (_) #f)])
    (dynamic-require 'redex/reduction-semantics #f)
    #t))

(define model-files
  (if (directory-exists? redex-tests-dir)
      (sort (for/list ([p (in-list (directory-list redex-tests-dir))]
                       #:when (let ([s (path->string p)])
                                (and (regexp-match? #rx"^test-" s)
                                     (regexp-match? #rx"[.]rkt$" s))))
              (build-path redex-tests-dir p))
            string<? #:key path->string)
      '()))

;; Run one model file, returning its printed tally.
(define (run-model-file path)
  (define out (open-output-string))
  (define err (open-output-string))
  (define exn
    (with-handlers ([(lambda (_) #t) (lambda (e) e)])
      (parameterize ([current-output-port out] [current-error-port err])
        (dynamic-require path #f))
      #f))
  (values (get-output-string out) (get-output-string err) exn))

(cond
  [(not redex-available?)
   (eprintf (string-append
             "\n"
             "  ┌───────────────────────────────────────────────────────────┐\n"
             "  │ REDEX MODEL NOT CHECKED — the `redex` package is absent.  │\n"
             "  │ The spec in redex/ was NOT run. Install it with:          │\n"
             "  │     raco pkg install --auto redex                         │\n"
             "  └───────────────────────────────────────────────────────────┘\n\n"))
   ;; Deliberately not a failing check — see the header. The banner is the
   ;; signal; this case exists so the skip is a recorded outcome rather than an
   ;; empty file that looks like coverage.
   (test-case "redex-model/SKIPPED — the redex package is not installed"
     (check-false redex-available?
                  "unreachable: this branch only runs when redex is absent"))]

  [else
   (test-case "redex-model/the model directory was found and is not empty"
     ;; Without this the file passes vacuously if the path ever moves — which
     ;; is the same class of silence this whole file exists to remove.
     (check-true (>= (length model-files) 5)
                 (format "expected the 5 model test files, found: ~v"
                         (map path->string model-files))))

   (for ([f (in-list model-files)])
     (define name (path->string (file-name-from-path f)))
     (test-case (format "redex-model/~a" name)
       (define-values (out err exn) (run-model-file f))
       (check-false exn (format "~a raised: ~a" name
                                (if (exn? exn) (exn-message exn) exn)))
       ;; The success shape, not the absence of a raise: redex records
       ;; mismatches and prints a tally rather than throwing.
       (check-true (regexp-match? #rx"^All [0-9]+ tests passed\\.\n?$" out)
                   (format "~a did not report all-passed.\n  stdout: ~s\n  stderr: ~s"
                           name out err))))])
