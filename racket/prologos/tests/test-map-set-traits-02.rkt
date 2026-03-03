#lang racket/base

;;;
;;; Tests for Phase 3c: Map/Set Trait Instances + Ops Modules
;;; Tests: keyed-map, setlike-set, seqable-set, buildable-set,
;;;        foldable-set, set-ops, map-ops
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
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
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
;; Preamble — loads Map/Set traits + ops
;; ========================================

(define preamble
  "(ns test)
(imports (prologos::core::collection-traits    :refer (Keyed)))
(imports (prologos::core::collection-traits  :refer (Setlike)))
(imports (prologos::core::collection-traits  :refer (Seqable)))
(imports (prologos::core::collection-traits :refer (Buildable Buildable-from-seq Buildable-empty-coll)))
(imports (prologos::core::collection-traits  :refer (Foldable)))
(imports (prologos::core::map :refer (Map--Keyed--dict map-filter-vals map-keys-list map-vals-list map-merge)))
(imports (prologos::core::set :refer (Set--Setlike--dict Set--Seqable--dict Set--Buildable--dict
                                      set-foldable set-map set-any? set-all? set-to-list-fn set-from-list-fn)))
(imports (prologos::data::lseq           :refer (LSeq lseq-nil lseq-cell)))
(imports (prologos::data::lseq-ops       :refer (lseq-to-list list-to-lseq)))
(imports (prologos::data::option         :refer (Option some none)))
(imports (prologos::data::list           :refer (List nil cons)))
(imports (prologos::data::set            :refer (set-singleton set-from-list)))
")


;; ========================================
;; Seqable Set — type inference
;; ========================================

(test-case "map-set-traits/seqable-set-dict-type"
  (define result (run-ns-last (string-append preamble "(infer Set--Seqable--dict)")))
  (check-contains result "Pi")
  (check-contains result "Set")
  (check-contains result "LSeq"))


(test-case "map-set-traits/seqable-set-to-seq"
  (define result (run-ns-last (string-append preamble
    "(def s <(Set Nat)> (set-insert (set-empty Nat) zero))
     (infer (Set--Seqable--dict Nat s))")))
  (check-contains result "LSeq")
  (check-contains result "Nat"))


;; ========================================
;; Buildable Set — type inference
;; ========================================

(test-case "map-set-traits/buildable-set-dict-type"
  (define result (run-ns-last (string-append preamble "(infer Set--Buildable--dict)")))
  (check-contains result "Sigma")
  (check-contains result "LSeq")
  (check-contains result "Set"))


(test-case "map-set-traits/buildable-set-second"
  ;; second of buildable dict = empty-coll function
  (define result (run-ns-last (string-append preamble
    "(infer (second Set--Buildable--dict))")))
  (check-contains result "Pi")
  (check-contains result "Set"))


;; ========================================
;; Foldable Set — type inference
;; ========================================

(test-case "map-set-traits/foldable-set-dict-type"
  (define result (run-ns-last (string-append preamble "(infer set-foldable)")))
  (check-contains result "Pi")
  (check-contains result "Set"))


;; ========================================
;; Set Ops — type inference
;; ========================================

(test-case "map-set-traits/set-map-type"
  (define result (run-ns-last (string-append preamble "(infer set-map)")))
  (check-contains result "Pi")
  (check-contains result "Set"))


;; set-filter and set-fold are now native parser keywords.
;; Test them in applied form.

(test-case "map-set-traits/set-filter-type"
  (define result (run-ns-last (string-append preamble
    "(def s <(Set Nat)> (set-insert (set-empty Nat) zero))
     (infer (set-filter (fn (x : Nat) true) s))")))
  (check-contains result "Set")
  (check-contains result "Nat"))


(test-case "map-set-traits/set-fold-type"
  (define result (run-ns-last (string-append preamble
    "(imports (prologos::data::nat :refer (add)))
     (def s <(Set Nat)> (set-insert (set-empty Nat) zero))
     (infer (set-fold add zero s))")))
  (check-contains result "Nat"))


(test-case "map-set-traits/set-any-type"
  (define result (run-ns-last (string-append preamble "(infer set-any?)")))
  (check-contains result "Pi")
  (check-contains result "Set")
  (check-contains result "Bool"))


(test-case "map-set-traits/set-all-type"
  (define result (run-ns-last (string-append preamble "(infer set-all?)")))
  (check-contains result "Pi")
  (check-contains result "Set")
  (check-contains result "Bool"))


;; ========================================
;; Map Ops — type inference
;; ========================================

;; map-map-vals and map-fold-entries are now native parser keywords.
;; Test them in applied form.

(test-case "map-set-traits/map-map-vals-type"
  (define result (run-ns-last (string-append preamble
    "(def m : (Map Nat Nat) (map-assoc (map-empty Nat Nat) zero (suc zero)))
     (infer (map-map-vals (fn (v : Nat) (suc v)) m))")))
  (check-contains result "Map")
  (check-contains result "Nat"))


(test-case "map-set-traits/map-fold-entries-type"
  (define result (run-ns-last (string-append preamble
    "(def m : (Map Nat Nat) (map-assoc (map-empty Nat Nat) zero (suc zero)))
     (infer (map-fold-entries (fn (acc : Nat) (fn (k : Nat) (fn (v : Nat) acc))) zero m))")))
  (check-contains result "Nat"))


(test-case "map-set-traits/map-keys-list-type"
  (define result (run-ns-last (string-append preamble "(infer map-keys-list)")))
  (check-contains result "Map")
  (check-contains result "List"))


(test-case "map-set-traits/map-vals-list-type"
  (define result (run-ns-last (string-append preamble "(infer map-vals-list)")))
  (check-contains result "Map")
  (check-contains result "List"))


(test-case "map-set-traits/map-merge-type"
  (define result (run-ns-last (string-append preamble "(infer map-merge)")))
  (check-contains result "Pi")
  (check-contains result "Map"))
