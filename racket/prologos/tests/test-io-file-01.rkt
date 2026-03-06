#lang racket/base

;;;
;;; test-io-file-01.rkt — File IO convenience function tests
;;;
;;; Phase IO-D1: Tests for read-file, write-file, append-file from
;;; lib/prologos/core/io.prologos via foreign racket "io-ffi.rkt".
;;;
;;; Pattern: Shared fixture with process-string, temp files for IO tests.
;;; process-string returns formatted strings like "\"content\" : String"
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         racket/file
         racket/port
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
;; Shared Fixture (io module loaded once)
;; ========================================

(define shared-preamble
  "(ns test-io)
(imports (prologos::core::io :refer (read-file write-file append-file)))")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg)
  (parameterize ([current-global-env (hasheq)]
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
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry))))

(define (run s)
  (parameterize ([current-global-env shared-global-env]
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
;; Group 1: read-file
;; ========================================

(test-case "read-file: reads file contents"
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "hello from IO-D" out))
    #:exists 'truncate/replace)
  (define result (run-last (format "(read-file ~s)" (path->string tmp))))
  (check-equal? result "\"hello from IO-D\" : String")
  (delete-file tmp))

(test-case "read-file: empty file"
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (void))
    #:exists 'truncate/replace)
  (define result (run-last (format "(read-file ~s)" (path->string tmp))))
  (check-equal? result "\"\" : String")
  (delete-file tmp))

(test-case "read-file: multi-line content"
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "line1\nline2\nline3" out))
    #:exists 'truncate/replace)
  (define result (run-last (format "(read-file ~s)" (path->string tmp))))
  ;; pp-expr escapes newlines in string output
  (check-true (string-contains? result "line1") "should contain line1")
  (check-true (string-contains? result ": String") "should have String type")
  (delete-file tmp))

(test-case "read-file: nonexistent file raises error"
  (check-exn
    exn:fail?
    (lambda ()
      (run-last "(read-file \"/nonexistent/path/no-such-file.txt\")"))))

;; ========================================
;; Group 2: write-file
;; ========================================

(test-case "write-file: creates and writes"
  (define tmp (make-temporary-file))
  (run-last (format "(write-file ~s \"written by prologos\")" (path->string tmp)))
  (check-equal? (file->string (path->string tmp)) "written by prologos")
  (delete-file tmp))

(test-case "write-file: overwrites existing"
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "old content" out))
    #:exists 'truncate/replace)
  (run-last (format "(write-file ~s \"new content\")" (path->string tmp)))
  (check-equal? (file->string (path->string tmp)) "new content")
  (delete-file tmp))

;; ========================================
;; Group 3: append-file
;; ========================================

(test-case "append-file: appends to existing"
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "first " out))
    #:exists 'truncate/replace)
  (run-last (format "(append-file ~s \"second\")" (path->string tmp)))
  (check-equal? (file->string (path->string tmp)) "first second")
  (delete-file tmp))

(test-case "append-file: creates if not exists"
  (define tmp (make-temporary-file))
  (delete-file tmp)  ;; remove so append-file creates it
  (run-last (format "(append-file ~s \"created by append\")" (path->string tmp)))
  (check-equal? (file->string (path->string tmp)) "created by append")
  (delete-file tmp))
