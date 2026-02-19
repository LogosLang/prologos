#lang racket/base

;;;
;;; Surface integration tests — full pipeline from surface syntax to results.
;;; Tests: parse -> elaborate -> type-check -> pretty-print
;;;

(require rackunit
         racket/string
         racket/list
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

(test-case "surface: (check (suc zero) : Nat) -> OK"
  (check-equal? (run-first "(check (suc zero) : Nat)") "OK"))

(test-case "surface: (check true : Bool) -> OK"
  (check-equal? (run-first "(check true : Bool)") "OK"))

(test-case "surface: (check refl : (Eq Nat zero zero)) -> OK"
  (check-equal? (run-first "(check refl : (Eq Nat zero zero))") "OK"))

;; ========================================
;; Type inference
;; ========================================

(test-case "surface: (infer zero) -> Nat"
  (check-equal? (run-first "(infer zero)") "Nat"))

(test-case "surface: (infer (suc zero)) -> Nat"
  (check-equal? (run-first "(infer (suc zero))") "Nat"))

(test-case "surface: (infer true) -> Bool"
  (check-equal? (run-first "(infer true)") "Bool"))

(test-case "surface: (infer Nat) -> (Type 0)"
  (check-equal? (run-first "(infer Nat)") "[Type 0]"))

;; ========================================
;; Evaluation
;; ========================================

(test-case "surface: (eval zero) -> zero : Nat"
  (check-equal? (run-first "(eval zero)") "0N : Nat"))

(test-case "surface: (eval (suc (suc zero))) -> 2 : Nat"
  (check-equal? (run-first "(eval (suc (suc zero)))") "2N : Nat"))

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
    (check-equal? (cadr results) "0N : Nat")))

(test-case "surface: define and check identity"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(def myid : (-> Nat Nat) (fn (x : Nat) x))\n"
                      "(check (myid (suc zero)) : Nat)")))
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
    (check-equal? (cadr results) "0N : Nat")))

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
   (run-first "(check (the (-> Nat Nat) (fn (x : Nat) (suc x))) : (-> Nat Nat))")
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
    "(check (vcons Nat zero (suc zero) (vnil Nat)) : (Vec Nat (suc zero)))")
   "OK"))

;; ========================================
;; Multiple definitions building on each other
;; ========================================

(test-case "surface: chained definitions"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(def one : Nat (suc zero))\n"
                      "(def two : Nat (suc one))\n"
                      "(eval two)")))
    (check-equal? (length results) 3)
    (check-equal? (caddr results) "2N : Nat")))

;; ========================================
;; defn macro tests
;; ========================================

(test-case "surface: defn simple increment"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(defn increment : (-> Nat Nat) [x] (suc x))\n"
                      "(eval (increment zero))")))
    (check-equal? (length results) 2)
    (check-equal? (car results) "increment : Nat -> Nat defined.")
    (check-equal? (cadr results) "1N : Nat")))

(test-case "surface: defn polymorphic id"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(defn id : (Pi (A :0 (Type 0)) (-> A A)) [A x] x)\n"
                      "(eval (id Nat (suc zero)))")))
    (check-equal? (length results) 2)
    (check-equal? (car results) "id : [Pi [x :0 <[Type 0]>] x -> x] defined.")
    (check-equal? (cadr results) "1N : Nat")))

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
    (define results (process-string "(suc zero)"))
    (check-equal? (length results) 1)
    (check-equal? (car results) "1N : Nat")))

(test-case "surface: implicit eval of zero"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string "zero"))
    (check-equal? (length results) 1)
    (check-equal? (car results) "0N : Nat")))

;; ========================================
;; boolrec tests (full pipeline)
;; ========================================

(test-case "surface: boolrec true -> zero"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (boolrec (the (-> Bool (Type 0)) (fn (b : Bool) Nat)) zero (suc zero) true))")
     "0N : Nat")))

(test-case "surface: boolrec false -> 1"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (boolrec (the (-> Bool (Type 0)) (fn (b : Bool) Nat)) zero (suc zero) false))")
     "1N : Nat")))

(test-case "surface: check boolrec type"
  (check-equal?
   (run-first "(check (boolrec (the (-> Bool (Type 0)) (fn (b : Bool) Nat)) zero (suc zero) true) : Nat)")
   "OK"))

;; ========================================
;; let macro tests
;; ========================================

