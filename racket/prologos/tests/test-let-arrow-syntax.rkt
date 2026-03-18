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
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (process-string s)))

(define (run-first s)
  (car (run s)))

;; ========================================
;; 1. Let := evaluates correctly
;; ========================================

(test-case "e2e: let := with typed binding evaluates"
  (check-equal?
   (run-first "(eval (let x : Nat := (suc zero) x))")
   "1N : Nat"))

(test-case "e2e: let := in def body"
  (define results
    (run "(def r : Nat (let a : Nat := (suc (suc zero)) a))\n(eval r)"))
  (check-equal? (second results) "2N : Nat"))

;; ========================================
;; 2. Let := with type type-checks
;; ========================================

(test-case "e2e: let := preserves type annotation"
  (check-equal?
   (run-first "(check (let x : Nat := zero (suc x)) : Nat)")
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
          "  (let a : Nat := (suc zero))"
          "  (let b : Nat := (suc a))"
          "  (let c : Nat := (suc b) c))\n"
          "(eval answer)")))
  (check-equal? (second results) "3N : Nat"))

(test-case "e2e: sibling lets in defn body"
  (define results
    (run (string-append
          "(defn add-three [x : Nat] : Nat "
          "  (let a : Nat := (suc x))"
          "  (let b : Nat := (suc a))"
          "  (let c : Nat := (suc b) c))\n"
          "(eval (add-three zero))")))
  (check-equal? (second results) "3N : Nat"))

(test-case "e2e: sibling lets with trailing body (all bodyless)"
  ;; When body is a sibling (same level), not indented under last let:
  ;; (def r : Nat (let x := 10) (let y := 20) (let z := (suc x)) z)
  ;; All lets are bodyless; trailing `z` is the body.
  (define results
    (run (string-append
          "(def r : Nat "
          "  (let x := (suc zero))"
          "  (let y := (suc (suc zero)))"
          "  (let z := (suc x))"
          "  z)\n"
          "(eval r)")))
  (check-equal? (second results) "2N : Nat"))

(test-case "e2e: sibling lets with multi-token value and trailing body"
  ;; Multi-token value: the value is (add x y), not separate tokens.
  ;; (def r : Nat (let x := 10) (let y := 20) (let z := add x y) z)
  (define results
    (run (string-append
          "(defn add [x : Nat y : Nat] : Nat"
          "  (natrec Nat x (fn (k : Nat) (fn (r : Nat) (suc r))) y))\n"
          "(def r : Nat "
          "  (let x := (suc (suc (suc zero))))"
          "  (let y := (suc (suc zero)))"
          "  (let z := (add x y))"
          "  z)\n"
          "(eval r)")))
  (check-equal? (third results) "5N : Nat"))

;; ========================================
;; 4. Inline [let ...] in expression position
;; ========================================

(test-case "e2e: inline let in application"
  (check-equal?
   (run-first "(eval (suc (let x : Nat := (suc zero) x)))")
   "2N : Nat"))

;; ========================================
;; 5. Defn with uncurried arrow return type
;; ========================================

(test-case "e2e: defn checked against uncurried arrow type"
  (define results
    (run (string-append
          "(defn add [x <Nat> y <Nat>] <Nat>\n"
          "  (natrec Nat x (fn (k : Nat) (fn (r : Nat) (suc r))) y))\n"
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
          "(defn inc2 [n : Nat] : Nat (suc (suc n)))\n"
          "(eval (apply-fn inc2 (suc zero)))")))
  (check-equal? (last results) "3N : Nat"))

;; ========================================
;; 7. Combined: let with arrow type annotation
;; ========================================

(test-case "e2e: let := with arrow type in def body"
  (define results
    (run (string-append
          "(def result : Nat\n"
          "  (let f : (-> Nat Nat) := (fn (x : Nat) (suc x))\n"
          "    (f zero)))\n"
          "(eval result)")))
  (check-equal? (second results) "1N : Nat"))

;; ========================================
;; 8. Block let with mixed := and typed bindings
;; ========================================

(test-case "e2e: bracket let with multiple typed := bindings"
  (define results
    (run "(def r : Nat (let (a : Nat := zero b : Nat := (suc a)) (suc b)))\n(eval r)"))
  (check-equal? (second results) "2N : Nat"))

;; ========================================
;; 9. Pretty printer outputs uncurried arrows
;; ========================================

(test-case "e2e: pp multi-arg fn type as uncurried arrow"
  (define results
    (run (string-append
          "(defn add [x : Nat y : Nat] : Nat\n"
          "  (natrec Nat x (fn (k : Nat) (fn (r : Nat) (suc r))) y))\n")))
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
          "(defn inc2 [x : Nat] : Nat (suc (suc x)))\n")))
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
   (run-first "(eval (let ([x : Nat (suc zero)]) (suc x)))")
   "2N : Nat"))

(test-case "e2e: existing angle-type let format works"
  (check-equal?
   (run-first "(eval (let x <Nat> (suc zero) x))")
   "1N : Nat"))

;; ========================================
;; 9. Let bracket binding with inferred type
;; ========================================

(test-case "e2e: let bracket binding with inferred type (single)"
  (check-equal?
   (run-first "(eval (let ([x (suc zero)]) (suc x)))")
   "2N : Nat"))

(test-case "e2e: let bracket binding with inferred type (multiple)"
  (check-equal?
   (run-first "(eval (let ([x (suc zero)] [y (suc x)]) (suc y)))")
   "3N : Nat"))

(test-case "e2e: let bracket binding mixed inferred and annotated"
  (check-equal?
   (run-first "(eval (let ([x (suc zero)] [y : Nat (suc x)]) (suc y)))")
   "3N : Nat"))

;; ========================================
;; 10. def := assignment syntax
;; ========================================

(test-case "e2e: def := with inferred type"
  (define results
    (run "(def one := (suc zero))\n(eval one)"))
  (check-equal? (last results) "1N : Nat"))

(test-case "e2e: def := with type annotation"
  (define results
    (run "(def one : Nat := (suc zero))\n(eval one)"))
  (check-equal? (last results) "1N : Nat"))

(test-case "e2e: def := with multi-token type"
  (define results
    (run "(def id : Nat -> Nat := (fn [x <Nat>] x))\n(eval (id (suc zero)))"))
  (check-equal? (last results) "1N : Nat"))

;; ========================================
;; 11. expand / parse / elaborate inspection commands
;; ========================================

(test-case "e2e: expand shows def := expansion"
  (check-equal?
   (run-first "(expand (def one := (suc zero)))")
   "(def one (suc zero))"))

(test-case "e2e: expand shows let expansion"
  (check-equal?
   (run-first "(expand (let x (suc zero) x))")
   "((fn (x : _) x) (suc zero))"))

(test-case "e2e: expand passes through plain expression"
  (check-equal?
   (run-first "(expand (suc zero))")
   "(suc zero)"))

(test-case "e2e: parse shows surface AST"
  (check-true
   (string-contains? (run-first "(parse zero)") "surf-zero")))

(test-case "e2e: parse shows surface AST for application"
  (check-true
   (string-contains? (run-first "(parse (suc zero))") "surf-suc")))

(test-case "e2e: elaborate shows core AST for suc zero"
  (check-equal?
   (run-first "(elaborate (suc zero))")
   "1N"))

(test-case "e2e: elaborate shows core AST for zero"
  (check-equal?
   (run-first "(elaborate zero)")
   "0N"))
