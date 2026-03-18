#lang racket/base

;;;
;;; Tests for the `spec` form — separate type specifications for definitions.
;;;

(require rackunit
         racket/string
         racket/list
         racket/set
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
         "../macros.rkt"
         "../source-location.rkt")

;; ========================================
;; Helper
;; ========================================
(define (run s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-propagated-specs (seteq)]
                 [current-preparse-registry (current-preparse-registry)])
    (process-string s)))

(define (run-first s)
  (car (run s)))

;; ========================================
;; 1. Basic spec + defn pairing
;; ========================================

(test-case "spec: simple Nat Nat -> Nat"
  (define results
    (run (string-append
          "(spec add Nat Nat -> Nat)\n"
          "(defn add [x y]\n"
          "  (natrec Nat x (fn (k : Nat) (fn (r : Nat) (suc r))) y))\n"
          "(eval (add (suc zero) (suc (suc zero))))")))
  ;; spec is consumed, defn produces 1 result, eval produces 1 result
  (check-equal? (length results) 2)
  (check-true (string-contains? (car results) "add"))
  (check-true (string-contains? (car results) "defined"))
  (check-equal? (cadr results) "3N : Nat"))

(test-case "spec: single param Nat -> Nat"
  (define results
    (run (string-append
          "(spec inc2 Nat -> Nat)\n"
          "(defn inc2 [x] (suc (suc x)))\n"
          "(eval (inc2 (suc zero)))")))
  (check-equal? (length results) 2)
  (check-equal? (cadr results) "3N : Nat"))

(test-case "spec: constant function Nat Nat -> Nat"
  (define results
    (run (string-append
          "(spec const Nat Nat -> Nat)\n"
          "(defn const [x y] x)\n"
          "(eval (const (suc zero) zero))")))
  (check-equal? (cadr results) "1N : Nat"))

(test-case "spec: with docstring"
  (define results
    (run (string-append
          "(spec add \"Adds two natural numbers.\" Nat Nat -> Nat)\n"
          "(defn add [x y]\n"
          "  (natrec Nat x (fn (k : Nat) (fn (r : Nat) (suc r))) y))\n"
          "(eval (add (suc zero) (suc zero)))")))
  (check-equal? (length results) 2)
  (check-equal? (cadr results) "2N : Nat"))

;; ========================================
;; 2. HOF (higher-order function) spec
;; ========================================

(test-case "spec: HOF [Nat -> Nat] Nat -> Nat"
  (define results
    (run (string-append
          "(spec apply-fn (-> Nat Nat) Nat -> Nat)\n"
          "(defn apply-fn [f x] (f x))\n"
          "(defn inc2 [x : Nat] : Nat (suc (suc x)))\n"
          "(eval (apply-fn inc2 zero))")))
  (check-equal? (last results) "2N : Nat"))

;; ========================================
;; 3. Auto-implicit inference with spec
;; ========================================

(test-case "spec: polymorphic id A -> A with auto-implicits"
  (define results
    (run (string-append
          "(spec id A -> A)\n"
          "(defn id [x] x)\n"
          "(eval (id Nat zero))\n"
          "(eval (id Bool true))")))
  (check-equal? (length results) 3)
  ;; id should have implicit A
  (check-true (string-contains? (car results) "id"))
  (check-equal? (cadr results) "0N : Nat")
  (check-equal? (caddr results) "true : Bool"))

;; ========================================
;; 4. Spec with curried return type
;; ========================================

(test-case "spec: Nat -> Nat -> Nat with one param (curried return)"
  (define results
    (run (string-append
          "(spec adder Nat -> Nat -> Nat)\n"
          "(defn adder [x]\n"
          "  (fn (y : Nat) (natrec Nat x (fn (k : Nat) (fn (r : Nat) (suc r))) y)))\n"
          "(eval ((adder (suc zero)) (suc (suc zero))))")))
  (check-equal? (length results) 2)
  (check-equal? (cadr results) "3N : Nat"))

;; ========================================
;; 5. Pretty printer output
;; ========================================

(test-case "spec: outputs uncurried arrow type"
  (define results
    (run (string-append
          "(spec add Nat Nat -> Nat)\n"
          "(defn add [x y]\n"
          "  (natrec Nat x (fn (k : Nat) (fn (r : Nat) (suc r))) y))")))
  (check-equal? (car results) "add : Nat Nat -> Nat defined."))

(test-case "spec: HOF type wraps domain in brackets"
  (define results
    (run (string-append
          "(spec apply-fn (-> Nat Nat) Nat -> Nat)\n"
          "(defn apply-fn [f x] (f x))")))
  (check-equal? (car results) "apply-fn : [Nat -> Nat] Nat -> Nat defined."))

