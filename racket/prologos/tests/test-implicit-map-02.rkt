#lang racket/base

;;;
;;; E2E tests for implicit map syntax (sexp + WS mode)
;;;
;;; Tests the full pipeline: reader → preparse → parse → elaborate
;;; for keyword-headed tails on def/defn desugaring to map literals.
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
         "../parse-reader.rkt")

;; ========================================
;; Shared Fixture for E2E tests
;; ========================================

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Load prelude and helpers once
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
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    ;; Set up a basic namespace with prelude
    (process-string "(ns test-implicit-map)")
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
;; C. E2E tests: implicit map via sexp mode
;; ========================================
;; These test the preparse macro path using (:key value) children directly.

(test-case "e2e/sexp: basic implicit map"
  ;; (def m (:name 1N)) should desugar to (def m ($brace-params :name 1N))
  ;; which the parser handles as a map literal {: name 1N}
  (define result
    (run-last
     (string-append
      "(def m : (Map Keyword Nat) (:name 1N))\n"
      "(eval (map-get m :name))")))
  (check-equal? result "1N : Nat"))

(test-case "e2e/sexp: nested implicit map"
  (define result
    (run-last
     (string-append
      "(def inner : (Map Keyword Nat) (:val 42N))\n"
      "(def outer : (Map Keyword (Map Keyword Nat)) (:inner inner))\n"
      "(eval (map-get (map-get outer :inner) :val))")))
  (check-equal? result "42N : Nat"))

;; ========================================
;; D. E2E tests: implicit map via WS mode
;; ========================================
;; These test the full reader → preparse → elaboration path.

(test-case "e2e/ws: basic implicit map"
  (define result
    (run-ws-last
     (string-append
      "def m : [Map Keyword Nat]\n"
      "  :name 1N\n"
      "eval [map-get m :name]\n")))
  (check-equal? result "1N : Nat"))

(test-case "e2e/ws: nested implicit map"
  (define result
    (run-ws-last
     (string-append
      "def inner : [Map Keyword Nat]\n"
      "  :val 42N\n"
      "def outer : [Map Keyword [Map Keyword Nat]]\n"
      "  :inner inner\n"
      "eval [map-get [map-get outer :inner] :val]\n")))
  (check-equal? result "42N : Nat"))

(test-case "e2e/ws: implicit map with dot-access"
  (define result
    (run-ws-last
     (string-append
      "def m : [Map Keyword Nat]\n"
      "  :name 5N\n"
      "eval m.name\n")))
  (check-equal? result "5N : Nat"))

(test-case "e2e/ws: type-annotated implicit map"
  (define result
    (run-ws-last
     (string-append
      "def m <[Map Keyword Nat]>\n"
      "  :val 3N\n"
      "eval m.val\n")))
  (check-equal? result "3N : Nat"))

(test-case "e2e/ws: implicit map with inline vector value"
  (define result
    (run-ws-last
     (string-append
      "def m : [Map Keyword [PVec Keyword]]\n"
      "  :tags @[:admin :active]\n"
      "eval m.tags\n")))
  (check-equal? result "@[:admin :active] : (PVec Keyword)"))

(test-case "e2e/ws: implicit map with computed value"
  (define result
    (run-ws-last
     (string-append
      "def m : [Map Keyword Nat]\n"
      "  :val [add 2N 3N]\n"
      "eval m.val\n")))
  (check-equal? result "5N : Nat"))

(test-case "e2e/ws: non-interference with regular def"
  ;; Plain def (no keyword children) should not be affected
  (define result
    (run-ws-last "def x : Nat 42N\neval x\n"))
  (check-equal? result "42N : Nat"))

(test-case "e2e/ws: non-interference with function def"
  ;; defn with non-keyword body should not be affected
  (define result
    (run-ws-last
     (string-append
      "defn f [x : Nat] : Nat\n"
      "  [add x 1N]\n"
      "eval [f 5N]\n")))
  (check-equal? result "6N : Nat"))
