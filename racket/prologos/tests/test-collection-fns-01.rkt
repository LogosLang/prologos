#lang racket/base

;;;
;;; Tests for Stage F: Generic collection-fns module.
;;; Verifies generic map, filter, reduce, length, concat, any?, all?,
;;; to-list, find, take, drop work on List, PVec, and Set.
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt"
         "../macros.rkt"
         "../syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt")

;; ========================================
;; Shared Fixture (modules loaded once)
;; ========================================

(define shared-preamble
  "(ns test)
(imports (prologos::core::collections :refer (map filter reduce reduce1 length concat any? all? to-list find take drop)))
(imports (prologos::data::nat :refer (add)))
")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry))))

(define (run s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg])
    (process-string s)))

(define (run-last s) (last (run s)))
(define (run-all s) (run s))

;; ========================================
;; Module loading test
;; ========================================

(test-case "collection-fns/module-loads"
  ;; Shared fixture already loaded the collection-fns module successfully.
  ;; Verify the fixture environment is non-empty.
  (check-true (positive? (hash-count shared-global-env))))

;; ========================================
;; Generic map — type checks
;; ========================================

(test-case "collection-fns/map-list-type"
  (define result
    (run-last
      "(spec inc Nat -> Nat)
       (defn inc [x] (suc x))
       (infer (map inc '[0N 1N 2N]))"))
  (check-true (string-contains? result "List"))
  (check-true (string-contains? result "Nat")))

(test-case "collection-fns/map-list-eval"
  (define result
    (run-last
      "(spec inc Nat -> Nat)
       (defn inc [x] (suc x))
       (eval (map inc '[0N 1N 2N]))"))
  (check-true (string-contains? result "'[1N 2N 3N]")))

(test-case "collection-fns/map-pvec-type"
  (define result
    (run-last
      "(spec inc Nat -> Nat)
       (defn inc [x] (suc x))
       (def v : (PVec Nat) (pvec-push (pvec-push (pvec-empty Nat) 0N) 1N))
       (infer (map inc v))"))
  (check-true (string-contains? result "PVec"))
  (check-true (string-contains? result "Nat")))

(test-case "collection-fns/map-pvec-eval"
  (define result
    (run-last
      "(spec inc Nat -> Nat)
       (defn inc [x] (suc x))
       (def v : (PVec Nat) (pvec-push (pvec-push (pvec-empty Nat) 0N) 1N))
       (eval (map inc v))"))
  (check-true (string-contains? result "@[1N 2N]")))

;; ========================================
;; Generic filter — type checks + eval
;; ========================================

(test-case "collection-fns/filter-list-eval"
  (define result
    (run-last
      "(spec pos? Nat -> Bool)
       (defn pos? [x] (match x (zero -> false) (suc _ -> true)))
       (eval (filter pos? '[0N 1N 2N 0N 3N]))"))
  (check-true (string-contains? result "'[1N 2N 3N]")))

;; ========================================
;; Generic reduce — type checks + eval
;; ========================================

(test-case "collection-fns/reduce-list-eval"
  (define result
    (run-last
      "(eval (reduce (fn (acc : Nat) (fn (x : Nat) (add acc x))) zero '[1N 2N 3N]))"))
  (check-true (string-contains? result "6N")))

;; ========================================
;; Generic reduce1 — first-element-as-init
;; ========================================

(test-case "collection-fns/reduce1-list-some"
  (define result
    (run-last
      "(eval (reduce1 add '[1N 2N 3N]))"))
  (check-true (string-contains? result "some"))
  (check-true (string-contains? result "6N")))

(test-case "collection-fns/reduce1-list-none"
  (define result
    (run-last
      "(eval (reduce1 add (the (List Nat) (nil Nat))))"))
  (check-true (string-contains? result "none")))

(test-case "collection-fns/reduce1-pvec"
  (define result
    (run-last
      "(def v : (PVec Nat) (pvec-push (pvec-push (pvec-push (pvec-empty Nat) 1N) 2N) 3N))
       (eval (reduce1 add v))"))
  (check-true (string-contains? result "some"))
  (check-true (string-contains? result "6N")))

;; ========================================
;; Generic length
;; ========================================

(test-case "collection-fns/length-list-eval"
  (define result
    (run-last
      "(eval (length '[1N 2N 3N]))"))
  (check-true (string-contains? result "3N")))

(test-case "collection-fns/length-pvec-eval"
  (define result
    (run-last
      "(def v : (PVec Nat) (pvec-push (pvec-push (pvec-empty Nat) 0N) 1N))
       (eval (length v))"))
  (check-true (string-contains? result "2N")))

;; ========================================
;; Generic any? / all?
;; ========================================

(test-case "collection-fns/any-list-true"
  (define result
    (run-last
      "(spec pos? Nat -> Bool)
       (defn pos? [x] (match x (zero -> false) (suc _ -> true)))
       (eval (any? pos? '[0N 0N 1N]))"))
  (check-true (string-contains? result "true")))

(test-case "collection-fns/all-list-false"
  (define result
    (run-last
      "(spec pos? Nat -> Bool)
       (defn pos? [x] (match x (zero -> false) (suc _ -> true)))
       (eval (all? pos? '[0N 0N 1N]))"))
  (check-true (string-contains? result "false")))
