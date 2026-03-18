#lang racket/base

;;;
;;; Tests for Char and String types: type formation and literals (sexp + WS mode)
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
  (parameterize ([current-prelude-env (hasheq)]
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
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

;; Run sexp code using shared environment
(define (run s)
  (parameterize ([current-prelude-env shared-global-env]
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
    (parameterize ([current-prelude-env shared-global-env]
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
;; A. Char type - sexp mode
;; ========================================

(test-case "char type formation: infer Char"
  (check-equal? (run-last "(infer Char)") "[Type 0]"))

(test-case "char literal: sexp mode def + eval"
  (check-equal? (run-last "(def c : Char #\\a) (eval c)") "\\a : Char"))

(test-case "char literal: check type"
  (check-equal? (run-last "(check #\\a : Char)") "OK"))

(test-case "char newline literal: sexp mode"
  (check-equal? (run-last "(def c : Char #\\newline) (eval c)") "\\newline : Char"))

(test-case "char space literal: sexp mode"
  (check-equal? (run-last "(def c : Char #\\space) (eval c)") "\\space : Char"))

;; ========================================
;; B. String type - sexp mode
;; ========================================

(test-case "string type formation: infer String"
  (check-equal? (run-last "(infer String)") "[Type 0]"))

(test-case "string literal: sexp mode def + eval"
  (check-equal? (run-last "(def s : String \"hello\") (eval s)") "\"hello\" : String"))

(test-case "string literal: check type"
  (check-equal? (run-last "(check \"hello\" : String)") "OK"))

(test-case "string empty literal"
  (check-equal? (run-last "(def s : String \"\") (eval s)") "\"\" : String"))

(test-case "string with escape chars"
  (check-equal? (run-last "(def s : String \"line1\\nline2\") (eval s)")
                "\"line1\\nline2\" : String"))

;; ========================================
;; C. Char type - WS mode
;; ========================================

(test-case "char literal: WS mode basic"
  (check-equal? (run-ws-last "ns test :no-prelude\ndef c : Char \\a\neval c")
                "\\a : Char"))

(test-case "char literal: WS mode named character"
  (check-equal? (run-ws-last "ns test :no-prelude\ndef c : Char \\newline\neval c")
                "\\newline : Char"))

(test-case "char literal: WS mode space character"
  (check-equal? (run-ws-last "ns test :no-prelude\ndef c : Char \\space\neval c")
                "\\space : Char"))

(test-case "char literal: WS mode tab character"
  (check-equal? (run-ws-last "ns test :no-prelude\ndef c : Char \\tab\neval c")
                "\\tab : Char"))

(test-case "char literal: WS mode unicode escape"
  (check-equal? (run-ws-last "ns test :no-prelude\ndef c : Char \\u0041\neval c")
                "\\A : Char"))

(test-case "char type: WS mode infer"
  (check-equal? (run-ws-last "ns test :no-prelude\ninfer Char")
                "[Type 0]"))

;; ========================================
;; D. String type - WS mode
;; ========================================

(test-case "string literal: WS mode basic"
  (check-equal? (run-ws-last "ns test :no-prelude\ndef s : String \"hello\"\neval s")
                "\"hello\" : String"))

(test-case "string type: WS mode infer"
  (check-equal? (run-ws-last "ns test :no-prelude\ninfer String")
                "[Type 0]"))

(test-case "string literal: WS mode empty"
  (check-equal? (run-ws-last "ns test :no-prelude\ndef s : String \"\"\neval s")
                "\"\" : String"))
