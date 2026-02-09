#lang racket/base

;;;
;;; Surface integration tests — full pipeline from surface syntax to results.
;;; Tests: parse -> elaborate -> type-check -> pretty-print
;;;

(require rackunit
         racket/string
         "../prelude.rkt"
         "../syntax.rkt"
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../source-location.rkt"
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
;; Helper: process commands and return results list
;; ========================================
(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

(define (run-first s)
  (car (run s)))

;; ========================================
;; Basic type checking
;; ========================================

(test-case "surface: (check zero : Nat) -> OK"
  (check-equal? (run-first "(check zero : Nat)") "OK"))

(test-case "surface: (check (inc zero) : Nat) -> OK"
  (check-equal? (run-first "(check (inc zero) : Nat)") "OK"))

(test-case "surface: (check true : Bool) -> OK"
  (check-equal? (run-first "(check true : Bool)") "OK"))

(test-case "surface: (check refl : (Eq Nat zero zero)) -> OK"
  (check-equal? (run-first "(check refl : (Eq Nat zero zero))") "OK"))

;; ========================================
;; Type inference
;; ========================================

(test-case "surface: (infer zero) -> Nat"
  (check-equal? (run-first "(infer zero)") "Nat"))

(test-case "surface: (infer (inc zero)) -> Nat"
  (check-equal? (run-first "(infer (inc zero))") "Nat"))

(test-case "surface: (infer true) -> Bool"
  (check-equal? (run-first "(infer true)") "Bool"))

(test-case "surface: (infer Nat) -> (Type 0)"
  (check-equal? (run-first "(infer Nat)") "(Type 0)"))

;; ========================================
;; Evaluation
;; ========================================

(test-case "surface: (eval zero) -> zero : Nat"
  (check-equal? (run-first "(eval zero)") "zero : Nat"))

(test-case "surface: (eval (inc (inc zero))) -> 2 : Nat"
  (check-equal? (run-first "(eval (inc (inc zero)))") "2 : Nat"))

;; ========================================
;; Definitions
;; ========================================

(test-case "surface: define identity function"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     "(def myid : (-> Nat Nat) (fn (x : Nat) x))"))
    (check-true (string-contains? (car results) "myid"))
    (check-true (string-contains? (car results) "defined"))))

(test-case "surface: define and use identity"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(def myid : (-> Nat Nat) (fn (x : Nat) x))\n"
                      "(eval (myid zero))")))
    (check-equal? (length results) 2)
    (check-true (string-contains? (car results) "defined"))
    (check-equal? (cadr results) "zero : Nat")))

(test-case "surface: define and check identity"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(def myid : (-> Nat Nat) (fn (x : Nat) x))\n"
                      "(check (myid (inc zero)) : Nat)")))
    (check-equal? (length results) 2)
    (check-equal? (cadr results) "OK")))

;; ========================================
;; Polymorphic identity
;; ========================================

(test-case "surface: polymorphic identity"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(def id : (Pi (A :0 (Type 0)) (-> A A))\n"
                      "  (fn (A :0 (Type 0)) (fn (x : A) x)))\n"
                      "(eval (id Nat zero))")))
    (check-equal? (length results) 2)
    (check-true (string-contains? (car results) "defined"))
    (check-equal? (cadr results) "zero : Nat")))

(test-case "surface: polymorphic identity applied to Bool"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(def id : (Pi (A :0 (Type 0)) (-> A A))\n"
                      "  (fn (A :0 (Type 0)) (fn (x : A) x)))\n"
                      "(eval (id Bool true))")))
    (check-equal? (cadr results) "true : Bool")))

;; ========================================
;; Type annotations
;; ========================================

(test-case "surface: annotated lambda"
  (check-equal?
   (run-first "(check (the (-> Nat Nat) (fn (x : Nat) (inc x))) : (-> Nat Nat))")
   "OK"))

;; ========================================
;; Negative tests (type errors)
;; ========================================

(test-case "surface: NEGATIVE — check true : Nat"
  (check-true (prologos-error? (run-first "(check true : Nat)"))))

(test-case "surface: NEGATIVE — unbound variable"
  (check-true (prologos-error? (run-first "(eval undefined_var)"))))

;; ========================================
;; Pairs and Sigma
;; ========================================

(test-case "surface: check pair against Sigma"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(check (pair zero refl) : (Sigma (x : Nat) (Eq Nat x zero)))")
     "OK")))

