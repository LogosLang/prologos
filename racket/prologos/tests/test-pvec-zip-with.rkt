#lang racket/base

;;;
;;; Tests for pvec-zip-with library function.
;;; Addresses eigentrust pitfalls doc #13: provide a zip-with equivalent for
;;; PVec so elementwise operations on two PVecs do not require explicit
;;; index-threaded-accumulator recursion in user code.
;;;
;;; Signature: pvec-zip-with : (A -> B -> C) -> PVec A -> PVec B -> PVec C
;;; Truncates to the length of the shorter input (mirrors List zip-with).
;;;

(require rackunit
         racket/string
         "test-support.rkt")

;; ========================================
;; Helpers
;; ========================================
;; Use test-support.rkt's run-ns-* helpers (canonical post-S2.e pattern;
;; the manual parameterize block here referenced retired `current-mult-meta-store`
;; and friends — fixed 2026-04-27).

(define (run-last s) (run-ns-last s))

(define (check-contains actual substr [msg #f])
  (check-true (and (string? actual) (string-contains? actual substr))
              (or msg (format "Expected ~s to contain ~s" actual substr))))

(define preamble
  (string-append
    "(ns pvec-zip-with-test)\n"
    "(require [prologos::core::pvec :refer [pvec-zip-with]])\n"))

;; ========================================
;; 1. Equal-length pvecs (basic case)
;; ========================================

(test-case "pvec-zip-with/equal-length: type-checks against PVec Nat"
  (define result
    (run-last
      (string-append preamble
        "(check (pvec-zip-with add @[1N 2N 3N] @[10N 20N 30N]) : (PVec Nat))\n")))
  (check-equal? result "OK"))

(test-case "pvec-zip-with/equal-length: elementwise add yields expected length"
  ;; @[1+10, 2+20, 3+30] = @[11, 22, 33]; length 3
  (define result
    (run-last
      (string-append preamble
        "(eval (pvec-length"
        "         (pvec-zip-with add @[1N 2N 3N] @[10N 20N 30N])))\n")))
  (check-equal? result "3N : Nat"))

(test-case "pvec-zip-with/equal-length: elementwise add nth=0 yields 11"
  (define result
    (run-last
      (string-append preamble
        "(eval (pvec-nth"
        "         (pvec-zip-with add @[1N 2N 3N] @[10N 20N 30N])"
        "         zero))\n")))
  (check-equal? result "11N : Nat"))

(test-case "pvec-zip-with/equal-length: elementwise add nth=2 yields 33"
  (define result
    (run-last
      (string-append preamble
        "(eval (pvec-nth"
        "         (pvec-zip-with add @[1N 2N 3N] @[10N 20N 30N])"
        "         (suc (suc zero))))\n")))
  (check-equal? result "33N : Nat"))

;; ========================================
;; 2. Truncation: shorter-first (xs shorter)
;; ========================================

(test-case "pvec-zip-with/truncate-xs-shorter: length is min(2,4)=2"
  (define result
    (run-last
      (string-append preamble
        "(eval (pvec-length"
        "         (pvec-zip-with add @[1N 2N] @[10N 20N 30N 40N])))\n")))
  (check-equal? result "2N : Nat"))

;; ========================================
;; 3. Truncation: shorter-second (ys shorter)
;; ========================================

(test-case "pvec-zip-with/truncate-ys-shorter: length is min(4,1)=1"
  (define result
    (run-last
      (string-append preamble
        "(eval (pvec-length"
        "         (pvec-zip-with add @[1N 2N 3N 4N] @[100N])))\n")))
  (check-equal? result "1N : Nat"))

(test-case "pvec-zip-with/truncate-ys-shorter: nth=0 yields 1+100=101"
  (define result
    (run-last
      (string-append preamble
        "(eval (pvec-nth"
        "         (pvec-zip-with add @[1N 2N 3N 4N] @[100N])"
        "         zero))\n")))
  (check-equal? result "101N : Nat"))

;; ========================================
;; 4. Empty inputs
;; ========================================

(test-case "pvec-zip-with/both-empty: yields empty PVec (length 0)"
  (define result
    (run-last
      (string-append preamble
        "(check (pvec-zip-with add @[] @[]) : (PVec Nat))\n")))
  (check-equal? result "OK"))

(test-case "pvec-zip-with/xs-empty: yields empty PVec (length 0)"
  (define result
    (run-last
      (string-append preamble
        "(eval (pvec-length"
        "         (pvec-zip-with add @[] @[1N 2N 3N])))\n")))
  (check-equal? result "0N : Nat"))

;; ========================================
;; 5. Heterogeneous: f changes element type (Nat -> Nat -> Bool)
;; ========================================

(test-case "pvec-zip-with/result-type: PVec Bool when f returns Bool"
  ;; (fn x y -> zero? x) :: Nat -> Nat -> Bool
  (define result
    (run-last
      (string-append preamble
        "(check (pvec-zip-with"
        "         (fn (x : Nat) (y : Nat) (zero? x))"
        "         @[0N 1N]"
        "         @[10N 20N]) : (PVec Bool))\n")))
  (check-equal? result "OK"))

;; ========================================
;; 6. Eigentrust use case mirror: pvec-zip-with with named binary op
;; ========================================
;; The eigentrust pitfalls doc's motivating example was elementwise addition over
;; two reputation vectors. Verify that pattern works end-to-end.

(test-case "pvec-zip-with/eigentrust-mirror: add two equal-length vectors"
  (define result
    (run-last
      (string-append preamble
        "(eval (pvec-to-list"
        "         (pvec-zip-with add @[5N 7N 11N] @[2N 3N 4N])))\n")))
  (check-contains result "7N")    ; 5 + 2
  (check-contains result "10N")   ; 7 + 3
  (check-contains result "15N"))  ; 11 + 4
