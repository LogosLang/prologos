#lang racket/base

;;;
;;; Tests for Map <-> LSeq bridge functions.
;;; Verifies map-to-entry-list, map-seq, map-from-seq type-check
;;; and produce correct types.
;;;
;;; NOTE: Full eval of bridge functions is limited by the same
;;; List-conversion reduction issue as other map-ops functions.
;;; Type-correctness (check/infer) is the primary verification.
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
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string s)))

(define (run-last s)
  (last (run-ns s)))

(define (check-contains actual substr [msg #f])
  (check-true (and (string? actual) (string-contains? actual substr))
              (or msg (format "Expected ~s to contain ~s" actual substr))))

(define preamble
  (string-append
    "(ns map-bridge-test)\n"
    "(require (prologos::data::map-entry :refer (MapEntry mk-entry entry-key entry-val))\n"
    "         (prologos::data::lseq :refer (LSeq lseq-nil lseq-cell))\n"
    "         (prologos::data::lseq-ops :refer (list-to-lseq lseq-to-list))\n"
    "         (prologos::core::map :refer (map-to-entry-list map-seq map-from-seq\n"
    "                                       map-filter-vals map-merge)))\n"))

;; Helper: build a 1-entry map {0 -> 1}
(define mk-map1
  "(def m1 : (Map Nat Nat) (map-assoc (map-empty Nat Nat) zero (suc zero)))\n")

;; Helper: build a 2-entry map {0 -> 1, 1 -> 2}
(define mk-map2
  (string-append mk-map1
    "(def m2 : (Map Nat Nat) (map-assoc m1 (suc zero) (suc (suc zero))))\n"))


;; ========================================
;; map-to-entry-list type checks
;; ========================================

(test-case "map-bridge/entry-list-type-empty"
  (check-equal?
    (run-last (string-append preamble
      "(check (map-to-entry-list Nat Nat (map-empty Nat Nat)) : (List (MapEntry Nat Nat)))"))
    "OK"))

(test-case "map-bridge/entry-list-type-singleton"
  (check-equal?
    (run-last (string-append preamble mk-map1
      "(check (map-to-entry-list Nat Nat m1) : (List (MapEntry Nat Nat)))"))
    "OK"))

(test-case "map-bridge/entry-list-infer"
  (define result
    (run-last (string-append preamble mk-map1
      "(infer (map-to-entry-list Nat Nat m1))")))
  (check-contains result "List")
  (check-contains result "MapEntry"))


;; ========================================
;; map-seq type checks
;; ========================================

(test-case "map-bridge/map-seq-type-empty"
  (check-equal?
    (run-last (string-append preamble
      "(check (map-seq Nat Nat (map-empty Nat Nat)) : (LSeq (MapEntry Nat Nat)))"))
    "OK"))

(test-case "map-bridge/map-seq-type-singleton"
  (check-equal?
    (run-last (string-append preamble mk-map1
      "(check (map-seq Nat Nat m1) : (LSeq (MapEntry Nat Nat)))"))
    "OK"))

(test-case "map-bridge/map-seq-infer"
  (define result
    (run-last (string-append preamble mk-map2
      "(infer (map-seq Nat Nat m2))")))
  (check-contains result "LSeq")
  (check-contains result "MapEntry"))


;; ========================================
;; map-from-seq type checks
;; ========================================

(test-case "map-bridge/map-from-seq-type-empty"
  (check-equal?
    (run-last (string-append preamble
      "(check (map-from-seq Nat Nat (lseq-nil (MapEntry Nat Nat))) : (Map Nat Nat))"))
    "OK"))

(test-case "map-bridge/map-from-seq-infer"
  (define result
    (run-last (string-append preamble
      "(infer (map-from-seq Nat Nat (lseq-nil (MapEntry Nat Nat))))")))
  (check-contains result "Map")
  (check-contains result "Nat"))


;; ========================================
;; Roundtrip type checks (map-seq then map-from-seq)
;; ========================================

(test-case "map-bridge/roundtrip-type"
  (check-equal?
    (run-last (string-append preamble mk-map1
      "(check (map-from-seq Nat Nat (map-seq Nat Nat m1)) : (Map Nat Nat))"))
    "OK"))

(test-case "map-bridge/roundtrip-type-2entry"
  (check-equal?
    (run-last (string-append preamble mk-map2
      "(check (map-from-seq Nat Nat (map-seq Nat Nat m2)) : (Map Nat Nat))"))
    "OK"))


;; ========================================
;; Existing map-ops still work with new requires
;; ========================================

(test-case "map-bridge/compat-map-merge"
  (check-equal?
    (run-last (string-append preamble mk-map2
      "(check (map-merge m1 m2) : (Map Nat Nat))"))
    "OK"))

(test-case "map-bridge/compat-eval-map-size"
  (check-equal?
    (run-last (string-append preamble mk-map2
      "(eval (map-size m2))"))
    "2N : Nat"))


;; ========================================
;; Prelude integration (no explicit require needed)
;; ========================================

(test-case "map-bridge/prelude-mapentry-type"
  ;; MapEntry is available from the prelude
  (check-contains
    (run-last
      (string-append
        "(ns prelude-bridge-test-1)\n"
        "(infer (MapEntry Nat Bool))\n"))
    "Type"))

(test-case "map-bridge/prelude-mk-entry-check"
  ;; mk-entry available from prelude
  (check-equal?
    (run-last
      (string-append
        "(ns prelude-bridge-test-2)\n"
        "(check (mk-entry Nat Bool zero true) : (MapEntry Nat Bool))\n"))
    "OK"))

(test-case "map-bridge/prelude-map-seq-check"
  ;; map-seq available from prelude
  (check-equal?
    (run-last
      (string-append
        "(ns prelude-bridge-test-3)\n"
        "(def m : (Map Nat Nat) (map-assoc (map-empty Nat Nat) zero (suc zero)))\n"
        "(check (map-seq Nat Nat m) : (LSeq (MapEntry Nat Nat)))\n"))
    "OK"))

(test-case "map-bridge/prelude-entry-key-eval"
  ;; entry-key available from prelude + reduces correctly
  (check-equal?
    (run-last
      (string-append
        "(ns prelude-bridge-test-4)\n"
        "(eval (entry-key (mk-entry Nat Nat zero (suc zero))))\n"))
    "0N : Nat"))

(test-case "map-bridge/prelude-entry-val-eval"
  ;; entry-val available from prelude + reduces correctly
  (check-equal?
    (run-last
      (string-append
        "(ns prelude-bridge-test-5)\n"
        "(eval (entry-val (mk-entry Nat Nat zero (suc zero))))\n"))
    "1N : Nat"))