(test-case "surface: let with single binding"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (let ([x : Nat (suc zero)]) x))")
     "1N : Nat")))

(test-case "surface: let with two bindings (sequential)"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (let ([x : Nat (suc zero)] [y : Nat (suc x)]) y))")
     "2N : Nat")))

(test-case "surface: let with computation"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (let ([x : Nat (suc (suc zero))]) (suc x)))")
     "3N : Nat")))

;; ========================================
;; let := tests
;; ========================================

(test-case "surface: let := with type evaluates"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (let x : Nat := (suc zero) x))")
     "1N : Nat")))

(test-case "surface: let := bracket with types"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (let (x : Nat := (suc zero) y : Nat := (suc x)) y))")
     "2N : Nat")))

(test-case "surface: let := bracket single binding"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (let (x : Nat := (suc (suc zero))) (suc x)))")
     "3N : Nat")))

(test-case "surface: let := with computation"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (let x : Nat := (suc (suc zero)) (suc x)))")
     "3N : Nat")))

;; ========================================
;; Sibling let merge tests
;; ========================================

(test-case "surface: sibling lets evaluate"
  (parameterize ([current-global-env (hasheq)])
    ;; Sexp-mode: def with sibling let forms
    (define results
      (run "(def result : Nat (let a : Nat := (suc zero)) (let b : Nat := (suc a) (suc b)))\n(eval result)"))
    (check-equal? (second results) "3N : Nat")))

(test-case "surface: three sibling lets"
  (parameterize ([current-global-env (hasheq)])
    (define results
      (run "(def r : Nat (let a : Nat := zero) (let b : Nat := (suc a)) (let c : Nat := (suc b) c))\n(eval r)"))
    (check-equal? (second results) "2N : Nat")))

;; ========================================
;; do macro tests
;; ========================================

(test-case "surface: do with single binding"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (do [x : Nat = (suc zero)] x))")
     "1N : Nat")))

(test-case "surface: do with two bindings"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (do [x : Nat = (suc zero)] [y : Nat = (suc x)] y))")
     "2N : Nat")))

;; ========================================
;; if macro tests
;; ========================================

(test-case "surface: if true"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (if Nat true zero (suc zero)))")
     "0N : Nat")))

(test-case "surface: if false"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (if Nat false zero (suc zero)))")
     "1N : Nat")))

;; ========================================
;; defmacro tests (end-to-end)
;; ========================================

(test-case "surface: defmacro not and use"
  (parameterize ([current-global-env (hasheq)]
                 [current-preparse-registry (current-preparse-registry)])
    (define results (process-string
                     (string-append
                      "(defmacro not ($b) (if Bool $b false true))\n"
                      "(eval (not true))")))
    ;; defmacro is consumed, so 1 result
    (check-equal? (length results) 1)
    (check-equal? (car results) "false : Bool")))

(test-case "surface: defmacro not false"
  (parameterize ([current-global-env (hasheq)]
                 [current-preparse-registry (current-preparse-registry)])
    (define results (process-string
                     (string-append
                      "(defmacro not ($b) (if Bool $b false true))\n"
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
    (check-equal? (car results) "[Type 0]")))

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
     (run-first "(eval (let ([b : Bool true]) (if Nat b (suc zero) zero)))")
     "1N : Nat")))

(test-case "surface: defn with boolrec"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(defn to-nat : (-> Bool Nat) [b]\n"
                      "  (boolrec (the (-> Bool (Type 0)) (fn (_ : Bool) Nat)) (suc zero) zero b))\n"
                      "(eval (to-nat true))\n"
                      "(eval (to-nat false))")))
    (check-equal? (length results) 3)
    (check-true (string-contains? (car results) "to-nat"))
    (check-equal? (cadr results) "1N : Nat")
    (check-equal? (caddr results) "0N : Nat")))

;; ========================================
;; Angle bracket syntax tests (new format)
;; ========================================

(test-case "surface: angle-bracket def"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string "(def one <Nat> (suc zero))"))
    (check-equal? (car results) "one : Nat defined.")))

(test-case "surface: angle-bracket check"
  (check-equal? (run-first "(check zero <Nat>)") "OK"))

(test-case "surface: angle-bracket fn binder"
  (check-equal?
   (run-first "(check (the (-> Nat Nat) (fn [x <Nat>] (suc x))) <(-> Nat Nat)>)")
   "OK"))

