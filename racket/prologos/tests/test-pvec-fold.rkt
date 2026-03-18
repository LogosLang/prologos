#lang racket/base

;;;
;;; Tests for native expr-pvec-fold AST primitive (Stage C1).
;;; Verifies that pvec-fold fully reduces via rrb-fold in the reduction engine.
;;; Signature: (B → A → B) → B → PVec A → B  (accumulator first, matching library pvec-fold)
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
                 [current-module-definitions-content (hasheq)]
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


;; ========================================
;; 1. Type checking
;; ========================================

(test-case "pvec-fold/type: sum Nat"
  (define result
    (run-last
      (string-append
        "(ns pf-type-1)\n"
        "(check (pvec-fold (fn [acc : Nat] [x : Nat] (add acc x)) zero @[1N 2N 3N]) : Nat)\n")))
  (check-equal? result "OK"))


(test-case "pvec-fold/type: result type is accumulator type"
  (define result
    (run-last
      (string-append
        "(ns pf-type-2)\n"
        "(check (pvec-fold (fn [acc : Bool] [x : Nat] (zero? x)) true @[1N]) : Bool)\n")))
  (check-equal? result "OK"))


;; ========================================
;; 2. Eval (native reduction via rrb-fold)
;; ========================================

(test-case "pvec-fold/eval: sum of @[1N 2N 3N]"
  (define result
    (run-last
      (string-append
        "(ns pf-eval-1)\n"
        "(eval (pvec-fold (fn [acc : Nat] [x : Nat] (add acc x)) zero @[1N 2N 3N]))\n")))
  (check-equal? result "6N : Nat"))


(test-case "pvec-fold/eval: empty pvec"
  (define result
    (run-last
      (string-append
        "(ns pf-eval-2)\n"
        "(eval (pvec-fold (fn [acc : Nat] [x : Nat] (add acc x)) zero @[]))\n")))
  (check-equal? result "0N : Nat"))


(test-case "pvec-fold/eval: single element"
  (define result
    (run-last
      (string-append
        "(ns pf-eval-3)\n"
        "(eval (pvec-fold (fn [acc : Nat] [x : Nat] (add acc x)) zero @[42N]))\n")))
  (check-equal? result "42N : Nat"))


(test-case "pvec-fold/eval: count elements (Nat accumulator)"
  (define result
    (run-last
      (string-append
        "(ns pf-eval-4)\n"
        "(eval (pvec-fold (fn [acc : Nat] [x : Nat] (suc acc)) zero @[10N 20N 30N 40N]))\n")))
  (check-equal? result "4N : Nat"))


(test-case "pvec-fold/eval: all positive (Bool accumulator)"
  (define result
    (run-last
      (string-append
        "(ns pf-eval-5)\n"
        "(eval (pvec-fold (fn [acc : Bool] [x : Nat] (if (zero? x) false acc)) true @[1N 2N 3N]))\n")))
  (check-equal? result "true : Bool"))


(test-case "pvec-fold/eval: any zero (Bool accumulator)"
  (define result
    (run-last
      (string-append
        "(ns pf-eval-6)\n"
        "(eval (pvec-fold (fn [acc : Bool] [x : Nat] (if (zero? x) true acc)) false @[1N 0N 3N]))\n")))
  (check-equal? result "true : Bool"))


(test-case "pvec-fold/eval: product of @[2N 3N 4N]"
  (define result
    (run-last
      (string-append
        "(ns pf-eval-7)\n"
        "(eval (pvec-fold (fn [acc : Nat] [x : Nat] (mult acc x)) (suc zero) @[2N 3N 4N]))\n")))
  (check-equal? result "24N : Nat"))


(test-case "pvec-fold/eval: left-fold order verification"
  ;; Left fold: f(f(f(init, 1), 2), 3)
  ;; With f = (acc, x) -> add(mult(x, x), acc): ((0+1)+4)+9 = 14
  (define result
    (run-last
      (string-append
        "(ns pf-eval-8)\n"
        "(eval (pvec-fold (fn [acc : Nat] [x : Nat] (add (mult x x) acc)) zero @[1N 2N 3N]))\n")))
  ;; 1*1 + 2*2 + 3*3 = 1 + 4 + 9 = 14
  (check-equal? result "14N : Nat"))


;; ========================================
;; 3. Pretty-printing
;; ========================================

(test-case "pvec-fold/pp: infer returns result type"
  (define result
    (run-last
      (string-append
        "(ns pf-pp-1)\n"
        "(spec my-f Nat -> Nat -> Nat)\n"
        "(defn my-f [acc x] (add acc x))\n"
        "(infer (pvec-fold my-f zero @[1N]))\n")))
  (check-equal? result "Nat"))


;; ========================================
;; 4. Interaction with named functions
;; ========================================

(test-case "pvec-fold/named: fold with named step function"
  (define result
    (run-last
      (string-append
        "(ns pf-named-1)\n"
        "(spec step Nat -> Nat -> Nat)\n"
        "(defn step [acc x] (add acc x))\n"
        "(eval (pvec-fold step zero @[10N 20N 30N]))\n")))
  (check-equal? result "60N : Nat"))


(test-case "pvec-fold/named: fold with curried add"
  (define result
    (run-last
      (string-append
        "(ns pf-named-2)\n"
        "(eval (pvec-fold add zero @[1N 2N 3N]))\n")))
  (check-equal? result "6N : Nat"))
