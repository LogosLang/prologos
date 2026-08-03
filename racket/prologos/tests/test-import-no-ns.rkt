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

(test-case "imports/a file with no `ns` gives a named error, not a contract violation"
  (define msg (import-book))
  (check-false (string-contains? msg "ns-context-refer-map")
               (format "still the raw struct-accessor crash: ~a" msg))
  (check-true (string-contains? msg "no namespace is in scope")
              (format "got: ~a" msg))
  ;; The message must blame the IMPORTER, not the imported module — an earlier
  ;; draft blamed the module, and the first one to trip it has an `ns` on line 1.
  (check-true (string-contains? msg "IMPORTING file")
              (format "the message misattributes the fault: ~a" msg)))