;; ========================================
;; Vec operations
;; ========================================

(test-case "surface: check vnil"
  (check-equal?
   (run-first "(check (vnil Nat) : (Vec Nat zero))")
   "OK"))

(test-case "surface: check vcons"
  (check-equal?
   (run-first
    "(check (vcons Nat zero (inc zero) (vnil Nat)) : (Vec Nat (inc zero)))")
   "OK"))

;; ========================================
;; Multiple definitions building on each other
;; ========================================

(test-case "surface: chained definitions"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(def one : Nat (inc zero))\n"
                      "(def two : Nat (inc one))\n"
                      "(eval two)")))
    (check-equal? (length results) 3)
    (check-equal? (caddr results) "2 : Nat")))

;; ========================================
;; defn macro tests
;; ========================================

(test-case "surface: defn simple increment"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(defn increment : (-> Nat Nat) [x] (inc x))\n"
                      "(eval (increment zero))")))
    (check-equal? (length results) 2)
    (check-equal? (car results) "increment : (-> Nat Nat) defined.")
    (check-equal? (cadr results) "1 : Nat")))

(test-case "surface: defn polymorphic id"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(defn id : (Pi (A :0 (Type 0)) (-> A A)) [A x] x)\n"
                      "(eval (id Nat (inc zero)))")))
    (check-equal? (length results) 2)
    (check-equal? (car results) "id : (Pi [x :0 <(Type 0)>] (-> x x)) defined.")
    (check-equal? (cadr results) "1 : Nat")))

(test-case "surface: defn param count mismatch"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                      "(defn f : (-> Nat Nat) [x y] x)"))
    (check-equal? (length results) 1)
    (check-true (prologos-error? (car results)))))

;; ========================================
;; Implicit eval tests
;; ========================================

(test-case "surface: implicit eval of bare expression"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string "(inc zero)"))
    (check-equal? (length results) 1)
    (check-equal? (car results) "1 : Nat")))

(test-case "surface: implicit eval of zero"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string "zero"))
    (check-equal? (length results) 1)
    (check-equal? (car results) "zero : Nat")))

;; ========================================
;; boolrec tests (full pipeline)
;; ========================================

(test-case "surface: boolrec true -> zero"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (boolrec (the (-> Bool (Type 0)) (fn (b : Bool) Nat)) zero (inc zero) true))")
     "zero : Nat")))

(test-case "surface: boolrec false -> 1"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (boolrec (the (-> Bool (Type 0)) (fn (b : Bool) Nat)) zero (inc zero) false))")
     "1 : Nat")))

(test-case "surface: check boolrec type"
  (check-equal?
   (run-first "(check (boolrec (the (-> Bool (Type 0)) (fn (b : Bool) Nat)) zero (inc zero) true) : Nat)")
   "OK"))

;; ========================================
;; let macro tests
;; ========================================

(test-case "surface: let with single binding"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (let ([x : Nat (inc zero)]) x))")
     "1 : Nat")))

(test-case "surface: let with two bindings (sequential)"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (let ([x : Nat (inc zero)] [y : Nat (inc x)]) y))")
     "2 : Nat")))

(test-case "surface: let with computation"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (let ([x : Nat (inc (inc zero))]) (inc x)))")
     "3 : Nat")))

;; ========================================
;; do macro tests
;; ========================================

(test-case "surface: do with single binding"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (do [x : Nat = (inc zero)] x))")
     "1 : Nat")))

(test-case "surface: do with two bindings"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (do [x : Nat = (inc zero)] [y : Nat = (inc x)] y))")
     "2 : Nat")))

;; ========================================
;; if macro tests
;; ========================================

(test-case "surface: if true"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (if Nat true zero (inc zero)))")
     "zero : Nat")))

(test-case "surface: if false"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (if Nat false zero (inc zero)))")
     "1 : Nat")))

;; ========================================
;; defmacro tests (end-to-end)
;; ========================================

(test-case "surface: defmacro not and use"
  (parameterize ([current-global-env (hasheq)]
                 [current-preparse-registry (current-preparse-registry)])
    (define results (process-string
                     (string-append
                      "(defmacro (not $b) (if Bool $b false true))\n"
                      "(eval (not true))")))
    ;; defmacro is consumed, so 1 result
    (check-equal? (length results) 1)
    (check-equal? (car results) "false : Bool")))

