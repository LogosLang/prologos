#lang racket/base

;;;
;;; Tests for mixed-type (heterogeneous value) maps.
;;;
;;; Map literals with values of different types auto-infer a union
;;; value type. map-assoc widens via union when the new value
;;; doesn't fit the existing value type.
;;;

(require rackunit
         racket/string
         racket/list
         racket/path
         "test-support.rkt"
         "../syntax.rkt"
         "../prelude.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../unify.rkt"
         "../pretty-print.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../metavar-store.rkt"
         "../namespace.rkt"
         "../macros.rkt"
         "../champ.rkt")

;; Helper to run sexp code with clean global env
(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

;; Helper: run prologos code with namespace system active
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    (process-string s)))

;; Helper: extract last string result, skipping errors
(define (last-string results)
  (define strings (filter string? results))
  (if (null? strings) "" (last strings)))

;; ========================================
;; A. Unit tests: build-union-type
;; ========================================

(test-case "build-union-type: single type is identity"
  (check-equal? (build-union-type (list (expr-Nat)))
                (expr-Nat)))

(test-case "build-union-type: two distinct types"
  (define result (build-union-type (list (expr-Nat) (expr-String))))
  (check-true (expr-union? result))
  ;; After sort: Nat < String (by union-sort-key)
  (check-equal? (expr-union-left result) (expr-Nat))
  (check-equal? (expr-union-right result) (expr-String)))

(test-case "build-union-type: deduplicates identical types"
  (check-equal? (build-union-type (list (expr-Nat) (expr-Nat)))
                (expr-Nat)))

(test-case "build-union-type: three types, right-associated"
  (define result (build-union-type (list (expr-String) (expr-Nat) (expr-Bool))))
  ;; Sort order by key: Bool < Nat < String
  (check-true (expr-union? result))
  (check-equal? (expr-union-left result) (expr-Bool))
  (check-true (expr-union? (expr-union-right result)))
  (define inner (expr-union-right result))
  (check-equal? (expr-union-left inner) (expr-Nat))
  (check-equal? (expr-union-right inner) (expr-String)))

(test-case "build-union-type: flattens nested union input"
  (define input-union (expr-union (expr-Nat) (expr-Bool)))
  (define result (build-union-type (list input-union (expr-String))))
  ;; Should flatten to {Bool, Nat, String}
  (check-true (expr-union? result))
  (check-equal? (expr-union-left result) (expr-Bool))
  (define inner (expr-union-right result))
  (check-equal? (expr-union-left inner) (expr-Nat))
  (check-equal? (expr-union-right inner) (expr-String)))

;; ========================================
;; B. AST-level infer: map-assoc widening
;; ========================================

