#lang racket/base

;;;
;;; test-io-path-01.rkt — Path and IOError type tests
;;;
;;; Phase IO-A2: Tests for pure Prologos library types path.prologos and io-error.prologos.
;;; Verifies data construction, accessors, pattern matching, and type inference.
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
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
;; Shared Fixture (modules loaded once)
;; ========================================
;;
;; NOTE: This fixture captures current-ctor-registry and current-type-meta
;; because the Path and IOError data declarations register constructors
;; in the ctor registry during loading. Without capturing, the ctor
;; registrations are lost when the parameterize block exits, causing
;; match/reduce to fail (it can't look up constructor metadata).

(define shared-preamble
  (string-append
   "(ns test-io-path)\n"
   "(require [prologos::data::path :refer [path path-str path-join mk-path]])\n"
   "(require [prologos::data::io-error :refer [file-not-found permission-denied is-directory already-exists not-a-file io-failed]])"))

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-capability-reg
                shared-ctor-reg
                shared-type-meta)
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
                 [current-spec-store (hasheq)]
                 [current-capability-registry (hasheq)])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-capability-registry)
            (current-ctor-registry)
            (current-type-meta))))

(define (run s)
  (parameterize ([current-global-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-capability-registry shared-capability-reg]
                 [current-ctor-registry shared-ctor-reg]
                 [current-type-meta shared-type-meta])
    (process-string s)))

(define (run-last s) (last (run s)))

;; ========================================
;; Path — constructor and accessor
;; ========================================

(test-case "path/constructor-accessor-round-trip"
  ;; path wraps a String; path-str extracts it
  (define result (run-last "(path-str (path \"hello\"))"))
  (check-true (string-contains? result "\"hello\""))
  (check-true (string-contains? result "String")))

(test-case "path/empty-string"
  ;; Edge case: empty string path
  (define result (run-last "(path-str (path \"\"))"))
  (check-true (string-contains? result "String")))

(test-case "path/nested-path"
  ;; Path with directory separators
  (define result (run-last "(path-str (path \"/usr/local/bin\"))"))
  (check-true (string-contains? result "/usr/local/bin")))

;; ========================================
;; Path — path-join
;; ========================================

(test-case "path/join-two-paths"
  ;; path-join concatenates with "/" separator
  (define result (run-last "(path-str (path-join (path \"a\") (path \"b\")))"))
  (check-true (string-contains? result "a/b")))

(test-case "path/join-directory-file"
  ;; Join a directory path with a filename
  (define result (run-last "(path-str (path-join (path \"/home/user\") (path \"file.txt\")))"))
  (check-true (string-contains? result "/home/user/file.txt")))

;; ========================================
;; Path — construction produces correct type
;; ========================================

(test-case "path/constructor-produces-path-value"
  ;; (path "x") should produce a value containing mk-path
  (define result (run-last "(path \"test\")"))
  (check-true (string-contains? result "mk-path"))
  (check-true (string-contains? result "Path")))

;; ========================================
;; IOError — constructors produce correct types
;; ========================================

(test-case "io-error/file-not-found-type"
  ;; file-not-found should have type IOError
  (define result (run-last "(infer (file-not-found \"missing.txt\"))"))
  (check-true (string-contains? result "IOError")))

(test-case "io-error/permission-denied-type"
  (define result (run-last "(infer (permission-denied \"/etc/shadow\"))"))
  (check-true (string-contains? result "IOError")))

(test-case "io-error/is-directory-type"
  (define result (run-last "(infer (is-directory \"/tmp\"))"))
  (check-true (string-contains? result "IOError")))

(test-case "io-error/already-exists-type"
  (define result (run-last "(infer (already-exists \"/tmp/foo\"))"))
  (check-true (string-contains? result "IOError")))

(test-case "io-error/not-a-file-type"
  (define result (run-last "(infer (not-a-file \"/dev/null\"))"))
  (check-true (string-contains? result "IOError")))

(test-case "io-error/io-failed-type"
  (define result (run-last "(infer (io-failed \"disk full\"))"))
  (check-true (string-contains? result "IOError")))

;; ========================================
;; Type inference
;; ========================================

(test-case "path/type-inference"
  ;; (path "x") should have type Path
  (define result (run-last "(infer (path \"x\"))"))
  (check-true (string? result))
  (check-true (string-contains? result "Path")))

(test-case "path/path-str-type-inference"
  ;; path-str should have type Path -> String
  (define result (run-last "(infer path-str)"))
  (check-true (string? result))
  (check-true (string-contains? result "Path"))
  (check-true (string-contains? result "String")))
