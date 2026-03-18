#lang racket/base

;;;
;;; Tests for Phase 3e: General-purpose path expressions (get-in, update-in)
;;; Verifies parsing, elaboration, and E2E behavior of path algebra
;;; applied to values via get-in and update-in forms.
;;;

(require rackunit
         racket/list
         racket/string
         "../parser.rkt"
         "../surface-syntax.rkt"
         "../sexp-readtable.rkt"
         "../errors.rkt"
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../multi-dispatch.rkt")

;; ========================================
;; Parse helper
;; ========================================

(define (test-parse str)
  (define port (open-input-string str))
  (define stx (prologos-sexp-read-syntax "<test>" port))
  (parse-datum stx))

;; ========================================
;; Section 1: Parser-level tests
;; ========================================

;; 1. get-in parses single path
(test-case "path-expr/parse-get-in-single"
  (define result (test-parse "(get-in m :address.zip)"))
  (check-true (surf-get-in? result)
              (format "Expected surf-get-in, got ~v" result))
  (check-equal? (surf-get-in-paths result) '((#:address #:zip))))

;; 2. get-in parses flat path (single segment)
(test-case "path-expr/parse-get-in-flat"
  (define result (test-parse "(get-in m :name)"))
  (check-true (surf-get-in? result))
  (check-equal? (surf-get-in-paths result) '((#:name))))

;; 3. get-in parses branched path
(test-case "path-expr/parse-get-in-branched"
  (define result (test-parse "(get-in m :address.{zip city})"))
  (check-true (surf-get-in? result))
  (check-equal? (surf-get-in-paths result) '((#:address #:zip) (#:address #:city))))

;; 4. get-in parses three-level path
(test-case "path-expr/parse-get-in-deep"
  (define result (test-parse "(get-in m :a.b.c)"))
  (check-true (surf-get-in? result))
  (check-equal? (surf-get-in-paths result) '((#:a #:b #:c))))

;; 5. get-in parses nested braces
(test-case "path-expr/parse-get-in-nested-braces"
  (define result (test-parse "(get-in m :a.{b.{c d} e})"))
  (check-true (surf-get-in? result))
  (check-equal? (surf-get-in-paths result)
                '((#:a #:b #:c) (#:a #:b #:d) (#:a #:e))))

;; 6. update-in parses single path with function
(test-case "path-expr/parse-update-in"
  (define result (test-parse "(update-in m :address.zip inc)"))
  (check-true (surf-update-in? result)
              (format "Expected surf-update-in, got ~v" result))
  (check-equal? (surf-update-in-paths result) '((#:address #:zip)))
  (check-true (surf-var? (surf-update-in-fn-expr result))))

;; 7. update-in parses with lambda function
(test-case "path-expr/parse-update-in-lambda"
  (define result (test-parse "(update-in m :a.b (fn [x] 0N))"))
  (check-true (surf-update-in? result))
  (check-equal? (surf-update-in-paths result) '((#:a #:b))))

;; 8. get-in error: too few args
(test-case "path-expr/parse-get-in-too-few-args"
  (define result (test-parse "(get-in m)"))
  (check-true (prologos-error? result)
              (format "Expected error for too few args, got ~v" result)))

;; 9. update-in error: too few args (no fn)
(test-case "path-expr/parse-update-in-too-few-args"
  (define result (test-parse "(update-in m :a.b)"))
  (check-true (prologos-error? result)
              (format "Expected error for update-in without fn, got ~v" result)))

;; ========================================
;; Section 2: E2E pipeline tests
;; ========================================

;; Shared preamble: homogeneous maps (avoid Peano union type issues)
(define shared-preamble
  (string-append
   "(ns test)\n"
   ;; Flat map
   "(def flat := {:x 1N :y 2N :z 3N})\n"
   ;; Nested homogeneous map
   "(def nested := {:a {:x 1N :y 2N} :b {:x 3N :y 0N}})\n"
   ;; Three-level nesting
   "(def deep := {:top {:mid {:leaf 1N :other 2N}}})\n"))

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-schema-reg
                shared-selection-reg)
  (parameterize ([current-global-env (hasheq)]
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
                 [current-spec-store (hasheq)]
                 [current-schema-registry (hasheq)]
                 [current-selection-registry (hasheq)])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-schema-registry)
            (current-selection-registry))))

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
                 [current-schema-registry shared-schema-reg]
                 [current-selection-registry shared-selection-reg])
    (process-string s)))

(define (run-last s)
  (define results (run s))
  (and (pair? results) (last results)))

(define (check-no-errors results)
  (for ([r (in-list results)])
    (check-false (prologos-error? r)
                 (format "Unexpected error: ~v" r))))

;; ========================================
;; get-in tests
;; ========================================

;; 10. get-in flat map, single key
(test-case "path-expr/get-in-flat-single"
  (define result (run-last "(get-in flat :x)"))
  (check-false (prologos-error? result)
               (format "Expected success, got ~v" result))
  (check-true (string-contains? (format "~a" result) "1N")))

;; 11. get-in nested map, two-level path
(test-case "path-expr/get-in-nested-path"
  (define result (run-last "(get-in nested :a.x)"))
  (check-false (prologos-error? result)
               (format "Expected success, got ~v" result))
  (check-true (string-contains? (format "~a" result) "1N")))

;; 12. get-in three-level path
(test-case "path-expr/get-in-deep-path"
  (define result (run-last "(get-in deep :top.mid.leaf)"))
  (check-false (prologos-error? result)
               (format "Expected success, got ~v" result))
  (check-true (string-contains? (format "~a" result) "1N")))

;; 13. get-in branched path builds projection map
(test-case "path-expr/get-in-branched"
  (define result (run-last "(get-in nested :a.{x y})"))
  (check-false (prologos-error? result)
               (format "Expected success, got ~v" result))
  ;; Result should be a map with :x and :y keys
  (check-true (string-contains? (format "~a" result) "Map")))

;; 14. get-in types correctly for homogeneous map
(test-case "path-expr/get-in-type"
  (define result (run-last "(get-in flat :x)"))
  (check-false (prologos-error? result))
  (check-true (string-contains? (format "~a" result) "Nat")))

;; ========================================
;; update-in tests
;; ========================================

;; 15. update-in flat map
(test-case "path-expr/update-in-flat"
  (define result (run-last "(update-in flat :x (fn [n] 0N))"))
  (check-false (prologos-error? result)
               (format "Expected success, got ~v" result))
  (check-true (string-contains? (format "~a" result) "Map")))

;; 16. update-in nested map
(test-case "path-expr/update-in-nested"
  (define result (run-last "(update-in nested :a.x (fn [n] 0N))"))
  (check-false (prologos-error? result)
               (format "Expected success, got ~v" result)))

;; 17. update-in deep map
(test-case "path-expr/update-in-deep"
  (define result (run-last "(update-in deep :top.mid.leaf (fn [n] 0N))"))
  (check-false (prologos-error? result)
               (format "Expected success, got ~v" result)))

;; 18. update-in error: branched path rejected
(test-case "path-expr/update-in-branched-error"
  (define result (run-last "(update-in nested :a.{x y} (fn [n] 0N))"))
  (check-true (prologos-error? result)
              (format "Expected error for branched update-in, got ~v" result)))

;; ========================================
;; Composition: get-in on update-in result
;; ========================================

;; 19. get-in after update-in verifies update applied
(test-case "path-expr/get-in-after-update-in"
  (define result (run-last "(get-in (update-in flat :x (fn [n] 0N)) :x)"))
  (check-false (prologos-error? result)
               (format "Expected success, got ~v" result))
  (check-true (string-contains? (format "~a" result) "0N")))

;; 20. get-in after nested update-in
(test-case "path-expr/get-in-after-nested-update"
  (define result (run-last "(get-in (update-in nested :a.x (fn [n] 0N)) :a.x)"))
  (check-false (prologos-error? result)
               (format "Expected success, got ~v" result))
  (check-true (string-contains? (format "~a" result) "0N")))
