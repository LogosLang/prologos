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

(test-case "imports/importing a book CHAPTER explains what a chapter is"
  ;; ⚠ THE ENTRY THIS TEST WAS FILED UNDER WAS WRONG, and the correction is the
  ;; point. It was filed as "the no-namespace guard stopped firing" — a
  ;; regression from the 2026-08-05 merge. The guard did not stop firing.
  ;;
  ;; `book/collection-functions.prologos` has TWO problems, and which one you
  ;; see depends on error-surf handling:
  ;;
  ;;   line 28  `module prologos::core::collections`  ← not a Prologos form at
  ;;            all; `module` is the literate-BOOK directive tangle-stdlib reads
  ;;   line 30  `(imports …)` with no `ns` in scope   ← the guard's case
  ;;
  ;; This branch's old code SKIPPED error surfs, so it passed over line 28 and
  ;; surfaced line 30's guard message. Main's shape REPORTS the first error
  ;; surf. Reporting the earlier error is the better shape — the old path was
  ;; skipping a real one — it just arrived bare.
  ;;
  ;; So the fix was not to restore the guard: it was to make line 28 say what
  ;; line 30 used to say, via the existing `unbound-op-hint-table`.
  (define msg (import-book))
  (check-false (string-contains? msg "ns-context-refer-map")
               (format "still the raw struct-accessor crash: ~a" msg))
  ;; named, and LOCATED — main reported this bare, with no file:line at all
  (check-true (string-contains? msg "Error loading module")
              (format "the failure is not named: ~a" msg))
  (check-true (regexp-match? #rx"[.]prologos:[0-9]+" msg)
              (format "no file:line — the reader cannot find it: ~a" msg))
  ;; …and it explains WHAT a book chapter is, which is the thing a reader who
  ;; imported one actually needs to know.
  (check-true (string-contains? msg "book-chapter directive")
              (format "the message does not explain the real problem: ~a" msg))
  (check-true (string-contains? msg "not importable modules")
              (format "the message does not say chapters are not modules: ~a" msg)))
