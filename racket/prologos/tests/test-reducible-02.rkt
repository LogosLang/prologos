#lang racket/base

;;;
;;; Tests for Layer 1: Reducible trait + Buildable conj + generic ops rewrite.
;;; Verifies:
;;;   - Reducible trait type inference
;;;   - Reducible instances (List, PVec, Set, LSeq) evaluate correctly
;;;   - Buildable-conj accessor type inference
;;;   - Buildable conj instances (List, PVec, Set) evaluate correctly
;;;   - Generic ops using Reducible (reduce, length, any?, all?, find)
;;;   - Unchanged ops still work (map, filter on Seqable+Buildable path)
;;;   - Collection bundle includes Reducible
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
(imports (prologos::core::collection-traits  :refer (Reducible)))
(imports (prologos::core::collection-traits  :refer (Buildable Buildable-from-seq Buildable-empty-coll Buildable-conj)))
(imports (prologos::core::list   :refer (list-reducible List--Buildable--dict)))
(imports (prologos::core::pvec   :refer (pvec-reducible PVec--Buildable--dict)))
(imports (prologos::core::set    :refer (set-reducible Set--Buildable--dict)))
(imports (prologos::core::lseq   :refer (lseq-reducible)))
(imports (prologos::core::collections   :refer (map filter reduce reduce1 length concat any? all? to-list find take drop into head empty?)))
(imports (prologos::data::nat              :refer (add)))
(imports (prologos::data::lseq             :refer (LSeq lseq-nil lseq-cell)))
(imports (prologos::data::lseq-ops         :refer (lseq-to-list list-to-lseq)))
(imports (prologos::data::list             :refer (List nil cons)))
(imports (prologos::data::option           :refer (Option some none)))
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

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; ========================================
;; Generic reduce (now uses Reducible)
;; ========================================

(test-case "reducible/generic-reduce-list"
  (define result
    (run-last
      "(eval (reduce (fn (acc : Nat) (fn (x : Nat) (add acc x))) zero '[1N 2N 3N]))"))
  (check-contains result "6N"))

(test-case "reducible/generic-reduce-pvec"
  (define result
    (run-last
      "(def v : (PVec Nat) (pvec-push (pvec-push (pvec-push (pvec-empty Nat) 1N) 2N) 3N))
       (eval (reduce (fn (acc : Nat) (fn (x : Nat) (add acc x))) zero v))"))
  (check-contains result "6N"))

;; ========================================
;; Generic length (now uses Reducible)
;; ========================================

(test-case "reducible/generic-length-list"
  (define result (run-last "(eval (length '[1N 2N 3N]))"))
  (check-contains result "3N"))

(test-case "reducible/generic-length-pvec"
  (define result
    (run-last
      "(def v : (PVec Nat) (pvec-push (pvec-push (pvec-empty Nat) 0N) 1N))
       (eval (length v))"))
  (check-contains result "2N"))

(test-case "reducible/generic-length-empty"
  (define result (run-last "(eval (length (the (List Nat) (nil Nat))))"))
  (check-contains result "0N"))

;; ========================================
;; Generic any? / all? (now uses Reducible)
;; ========================================

(test-case "reducible/generic-any-true"
  (define result
    (run-last
      "(spec pos? Nat -> Bool)
       (defn pos? [x] (match x (zero -> false) (suc _ -> true)))
       (eval (any? pos? '[0N 0N 1N]))"))
  (check-contains result "true"))

(test-case "reducible/generic-any-false"
  (define result
    (run-last
      "(spec pos? Nat -> Bool)
       (defn pos? [x] (match x (zero -> false) (suc _ -> true)))
       (eval (any? pos? '[0N 0N 0N]))"))
  (check-contains result "false"))

(test-case "reducible/generic-all-true"
  (define result
    (run-last
      "(spec pos? Nat -> Bool)
       (defn pos? [x] (match x (zero -> false) (suc _ -> true)))
       (eval (all? pos? '[1N 2N 3N]))"))
  (check-contains result "true"))

(test-case "reducible/generic-all-false"
  (define result
    (run-last
      "(spec pos? Nat -> Bool)
       (defn pos? [x] (match x (zero -> false) (suc _ -> true)))
       (eval (all? pos? '[0N 0N 1N]))"))
  (check-contains result "false"))

;; ========================================
;; Generic find (now uses Reducible)
;; ========================================

(test-case "reducible/generic-find-some"
  (define result
    (run-last
      "(spec pos? Nat -> Bool)
       (defn pos? [x] (match x (zero -> false) (suc _ -> true)))
       (eval (find pos? '[0N 1N 2N]))"))
  (check-contains result "some"))

(test-case "reducible/generic-find-none"
  (define result
    (run-last
      "(spec pos? Nat -> Bool)
       (defn pos? [x] (match x (zero -> false) (suc _ -> true)))
       (eval (find pos? '[0N 0N 0N]))"))
  (check-contains result "none"))

;; ========================================
;; Unchanged ops still work (map, filter)
;; ========================================

(test-case "reducible/map-still-works"
  (define result
    (run-last
      "(spec inc Nat -> Nat)
       (defn inc [x] (suc x))
       (eval (map inc '[0N 1N 2N]))"))
  (check-contains result "'[1N 2N 3N]"))

(test-case "reducible/filter-still-works"
  (define result
    (run-last
      "(spec pos? Nat -> Bool)
       (defn pos? [x] (match x (zero -> false) (suc _ -> true)))
       (eval (filter pos? '[0N 1N 2N 0N 3N]))"))
  (check-contains result "'[1N 2N 3N]"))

(test-case "reducible/to-list-still-works"
  (define result
    (run-last
      "(def v : (PVec Nat) (pvec-push (pvec-push (pvec-empty Nat) 1N) 2N))
       (eval (to-list v))"))
  (check-contains result "'[1N 2N]"))
