#lang racket/base

;;;
;;; E2E tests for schema-typed relations: (defr R : Schema || rows)
;;;
;;; Covers the wiring added to make schema-typed defr register at Level 3:
;;;   - arity + (field-named) params derived from the named schema (parser.rkt
;;;     parse-defr-schema-typed)
;;;   - positional fact-row type-checking against the schema field types
;;;     (driver.rkt check-relation-schema-rows)
;;;
;;; Full pipeline: WS reader -> parser -> elaborator -> type-check -> zonk ->
;;; driver registration -> solve reduction. Mirrors test-relational-e2e.rkt.
;;;

(require rackunit
         racket/list
         racket/string
         racket/path
         racket/file
         "../driver.rkt"
         "../errors.rkt"
         "../namespace.rkt"
         "../metavar-store.rkt"
         "../relations.rkt"
         "../trait-resolution.rkt"
         "../macros.rkt")

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define (run-prologos-string content)
  (define tmp (make-temporary-file "prologos-defrschema-~a.prologos"))
  (call-with-output-file tmp
    (lambda (out) (display content out))
    #:exists 'truncate)
  (define results
    (parameterize ([current-ns-context #f]
                   [current-module-registry (hasheq)]
                   [current-lib-paths (list lib-dir)]
                   [current-relation-store (make-relation-store)]
                   [current-preparse-registry (current-preparse-registry)]
                   [current-trait-registry (current-trait-registry)]
                   [current-impl-registry (current-impl-registry)]
                   [current-param-impl-registry (current-param-impl-registry)]
                   [current-bundle-registry (current-bundle-registry)])
      (install-module-loader!)
      (process-file (path->string tmp))))
  (delete-file tmp)
  results)

(define (check-no-errors results)
  (for ([r (in-list results)])
    (when (prologos-error? r)
      (fail (format "Unexpected error: ~a" (prologos-error-message r))))))

(define (count-answers s) (length (regexp-match* #rx"\\{:" s)))
(define (last-result results) (last results))
(define (first-error-message results)
  (for/or ([r (in-list results)])
    (and (prologos-error? r) (prologos-error-message r))))

(define PKG-SCHEMA
  (string-append
   "ns test :no-prelude\n\n"
   "schema Package\n"
   "  :name    String\n"
   "  :version String\n"
   "  :license String\n\n"))

(define VER-SCHEMA
  (string-append
   "ns test :no-prelude\n\n"
   "schema Versioned\n"
   "  :name String\n"
   "  :rank Nat\n\n"))

;; ========================================
;; 1. Registration + solve (arity derived from schema)
;; ========================================
(test-case "schema-typed defr registers and solves; arity from schema"
  (define results
    (run-prologos-string
     (string-append PKG-SCHEMA
       "defr package : Package\n"
       "  || \"app\"    \"1.0.0\" \"MIT\"\n"
       "     \"logger\" \"0.9.0\" \"GPL-3.0\"\n\n"
       "eval (solve (package n v l))\n")))
  (check-no-errors results)
  (check-equal? (count-answers (last-result results)) 2
                "schema-typed package should register 2 rows and solve to 2 answers"))

;; ========================================
;; 2. Ground-arg query matches (arity-3 matching works)
;; ========================================
(test-case "schema-typed defr: ground-arg query matches one row"
  (define results
    (run-prologos-string
     (string-append PKG-SCHEMA
       "defr package : Package\n"
       "  || \"app\"    \"1.0.0\" \"MIT\"\n"
       "     \"logger\" \"0.9.0\" \"GPL-3.0\"\n\n"
       "eval (solve (package \"logger\" v l))\n")))
  (check-no-errors results)
  (check-equal? (count-answers (last-result results)) 1))

;; ========================================
;; 3. Nat field accepts Nat literals (positive type-check)
;; ========================================
(test-case "schema-typed defr: Nat field accepts Nat literals"
  (define results
    (run-prologos-string
     (string-append VER-SCHEMA
       "defr item : Versioned\n"
       "  || \"app\"  1N\n"
       "     \"core\" 2N\n\n"
       "eval (solve (item n r))\n")))
  (check-no-errors results)
  (check-equal? (count-answers (last-result results)) 2))

;; ========================================
;; 4. Wrong field type is a type error (negative)
;; ========================================
(test-case "schema-typed defr: String in a Nat field is a type error"
  (define results
    (run-prologos-string
     (string-append VER-SCHEMA
       "defr item : Versioned\n"
       "  || \"app\" 1N\n"
       "     \"bad\" \"oops\"\n")))
  (define msg (first-error-message results))
  (check-true (and msg (string-contains? msg "rank"))
              (format "expected a :rank field type error, got: ~a" msg)))

;; ========================================
;; 5. Wrong row width is an error (negative)
;; ========================================
(test-case "schema-typed defr: wrong-width fact row is an error"
  (define results
    (run-prologos-string
     (string-append PKG-SCHEMA
       "defr package : Package\n"
       "  || \"app\" \"1.0.0\"\n")))
  (define msg (first-error-message results))
  (check-true (and msg (string-contains? msg "field"))
              (format "expected a width-mismatch error, got: ~a" msg)))
