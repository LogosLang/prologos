#lang racket/base

;;;
;;; Tests for parser.rkt and surface-syntax.rkt
;;;

(require rackunit
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../parser.rkt"
         "../errors.rkt")

;; Helper: parse from string, ignoring source locations in comparisons
(define (p s) (parse-string s))

;; ========================================
;; Bare symbols
;; ========================================

(test-case "parse: Nat"
  (check-true (surf-nat-type? (p "Nat"))))

(test-case "parse: Bool"
  (check-true (surf-bool-type? (p "Bool"))))

(test-case "parse: zero"
  (check-true (surf-zero? (p "zero"))))

(test-case "parse: true"
  (check-true (surf-true? (p "true"))))

(test-case "parse: false"
  (check-true (surf-false? (p "false"))))

(test-case "parse: refl"
  (check-true (surf-refl? (p "refl"))))

(test-case "parse: variable"
  (let ([r (p "x")])
    (check-true (surf-var? r))
    (check-equal? (surf-var-name r) 'x)))

;; ========================================
;; Number literals
;; ========================================

(test-case "parse: 0 -> surf-zero"
  (check-true (surf-zero? (p "0"))))

(test-case "parse: 3 -> surf-nat-lit"
  (let ([r (p "3")])
    (check-true (surf-nat-lit? r))
    (check-equal? (surf-nat-lit-value r) 3)))

;; ========================================
;; inc
;; ========================================

(test-case "parse: (inc zero)"
  (let ([r (p "(inc zero)")])
    (check-true (surf-suc? r))
    (check-true (surf-zero? (surf-suc-pred r)))))

(test-case "parse: (inc (inc zero))"
  (let ([r (p "(inc (inc zero))")])
    (check-true (surf-suc? r))
    (check-true (surf-suc? (surf-suc-pred r)))))

;; ========================================
;; Lambda
;; ========================================

(test-case "parse: (fn (x : Nat) x)"
  (let ([r (p "(fn (x : Nat) x)")])
    (check-true (surf-lam? r))
    (let ([b (surf-lam-binder r)])
      (check-equal? (binder-info-name b) 'x)
      ;; Sprint 7: omitted mult → #f (elaborator converts to mult-meta)
      (check-false (binder-info-mult b))
      (check-true (surf-nat-type? (binder-info-type b))))
    (check-true (surf-var? (surf-lam-body r)))))

(test-case "parse: (fn (x :1 Nat) x) — linear lambda"
  (let ([r (p "(fn (x :1 Nat) x)")])
    (check-true (surf-lam? r))
    (check-equal? (binder-info-mult (surf-lam-binder r)) 'm1)))

(test-case "parse: (fn (x :0 Nat) zero) — erased lambda"
  (let ([r (p "(fn (x :0 Nat) zero)")])
    (check-true (surf-lam? r))
    (check-equal? (binder-info-mult (surf-lam-binder r)) 'm0)))

;; ========================================
;; Pi
;; ========================================

(test-case "parse: (Pi (x : Nat) Nat)"
  (let ([r (p "(Pi (x : Nat) Nat)")])
    (check-true (surf-pi? r))
    (check-equal? (binder-info-name (surf-pi-binder r)) 'x)
    (check-true (surf-nat-type? (surf-pi-body r)))))

(test-case "parse: (Pi (A :0 (Type 0)) (-> A A))"
  (let ([r (p "(Pi (A :0 (Type 0)) (-> A A))")])
    (check-true (surf-pi? r))
    (check-equal? (binder-info-mult (surf-pi-binder r)) 'm0)
    (check-true (surf-arrow? (surf-pi-body r)))))

;; ========================================
;; Arrow
;; ========================================

(test-case "parse: (-> Nat Nat)"
  (let ([r (p "(-> Nat Nat)")])
    (check-true (surf-arrow? r))
    (check-true (surf-nat-type? (surf-arrow-domain r)))
    (check-true (surf-nat-type? (surf-arrow-codomain r)))))

;; ========================================
;; Sigma
;; ========================================

(test-case "parse: (Sigma (x : Nat) (Eq Nat x zero))"
  (let ([r (p "(Sigma (x : Nat) (Eq Nat x zero))")])
    (check-true (surf-sigma? r))
    (check-true (surf-eq? (surf-sigma-body r)))))

;; ========================================
;; Pair, first, second
;; ========================================

(test-case "parse: (pair zero refl)"
  (let ([r (p "(pair zero refl)")])
    (check-true (surf-pair? r))
    (check-true (surf-zero? (surf-pair-fst r)))
    (check-true (surf-refl? (surf-pair-snd r)))))

(test-case "parse: (first x)"
  (let ([r (p "(first x)")])
    (check-true (surf-fst? r))
    (check-true (surf-var? (surf-fst-expr r)))))

(test-case "parse: (second x)"
  (let ([r (p "(second x)")])
    (check-true (surf-snd? r))
    (check-true (surf-var? (surf-snd-expr r)))))

;; ========================================
;; the (annotation)
;; ========================================

(test-case "parse: (the Nat zero)"
  (let ([r (p "(the Nat zero)")])
    (check-true (surf-ann? r))
    (check-true (surf-nat-type? (surf-ann-type r)))
    (check-true (surf-zero? (surf-ann-term r)))))

;; ========================================
;; Eq
;; ========================================

(test-case "parse: (Eq Nat zero zero)"
  (let ([r (p "(Eq Nat zero zero)")])
    (check-true (surf-eq? r))
    (check-true (surf-nat-type? (surf-eq-type r)))
    (check-true (surf-zero? (surf-eq-lhs r)))
    (check-true (surf-zero? (surf-eq-rhs r)))))

;; ========================================
;; Type
;; ========================================

(test-case "parse: (Type 0)"
  (let ([r (p "(Type 0)")])
    (check-true (surf-type? r))
    (check-equal? (surf-type-level r) 0)))

(test-case "parse: (Type 1)"
  (let ([r (p "(Type 1)")])
    (check-equal? (surf-type-level r) 1)))

;; ========================================
;; natrec
;; ========================================

;; Bare variable motive uses constant motive shorthand:
;; (natrec m b s t) → motive is (the (-> Nat (Type 0)) (fn [_ <Nat>] m))
(test-case "parse: (natrec m b s t) — constant motive shorthand"
  (let ([r (p "(natrec m b s t)")])
    (check-true (surf-natrec? r))
    (check-true (surf-ann? (surf-natrec-motive r)))
    (check-equal? (surf-var-name (surf-natrec-target r)) 't)))

;; Explicit motive with (the ...) passes through unchanged
(test-case "parse: (natrec (the ...) b s t) — explicit motive"
  (let ([r (p "(natrec (the (-> Nat (Type 0)) (fn (_ : Nat) Nat)) b s t)")])
    (check-true (surf-natrec? r))
    (check-true (surf-ann? (surf-natrec-motive r)))
    (check-equal? (surf-var-name (surf-natrec-target r)) 't)))

;; ========================================
;; J
;; ========================================

(test-case "parse: (J m b l r p)"
  (let ([r (p "(J m b l r p)")])
    (check-true (surf-J? r))
    (check-equal? (surf-var-name (surf-J-motive r)) 'm)
    (check-equal? (surf-var-name (surf-J-proof r)) 'p)))

;; ========================================
;; Vec/Fin
;; ========================================

(test-case "parse: (Vec Nat (inc zero))"
  (let ([r (p "(Vec Nat (inc zero))")])
    (check-true (surf-vec-type? r))
    (check-true (surf-nat-type? (surf-vec-type-elem-type r)))
    (check-true (surf-suc? (surf-vec-type-length r)))))

(test-case "parse: (vnil Nat)"
  (check-true (surf-vnil? (p "(vnil Nat)"))))

(test-case "parse: (vcons Nat (inc zero) zero (vnil Nat))"
  (let ([r (p "(vcons Nat (inc zero) zero (vnil Nat))")])
    (check-true (surf-vcons? r))))

(test-case "parse: (Fin (inc zero))"
  (check-true (surf-fin-type? (p "(Fin (inc zero))"))))

(test-case "parse: (fzero zero)"
  (check-true (surf-fzero? (p "(fzero zero)"))))

(test-case "parse: (fsuc (inc zero) (fzero zero))"
  (check-true (surf-fsuc? (p "(fsuc (inc zero) (fzero zero))"))))

(test-case "parse: (vhead Nat zero v)"
  (check-true (surf-vhead? (p "(vhead Nat zero v)"))))

(test-case "parse: (vtail Nat zero v)"
  (check-true (surf-vtail? (p "(vtail Nat zero v)"))))

(test-case "parse: (vindex Nat (inc zero) i v)"
  (check-true (surf-vindex? (p "(vindex Nat (inc zero) i v)"))))

;; ========================================
;; Application
;; ========================================

(test-case "parse: (f x) — single arg"
  (let ([r (p "(f x)")])
    (check-true (surf-app? r))
    (check-equal? (surf-var-name (surf-app-func r)) 'f)
    (check-equal? (length (surf-app-args r)) 1)))

(test-case "parse: (f x y z) — multi-arg"
  (let ([r (p "(f x y z)")])
    (check-true (surf-app? r))
    (check-equal? (length (surf-app-args r)) 3)))

(test-case "parse: ((fn (x : Nat) x) zero) — compound function"
  (let ([r (p "((fn (x : Nat) x) zero)")])
    (check-true (surf-app? r))
    (check-true (surf-lam? (surf-app-func r)))))

;; ========================================
;; Top-level commands
;; ========================================

(test-case "parse: (def id : (-> Nat Nat) (fn (x : Nat) x))"
  (let ([r (p "(def id : (-> Nat Nat) (fn (x : Nat) x))")])
    (check-true (surf-def? r))
    (check-equal? (surf-def-name r) 'id)
    (check-true (surf-arrow? (surf-def-type r)))
    (check-true (surf-lam? (surf-def-body r)))))

(test-case "parse: (check zero : Nat)"
  (let ([r (p "(check zero : Nat)")])
    (check-true (surf-check? r))
    (check-true (surf-zero? (surf-check-expr r)))
    (check-true (surf-nat-type? (surf-check-type r)))))

(test-case "parse: (eval zero)"
  (let ([r (p "(eval zero)")])
    (check-true (surf-eval? r))
    (check-true (surf-zero? (surf-eval-expr r)))))

(test-case "parse: (infer zero)"
  (let ([r (p "(infer zero)")])
    (check-true (surf-infer? r))
    (check-true (surf-zero? (surf-infer-expr r)))))

;; ========================================
;; Error cases
;; ========================================

(test-case "parse: (inc) — wrong arity"
  (check-true (prologos-error? (p "(inc)"))))

(test-case "parse: (inc a b) — wrong arity"
  (check-true (prologos-error? (p "(inc a b)"))))

(test-case "parse: (Type x) — non-numeric level"
  (check-true (prologos-error? (p "(Type x)"))))

(test-case "parse: (fn x y) — untyped fn"
  ;; (fn x y) is now a valid untyped lambda: fn with hole type
  (let ([r (p "(fn x y)")])
    (check-true (surf-lam? r))
    (check-equal? (binder-info-name (surf-lam-binder r)) 'x)
    (check-true (surf-hole? (binder-info-type (surf-lam-binder r))))
    (check-true (surf-var? (surf-lam-body r)))))

;; ========================================
;; parse-port: multiple forms
;; ========================================

(test-case "parse-port: multiple forms"
  (let* ([in (open-input-string "(def x : Nat zero)\n(eval x)")]
         [results (parse-port in "<test>")])
    (check-equal? (length results) 2)
    (check-true (surf-def? (car results)))
    (check-true (surf-eval? (cadr results)))))

;; ========================================
;; Source location tracking
;; ========================================

(test-case "parse: source locations from read-syntax"
  (let ([r (p "zero")])
    ;; Should have a srcloc from the string reader
    (check-true (srcloc? (surf-zero-srcloc r)))))

;; ========================================
;; defn parsing
;; ========================================

(test-case "parse: defn simple (-> Nat Nat)"
  (let ([r (p "(defn increment : (-> Nat Nat) [x] (inc x))")])
    (check-true (surf-defn? r))
    (check-equal? (surf-defn-name r) 'increment)
    (check-true (surf-arrow? (surf-defn-type r)))
    (check-equal? (surf-defn-param-names r) '(x))
    (check-true (surf-suc? (surf-defn-body r)))))

(test-case "parse: defn polymorphic with Pi"
  (let ([r (p "(defn id : (Pi (A :0 (Type 0)) (-> A A)) [A x] x)")])
    (check-true (surf-defn? r))
    (check-equal? (surf-defn-name r) 'id)
    (check-true (surf-pi? (surf-defn-type r)))
    (check-equal? (surf-defn-param-names r) '(A x))
    (check-true (surf-var? (surf-defn-body r)))))

(test-case "parse: defn error — too few args"
  (check-true (prologos-error? (p "(defn f : Nat [x])"))))

(test-case "parse: defn error — missing colon"
  (check-true (prologos-error? (p "(defn f Nat [x] x)"))))

(test-case "parse: defn error — no brackets for params"
  (check-true (prologos-error? (p "(defn f : Nat (x) x)"))))

(test-case "parse: defn error — non-symbol in params"
  (check-true (prologos-error? (p "(defn f : Nat [42] zero)"))))

;; ========================================
;; Angle bracket syntax tests
;; ========================================

(test-case "parse: angle-bracket binder [x <Nat>]"
  (define result (p "(fn [x <Nat>] x)"))
  (check-true (surf-lam? result))
  (check-equal? (binder-info-name (surf-lam-binder result)) 'x)
  ;; Sprint 7: omitted mult → #f (elaborator converts to mult-meta)
  (check-false (binder-info-mult (surf-lam-binder result)))
  (check-true (surf-nat-type? (binder-info-type (surf-lam-binder result)))))

(test-case "parse: angle-bracket binder with multiplicity [x :0 <Nat>]"
  (define result (p "(fn [x :0 <Nat>] x)"))
  (check-true (surf-lam? result))
  (check-equal? (binder-info-mult (surf-lam-binder result)) 'm0))

(test-case "parse: angle-bracket def"
  (define result (p "(def one <Nat> (inc zero))"))
  (check-true (surf-def? result))
  (check-equal? (surf-def-name result) 'one))

(test-case "parse: angle-bracket check"
  (define result (p "(check zero <Nat>)"))
  (check-true (surf-check? result))
  (check-true (surf-nat-type? (surf-check-type result))))

(test-case "parse: angle-bracket defn with typed binders"
  (define result (p "(defn inc2 [x <Nat>] <Nat> (inc x))"))
  (check-true (surf-defn? result))
  (check-equal? (surf-defn-name result) 'inc2)
  (check-equal? (surf-defn-param-names result) '(x)))

(test-case "parse: angle-bracket defn polymorphic"
  (define result (p "(defn id [A :0 <(Type 0)> x <A>] <A> x)"))
  (check-true (surf-defn? result))
  (check-equal? (surf-defn-name result) 'id)
  (check-equal? (surf-defn-param-names result) '(A x))
  ;; Type should be Pi [A :0 Type0] (-> A A)
  (check-true (surf-pi? (surf-defn-type result)))
  (check-equal? (binder-info-mult (surf-pi-binder (surf-defn-type result))) 'm0))

(test-case "parse: angle-bracket Pi"
  (define result (p "(Pi [x <Nat>] Nat)"))
  (check-true (surf-pi? result))
  (check-equal? (binder-info-name (surf-pi-binder result)) 'x))

(test-case "parse: angle-bracket Sigma"
  (define result (p "(Sigma [x <Nat>] (Eq Nat x zero))"))
  (check-true (surf-sigma? result))
  (check-equal? (binder-info-name (surf-sigma-binder result)) 'x))

(test-case "parse: angle-bracket complex type"
  (define result (p "(def f <(-> Nat Nat)> (fn [x <Nat>] (inc x)))"))
  (check-true (surf-def? result))
  (check-true (surf-arrow? (surf-def-type result))))

;; ========================================
;; Phase 3: Colon-based parameter syntax
;; ========================================

(test-case "parse: colon binder [x : Nat]"
  (define result (p "(defn inc2 [x : Nat] <Nat> (inc x))"))
  (check-true (surf-defn? result))
  (check-equal? (surf-defn-name result) 'inc2)
  (check-equal? (surf-defn-param-names result) '(x))
  ;; Type is Pi (constructed from binder + return type)
  (check-true (surf-pi? (surf-defn-type result))))

(test-case "parse: colon binder with arrow type [f : Nat -> Nat x : Nat]"
  ;; Note: no commas in sexp mode (comma is Racket's unquote)
  (define result (p "(defn apply-fn [f : Nat -> Nat x : Nat] <Nat> (f x))"))
  (check-true (surf-defn? result))
  (check-equal? (surf-defn-name result) 'apply-fn)
  (check-equal? (surf-defn-param-names result) '(f x))
  ;; Type should be Pi for f:(->Nat Nat), then Pi for x:Nat, then Nat
  (check-true (surf-pi? (surf-defn-type result)))
  ;; f's type should be (-> Nat Nat)
  (define f-type (binder-info-type (surf-pi-binder (surf-defn-type result))))
  (check-true (surf-arrow? f-type)))

(test-case "parse: colon binder with multiplicity [x :0 : Nat]"
  (define result (p "(defn erase [x :0 : Nat] <Nat> zero)"))
  (check-true (surf-defn? result))
  (check-equal? (surf-defn-param-names result) '(x))
  ;; Check multiplicity is m0
  (define pi-type (surf-defn-type result))
  (check-true (surf-pi? pi-type))
  (check-equal? (binder-info-mult (surf-pi-binder pi-type)) 'm0))

(test-case "parse: colon return type : Nat"
  (define result (p "(defn inc2 [x : Nat] : Nat (inc x))"))
  (check-true (surf-defn? result))
  (check-equal? (surf-defn-name result) 'inc2)
  (check-equal? (surf-defn-param-names result) '(x))
  ;; Full type is Pi (from colon binder + colon return type)
  (check-true (surf-pi? (surf-defn-type result))))

(test-case "parse: colon return type with arrow : Nat -> Nat"
  (define result (p "(defn mk-fn [x : Nat] : Nat -> Nat (fn [y <Nat>] x))"))
  (check-true (surf-defn? result))
  ;; Return type should be (-> Nat Nat), so full type is Pi(x:Nat, (-> Nat Nat))
  (define full-type (surf-defn-type result))
  (check-true (surf-pi? full-type))
  (define ret-type (surf-pi-body full-type))
  (check-true (surf-arrow? ret-type)))

(test-case "parse: colon binder right-associative arrow [f : Nat -> Nat -> Nat]"
  ;; No commas in sexp mode
  (define result (p "(defn app [f : Nat -> Nat -> Nat x : Nat y : Nat] <Nat> (f x y))"))
  (check-true (surf-defn? result))
  (check-equal? (surf-defn-param-names result) '(f x y))
  ;; f's type should be (-> Nat (-> Nat Nat)) — right-associative
  (define pi1 (surf-defn-type result))
  (check-true (surf-pi? pi1))
  (define f-type (binder-info-type (surf-pi-binder pi1)))
  (check-true (surf-arrow? f-type))
  (check-true (surf-arrow? (surf-arrow-codomain f-type))))

(test-case "parse: colon with {A B} implicit params"
  (define result (p "(defn id {A} [x : A] : A x)"))
  (check-true (surf-defn? result))
  (check-equal? (surf-defn-name result) 'id)
  (check-equal? (surf-defn-param-names result) '(A x))
  ;; Type should be Pi [A :0 Type0] (Pi [x :mw A] A)
  (check-true (surf-pi? (surf-defn-type result)))
  (check-equal? (binder-info-mult (surf-pi-binder (surf-defn-type result))) 'm0))

(test-case "parse: bare Type in colon binder [A :0 : Type x : A]"
  ;; No commas in sexp mode
  (define result (p "(defn id [A :0 : Type x : A] : A x)"))
  (check-true (surf-defn? result))
  (check-equal? (surf-defn-param-names result) '(A x))
  (define pi1 (surf-defn-type result))
  (check-true (surf-pi? pi1))
  (check-equal? (binder-info-mult (surf-pi-binder pi1)) 'm0)
  ;; A's type should be Type (= (Type 0))
  (check-true (surf-type? (binder-info-type (surf-pi-binder pi1)))))

(test-case "parse: colon binder with commas [x : Nat, y : Nat]"
  ;; Commas are now supported in sexp mode via readtable
  (define result (p "(defn add [x : Nat, y : Nat] <Nat> (natrec Nat y (fn (_ : Nat) (fn (acc : Nat) (inc acc))) x))"))
  (check-true (surf-defn? result))
  (check-equal? (surf-defn-param-names result) '(x y)))

;; ========================================
;; Phase 4: Multi-argument untyped fn
;; ========================================

(test-case "parse: (fn a b c body) — multi-arg untyped fn"
  (let ([r (p "(fn a b c (f a b c))")])
    (check-true (surf-lam? r))
    (check-equal? (binder-info-name (surf-lam-binder r)) 'a)
    (check-true (surf-hole? (binder-info-type (surf-lam-binder r))))
    ;; Second level
    (define inner1 (surf-lam-body r))
    (check-true (surf-lam? inner1))
    (check-equal? (binder-info-name (surf-lam-binder inner1)) 'b)
    (check-true (surf-hole? (binder-info-type (surf-lam-binder inner1))))
    ;; Third level
    (define inner2 (surf-lam-body inner1))
    (check-true (surf-lam? inner2))
    (check-equal? (binder-info-name (surf-lam-binder inner2)) 'c)
    ;; Innermost body is the application
    (check-true (surf-app? (surf-lam-body inner2)))))
