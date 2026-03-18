#lang racket/base

;;;
;;; Tests for Quire accumulators — core AST + surface syntax end-to-end
;;;
;;; Quire is an exact accumulator for fused multiply-add operations.
;;; quire-zero starts at 0, quire-fma(q, a, b) = q + a*b, quire-to converts back to posit.
;;;

(require racket/string
         rackunit
         "../syntax.rkt"
         "../prelude.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../pretty-print.rkt"
         "../driver.rkt"
         "../global-env.rkt")

;; Posit constants (encoded bit patterns):
;; Posit8:  zero=0, one=64, two=72, NaR=128
;; Posit16: zero=0, one=16384, two=18432, NaR=32768
;; Posit32: zero=0, one=1073741824, two=1207959552, three=1275068416, NaR=2147483648
;; Posit64: zero=0, one=4611686018427387904, two=5188146770730811392, NaR=9223372036854775808

;; ========================================
;; Quire8: Type formation + core AST
;; ========================================

(test-case "Quire8 type formation"
  (check-equal? (tc:infer ctx-empty (expr-Quire8))
                (expr-Type (lzero))
                "Quire8 : Type 0")
  (check-equal? (tc:infer-level ctx-empty (expr-Quire8))
                (tc:just-level (lzero))
                "Quire8 at level 0")
  (check-true (tc:is-type ctx-empty (expr-Quire8))
              "Quire8 is a type"))

(test-case "quire8-val typing"
  (check-equal? (tc:infer ctx-empty (expr-quire8-val 0))
                (expr-Quire8)
                "quire8-val(0) : Quire8")
  (check-true (tc:check ctx-empty (expr-quire8-val 0) (expr-Quire8))
              "check quire8-val(0) : Quire8"))

(test-case "quire8 fma typing"
  (check-equal? (tc:infer ctx-empty
                  (expr-quire8-fma (expr-quire8-val 0) (expr-posit8 64) (expr-posit8 64)))
                (expr-Quire8)
                "quire8-fma : Quire8")
  ;; Type error: wrong arg types
  (check-equal? (tc:infer ctx-empty
                  (expr-quire8-fma (expr-quire8-val 0) (expr-true) (expr-posit8 64)))
                (expr-error)
                "quire8-fma rejects non-Posit8 arg"))

(test-case "quire8 to typing"
  (check-equal? (tc:infer ctx-empty (expr-quire8-to (expr-quire8-val 0)))
                (expr-Posit8)
                "quire8-to : Posit8")
  ;; Type error: wrong arg type
  (check-equal? (tc:infer ctx-empty (expr-quire8-to (expr-true)))
                (expr-error)
                "quire8-to rejects non-Quire8 arg"))

(test-case "quire8 fma reduction"
  ;; fma(0, 1, 1) = 0 + 1*1 = 1
  (check-equal? (whnf (expr-quire8-fma (expr-quire8-val 0) (expr-posit8 64) (expr-posit8 64)))
                (expr-quire8-val 1)
                "q8-fma(0, 1, 1) = 1")
  ;; fma(0, 1, 2) = 0 + 1*2 = 2
  (check-equal? (whnf (expr-quire8-fma (expr-quire8-val 0) (expr-posit8 64) (expr-posit8 72)))
                (expr-quire8-val 2)
                "q8-fma(0, 1, 2) = 2"))

(test-case "quire8 to reduction"
  ;; to(quire-val(1)) = posit8-encode(1) = 64
  (check-equal? (whnf (expr-quire8-to (expr-quire8-val 1)))
                (expr-posit8 64)
                "q8-to(1) = posit8(64)")
  ;; to(quire-val(0)) = posit8(0)
  (check-equal? (whnf (expr-quire8-to (expr-quire8-val 0)))
                (expr-posit8 0)
                "q8-to(0) = posit8(0)"))

