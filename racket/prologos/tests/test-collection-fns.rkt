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
;; Module loading test
;; ========================================

(test-case "collection-fns/module-loads"
  (check-not-exn
    (lambda ()
      (run-ns-all
        "(ns cfn-load-test)
         (require (prologos::core::collection-fns :refer (map filter reduce length concat any? all? to-list find take drop)))"))))

;; ========================================
;; Generic map — type checks
;; ========================================

(test-case "collection-fns/map-list-type"
  (define result
    (run-ns-last
      "(ns cfn-map-1)
       (require (prologos::core::collection-fns :refer (map)))
       (spec inc Nat -> Nat)
       (defn inc [x] (suc x))
       (infer (map inc '[0N 1N 2N]))"))
  (check-true (string-contains? result "List"))
  (check-true (string-contains? result "Nat")))

(test-case "collection-fns/map-list-eval"
  (define result
    (run-ns-last
      "(ns cfn-map-2)
       (require (prologos::core::collection-fns :refer (map)))
       (spec inc Nat -> Nat)
       (defn inc [x] (suc x))
       (eval (map inc '[0N 1N 2N]))"))
  (check-true (string-contains? result "'[1N 2N 3N]")))

(test-case "collection-fns/map-pvec-type"
  (define result
    (run-ns-last
      "(ns cfn-map-3)
       (require (prologos::core::collection-fns :refer (map)))
       (spec inc Nat -> Nat)
       (defn inc [x] (suc x))
       (def v : (PVec Nat) (pvec-push (pvec-push (pvec-empty Nat) 0N) 1N))
       (infer (map inc v))"))
  (check-true (string-contains? result "PVec"))
  (check-true (string-contains? result "Nat")))

(test-case "collection-fns/map-pvec-eval"
  (define result
    (run-ns-last
      "(ns cfn-map-4)
       (require (prologos::core::collection-fns :refer (map)))
       (spec inc Nat -> Nat)
       (defn inc [x] (suc x))
       (def v : (PVec Nat) (pvec-push (pvec-push (pvec-empty Nat) 0N) 1N))
       (eval (map inc v))"))
  (check-true (string-contains? result "@[1N 2N]")))

;; ========================================
;; Generic filter — type checks + eval
;; ========================================

(test-case "collection-fns/filter-list-eval"
  (define result
    (run-ns-last
      "(ns cfn-filter-1)
       (require (prologos::core::collection-fns :refer (filter)))
       (spec pos? Nat -> Bool)
       (defn pos? [x] (match x (zero -> false) (suc _ -> true)))
       (eval (filter pos? '[0N 1N 2N 0N 3N]))"))
  (check-true (string-contains? result "'[1N 2N 3N]")))

;; ========================================
;; Generic reduce — type checks + eval
;; ========================================

(test-case "collection-fns/reduce-list-eval"
  (define result
    (run-ns-last
      "(ns cfn-reduce-1)
       (require (prologos::core::collection-fns :refer (reduce)))
       (require (prologos::data::nat :refer (add)))
       (eval (reduce (fn (acc : Nat) (fn (x : Nat) (add acc x))) zero '[1N 2N 3N]))"))
  (check-true (string-contains? result "6N")))

;; ========================================
;; Generic reduce1 — first-element-as-init
;; ========================================

(test-case "collection-fns/reduce1-list-some"
  (define result
    (run-ns-last
      "(ns cfn-reduce1-1)
       (require (prologos::core::collection-fns :refer (reduce1)))
       (require (prologos::data::nat :refer (add)))
       (eval (reduce1 add '[1N 2N 3N]))"))
  (check-true (string-contains? result "some"))
  (check-true (string-contains? result "6N")))

(test-case "collection-fns/reduce1-list-none"
  (define result
    (run-ns-last
      "(ns cfn-reduce1-2)
       (require (prologos::core::collection-fns :refer (reduce1)))
       (require (prologos::data::nat :refer (add)))
       (eval (reduce1 add (the (List Nat) (nil Nat))))"))
  (check-true (string-contains? result "none")))

(test-case "collection-fns/reduce1-pvec"
  (define result
    (run-ns-last
      "(ns cfn-reduce1-3)
       (require (prologos::core::collection-fns :refer (reduce1)))
       (require (prologos::data::nat :refer (add)))
       (def v : (PVec Nat) (pvec-push (pvec-push (pvec-push (pvec-empty Nat) 1N) 2N) 3N))
       (eval (reduce1 add v))"))
  (check-true (string-contains? result "some"))
  (check-true (string-contains? result "6N")))

;; ========================================
;; Generic length
;; ========================================

(test-case "collection-fns/length-list-eval"
  (define result
    (run-ns-last
      "(ns cfn-length-1)
       (require (prologos::core::collection-fns :refer (length)))
       (eval (length '[1N 2N 3N]))"))
  (check-true (string-contains? result "3N")))

(test-case "collection-fns/length-pvec-eval"
  (define result
    (run-ns-last
      "(ns cfn-length-2)
       (require (prologos::core::collection-fns :refer (length)))
       (def v : (PVec Nat) (pvec-push (pvec-push (pvec-empty Nat) 0N) 1N))
       (eval (length v))"))
  (check-true (string-contains? result "2N")))

;; ========================================
;; Generic any? / all?
;; ========================================

(test-case "collection-fns/any-list-true"
  (define result
    (run-ns-last
      "(ns cfn-any-1)
       (require (prologos::core::collection-fns :refer (any?)))
       (spec pos? Nat -> Bool)
       (defn pos? [x] (match x (zero -> false) (suc _ -> true)))
       (eval (any? pos? '[0N 0N 1N]))"))
  (check-true (string-contains? result "true")))

(test-case "collection-fns/all-list-false"
  (define result
    (run-ns-last
      "(ns cfn-all-1)
       (require (prologos::core::collection-fns :refer (all?)))
       (spec pos? Nat -> Bool)
       (defn pos? [x] (match x (zero -> false) (suc _ -> true)))
       (eval (all? pos? '[0N 0N 1N]))"))
  (check-true (string-contains? result "false")))

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