(test-case "surface: defmacro not false"
  (parameterize ([current-global-env (hasheq)]
                 [current-preparse-registry (current-preparse-registry)])
    (define results (process-string
                     (string-append
                      "(defmacro (not $b) (if Bool $b false true))\n"
                      "(eval (not false))")))
    (check-equal? (car results) "true : Bool")))

;; ========================================
;; deftype tests
;; ========================================

(test-case "surface: deftype simple alias as standalone"
  (parameterize ([current-global-env (hasheq)]
                 [current-preparse-registry (current-preparse-registry)])
    ;; Simple alias expands when used as a standalone top-level form
    ;; (infer Endo) returns the type of Endo, which is (Type 0) since Endo = (-> Nat Nat)
    (define results (process-string
                     (string-append
                      "(deftype Endo (-> Nat Nat))\n"
                      "(infer Endo)")))
    ;; deftype consumed, 1 result
    (check-equal? (length results) 1)
    (check-equal? (car results) "(Type 0)")))

(test-case "surface: deftype parameterized alias"
  (parameterize ([current-global-env (hasheq)]
                 [current-preparse-registry (current-preparse-registry)])
    (define results (process-string
                     (string-append
                      "(deftype (Pair $A $B) (Sigma (x : $A) $B))\n"
                      "(check (pair zero true) : (Pair Nat Bool))")))
    (check-equal? (length results) 1)
    (check-equal? (car results) "OK")))

;; ========================================
;; Combined macro tests
;; ========================================

(test-case "surface: let with if"
  (parameterize ([current-global-env (hasheq)]
                 [current-preparse-registry (current-preparse-registry)])
    (check-equal?
     (run-first "(eval (let ([b : Bool true]) (if Nat b (inc zero) zero)))")
     "1 : Nat")))

(test-case "surface: defn with boolrec"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(defn to-nat : (-> Bool Nat) [b]\n"
                      "  (boolrec (the (-> Bool (Type 0)) (fn (_ : Bool) Nat)) (inc zero) zero b))\n"
                      "(eval (to-nat true))\n"
                      "(eval (to-nat false))")))
    (check-equal? (length results) 3)
    (check-true (string-contains? (car results) "to-nat"))
    (check-equal? (cadr results) "1 : Nat")
    (check-equal? (caddr results) "zero : Nat")))

;; ========================================
;; Angle bracket syntax tests (new format)
;; ========================================

(test-case "surface: angle-bracket def"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string "(def one <Nat> (inc zero))"))
    (check-equal? (car results) "one : Nat defined.")))

(test-case "surface: angle-bracket check"
  (check-equal? (run-first "(check zero <Nat>)") "OK"))

(test-case "surface: angle-bracket fn binder"
  (check-equal?
   (run-first "(check (the (-> Nat Nat) (fn [x <Nat>] (inc x))) <(-> Nat Nat)>)")
   "OK"))

(test-case "surface: angle-bracket defn simple"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(defn inc2 [x <Nat>] <Nat> (inc (inc x)))\n"
                      "(eval (inc2 zero))")))
    (check-equal? (length results) 2)
    (check-equal? (car results) "inc2 : (-> Nat Nat) defined.")
    (check-equal? (cadr results) "2 : Nat")))

(test-case "surface: angle-bracket defn polymorphic"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(defn id [A :0 <(Type 0)> x <A>] <A> x)\n"
                      "(eval (id Nat zero))\n"
                      "(eval (id Bool true))")))
    (check-equal? (length results) 3)
    (check-equal? (car results) "id : (Pi [x :0 <(Type 0)>] (-> x x)) defined.")
    (check-equal? (cadr results) "zero : Nat")
    (check-equal? (caddr results) "true : Bool")))

(test-case "surface: angle-bracket let"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (let [x <Nat> (inc zero) y <Nat> (inc x)] y))")
     "2 : Nat")))

(test-case "surface: angle-bracket Sigma"
  (check-equal?
   (run-first "(check (pair zero refl) <(Sigma [x <Nat>] (Eq Nat x zero))>)")
   "OK"))

(test-case "surface: angle-bracket Pi"
  (check-equal?
   (run-first "(infer (Pi [A :0 <(Type 0)>] (-> A A)))")
   "(Type 1)"))