(test-case "surface: angle-bracket defn simple"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(defn inc2 [x <Nat>] <Nat> (suc (suc x)))\n"
                      "(eval (inc2 zero))")))
    (check-equal? (length results) 2)
    (check-equal? (car results) "inc2 : Nat -> Nat defined.")
    (check-equal? (cadr results) "2N : Nat")))

(test-case "surface: angle-bracket defn polymorphic"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(defn id [A :0 <(Type 0)> x <A>] <A> x)\n"
                      "(eval (id Nat zero))\n"
                      "(eval (id Bool true))")))
    (check-equal? (length results) 3)
    (check-equal? (car results) "id : [Pi [x :0 <[Type 0]>] x -> x] defined.")
    (check-equal? (cadr results) "0N : Nat")
    (check-equal? (caddr results) "true : Bool")))

(test-case "surface: angle-bracket let"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (let [x <Nat> (suc zero) y <Nat> (suc x)] y))")
     "2N : Nat")))

(test-case "surface: angle-bracket Sigma"
  (check-equal?
   (run-first "(check (pair zero refl) <(Sigma [x <Nat>] (Eq Nat x zero))>)")
   "OK"))

(test-case "surface: angle-bracket Pi"
  (check-equal?
   (run-first "(infer (Pi [A :0 <(Type 0)>] (-> A A)))")
   "[Type 1]"))

;; ========================================
;; Phase 3: Colon-based parameter syntax (integration tests)
;; ========================================

(test-case "surface: colon defn simple increment"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(defn inc2 [x : Nat] : Nat (suc (suc x)))\n"
                      "(eval (inc2 zero))")))
    (check-equal? (length results) 2)
    (check-equal? (car results) "inc2 : Nat -> Nat defined.")
    (check-equal? (cadr results) "2N : Nat")))

(test-case "surface: colon defn with arrow param"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(defn apply-to-zero [f : Nat -> Nat] : Nat (f zero))\n"
                      "(defn inc2 [x : Nat] : Nat (suc (suc x)))\n"
                      "(eval (apply-to-zero inc2))")))
    (check-equal? (length results) 3)
    (check-equal? (car results) "apply-to-zero : [Nat -> Nat] -> Nat defined.")
    (check-equal? (caddr results) "2N : Nat")))

(test-case "surface: colon defn polymorphic with {A}"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(defn id {A} [x : A] : A x)\n"
                      "(eval (id Nat zero))\n"
                      "(eval (id Bool true))")))
    (check-equal? (length results) 3)
    (check-equal? (car results) "id : [Pi [x :0 <[Type 0]>] x -> x] defined.")
    (check-equal? (cadr results) "0N : Nat")
    (check-equal? (caddr results) "true : Bool")))

(test-case "surface: colon defn with multiplicity"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(defn const {A B} [x : A y :0 : B] : A x)\n"
                      "(eval (const Nat Bool (suc zero) true))")))
    (check-equal? (length results) 2)
    (check-equal? (cadr results) "1N : Nat")))

(test-case "surface: colon defn multi-arrow type A -> B -> C"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(defn add [x : Nat y : Nat] : Nat (natrec Nat y (fn (_ : Nat) (fn (acc : Nat) (suc acc))) x))\n"
                      "(eval (add (suc zero) (suc (suc zero))))")))
    (check-equal? (length results) 2)
    (check-equal? (cadr results) "3N : Nat")))

(test-case "surface: colon defn with bare Type"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(defn id [A :0 : Type x : A] : A x)\n"
                      "(eval (id Nat (suc zero)))")))
    (check-equal? (length results) 2)
    (check-equal? (cadr results) "1N : Nat")))

;; ========================================
;; Phase 4: Untyped multi-argument fn
;; ========================================

(test-case "surface: untyped fn identity in checked context"
  (check-equal?
   (run-first "(check (fn x x) : (-> Nat Nat))")
   "OK"))

(test-case "surface: untyped fn two args in checked context"
  (check-equal?
   (run-first "(check (fn x y (suc x)) : (-> Nat (-> Nat Nat)))")
   "OK"))

(test-case "surface: untyped fn used in defn body"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(defn apply-to-zero [f : Nat -> Nat] : Nat (f zero))\n"
                      "(eval (apply-to-zero (fn x (suc x))))")))
    (check-equal? (length results) 2)
    (check-equal? (cadr results) "1N : Nat")))

(test-case "surface: untyped fn in let binding"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(eval (let ([f : (-> Nat Nat) (fn x (suc x))]) (f zero)))")
     "1N : Nat")))

