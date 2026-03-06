#lang racket/base

;;;
;;; test-io-csv-02.rkt — CSV module E2E tests (IO-G)
;;;
;;; End-to-end tests for prologos::core::csv module through the
;;; compilation pipeline: parse-csv, csv-to-string, read-csv, write-csv.
;;;
;;; Pattern: Shared fixture with process-string + prelude.
;;;

(require rackunit
         racket/list
         racket/string
         racket/file
         racket/path
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
;; Shared Fixture (csv module loaded once)
;; ========================================

(define shared-preamble
  (string-append
   "(ns test-csv)\n"
   "(imports (prologos::core::csv :refer [parse-csv csv-to-string read-csv write-csv]))\n"
   "(imports (prologos::core::io :refer [read-file write-file]))"))

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
;; Group 1: Module loading and type checking
;; ========================================

(test-case "csv-e2e/module-loads"
  ;; Verify the module loaded and functions are available
  (define result (run "(check parse-csv : (-> String (List (List String))))"))
  (check-true (pair? result)
              "parse-csv should type-check"))

(test-case "csv-e2e/csv-to-string-typechecks"
  (define result (run "(check csv-to-string : (-> (List (List String)) String))"))
  (check-true (pair? result)
              "csv-to-string should type-check"))

;; ========================================
;; Group 2: parse-csv through pipeline
;; ========================================

(test-case "csv-e2e/parse-simple-csv"
  ;; Parse a simple CSV and check we get a List (List String)
  (define result (run-last "(parse-csv \"a,b\\n1,2\\n\")"))
  ;; Result should be cons : List (List String)
  ;; Pretty printer uses list literal syntax: '["a" "b"] etc.
  (check-true (string-contains? result "List")
              "Should produce a List result"))

(test-case "csv-e2e/parse-empty-csv"
  (define result (run-last "(parse-csv \"\")"))
  ;; Empty string → nil
  (check-true (string-contains? result "nil")
              "Empty CSV should produce nil"))

(test-case "csv-e2e/parse-quoted-field"
  ;; Quoted field with embedded comma
  (define result (run-last "(parse-csv \"\\\"a,b\\\",c\\n\")"))
  (check-true (string-contains? result "List")
              "Quoted CSV should parse successfully"))

;; ========================================
;; Group 3: csv-to-string through pipeline
;; ========================================

(test-case "csv-e2e/serialize-empty"
  (define result
    (run-last "(csv-to-string (nil (List String)))"))
  (check-equal? result "\"\" : String"
                "Empty list → empty string"))

;; ========================================
;; Group 4: File-based CSV via pipeline
;; ========================================

(test-case "csv-e2e/read-csv-file"
  ;; Write a CSV file, read it through Prologos
  (define tmp (make-temporary-file "csv-e2e-~a.csv"))
  (display-to-file "name,age\nAlice,30\n" tmp #:exists 'truncate/replace)
  (define result
    (run-last (format "(read-csv ~s)" (path->string tmp))))
  (check-true (string-contains? result "List")
              "read-csv should produce parsed rows")
  (delete-file tmp))

(test-case "csv-e2e/write-csv-roundtrip"
  ;; Read CSV, write it back, read the output file
  (define tmp-in (make-temporary-file "csv-in-~a.csv"))
  (define tmp-out (make-temporary-file "csv-out-~a.csv"))
  (display-to-file "x,y\n1,2\n" tmp-in #:exists 'truncate/replace)
  ;; Read → write roundtrip
  (run (format
        (string-append
         "(def csv-data : (List (List String)) := (read-csv ~s))\n"
         "(write-csv ~s csv-data)")
        (path->string tmp-in)
        (path->string tmp-out)))
  ;; Verify the output file exists and has content
  (define content (file->string tmp-out))
  (check-true (string-contains? content "x")
              "Output file should contain header")
  (check-true (string-contains? content "1")
              "Output file should contain data")
  (delete-file tmp-in)
  (delete-file tmp-out))
