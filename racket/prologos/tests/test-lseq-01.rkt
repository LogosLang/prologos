#lang racket/base

;;;
;;; Tests for Phase 4: LSeq — Lazy Sequence Data Type
;;; Tests lseq.prologos (data type + accessors) and
;;; lseq-ops.prologos (list-to-lseq, lseq-to-list, lseq-map, etc.)
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

;; Standard preamble for tests: load lseq + lseq-ops + list + option + nat
(define preamble
  "(ns test)
(imports (prologos::data::lseq :refer (LSeq lseq-nil lseq-cell lseq-head lseq-rest lseq-empty?))
         (prologos::data::lseq-ops :refer (list-to-lseq lseq-to-list lseq-map lseq-filter lseq-take lseq-drop lseq-append lseq-fold lseq-length))
         (prologos::data::list :refer (List nil cons))
         (prologos::data::option :refer (Option some none))
         (prologos::data::nat :refer (add mult)))
")

;; Helper: check that a result string contains a substring
(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))


;; ========================================
;; LSeq Data Type — Basic Tests
;; ========================================

(test-case "lseq/type-check"
  ;; (LSeq Nat) should be a Type
  (check-contains
   (run-ns-last (string-append preamble "(infer (LSeq Nat))"))
   "Type"))


(test-case "lseq/lseq-nil-type"
  ;; lseq-nil Nat : LSeq Nat
  (define result (run-ns-last (string-append preamble "(eval (lseq-nil Nat))")))
  (check-contains result "lseq-nil")
  (check-contains result "LSeq Nat"))


(test-case "lseq/lseq-empty?-nil"
  ;; lseq-empty? on nil → true
  (check-contains
   (run-ns-last (string-append preamble "(eval (lseq-empty? Nat (lseq-nil Nat)))"))
   "true : Bool"))


(test-case "lseq/lseq-empty?-cell"
  ;; lseq-empty? on cell → false
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (lseq-empty? Nat (lseq-cell Nat zero (fn (_ : Unit) (lseq-nil Nat)))))"))
   "false : Bool"))


(test-case "lseq/lseq-head-nil"
  ;; lseq-head on nil → none
  (define result (run-ns-last (string-append preamble "(eval (lseq-head Nat (lseq-nil Nat)))")))
  (check-contains result "none")
  (check-contains result "Option Nat"))


(test-case "lseq/lseq-head-cell"
  ;; lseq-head on cell → some 1
  (define result (run-ns-last (string-append preamble
     "(eval (lseq-head Nat (lseq-cell Nat (suc zero) (fn (_ : Unit) (lseq-nil Nat)))))")))
  (check-contains result "some")
  (check-contains result "1"))


(test-case "lseq/lseq-rest-nil"
  ;; lseq-rest on nil → nil
  (define result (run-ns-last (string-append preamble "(eval (lseq-rest Nat (lseq-nil Nat)))")))
  (check-contains result "lseq-nil")
  (check-contains result "LSeq Nat"))


(test-case "lseq/lseq-rest-cell"
  ;; lseq-rest on cell → forced tail (should be nil)
  (define result (run-ns-last (string-append preamble
     "(eval (lseq-rest Nat (lseq-cell Nat (suc zero) (fn (_ : Unit) (lseq-nil Nat)))))")))
  (check-contains result "lseq-nil")
  (check-contains result "LSeq Nat"))


;; ========================================
;; LSeq-Ops — Conversion
;; ========================================

(test-case "lseq-ops/list-to-lseq-nil"
  ;; Empty list → empty lseq
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (lseq-empty? Nat (list-to-lseq Nat (nil Nat))))"))
   "true : Bool"))


(test-case "lseq-ops/round-trip"
  ;; Convert list → lseq → list preserves structure
  (define result (run-ns-last (string-append preamble
     "(def list123 : (List Nat) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))
      (eval (lseq-to-list Nat (list-to-lseq Nat list123)))")))
  (check-contains result "'[1N 2N 3N]")
  (check-contains result "List Nat"))


(test-case "lseq-ops/round-trip-empty"
  ;; Empty round-trip
  (define result (run-ns-last (string-append preamble
     "(eval (lseq-to-list Nat (list-to-lseq Nat (nil Nat))))")))
  (check-contains result "nil")
  (check-contains result "List Nat"))
