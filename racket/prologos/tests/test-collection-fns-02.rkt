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
;; Generic to-list
;; ========================================

(test-case "collection-fns/to-list-pvec-eval"
  (define result
    (run-ns-last
      "(ns cfn-tolist-1)
       (require (prologos::core::collection-fns :refer (to-list)))
       (def v : (PVec Nat) (pvec-push (pvec-push (pvec-empty Nat) 1N) 2N))
       (eval (to-list v))"))
  (check-true (string-contains? result "'[1N 2N]")))

;; ========================================
;; Generic find
;; ========================================

(test-case "collection-fns/find-list-some"
  (define result
    (run-ns-last
      "(ns cfn-find-1)
       (require (prologos::core::collection-fns :refer (find)))
       (spec pos? Nat -> Bool)
       (defn pos? [x] (match x (zero -> false) (suc _ -> true)))
       (eval (find pos? '[0N 1N 2N]))"))
  (check-true (string-contains? result "some")))

(test-case "collection-fns/find-list-none"
  (define result
    (run-ns-last
      "(ns cfn-find-2)
       (require (prologos::core::collection-fns :refer (find)))
       (spec pos? Nat -> Bool)
       (defn pos? [x] (match x (zero -> false) (suc _ -> true)))
       (eval (find pos? '[0N 0N 0N]))"))
  (check-true (string-contains? result "none")))

;; ========================================
;; Generic take / drop
;; ========================================

(test-case "collection-fns/take-list-eval"
  (define result
    (run-ns-last
      "(ns cfn-take-1)
       (require (prologos::core::collection-fns :refer (take)))
       (eval (take (suc (suc zero)) '[1N 2N 3N 4N]))"))
  (check-true (string-contains? result "'[1N 2N]")))

(test-case "collection-fns/drop-list-eval"
  (define result
    (run-ns-last
      "(ns cfn-drop-1)
       (require (prologos::core::collection-fns :refer (drop)))
       (eval (drop (suc (suc zero)) '[1N 2N 3N 4N]))"))
  (check-true (string-contains? result "'[3N 4N]")))

;; ========================================
;; Generic into — collection conversion
;; ========================================

(test-case "collection-fns/into-list-to-pvec"
  (define result
    (run-ns-last
      "(ns cfn-into-1)
       (require (prologos::core::collection-fns :refer (into)))
       (eval (into (pvec-empty Nat) '[1N 2N 3N]))"))
  (check-true (string-contains? result "@[1N 2N 3N]")))

(test-case "collection-fns/into-pvec-to-list"
  (define result
    (run-ns-last
      "(ns cfn-into-2)
       (require (prologos::core::collection-fns :refer (into)))
       (def v : (PVec Nat) (pvec-push (pvec-push (pvec-push (pvec-empty Nat) 1N) 2N) 3N))
       (eval (into (the (List Nat) (nil Nat)) v))"))
  (check-true (string-contains? result "'[1N 2N 3N]")))

(test-case "collection-fns/into-list-to-set"
  (define result
    (run-ns-last
      "(ns cfn-into-3)
       (require (prologos::core::collection-fns :refer (into)))
       (eval (into (set-empty Nat) '[1N 2N 3N]))"))
  (check-true (string-contains? result "#{")))

(test-case "collection-fns/into-type-inference"
  ;; Verify the return type matches the target collection type
  (define result
    (run-ns-last
      "(ns cfn-into-4)
       (require (prologos::core::collection-fns :refer (into)))
       (infer (into (pvec-empty Nat) '[1N 2N 3N]))"))
  (check-true (string-contains? result "PVec"))
  (check-true (string-contains? result "Nat")))

;; ========================================
;; Generic first / empty? / rest-seq
;; ========================================

(test-case "collection-fns/head-list-some"
  (define result
    (run-ns-last
      "(ns cfn-first-1)
       (require (prologos::core::collection-fns :refer (head)))
       (eval (head'[1N 2N 3N]))"))
  (check-true (string-contains? result "some"))
  (check-true (string-contains? result "1N")))

(test-case "collection-fns/head-list-none"
  (define result
    (run-ns-last
      "(ns cfn-first-2)
       (require (prologos::core::collection-fns :refer (head)))
       (eval (head(the (List Nat) (nil Nat))))"))
  (check-true (string-contains? result "none")))

(test-case "collection-fns/head-pvec"
  (define result
    (run-ns-last
      "(ns cfn-first-3)
       (require (prologos::core::collection-fns :refer (head)))
       (def v : (PVec Nat) (pvec-push (pvec-push (pvec-empty Nat) 1N) 2N))
       (eval (head v))"))
  (check-true (string-contains? result "some"))
  (check-true (string-contains? result "1N")))

(test-case "collection-fns/empty?-list-true"
  (define result
    (run-ns-last
      "(ns cfn-empty-1)
       (require (prologos::core::collection-fns :refer (empty?)))
       (eval (empty? (the (List Nat) (nil Nat))))"))
  (check-true (string-contains? result "true")))

(test-case "collection-fns/empty?-list-false"
  (define result
    (run-ns-last
      "(ns cfn-empty-2)
       (require (prologos::core::collection-fns :refer (empty?)))
       (eval (empty? '[1N]))"))
  (check-true (string-contains? result "false")))

(test-case "collection-fns/empty?-pvec"
  (define result
    (run-ns-last
      "(ns cfn-empty-3)
       (require (prologos::core::collection-fns :refer (empty?)))
       (eval (empty? (pvec-empty Nat)))"))
  (check-true (string-contains? result "true")))
