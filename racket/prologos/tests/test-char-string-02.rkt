#lang racket/base

;;;
;;; Tests for Char and String types: foreign operations and trait instances
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         racket/port
         racket/file
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
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../namespace.rkt"
         "../trait-resolution.rkt"
         "../reader.rkt")

;; ========================================
;; Shared Fixture (prelude loaded once)
;; ========================================

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-bundle-reg)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string "(ns test-char-string)")
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

;; Run sexp code using shared environment
(define (run s)
  (parameterize ([current-global-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-bundle-registry shared-bundle-reg])
    (process-string s)))

(define (run-last s) (last (run s)))

;; Run WS code via temp file using shared environment
(define (run-ws s)
  (define tmp (make-temporary-file "prologos-test-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display s out)))
  (define result
    (parameterize ([current-global-env shared-global-env]
                   [current-ns-context shared-ns-context]
                   [current-module-registry shared-module-reg]
                   [current-lib-paths (list lib-dir)]
                   [current-mult-meta-store (make-hasheq)]
                   [current-preparse-registry (current-preparse-registry)]
                   [current-trait-registry shared-trait-reg]
                   [current-impl-registry shared-impl-reg]
                   [current-param-impl-registry shared-param-impl-reg]
                   [current-bundle-registry shared-bundle-reg])
      (process-file tmp)))
  (delete-file tmp)
  result)

(define (run-ws-last s) (last (run-ws s)))

;; ========================================
;; E. Foreign operations (requires prelude)
;; ========================================

(test-case "char foreign: eq"
  (check-equal? (run-last "(eval (char::eq #\\a #\\a))") "true : Bool"))

(test-case "char foreign: lt"
  (check-equal? (run-last "(eval (char::lt #\\a #\\b))") "true : Bool"))

(test-case "char foreign: code"
  (check-equal? (run-last "(eval (char::code #\\A))") "65 : Int"))

(test-case "char foreign: alpha?"
  (check-equal? (run-last "(eval (char::alpha? #\\a))") "true : Bool"))

(test-case "char foreign: numeric?"
  (check-equal? (run-last "(eval (char::numeric? #\\5))") "true : Bool"))

(test-case "char foreign: upper/lower"
  (check-equal? (run-last "(eval (char::upper #\\a))") "\\A : Char"))

(test-case "string foreign: eq"
  (check-equal? (run-last "(eval (str::eq \"hello\" \"hello\"))") "true : Bool"))

(test-case "string foreign: lt"
  (check-equal? (run-last "(eval (str::lt \"abc\" \"abd\"))") "true : Bool"))

(test-case "string foreign: length"
  (check-equal? (run-last "(eval (str::length \"hello\"))") "5 : Int"))

(test-case "string foreign: ref"
  (check-equal? (run-last "(eval (str::ref \"hello\" 0))") "\\h : Char"))

(test-case "string foreign: append"
  (check-equal? (run-last "(eval (str::append \"hello\" \" world\"))") "\"hello world\" : String"))

(test-case "string foreign: from-char"
  (check-equal? (run-last "(eval (str::from-char #\\A))") "\"A\" : String"))

;; ========================================
;; F. Trait instances (requires prelude)
;; ========================================

(test-case "Eq Char: trait resolution"
  (check-equal? (run-last "(infer Char--Eq--dict)") "Char Char -> Bool"))

(test-case "Ord Char: trait resolution"
  (check-equal? (run-last "(infer Char--Ord--dict)") "Char Char -> prologos::data::ordering::Ordering"))

(test-case "Hashable Char: trait resolution"
  (check-equal? (run-last "(infer Char--Hashable--dict)") "Char -> Nat"))

(test-case "Eq String: trait resolution"
  (check-equal? (run-last "(infer String--Eq--dict)") "String String -> Bool"))

(test-case "Ord String: trait resolution"
  (check-equal? (run-last "(infer String--Ord--dict)") "String String -> prologos::data::ordering::Ordering"))

(test-case "Hashable String: trait resolution"
  (check-equal? (run-last "(infer String--Hashable--dict)") "String -> Nat"))

(test-case "Add String: trait resolution"
  (check-equal? (run-last "(infer String--Add--dict)") "String String -> String"))