(test-case "spec: single arrow type unchanged"
  (define results
    (run (string-append
          "(spec inc2 Nat -> Nat)\n"
          "(defn inc2 [x] (suc (suc x)))")))
  (check-equal? (car results) "inc2 : Nat -> Nat defined."))

;; ========================================
;; 6. Conflict detection (spec + inline types → error)
;; ========================================

(test-case "spec: error when defn has inline types AND spec"
  (check-exn
   exn:fail?
   (lambda ()
     (run (string-append
           "(spec add Nat Nat -> Nat)\n"
           "(defn add [x : Nat y : Nat] : Nat\n"
           "  (natrec Nat x (fn (k : Nat) (fn (r : Nat) (suc r))) y))")))))

(test-case "spec: error when defn has angle-bracket return type AND spec"
  (check-exn
   exn:fail?
   (lambda ()
     (run (string-append
           "(spec inc2 Nat -> Nat)\n"
           "(defn inc2 [x] <Nat> (suc (suc x)))")))))

;; ========================================
;; 7. No-spec cases (existing behavior unchanged)
;; ========================================

(test-case "spec: defn without spec + bare params + return type still works"
  (define results
    (run (string-append
          "(defn inc2 [x] <Nat> (suc (suc x)))\n"
          "(eval (inc2 zero))")))
  (check-equal? (cadr results) "2N : Nat"))

(test-case "spec: defn without spec + fully typed still works"
  (define results
    (run (string-append
          "(defn inc2 [x : Nat] : Nat (suc (suc x)))\n"
          "(eval (inc2 zero))")))
  (check-equal? (cadr results) "2N : Nat"))

(test-case "spec: orphan spec without defn → no error"
  (define results
    (run "(spec orphan Nat -> Bool)"))
  ;; spec is consumed, no output
  (check-equal? (length results) 0))

;; ========================================
;; 8. Spec with grouped type [List Nat]
;; ========================================

;; Note: We can't easily test [List Nat] without the List type loaded,
;; but we can test that grouped types parse correctly by using (-> Nat Nat)
;; as a grouped param type.

(test-case "spec: grouped param type (-> Nat Nat)"
  (define results
    (run (string-append
          "(spec apply-fn (-> Nat Nat) Nat -> Nat)\n"
          "(defn apply-fn [f x] (f x))\n"
          "(eval (apply-fn (fn (n : Nat) (suc n)) zero))")))
  (check-equal? (last results) "1N : Nat"))

;; ========================================
;; 9. Multi-arity spec + multi-body defn
;; ========================================

(test-case "spec: multi-arity two branches"
  (define results
    (run (string-append
          "(spec greet ($pipe Nat -> Nat) ($pipe Nat Nat -> Nat))\n"
          "(defn greet ($pipe [x] (suc x)) ($pipe [x y] (natrec Nat x (fn (k : Nat) (fn (r : Nat) (suc r))) y)))\n"
          "(eval (greet (suc zero)))\n"
          "(eval (greet (suc zero) (suc (suc zero))))")))
  ;; Multi-body defn produces multiple defs + dispatch, then 2 evals
  (check-true (string-contains? (last (take results (- (length results) 2))) "defined"))
  (check-equal? (list-ref results (- (length results) 2)) "2N : Nat")
  (check-equal? (last results) "3N : Nat"))

(test-case "spec: multi-arity branch count mismatch → error"
  (check-exn
   exn:fail?
   (lambda ()
     (run (string-append
           "(spec greet ($pipe Nat -> Nat) ($pipe Nat Nat -> Nat))\n"
           "(defn greet ($pipe [x] (suc x)))")))))

(test-case "spec: single spec with multi-body defn → error"
  (check-exn
   exn:fail?
   (lambda ()
     (run (string-append
           "(spec greet Nat -> Nat)\n"
           "(defn greet ($pipe [x] (suc x)) ($pipe [x y] x))")))))

;; ========================================
;; 10. Dependent parameter syntax
;; ========================================

;; Simple dependent binder test: (n : Nat) in spec position
;; We test the parsing by using a named param that gets used in the return type
(test-case "spec: dependent binder (n : Nat) Nat -> Nat"
  ;; Even though (n : Nat) is dependent syntax, for Nat -> Nat it works the same
  ;; This tests that the parser handles the binder form correctly
  (define results
    (run (string-append
          "(spec add (n : Nat) Nat -> Nat)\n"
          "(defn add [x y]\n"
          "  (natrec Nat x (fn (k : Nat) (fn (r : Nat) (suc r))) y))\n"
          "(eval (add (suc zero) (suc zero)))")))
  (check-equal? (last results) "2N : Nat"))

;; ========================================
;; 11. Private spec-
;; ========================================

