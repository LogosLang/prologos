#lang racket/base

;;;
;;; Correctness tests for pvec-ops functions.
;;; Verifies that operations type-check correctly on concrete inputs.
;;;
;;; NOTE: Full eval (runtime reduction) of pvec-ops functions is blocked
;;; because pvec-to-list produces runtime values that library functions
;;; (map, filter, foldr) can't step through in the reduction engine.
;;; This will be resolved when native AST primitives replace the
;;; List-conversion pattern (Stage C of collections ergonomics).
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

(define preamble "(ns pvec-ops-eval-test)\n")

;; Helper PVec definitions
(define mk-vec
  (string-append
    "(def v1 (pvec-push (pvec-empty Nat) zero))\n"
    "(def v2 (pvec-push (pvec-push (pvec-empty Nat) zero) (suc zero)))\n"))

;; ========================================
;; pvec-map — type correctness on concrete inputs
;; ========================================

(test-case "pvec-ops-eval/pvec-map-result-type-nat"
  ;; pvec-map with Nat -> Nat function preserves PVec Nat
  (define result (run-last (string-append preamble mk-vec
    "(check (pvec-map (fn (x : Nat) (suc x)) v2) : (PVec Nat))")))
  (check-equal? result "OK"))

(test-case "pvec-ops-eval/pvec-map-result-type-bool"
  ;; pvec-map with Nat -> Bool changes element type to PVec Bool
  (define result (run-last (string-append preamble mk-vec
    "(check (pvec-map (fn (x : Nat) (zero? x)) v2) : (PVec Bool))")))
  (check-equal? result "OK"))

(test-case "pvec-ops-eval/pvec-map-infer-applied"
  ;; Applied pvec-map infers to PVec Nat
  (define result (run-last (string-append preamble mk-vec
    "(infer (pvec-map (fn (x : Nat) (suc x)) v2))")))
  (check-contains result "PVec")
  (check-contains result "Nat"))

;; ========================================
;; pvec-filter — type correctness on concrete inputs
;; ========================================

(test-case "pvec-ops-eval/pvec-filter-result-type"
  (define result (run-last (string-append preamble mk-vec
    "(check (pvec-filter (fn (x : Nat) (zero? x)) v2) : (PVec Nat))")))
  (check-equal? result "OK"))

(test-case "pvec-ops-eval/pvec-filter-infer"
  (define result (run-last (string-append preamble mk-vec
    "(infer (pvec-filter (fn (x : Nat) (zero? x)) v2))")))
  (check-contains result "PVec")
  (check-contains result "Nat"))

;; ========================================
;; pvec-fold — type correctness on concrete inputs
;; ========================================

(test-case "pvec-ops-eval/pvec-fold-result-nat"
  ;; pvec-fold with Nat -> Nat -> Nat step, Nat init → result Nat
  (define result (run-last (string-append preamble mk-vec
    "(check (pvec-fold (fn (acc : Nat) (fn (x : Nat) (suc acc))) zero v2) : Nat)")))
  (check-equal? result "OK"))

(test-case "pvec-ops-eval/pvec-fold-cross-type"
  ;; pvec-fold with Bool -> Nat -> Bool step → result Bool
  (define result (run-last (string-append preamble mk-vec
    "(check (pvec-fold (fn (acc : Bool) (fn (_ : Nat) acc)) true v2) : Bool)")))
  (check-equal? result "OK"))

;; ========================================
;; pvec-any? / pvec-all? — type correctness
;; ========================================

(test-case "pvec-ops-eval/pvec-any-result-type"
  (define result (run-last (string-append preamble mk-vec
    "(check (pvec-any? (fn (x : Nat) (zero? x)) v2) : Bool)")))
  (check-equal? result "OK"))

(test-case "pvec-ops-eval/pvec-all-result-type"
  (define result (run-last (string-append preamble mk-vec
    "(check (pvec-all? (fn (x : Nat) (zero? x)) v2) : Bool)")))
  (check-equal? result "OK"))

;; ========================================
;; pvec-from-list-fn / pvec-to-list-fn — type correctness
;; ========================================

(test-case "pvec-ops-eval/pvec-from-list-fn-type"
  (define result (run-last (string-append preamble
    "(check (pvec-from-list-fn (cons Nat zero (nil Nat))) : (PVec Nat))")))
  (check-equal? result "OK"))

(test-case "pvec-ops-eval/pvec-to-list-fn-type"
  (define result (run-last (string-append preamble mk-vec
    "(check (pvec-to-list-fn v1) : (List Nat))")))
  (check-equal? result "OK"))

;; ========================================
;; Direct AST keyword eval (these DO fully reduce)
;; ========================================

(test-case "pvec-ops-eval/pvec-push-length-eval"
  (define result (run-last (string-append preamble
    "(eval (pvec-length (pvec-push (pvec-push (pvec-empty Nat) zero) (suc zero))))")))
  (check-equal? result "2N : Nat"))

(test-case "pvec-ops-eval/pvec-nth-eval"
  (define result (run-last (string-append preamble
    "(eval (pvec-nth (pvec-push (pvec-push (pvec-empty Nat) zero) (suc zero)) (suc zero)))")))
  (check-equal? result "1N : Nat"))
