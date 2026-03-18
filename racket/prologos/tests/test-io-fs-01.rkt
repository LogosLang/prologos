#lang racket/base

;;;
;;; test-io-fs-01.rkt — Filesystem query function tests
;;;
;;; Phase IO-D4: Tests for exists?, file?, dir? from
;;; lib/prologos/io/fs.prologos.
;;;
;;; Pattern: Shared fixture with process-string, temp files/directories.
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         racket/file
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../multi-dispatch.rkt")

;; ========================================
;; Shared Fixture (fs module loaded once)
;; ========================================

(define shared-preamble
  "(ns test-fs)
(imports (prologos::io::fs :refer (exists? file? dir?)))")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry))))

(define (run s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg])
    (process-string s)))

(define (run-last s) (last (run s)))

;; ========================================
;; Tests
;; ========================================

(test-case "exists?: true for existing file"
  (define tmp (make-temporary-file))
  (check-equal?
    (run-last (format "(exists? ~s)" (path->string tmp)))
    "true : Bool")
  (delete-file tmp))

(test-case "exists?: false for nonexistent"
  (check-equal?
    (run-last "(exists? \"/nonexistent/path/bogus.txt\")")
    "false : Bool"))

(test-case "exists?: true for directory"
  (define tmp-dir (make-temporary-directory))
  (check-equal?
    (run-last (format "(exists? ~s)" (path->string tmp-dir)))
    "true : Bool")
  (delete-directory tmp-dir))

(test-case "file?: true for regular file"
  (define tmp (make-temporary-file))
  (check-equal?
    (run-last (format "(file? ~s)" (path->string tmp)))
    "true : Bool")
  (delete-file tmp))

(test-case "file?: false for directory"
  (define tmp-dir (make-temporary-directory))
  (check-equal?
    (run-last (format "(file? ~s)" (path->string tmp-dir)))
    "false : Bool")
  (delete-directory tmp-dir))

(test-case "dir?: true for directory"
  (define tmp-dir (make-temporary-directory))
  (check-equal?
    (run-last (format "(dir? ~s)" (path->string tmp-dir)))
    "true : Bool")
  (delete-directory tmp-dir))

(test-case "dir?: false for file"
  (define tmp (make-temporary-file))
  (check-equal?
    (run-last (format "(dir? ~s)" (path->string tmp)))
    "false : Bool")
  (delete-file tmp))
