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
  (parameterize ([current-file-module-network-ref (make-module-network)]
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
    (values (global-env-snapshot)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

;; Run sexp code using shared environment
(define (run s)
  (parameterize ([current-file-module-network-ref (module-network-add-import (make-module-network) (module-network-from-snapshot shared-global-env))]
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
    (parameterize ([current-file-module-network-ref (module-network-add-import (make-module-network) (module-network-from-snapshot shared-global-env))]
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
  (check-equal? result "@[:admin :active] : [PVec Keyword]"))

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

;; ========================================
;; Map-literal VALUE rewrites (CIU T6, 2026-07-18)
;; ========================================
;; dot-access / bracketed apps / nested maps inside map VALUES now expand
;; (were opaque during preparse → leak/crash). This is the "functions that
;; return records" pattern (`defn f [...] {:x [+ p.x q.x] ...}`).

(test-case "e2e/ws: dot-access in a map value projects"
  (check-equal?
   (run-ws-last
    (string-append
     "def pt := {:x 3N :y 4N}\n"
     "def m := {:a pt.x}\n"
     "eval m.a\n"))
   "3N : Nat"))

(test-case "e2e/ws: dot-access inside a bracketed app in a map value"
  (check-equal?
   (run-ws-last
    (string-append
     "def pt := {:x 3N :y 4N}\n"
     "def m := {:a [add pt.x pt.y]}\n"
     "eval m.a\n"))
   "7N : Nat"))

(test-case "e2e/ws: nested map value with dot-access projects"
  (check-equal?
   (run-ws-last
    (string-append
     "def pt := {:x 3N :y 4N}\n"
     "def m := {:a {:b pt.x}}\n"
     "eval m.a.b\n"))
   "3N : Nat"))

(test-case "e2e/ws: function returns a record built from projected fields"
  (check-equal?
   (run-ws-last
    (string-append
     "schema Pt\n  :x Nat\n  :y Nat\n"
     "defn padd [p : Pt, q : Pt] : Pt\n"
     "  {:x [add p.x q.x]\n"
     "   :y [add p.y q.y]}\n"
     "def a : Pt := {:x 1N :y 2N}\n"
     "def b : Pt := {:x 3N :y 4N}\n"
     "eval [padd a b].y\n"))
   "6N : Nat"))