(test-case "surface: untyped multi-arg fn in defn body"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(defn add [x : Nat y : Nat] : Nat (natrec Nat y (fn _ acc (suc acc)) x))\n"
                      "(eval (add (suc zero) (suc (suc zero))))")))
    (check-equal? (length results) 2)
    (check-equal? (cadr results) "3N : Nat")))

;; ========================================
;; Phase 5: Clean data constructor syntax
;; ========================================

(test-case "surface: data with colon ctor syntax (no params)"
  (parameterize ([current-global-env (hasheq)]
                 [current-preparse-registry (current-preparse-registry)])
    (define results (process-string
                     (string-append
                      "(data MyBool my-true my-false)\n"
                      "(check my-true : MyBool)")))
    ;; data generates: type def + 2 ctor defs = 3, then check = 1, total = 4
    (check-equal? (length results) 4)
    (check-equal? (last results) "OK")))

(test-case "surface: data with colon ctor syntax (parameterized)"
  (parameterize ([current-global-env (hasheq)]
                 [current-preparse-registry (current-preparse-registry)])
    (define results (process-string
                     (string-append
                      "(data Maybe {A} nothing (just : A))\n"
                      ;; Constructors need explicit type param: (nothing Nat), (just Nat zero)
                      "(check (nothing Nat) : (Maybe Nat))\n"
                      "(check (just Nat zero) : (Maybe Nat))")))
    ;; data generates: type def + 2 ctor defs = 3, then 2 checks, total = 5
    (check-equal? (length results) 5)
    ;; Last two should be OK
    (check-equal? (list-ref results 3) "OK")
    (check-equal? (list-ref results 4) "OK")))

(test-case "surface: data List with colon ctor syntax"
  (parameterize ([current-global-env (hasheq)]
                 [current-preparse-registry (current-preparse-registry)])
    (define results (process-string
                     (string-append
                      "(data List {A} nil (cons : A -> List A))\n"
                      ;; Constructors need explicit type param
                      "(check (nil Nat) : (List Nat))\n"
                      "(check (cons Nat zero (nil Nat)) : (List Nat))")))
    ;; data generates: type def + 2 ctor defs = 3, then 2 checks, total = 5
    (check-equal? (length results) 5)
    (check-equal? (list-ref results 3) "OK")
    (check-equal? (list-ref results 4) "OK")))

;; ========================================
;; Uncurried arrow syntax tests
;; ========================================

(test-case "surface: uncurried arrow Nat Nat -> Nat"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
      (string-append
       "(defn add [x <Nat> y <Nat>] <Nat>\n"
       "  (natrec Nat x (fn (k : Nat) (fn (r : Nat) (suc r))) y))\n"
       "(check add <Nat Nat -> Nat>)")))
    (check-equal? (last results) "OK")))

(test-case "surface: Nat -> Nat unchanged"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
      "(defn id [x <Nat>] <Nat> x)\n(check id <Nat -> Nat>)"))
    (check-equal? (last results) "OK")))

(test-case "surface: grouped HOF [Nat -> Nat] -> Nat"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
      (string-append
       "(defn apply-fn [f <(-> Nat Nat)> x <Nat>] <Nat> (f x))\n"
       "(check apply-fn <[Nat -> Nat] Nat -> Nat>)")))
    (check-equal? (last results) "OK")))

(test-case "surface: uncurried A B C -> D"
  (parameterize ([current-global-env (hasheq)])
    ;; 3-arg function: A B C -> D parsed as A -> B -> C -> D
    (define results (process-string
      (string-append
       "(defn f3 [a <Nat> b <Nat> c <Nat>] <Nat> a)\n"
       "(check f3 <Nat Nat Nat -> Nat>)")))
    (check-equal? (last results) "OK")))

(test-case "surface: A -> B -> C still right-assoc"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
      (string-append
       "(defn f2 [a <Nat> b <Nat>] <Nat> a)\n"
       "(check f2 <Nat -> Nat -> Nat>)")))
    (check-equal? (last results) "OK")))

(test-case "surface: [Nat -> Nat] Nat -> Nat grouped param"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
      (string-append
       "(defn app [f <(-> Nat Nat)> x <Nat>] <Nat> (f x))\n"
       "(check app <[Nat -> Nat] Nat -> Nat>)")))
    (check-equal? (last results) "OK")))