(test-case "spec-: private spec does not auto-export"
  ;; Just check it doesn't error — we can't easily test export behavior
  ;; in process-string mode, but we verify spec- is consumed
  (define results
    (run (string-append
          "(spec- internal Nat -> Nat)\n"
          "(defn internal [x] (suc x))\n"
          "(eval (internal zero))")))
  ;; 1 def result + 1 eval result
  (check-equal? (length results) 2)
  (check-equal? (cadr results) "1N : Nat"))

;; ========================================
;; 12. Spec store registration
;; ========================================

(test-case "spec: register-spec! stores entry"
  (parameterize ([current-spec-store (hasheq)])
    (register-spec! 'foo (spec-entry '((Nat -> Nat)) #f #f srcloc-unknown '() '() #f (hasheq)))
    (define entry (lookup-spec 'foo))
    (check-true (spec-entry? entry))
    (check-equal? (spec-entry-type-datums entry) '((Nat -> Nat)))
    (check-false (spec-entry-docstring entry))
    (check-false (spec-entry-multi? entry))))

(test-case "spec: register with docstring"
  (parameterize ([current-spec-store (hasheq)])
    (register-spec! 'bar (spec-entry '((Nat Nat -> Nat)) "Adds numbers" #f srcloc-unknown '() '() #f (hasheq)))
    (define entry (lookup-spec 'bar))
    (check-equal? (spec-entry-docstring entry) "Adds numbers")))

(test-case "spec: lookup-spec returns #f for missing"
  (parameterize ([current-spec-store (hasheq)])
    (check-false (lookup-spec 'nonexistent))))

;; ========================================
;; 13. process-spec unit tests
;; ========================================

(test-case "spec: process-spec registers single-arity"
  (parameterize ([current-spec-store (hasheq)])
    (process-spec '(spec add Nat Nat -> Nat))
    (define entry (lookup-spec 'add))
    (check-true (spec-entry? entry))
    (check-equal? (spec-entry-type-datums entry) '((Nat Nat -> Nat)))
    (check-false (spec-entry-multi? entry))
    (check-false (spec-entry-docstring entry))))

(test-case "spec: process-spec with docstring"
  (parameterize ([current-spec-store (hasheq)])
    (process-spec '(spec add "Adds two numbers." Nat Nat -> Nat))
    (define entry (lookup-spec 'add))
    (check-equal? (spec-entry-docstring entry) "Adds two numbers.")
    (check-equal? (spec-entry-type-datums entry) '((Nat Nat -> Nat)))))

(test-case "spec: process-spec multi-arity with $pipe"
  (parameterize ([current-spec-store (hasheq)])
    (process-spec '(spec greet ($pipe Nat -> Nat) ($pipe Nat Nat -> Nat)))
    (define entry (lookup-spec 'greet))
    (check-true (spec-entry-multi? entry))
    (check-equal? (length (spec-entry-type-datums entry)) 2)
    (check-equal? (car (spec-entry-type-datums entry)) '(Nat -> Nat))
    (check-equal? (cadr (spec-entry-type-datums entry)) '(Nat Nat -> Nat))))

;; ========================================
;; 14. Spec with {A} explicit implicits on defn
;; ========================================

(test-case "spec: paired with defn that has {A} implicits"
  ;; If defn has {A} brace params, it's not a bare-param defn
  ;; (has_type_annotation returns false for braces but parse-defn handles them)
  ;; The spec should still be looked up by name and inject remaining params
  ;; Actually, {A} is detected as $brace-params — need to test this case
  ;; For now, verify that defn with {A} and typed params + spec → conflict error
  (check-exn
   exn:fail?
   (lambda ()
     (run (string-append
           "(spec id A -> A)\n"
           "(defn id {A} [x : A] : A x)")))))

;; ========================================
;; spec + def
;; ========================================

(test-case "spec: def with spec type (simple value)"
  (define results
    (run "(spec one Nat)\n(def one := (suc zero))\n(eval one)"))
  (check-equal? (last results) "1N : Nat"))

(test-case "spec: def with spec function type"
  (define results
    (run (string-append
          "(spec double Nat -> Nat)\n"
          "(def double := (fn [x] (suc (suc x))))\n"
          "(eval (double (suc zero)))")))
  (check-equal? (last results) "3N : Nat"))

(test-case "spec: def with spec type, no :="
  ;; spec + def without :=  (bare def name body)
  (define results
    (run "(spec two Nat)\n(def two (suc (suc zero)))\n(eval two)"))
  (check-equal? (last results) "2N : Nat"))

(test-case "spec: def with spec AND inline type errors"
  (check-exn
   exn:fail?
   (lambda ()
     (run "(spec foo Nat)\n(def foo <Nat> zero)"))))

(test-case "spec: multi-arity spec with def errors"
  (check-exn
   exn:fail?
   (lambda ()
     (run "(spec foo ($pipe Nat -> Nat) ($pipe Bool -> Bool))\n(def foo zero)"))))
