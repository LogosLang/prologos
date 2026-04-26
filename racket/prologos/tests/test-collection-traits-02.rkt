#lang racket/base

;;;
;;; Tests for Phase 5: Collection Traits + List Instances
;;; Tests: seqable-trait, buildable-trait, indexed-trait, keyed-trait, setlike-trait
;;;        seqable-list, buildable-list, indexed-list
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         "test-support.rkt"
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
         "../namespace.rkt"
         "../multi-dispatch.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (run-ns s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string s)))

(define (run-ns-last s)
  (last (run-ns s)))

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; ========================================
;; Preamble — loads all collection traits + list instances
;; ========================================

(define preamble
  "(ns test)
(imports (prologos::core::collection-traits   :refer (Seqable Seqable-to-seq)))
(imports (prologos::core::collection-traits :refer (Buildable Buildable-from-seq Buildable-empty-coll)))
(imports (prologos::core::collection-traits   :refer (Indexed Indexed-idx-nth Indexed-idx-length Indexed-idx-update)))
(imports (prologos::core::collection-traits     :refer (Keyed Keyed-kv-get Keyed-kv-assoc Keyed-kv-dissoc)))
(imports (prologos::core::collection-traits   :refer (Setlike Setlike-set-member? Setlike-set-insert Setlike-set-remove)))
(imports (prologos::core::list    :refer (List--Seqable--dict List--Buildable--dict List--Buildable--from-seq List--Buildable--empty-coll List--Indexed--dict list-idx-nth list-idx-length list-idx-update)))
(imports (prologos::data::lseq            :refer (LSeq lseq-nil lseq-cell)))
(imports (prologos::data::lseq-ops        :refer (lseq-to-list list-to-lseq)))
(imports (prologos::data::option          :refer (Option some none)))
(imports (prologos::data::list            :refer (List nil cons)))
")


;; ========================================
;; Buildable List — functional tests
;; ========================================

(test-case "collection/buildable-list-from-seq"
  ;; from-seq materializes an lseq back to a list
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (List--Buildable--from-seq Nat (list-to-lseq Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "'[1N 2N]"))


(test-case "collection/buildable-list-from-seq-empty"
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (List--Buildable--from-seq Nat (lseq-nil Nat)))"))
   "nil"))


(test-case "collection/buildable-list-empty-coll"
  ;; empty-coll returns nil for the given type
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (List--Buildable--empty-coll Nat))"))
   "nil"))


(test-case "collection/buildable-list-roundtrip"
  ;; from-seq (to-seq xs) = xs
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (List--Buildable--from-seq Nat (List--Seqable--dict Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "'[1N 2N 3N]"))


;; ========================================
;; Indexed List — functional tests
;; ========================================

(test-case "collection/indexed-list-nth-first"
  ;; idx-nth [1,2,3] 0 = some 1
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (list-idx-nth Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))) zero))"))
   "some"))


(test-case "collection/indexed-list-nth-first-value"
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (list-idx-nth Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))) zero))"))
   "1"))


(test-case "collection/indexed-list-nth-middle"
  ;; idx-nth [1,2,3] 1 = some 2
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (list-idx-nth Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))) (suc zero)))"))
   "2"))


(test-case "collection/indexed-list-nth-out-of-bounds"
  ;; idx-nth [1,2,3] 5 = none
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (list-idx-nth Nat (cons Nat (suc zero) (nil Nat)) (suc (suc (suc (suc (suc zero)))))))"))
   "none"))


(test-case "collection/indexed-list-nth-empty"
  ;; idx-nth [] 0 = none
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (list-idx-nth Nat (nil Nat) zero))"))
   "none"))


(test-case "collection/indexed-list-length-empty"
  ;; length [] = 0
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (list-idx-length Nat (nil Nat)))"))
   "0N"))


(test-case "collection/indexed-list-length-nonempty"
  ;; length [1,2,3] = 3
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (list-idx-length Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
   "3"))


(test-case "collection/indexed-list-update-first"
  ;; update [1,2,3] 0 7 → [7,2,3]
  (define result (run-ns-last (string-append preamble
    "(eval (list-idx-update Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))) zero (suc (suc (suc (suc (suc (suc (suc zero)))))))))")))
  (check-contains result "7")
  (check-contains result "List"))


(test-case "collection/indexed-list-update-out-of-bounds"
  ;; update [1] 5 7 → [1] (unchanged, index out of bounds)
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (list-idx-update Nat (cons Nat (suc zero) (nil Nat)) (suc (suc (suc (suc (suc zero))))) (suc (suc (suc (suc (suc (suc (suc zero)))))))))"))
   "'[1N]"))


;; ========================================
;; Indexed dict — accessor usage
;; ========================================

(test-case "collection/indexed-dict-accessors"
  ;; Verify all three accessor types infer through the dict
  (define results (run-ns (string-append preamble
    "(infer list-idx-nth)
     (infer list-idx-length)
     (infer list-idx-update)")))
  (define type-results (filter string? results))
  (check-true (>= (length type-results) 3)
              "Expected at least 3 type-string results"))


;; ========================================
;; Module loading tests
;; ========================================

(test-case "collection/all-trait-modules-load"
  ;; Verify all 5 trait modules load
  (define results (run-ns (string-append preamble
    "(infer Seqable-to-seq)
     (infer Buildable-from-seq)
     (infer Buildable-empty-coll)
     (infer Indexed-idx-nth)
     (infer Indexed-idx-length)
     (infer Indexed-idx-update)
     (infer Keyed-kv-get)
     (infer Keyed-kv-assoc)
     (infer Keyed-kv-dissoc)
     (infer Setlike-set-member?)
     (infer Setlike-set-insert)
     (infer Setlike-set-remove)")))
  (define type-results (filter string? results))
  (check-true (>= (length type-results) 12)
              "Expected at least 12 type-string results for all trait accessors"))


(test-case "collection/all-list-instances-load"
  ;; Verify all 3 list instance modules load
  (define results (run-ns (string-append preamble
    "(infer List--Seqable--dict)
     (infer List--Buildable--dict)
     (infer List--Indexed--dict)")))
  (define type-results (filter string? results))
  (check-true (>= (length type-results) 3)
              "Expected at least 3 type-string results for List instance dicts"))
