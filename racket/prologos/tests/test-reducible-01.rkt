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
;; Reducible trait — type inference
;; ========================================

(test-case "reducible/trait-type"
  ;; Reducible is a single-method trait; dict IS the reduce function
  (define result (run-last "(infer list-reducible)"))
  (check-contains result "Pi")
  (check-contains result "List"))

(test-case "reducible/pvec-dict-type"
  (define result (run-last "(infer pvec-reducible)"))
  (check-contains result "Pi")
  (check-contains result "PVec"))

(test-case "reducible/set-dict-type"
  (define result (run-last "(infer set-reducible)"))
  (check-contains result "Pi")
  (check-contains result "Set"))

(test-case "reducible/lseq-dict-type"
  (define result (run-last "(infer lseq-reducible)"))
  (check-contains result "Pi")
  (check-contains result "LSeq"))

;; ========================================
;; Reducible instances — eval
;; ========================================

(test-case "reducible/list-sum"
  ;; reduce (+) 0 [1,2,3] = 6
  (define result
    (run-last
      "(eval (list-reducible Nat Nat (fn (acc : Nat) (fn (x : Nat) (add acc x))) zero '[1N 2N 3N]))"))
  (check-contains result "6N"))

(test-case "reducible/pvec-sum"
  ;; reduce (+) 0 @[1,2,3] = 6
  (define result
    (run-last
      "(def v : (PVec Nat) (pvec-push (pvec-push (pvec-push (pvec-empty Nat) 1N) 2N) 3N))
       (eval (pvec-reducible Nat Nat (fn (acc : Nat) (fn (x : Nat) (add acc x))) zero v))"))
  (check-contains result "6N"))

(test-case "reducible/set-fold"
  ;; Fold over a set counting elements — result is 3 for a 3-element set
  (define result
    (run-last
      "(def s : (Set Nat) (set-insert (set-insert (set-insert (set-empty Nat) 1N) 2N) 3N))
       (eval (set-reducible Nat Nat (fn (acc : Nat) (fn (_ : Nat) (suc acc))) zero s))"))
  (check-contains result "3N"))

(test-case "reducible/lseq-sum"
  ;; fold over a lazy sequence
  (define result
    (run-last
      "(def xs : (LSeq Nat) (list-to-lseq Nat '[1N 2N 3N]))
       (eval (lseq-reducible Nat Nat (fn (acc : Nat) (fn (x : Nat) (add acc x))) zero xs))"))
  (check-contains result "6N"))

;; ========================================
;; Buildable-conj — type inference
;; ========================================

(test-case "reducible/buildable-conj-accessor-type"
  ;; Buildable-conj accessor should have a Sigma-related type
  (define result (run-last "(infer Buildable-conj)"))
  (check-contains result "Type 0")
  (check-contains result "->"))

;; ========================================
;; Buildable conj instances — eval
;; ========================================

(test-case "reducible/list-conj"
  ;; List conj = cons (prepend)
  ;; conj [2,3] 1 = [1,2,3]
  (define result
    (run-last
      "(eval (Buildable-conj List--Buildable--dict Nat '[2N 3N] 1N))"))
  (check-contains result "'[1N 2N 3N]"))

(test-case "reducible/pvec-conj"
  ;; PVec conj = pvec-push (append)
  ;; conj @[1,2] 3 = @[1,2,3]
  (define result
    (run-last
      "(def v : (PVec Nat) (pvec-push (pvec-push (pvec-empty Nat) 1N) 2N))
       (eval (Buildable-conj PVec--Buildable--dict Nat v 3N))"))
  (check-contains result "@[1N 2N 3N]"))

(test-case "reducible/set-conj"
  ;; Set conj = set-insert
  (define result
    (run-last
      "(def s : (Set Nat) (set-insert (set-insert (set-empty Nat) 1N) 2N))
       (eval (Buildable-conj Set--Buildable--dict Nat s 3N))"))
  (check-contains result "#{"))

