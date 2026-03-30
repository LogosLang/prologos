#lang racket/base

;;;
;;; Tests for postfix bracket indexing: full E2E WS-mode tests
;;;
;;; Validates xs[0] on List, PVec, Map through the full
;;; WS reader → preparse → parse → elaborate → typecheck → reduce pipeline.
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
    (process-string "(ns test-postfix-index)")
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

;; Run WS code using shared environment
(define (run-ws s)
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
    (process-string-ws s)))

(define (run-ws-last s) (last (run-ws s)))

;; ========================================
;; A. List indexing
;; ========================================

(test-case "postfix-index: List[0] returns first element"
  (check-equal?
   (run-ws-last "
ns test
def xs : (List Nat) := '[1N 2N 3N]
eval xs[0]
")
   "1N : Nat"))

(test-case "postfix-index: List[2] returns third element"
  (check-equal?
   (run-ws-last "
ns test
def xs : (List Nat) := '[10N 20N 30N]
eval xs[2]
")
   "30N : Nat"))

(test-case "postfix-index: List with Int key"
  (check-equal?
   (run-ws-last "
ns test
def xs : (List Nat) := '[1N 2N 3N]
def i : Int := 1
eval xs[i]
")
   "2N : Nat"))

;; ========================================
;; B. Map indexing
;; ========================================

(test-case "postfix-index: Map[:key] returns value"
  (check-equal?
   (run-ws-last "
ns test
def m : (Map Keyword Nat) := {:a 1N :b 2N :c 3N}
eval m[:b]
")
   "2N : Nat"))

(test-case "postfix-index: Map with computed key"
  (check-equal?
   (run-ws-last "
ns test
def m : (Map Keyword Nat) := {:x 42N}
def k : Keyword := :x
eval m[k]
")
   "42N : Nat"))

;; ========================================
;; C. Chained indexing
;; ========================================

(test-case "postfix-index: nested Map m[:a][:x]"
  (check-equal?
   (run-ws-last "
ns test
def m : (Map Keyword (Map Keyword Nat)) := {:a {:x 1N} :b {:y 2N}}
eval m[:a][:x]
")
   "1N : Nat"))

(test-case "postfix-index: List of Maps xs[0].field"
  (check-equal?
   (run-ws-last "
ns test
def xs : (List (Map Keyword Nat)) := '[{:age 25N} {:age 30N}]
eval xs[0].age
")
   "25N : Nat"))

(test-case "postfix-index: chained xs[1].field"
  (check-equal?
   (run-ws-last "
ns test
def xs : (List (Map Keyword Nat)) := '[{:age 25N} {:age 30N}]
eval xs[1].age
")
   "30N : Nat"))

;; ========================================
;; D. Spaced brackets = application (no index)
;; ========================================

(test-case "postfix-index: spaced xs [0] is application not index"
  ;; xs [0] should treat [0] as an argument (application), not as index.
  ;; This should produce a type error or different result vs xs[0].
  (define results (run-ws "
ns test
def xs : (List Nat) := '[1N 2N 3N]
eval xs [0]
"))
  ;; Should NOT produce "1N : Nat" (which xs[0] would give)
  (check-false
   (for/or ([r (in-list results)])
     (and (string? r) (equal? r "1N : Nat")))))

;; ========================================
;; E. Additional WS-mode tests
;; ========================================

(test-case "postfix-index: Map with string-like key"
  (check-equal?
   (run-ws-last "
ns test
def m : (Map Keyword Nat) := {:x 1N :y 2N :z 3N}
eval m[:z]
")
   "3N : Nat"))

(test-case "postfix-index: chained Map then dot-access"
  (check-equal?
   (run-ws-last "
ns test
def m : (Map Keyword (Map Keyword Nat)) := {:config {:port 8080N :host 443N}}
eval m[:config][:port]
")
   "8080N : Nat"))

(test-case "postfix-index: List index with Nat literal"
  (check-equal?
   (run-ws-last "
ns test
def xs : (List Nat) := '[100N 200N 300N]
eval xs[1N]
")
   "200N : Nat"))