(test-case "quire8 NaR propagation"
  ;; fma with NaR posit
  (check-equal? (whnf (expr-quire8-fma (expr-quire8-val 0) (expr-posit8 128) (expr-posit8 64)))
                (expr-quire8-val 'nar)
                "q8-fma(0, NaR, 1) = nar")
  ;; fma on nar accumulator
  (check-equal? (whnf (expr-quire8-fma (expr-quire8-val 'nar) (expr-posit8 64) (expr-posit8 64)))
                (expr-quire8-val 'nar)
                "q8-fma(nar, 1, 1) = nar")
  ;; to on nar
  (check-equal? (whnf (expr-quire8-to (expr-quire8-val 'nar)))
                (expr-posit8 128)
                "q8-to(nar) = posit8(NaR)"))

;; ========================================
;; Quire16: Type formation + core AST
;; ========================================

(test-case "Quire16 type formation"
  (check-equal? (tc:infer ctx-empty (expr-Quire16))
                (expr-Type (lzero))
                "Quire16 : Type 0")
  (check-true (tc:is-type ctx-empty (expr-Quire16))
              "Quire16 is a type"))

(test-case "quire16 fma + to reduction"
  ;; fma(0, 1, 1) = 1, to(1) = posit16(one)
  (check-equal? (whnf (expr-quire16-fma (expr-quire16-val 0) (expr-posit16 16384) (expr-posit16 16384)))
                (expr-quire16-val 1)
                "q16-fma(0, 1, 1) = 1")
  (check-equal? (whnf (expr-quire16-to (expr-quire16-val 1)))
                (expr-posit16 16384)
                "q16-to(1) = posit16(one)"))

;; ========================================
;; Quire32: Type formation + core AST
;; ========================================

(test-case "Quire32 type formation"
  (check-equal? (tc:infer ctx-empty (expr-Quire32))
                (expr-Type (lzero))
                "Quire32 : Type 0")
  (check-equal? (tc:infer-level ctx-empty (expr-Quire32))
                (tc:just-level (lzero))
                "Quire32 at level 0")
  (check-true (tc:is-type ctx-empty (expr-Quire32))
              "Quire32 is a type"))

(test-case "quire32 fma typing"
  (check-equal? (tc:infer ctx-empty
                  (expr-quire32-fma (expr-quire32-val 0) (expr-posit32 1073741824) (expr-posit32 1073741824)))
                (expr-Quire32)
                "quire32-fma : Quire32"))

(test-case "quire32 fma reduction"
  ;; fma(0, 1, 1) = 1
  (check-equal? (whnf (expr-quire32-fma (expr-quire32-val 0) (expr-posit32 1073741824) (expr-posit32 1073741824)))
                (expr-quire32-val 1)
                "q32-fma(0, 1, 1) = 1")
  ;; fma(0, 2, 3) = 6
  (check-equal? (whnf (expr-quire32-fma (expr-quire32-val 0) (expr-posit32 1207959552) (expr-posit32 1275068416)))
                (expr-quire32-val 6)
                "q32-fma(0, 2, 3) = 6"))

(test-case "quire32 to reduction"
  (check-equal? (whnf (expr-quire32-to (expr-quire32-val 1)))
                (expr-posit32 1073741824)
                "q32-to(1) = posit32(one)")
  (check-equal? (whnf (expr-quire32-to (expr-quire32-val 0)))
                (expr-posit32 0)
                "q32-to(0) = posit32(zero)"))

(test-case "quire32 dot product: 1*2 + 3*1 = 5"
  ;; Dot product: fma(fma(0, one, two), three, one) = 0 + 1*2 + 3*1 = 5
  (let* ([q0 (expr-quire32-val 0)]
         [one (expr-posit32 1073741824)]
         [two (expr-posit32 1207959552)]
         [three (expr-posit32 1275068416)]
         [q1 (expr-quire32-fma q0 one two)]          ; 0 + 1*2 = 2
         [q2 (expr-quire32-fma q1 three one)]         ; 2 + 3*1 = 5
         [result (expr-quire32-to q2)])                ; convert to posit
    ;; Reduce fully
    (check-equal? (whnf result)
                  (expr-posit32 1375731712)  ; posit32-encode(5)
                  "dot product 1*2 + 3*1 = 5")))

(test-case "quire32 NaR propagation"
  ;; fma with NaR posit
  (check-equal? (whnf (expr-quire32-fma (expr-quire32-val 0) (expr-posit32 2147483648) (expr-posit32 1073741824)))
                (expr-quire32-val 'nar)
                "q32-fma(0, NaR, 1) = nar")
  ;; to(nar)
  (check-equal? (whnf (expr-quire32-to (expr-quire32-val 'nar)))
                (expr-posit32 2147483648)
                "q32-to(nar) = posit32(NaR)"))

;; ========================================
;; Quire64: Type formation + core AST
;; ========================================

(test-case "Quire64 type formation"
  (check-equal? (tc:infer ctx-empty (expr-Quire64))
                (expr-Type (lzero))
                "Quire64 : Type 0")
  (check-true (tc:is-type ctx-empty (expr-Quire64))
              "Quire64 is a type"))

(test-case "quire64 fma + to reduction"
  ;; fma(0, 1, 1) = 1, to(1) = posit64(one)
  (check-equal? (whnf (expr-quire64-fma (expr-quire64-val 0) (expr-posit64 4611686018427387904) (expr-posit64 4611686018427387904)))
                (expr-quire64-val 1)
                "q64-fma(0, 1, 1) = 1")
  (check-equal? (whnf (expr-quire64-to (expr-quire64-val 1)))
                (expr-posit64 4611686018427387904)
                "q64-to(1) = posit64(one)"))

;; ========================================
;; Substitution
;; ========================================

(test-case "quire substitution"
  ;; Type and val are stable under shift
  (check-equal? (shift 1 0 (expr-Quire32)) (expr-Quire32) "Quire32 type stable under shift")
  (check-equal? (shift 1 0 (expr-quire32-val 42)) (expr-quire32-val 42) "quire32-val stable under shift")
  ;; Shift through fma
  (check-equal? (shift 1 0 (expr-quire32-fma (expr-bvar 0) (expr-posit32 1073741824) (expr-posit32 1073741824)))
                (expr-quire32-fma (expr-bvar 1) (expr-posit32 1073741824) (expr-posit32 1073741824))
                "shift increases bvar in q32-fma")
  ;; Shift through to
  (check-equal? (shift 1 0 (expr-quire32-to (expr-bvar 0)))
                (expr-quire32-to (expr-bvar 1))
                "shift increases bvar in q32-to")
  ;; Subst in fma
  (check-equal? (subst 0 (expr-quire32-val 0) (expr-quire32-fma (expr-bvar 0) (expr-posit32 1073741824) (expr-posit32 1073741824)))
                (expr-quire32-fma (expr-quire32-val 0) (expr-posit32 1073741824) (expr-posit32 1073741824))
                "subst replaces bvar in q32-fma")
  ;; Subst in to
  (check-equal? (subst 0 (expr-quire32-val 1) (expr-quire32-to (expr-bvar 0)))
                (expr-quire32-to (expr-quire32-val 1))
                "subst replaces bvar in q32-to"))

;; ========================================
;; Pretty-printing
;; ========================================

(test-case "quire pretty-printing"
  (check-equal? (pp-expr (expr-Quire8) '()) "Quire8" "pp Quire8")
  (check-equal? (pp-expr (expr-Quire16) '()) "Quire16" "pp Quire16")
  (check-equal? (pp-expr (expr-Quire32) '()) "Quire32" "pp Quire32")
  (check-equal? (pp-expr (expr-Quire64) '()) "Quire64" "pp Quire64")
  (check-equal? (pp-expr (expr-quire32-val 0) '()) "[quire32-val 0]" "pp quire32-val(0)")
  (check-equal? (pp-expr (expr-quire32-fma (expr-quire32-val 0) (expr-posit32 1073741824) (expr-posit32 1073741824)) '())
                "[q32-fma [quire32-val 0] [posit32 1073741824] [posit32 1073741824]]"
                "pp q32-fma")
  (check-equal? (pp-expr (expr-quire32-to (expr-quire32-val 1)) '())
                "[q32-to [quire32-val 1]]"
                "pp q32-to"))

;; ========================================
;; Surface syntax: End-to-end via process-string
;; ========================================

(define (run s)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (process-string s)))

(test-case "quire32 surface: type check"
  (check-equal? (run "(check Quire32 <(Type 0)>)")
                '("OK")))

(test-case "quire32 surface: zero literal"
  (check-equal? (run "(eval q32-zero)")
                '("[quire32-val 0] : Quire32")))

(test-case "quire32 surface: fma 1*1"
  (check-equal? (run "(eval (q32-fma q32-zero (posit32 1073741824) (posit32 1073741824)))")
                '("[quire32-val 1] : Quire32")))

(test-case "quire32 surface: to converts back to posit"
  (check-equal? (run "(eval (q32-to (q32-fma q32-zero (posit32 1073741824) (posit32 1073741824))))")
                '("[posit32 1073741824] : Posit32")))

(test-case "quire32 surface: check quire-zero type"
  (check-equal? (run "(check q32-zero <Quire32>)")
                '("OK")))

(test-case "quire32 surface: check fma type"
  (check-equal? (run "(check (q32-fma q32-zero (posit32 1073741824) (posit32 1073741824)) <Quire32>)")
                '("OK")))

(test-case "quire32 surface: check to type"
  (check-equal? (run "(check (q32-to q32-zero) <Posit32>)")
                '("OK")))

(test-case "quire32 surface: dot product 1*2 + 3*1 = 5"
  (check-equal? (run "(eval (q32-to (q32-fma (q32-fma q32-zero (posit32 1073741824) (posit32 1207959552)) (posit32 1275068416) (posit32 1073741824))))")
                '("[posit32 1375731712] : Posit32")))

(test-case "quire32 surface: def + eval"
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (let ([result (process-string "(def q <Quire32> (q32-fma q32-zero (posit32 1073741824) (posit32 1073741824)))\n(eval (q32-to q))")])
      (check-equal? (length result) 2)
      (check-true (string-contains? (car result) "q : Quire32 defined"))
      (check-equal? (cadr result) "[posit32 1073741824] : Posit32"))))

;; Test other widths at surface level

(test-case "quire8 surface: type + zero + fma + to"
  (check-equal? (run "(check Quire8 <(Type 0)>)")
                '("OK"))
  (check-equal? (run "(eval q8-zero)")
                '("[quire8-val 0] : Quire8"))
  (check-equal? (run "(eval (q8-to (q8-fma q8-zero (posit8 64) (posit8 64))))")
                '("[posit8 64] : Posit8")))

(test-case "quire16 surface: type + zero + fma + to"
  (check-equal? (run "(check Quire16 <(Type 0)>)")
                '("OK"))
  (check-equal? (run "(eval q16-zero)")
                '("[quire16-val 0] : Quire16"))
  (check-equal? (run "(eval (q16-to (q16-fma q16-zero (posit16 16384) (posit16 16384))))")
                '("[posit16 16384] : Posit16")))

(test-case "quire64 surface: type + zero + fma + to"
  (check-equal? (run "(check Quire64 <(Type 0)>)")
                '("OK"))
  (check-equal? (run "(eval q64-zero)")
                '("[quire64-val 0] : Quire64"))
  (check-equal? (run "(eval (q64-to (q64-fma q64-zero (posit64 4611686018427387904) (posit64 4611686018427387904))))")
                '("[posit64 4611686018427387904] : Posit64")))