(test-case "infer: map-assoc with matching value type -- no widening"
  (with-fresh-meta-env
    (parameterize ([current-global-env (hasheq)])
      (let* ([m (expr-map-empty (expr-Keyword) (expr-Nat))]
             [m1 (expr-map-assoc m (expr-keyword 'x) (expr-zero))])
        (define ty (tc:infer ctx-empty m1))
        (check-true (expr-Map? ty))
        (check-equal? (expr-Map-k-type ty) (expr-Keyword))
        (check-equal? (expr-Map-v-type ty) (expr-Nat))))))

(test-case "infer: map-assoc widens when value type differs"
  (with-fresh-meta-env
    (parameterize ([current-global-env (hasheq)])
      (let* ([m (expr-map-empty (expr-Keyword) (expr-Nat))]
             [m1 (expr-map-assoc m (expr-keyword 'x) (expr-zero))]
             [m2 (expr-map-assoc m1 (expr-keyword 'y) (expr-string "hello"))])
        (define ty (tc:infer ctx-empty m2))
        (check-true (expr-Map? ty) "result should be a Map type")
        (check-equal? (expr-Map-k-type ty) (expr-Keyword))
        (check-true (expr-union? (expr-Map-v-type ty))
                    "value type should be a union (Nat | String)")))))

;; ========================================
;; C. Surface syntax: sexp mode
;; ========================================

(test-case "surface/sexp: mixed map literal infers union value type"
  (define result (run "(infer {:name \"Alice\" :age zero})"))
  ;; Type should be Map Keyword (Nat | String)
  (define r (last-string result))
  (check-true (string-contains? r "Map") "should produce a Map type")
  (check-true (and (string-contains? r "Nat")
                   (string-contains? r "String"))
              "value type should contain both Nat and String"))

(test-case "surface/sexp: homogeneous map literal still works"
  (define result (run "(infer {:x zero :y (suc zero)})"))
  (define r (last-string result))
  (check-true (string-contains? r "Map"))
  (check-true (string-contains? r "Nat"))
  (check-false (string-contains? r "|")
               "homogeneous map should not have union type"))

(test-case "surface/sexp: map-get on mixed map returns union"
  (define result
    (run (string-append
          "(def m {:name \"Alice\" :age zero})\n"
          "(infer (map-get m :name))")))
  (define r (last-string result))
  (check-true (or (string-contains? r "Nat")
                  (string-contains? r "String"))
              "map-get on mixed map should return a union component"))

(test-case "surface/sexp: check mixed map against annotated union type"
  ;; Sexp union syntax: <(Map Keyword <Nat | String>)> — nested angle brackets
  (define result
    (run "(check {:name \"Alice\" :age zero} <(Map Keyword <Nat | String>)>)"))
  (define r (last-string result))
  (check-equal? r "OK" "mixed map should check against annotated union type"))

(test-case "surface/sexp: map-assoc widens existing map"
  ;; Annotated def uses <type> syntax
  (define result
    (run (string-append
          "(def m <(Map Keyword Nat)> {:x zero})\n"
          "(infer (map-assoc m :name \"hello\"))")))
  (define r (last-string result))
  (check-true (and (string-contains? r "Nat")
                   (string-contains? r "String"))
              "map-assoc should widen Nat to (Nat | String)"))

;; ========================================
;; C2. map-get on union types (chained access)
;; ========================================

(test-case "surface/sexp: chained map-get on nested mixed map"
  ;; {:name "Alice" :age 43 :address {:street "Main"}}
  ;; map-get ... :address → union → map-get on union → String
  (define result
    (run (string-append
          "(def m {:name \"Alice\" :age 43 :address {:street \"Main\"}})\n"
          "(infer (map-get (map-get m :address) :street))")))
  (define r (last-string result))
  (check-equal? r "String" "chained map-get should resolve to String"))

(test-case "surface/sexp: map-get on union with no Map components fails"
  (define result
    (run (string-append
          "(def m {:x 1 :y 2})\n"
          "(infer (map-get (map-get m :x) :z))")))
  ;; Second result should be an error (map-get on Int fails)
  (check-true (not (string? (cadr result)))
              "map-get on non-Map value should produce an error"))

(test-case "surface/sexp: map-get on union extracts Map value types"
  ;; When union has multiple Map components, result is union of their value types
  (define result
    (run (string-append
          "(def inner1 <(Map Keyword Nat)> {:x zero})\n"
          "(def inner2 <(Map Keyword String)> {:y \"hello\"})\n"
          "(def m {:a inner1 :b inner2})\n"
          "(infer (map-get (map-get m :a) :z))")))
  (define r (last-string result))
  ;; Value type is union of inner maps' value types: Nat | String
  (check-true (or (string-contains? r "Nat")
                  (string-contains? r "String"))
              "map-get on union should extract Map value types"))

;; ========================================
;; C3. Runtime: map-get on non-Map values returns none
;; ========================================

(test-case "runtime: map-get on non-Map value returns none"
  ;; map-get on a concrete non-Map value (like Int) should return none
  ;; instead of a stuck term
  (define result
    (run (string-append
          "(def m {:name \"Alice\" :age 43 :address {:street \"Main\"}})\n"
          "(eval (map-get (map-get m :age) :street))")))
  (define r (last-string result))
  (check-true (string-contains? r "none")
              "map-get on Int should return none at runtime"))

(test-case "runtime: chained map-get on nested map evaluates correctly"
  (define result
    (run (string-append
          "(def m {:name \"Alice\" :age 43 :address {:street \"Main\"}})\n"
          "(eval (map-get (map-get m :address) :street))")))
  (define r (last-string result))
  (check-true (string-contains? r "Main")
              "chained map-get should evaluate to the nested value"))

;; ========================================
;; D. Backward compatibility
;; ========================================

(test-case "backward-compat: homogeneous Nat map via check"
  ;; Use angle-bracket syntax for check type
  (define result (run "(check {:x zero :y (suc zero)} <(Map Keyword Nat)>)"))
  (define r (last-string result))
  (check-equal? r "OK"))

(test-case "backward-compat: map-get on homogeneous map returns single type"
  (define result
    (run (string-append
          "(def m {:x zero :y (suc zero)})\n"
          "(infer (map-get m :x))")))
  (define r (last-string result))
  (check-true (string-contains? r "Nat"))
  (check-false (string-contains? r "|")
               "homogeneous map-get should not return union"))

;; ========================================
;; E. Namespace mode tests
;; ========================================

(test-case "ns: mixed map with prelude types"
  (define result
    (run-ns (string-append
             "(ns test.mixed-map :no-prelude)\n"
             "(infer {:name \"Alice\" :active true})")))
  (define r (last-string result))
  (check-true (string-contains? r "Map") "should produce a Map type")
  (check-true (or (and (string-contains? r "Bool")
                       (string-contains? r "String"))
                  (string-contains? r "|"))
              "value type should be a union of Bool and String"))

(test-case "ns: mixed map with three value types"
  (define result
    (run-ns (string-append
             "(ns test.tri-map :no-prelude)\n"
             "(infer {:name \"Alice\" :age zero :active true})")))
  (define r (last-string result))
  (check-true (string-contains? r "Map"))
  (check-true (string-contains? r "Bool"))
  (check-true (string-contains? r "Nat"))
  (check-true (string-contains? r "String")))
