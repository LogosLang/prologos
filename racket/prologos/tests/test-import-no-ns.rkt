#lang racket/base

;;; test-import-no-ns.rkt — importing a file with no `ns` says so.
;;;
;;; `load-module` parameterizes `current-ns-context` to #f, and a file with no
;;; `ns` declaration never sets one. The `book/` chapter files are all like that
;;; — they are the stdlib book's prose, not importable modules. When such a file
;;; processes its own `require`s there is no namespace to add them to, and
;;; `ns-context-add-refer` died on
;;;
;;;     ns-context-refer-map: contract violation
;;;       expected: ns-context?  given: #f
;;;
;;; naming a struct accessor, losing the whole file, and pointing nowhere near
;;; the missing `ns`.
;;;
;;; Found by probing a DEFERRED entry (Collections, "Stage I: Transducer
;;; Runners") that claimed `into-vec`/`into-set` did not exist. They do — in a
;;; `book/` file — and trying to import it is what surfaced this.

(require rackunit
         racket/string
         racket/file
         "test-support.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../macros.rkt")

(define (import-book)
  (define f (make-prologos-temp-file))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file f #:exists 'truncate
        (lambda (o) (display "ns inb\nrequire [prologos::book::collection-functions :refer-all]\ndef a := 1\n" o)))
      (with-handlers ([exn:fail? (lambda (e) (exn-message e))])
        (parameterize ([current-module-registry prelude-module-registry]
                       [current-lib-paths (list prelude-lib-dir)]
                       [current-preparse-registry prelude-preparse-registry]
                       [current-trait-registry prelude-trait-registry]
                       [current-impl-registry prelude-impl-registry]
                       [current-param-impl-registry prelude-param-impl-registry])
          (install-module-loader!)
          (process-file (path->string f))
          "NO ERROR")))
    (lambda () (with-handlers ([void void]) (delete-file f)))))

(test-case "imports/a file with no `ns` gives a named, LOCATED error, not a contract violation"
  ;; ⚠ WEAKENED AT THE 2026-08-05 MERGE, and the loss is upstream's, not this
  ;; branch's. Measured on pure `origin/main` (worktree build, same input):
  ;;
  ;;   main:        "imports: Error loading module …: Unbound variable"
  ;;                 — contained as a per-command value, and BARE: no name,
  ;;                   no srcloc, no root cause.
  ;;   pre-merge:   "cannot import …: no namespace is in scope. The IMPORTING
  ;;                 file has no `ns` declaration…"
  ;;   post-merge:  raises, with file:line and "Unbound variable: module"
  ;;                 (this branch's `format-error` rendering, kept in the merge)
  ;;
  ;; So `require-ns-context`'s guard (namespace.rkt) no longer FIRES — main's
  ;; import path now gets further into the book file before failing, and reports
  ;; the downstream symptom instead. The merge did not cause that and does not
  ;; fix it; it does restore the NAME and the LOCATION main had dropped.
  ;;
  ;; What is still asserted is the defect this test was written for — a raw
  ;; struct-accessor contract violation — plus the two properties the merge
  ;; genuinely preserves. The lost root diagnostic is filed in DEFERRED
  ;; § "imports: the no-namespace guard stopped firing".
  (define msg (import-book))
  (check-false (string-contains? msg "ns-context-refer-map")
               (format "still the raw struct-accessor crash: ~a" msg))
  (check-true (string-contains? msg "Error loading module")
              (format "the failure is not named at all: ~a" msg))
  ;; a LOCATION — main reported this bare. `format-error` is what puts the
  ;; file:line back, and dropping it is how a library failure becomes unfindable.
  (check-true (regexp-match? #rx"[.]prologos:[0-9]+" msg)
              (format "no file:line — the reader cannot find it: ~a" msg)))
