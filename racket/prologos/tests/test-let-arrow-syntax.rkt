#lang racket/base

;;;
;;; End-to-end integration tests for:
;;;  - let := binding syntax
;;;  - Sibling let merging
;;;  - Uncurried arrow syntax
;;;  - Grouped function types
;;;  - Pretty printer uncurried arrow output
;;;

(require rackunit
         racket/string
         racket/list
         "../prelude.rkt"
         "../syntax.rkt"
         "../surface-syntax.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../errors.rkt"
         "../typing-errors.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../macros.rkt")

;; ========================================
;; Helper
;; ========================================
(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

(define (run-first s)
  (car (run s)))

;; ========================================
;; 1. Let := evaluates correctly
;; ========================================

(test-case "e2e: let := with typed binding evaluates"
  (check-equal?
   (run-first "(eval (let x : Nat := (inc zero) x))")
   "1 : Nat"))

(test-case "e2e: let := in def body"
  (define results
    (run "(def r : Nat (let a : Nat := (inc (inc zero)) a))\n(eval r)"))
  (check-equal? (second results) "2 : Nat"))

;; ========================================
;; 2. Let := with type type-checks
;; ========================================

(test-case "e2e: let := preserves type annotation"
  (check-equal?
   (run-first "(check (let x : Nat := zero (inc x)) : Nat)")
   "OK"))

(test-case "e2e: let := type mismatch caught"
  (check-true
   (prologos-error? (run-first "(check (let x : Bool := zero x) : Bool)"))))

;; ========================================
;; 3. Sibling lets with sequential dependencies
;; ========================================

(test-case "e2e: sibling lets chain computation"
  (define results
    (run (string-append
          "(def answer : Nat "
          "  (let a : Nat := (inc zero))"
          "  (let b : Nat := (inc a))"
          "  (let c : Nat := (inc b) c))\n"
          "(eval answer)")))
  (check-equal? (second results) "3 : Nat"))

(test-case "e2e: sibling lets in defn body"
  (define results
    (run (string-append
          "(defn add-three [x : Nat] : Nat "
          "  (let a : Nat := (inc x))"
          "  (let b : Nat := (inc a))"
          "  (let c : Nat := (inc b) c))\n"
          "(eval (add-three zero))")))
  (check-equal? (second results) "3 : Nat"))

;; ========================================
;; 4. Inline [let ...] in expression position
;; ========================================

(test-case "e2e: inline let in application"
  (check-equal?
   (run-first "(eval (inc (let x : Nat := (inc zero) x)))")
   "2 : Nat"))

;; ========================================
;; 5. Defn with uncurried arrow return type
;; ========================================

(test-case "e2e: defn checked against uncurried arrow type"
  (define results
    (run (string-append
          "(defn add [x <Nat> y <Nat>] <Nat>\n"
          "  (natrec Nat x (fn (k : Nat) (fn (r : Nat) (inc r))) y))\n"
          "(check add <Nat Nat -> Nat>)")))
  (check-equal? (last results) "OK"))

(test-case "e2e: 3-param fn with uncurried arrow"
  (define results
    (run (string-append
          "(defn f [a <Nat> b <Nat> c <Nat>] <Nat> a)\n"
          "(check f <Nat Nat Nat -> Nat>)")))
  (check-equal? (last results) "OK"))

;; ========================================
;; 6. Defn with grouped function type param [Nat -> Nat]
;; ========================================

(test-case "e2e: grouped HOF param [Nat -> Nat] Nat -> Nat"
  (define results
    (run (string-append
          "(defn apply-fn [f : (-> Nat Nat) x : Nat] : Nat (f x))\n"
          "(check apply-fn <[Nat -> Nat] Nat -> Nat>)")))
  (check-equal? (last results) "OK"))

(test-case "e2e: grouped HOF eval"
  (define results
    (run (string-append
          "(defn apply-fn [f : (-> Nat Nat) x : Nat] : Nat (f x))\n"
          "(defn inc2 [n : Nat] : Nat (inc (inc n)))\n"
          "(eval (apply-fn inc2 (inc zero)))")))
  (check-equal? (last results) "3 : Nat"))

;; ========================================
;; 7. Combined: let with arrow type annotation
;; ========================================

(test-case "e2e: let := with arrow type in def body"
  (define results
    (run (string-append
          "(def result : Nat\n"
          "  (let f : (-> Nat Nat) := (fn (x : Nat) (inc x))\n"
          "    (f zero)))\n"
          "(eval result)")))
  (check-equal? (second results) "1 : Nat"))

;; ========================================
;; 8. Block let with mixed := and typed bindings
;; ========================================

(test-case "e2e: bracket let with multiple typed := bindings"
  (define results
    (run "(def r : Nat (let (a : Nat := zero b : Nat := (inc a)) (inc b)))\n(eval r)"))
  (check-equal? (second results) "2 : Nat"))

;; ========================================
;; 9. Pretty printer outputs uncurried arrows
;; ========================================

(test-case "e2e: pp multi-arg fn type as uncurried arrow"
  (define results
    (run (string-append
          "(defn add [x : Nat y : Nat] : Nat\n"
          "  (natrec Nat x (fn (k : Nat) (fn (r : Nat) (inc r))) y))\n")))
  ;; Should print "add : Nat Nat -> Nat defined." (uncurried)
  (check-equal? (car results) "add : Nat Nat -> Nat defined."))

(test-case "e2e: pp HOF type wraps inner arrow"
  (define results
    (run (string-append
          "(defn apply-fn [f : (-> Nat Nat) x : Nat] : Nat (f x))\n")))
  ;; Should print "[Nat -> Nat] Nat -> Nat" — domain that is Pi gets wrapped
  (check-equal? (car results) "apply-fn : [Nat -> Nat] Nat -> Nat defined."))

(test-case "e2e: pp single arrow unchanged"
  (define results
    (run (string-append
          "(defn inc2 [x : Nat] : Nat (inc (inc x)))\n")))
  (check-equal? (car results) "inc2 : Nat -> Nat defined."))

;; ========================================
;; 10. Regressions
;; ========================================

(test-case "e2e: A -> B -> C still right-associative"
  (define results
    (run (string-append
          "(defn const [x : Nat y : Nat] : Nat x)\n"
          "(check const : (-> Nat (-> Nat Nat)))")))
  (check-equal? (last results) "OK"))

(test-case "e2e: existing let bracket format works"
  (check-equal?
   (run-first "(eval (let ([x : Nat (inc zero)]) (inc x)))")
   "2 : Nat"))

(test-case "e2e: existing angle-type let format works"
  (check-equal?
   (run-first "(eval (let x <Nat> (inc zero) x))")
   "1 : Nat"))
