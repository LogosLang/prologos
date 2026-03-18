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
(imports (prologos::core::collections :refer (map filter reduce reduce1 length concat any? all? to-list find take drop into head empty?)))
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
                 [current-mult-meta-store (make-hasheq)]
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
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg])
    (process-string s)))

(define (run-last s) (last (run s)))
(define (run-all s) (run s))

;; ========================================
;; Generic to-list
;; ========================================

(test-case "collection-fns/to-list-pvec-eval"
  (define result
    (run-last
      "(def v : (PVec Nat) (pvec-push (pvec-push (pvec-empty Nat) 1N) 2N))
       (eval (to-list v))"))
  (check-true (string-contains? result "'[1N 2N]")))

;; ========================================
;; Generic find
;; ========================================

(test-case "collection-fns/find-list-some"
  (define result
    (run-last
      "(spec pos? Nat -> Bool)
       (defn pos? [x] (match x (zero -> false) (suc _ -> true)))
       (eval (find pos? '[0N 1N 2N]))"))
  (check-true (string-contains? result "some")))

(test-case "collection-fns/find-list-none"
  (define result
    (run-last
      "(spec pos? Nat -> Bool)
       (defn pos? [x] (match x (zero -> false) (suc _ -> true)))
       (eval (find pos? '[0N 0N 0N]))"))
  (check-true (string-contains? result "none")))

;; ========================================
;; Generic take / drop
;; ========================================

(test-case "collection-fns/take-list-eval"
  (define result
    (run-last
      "(eval (take (suc (suc zero)) '[1N 2N 3N 4N]))"))
  (check-true (string-contains? result "'[1N 2N]")))

(test-case "collection-fns/drop-list-eval"
  (define result
    (run-last
      "(eval (drop (suc (suc zero)) '[1N 2N 3N 4N]))"))
  (check-true (string-contains? result "'[3N 4N]")))

;; ========================================
;; Generic into — collection conversion
;; ========================================

(test-case "collection-fns/into-list-to-pvec"
  (define result
    (run-last
      "(eval (into (pvec-empty Nat) '[1N 2N 3N]))"))
  (check-true (string-contains? result "@[1N 2N 3N]")))

(test-case "collection-fns/into-pvec-to-list"
  (define result
    (run-last
      "(def v : (PVec Nat) (pvec-push (pvec-push (pvec-push (pvec-empty Nat) 1N) 2N) 3N))
       (eval (into (the (List Nat) (nil Nat)) v))"))
  (check-true (string-contains? result "'[1N 2N 3N]")))

(test-case "collection-fns/into-list-to-set"
  (define result
    (run-last
      "(eval (into (set-empty Nat) '[1N 2N 3N]))"))
  (check-true (string-contains? result "#{")))

(test-case "collection-fns/into-type-inference"
  ;; Verify the return type matches the target collection type
  (define result
    (run-last
      "(infer (into (pvec-empty Nat) '[1N 2N 3N]))"))
  (check-true (string-contains? result "PVec"))
  (check-true (string-contains? result "Nat")))

;; ========================================
;; Generic first / empty? / rest-seq
;; ========================================

(test-case "collection-fns/head-list-some"
  (define result
    (run-last
      "(eval (head'[1N 2N 3N]))"))
  (check-true (string-contains? result "some"))
  (check-true (string-contains? result "1N")))

(test-case "collection-fns/head-list-none"
  (define result
    (run-last
      "(eval (head(the (List Nat) (nil Nat))))"))
  (check-true (string-contains? result "none")))

(test-case "collection-fns/head-pvec"
  (define result
    (run-last
      "(def v : (PVec Nat) (pvec-push (pvec-push (pvec-empty Nat) 1N) 2N))
       (eval (head v))"))
  (check-true (string-contains? result "some"))
  (check-true (string-contains? result "1N")))

(test-case "collection-fns/empty?-list-true"
  (define result
    (run-last
      "(eval (empty? (the (List Nat) (nil Nat))))"))
  (check-true (string-contains? result "true")))

(test-case "collection-fns/empty?-list-false"
  (define result
    (run-last
      "(eval (empty? '[1N]))"))
  (check-true (string-contains? result "false")))

(test-case "collection-fns/empty?-pvec"
  (define result
    (run-last
      "(eval (empty? (pvec-empty Nat)))"))
  (check-true (string-contains? result "true")))
