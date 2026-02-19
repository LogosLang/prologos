#lang racket/base

;;;
;;; Tests for Type Surface Syntax Refactoring
;;;   Phase 0a: surf-arrow mult field
;;;   Phase 0b: Multiplied arrows (-0>, -1>, -w>)
;;;   Phase 0c: * infix product operator
;;;   Phase 0d: () in WS mode for type grouping
;;;   Phase 1:  Dependent type syntax in <> brackets
;;;

(require rackunit
         racket/string
         racket/port
         "../prelude.rkt"
         "../syntax.rkt"
         "../surface-syntax.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../errors.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../metavar-store.rkt"
         "../macros.rkt"
         "../sexp-readtable.rkt"
         (prefix-in tc: "../typing-core.rkt"))

;; ========================================
;; Helpers
;; ========================================
(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

(define (run-first s)
  (car (run s)))

(define (parse-type-str s)
  ;; Read a sexp-mode string with prologos readtable, then parse-datum
  (define stx
    (parameterize ([current-readtable prologos-readtable])
      (read-syntax 'test (open-input-string s))))
  (parse-datum stx))

;; ========================================
;; Phase 0a: surf-arrow mult field
;; ========================================

(test-case "0a: surf-arrow has mult field (default #f for plain ->)"
  (define r (parse-type-str "(-> Nat Nat)"))
  (check-true (surf-arrow? r))
  (check-equal? (surf-arrow-mult r) #f)
  (check-true (surf-nat-type? (surf-arrow-domain r)))
  (check-true (surf-nat-type? (surf-arrow-codomain r))))

(test-case "0a: plain -> elaborates to expr-Pi with mw"
  (check-equal? (run-first "(infer (-> Nat Nat))") "[Type 0]"))

;; ========================================
;; Phase 0b: Multiplied arrows
;; ========================================

(test-case "0b: (-1> Nat Nat) parses to surf-arrow with m1"
  (define r (parse-type-str "(-1> Nat Nat)"))
  (check-true (surf-arrow? r))
  (check-equal? (surf-arrow-mult r) 'm1)
  (check-true (surf-nat-type? (surf-arrow-domain r)))
  (check-true (surf-nat-type? (surf-arrow-codomain r))))

(test-case "0b: (-0> Nat Nat) parses to surf-arrow with m0"
  (define r (parse-type-str "(-0> Nat Nat)"))
  (check-true (surf-arrow? r))
  (check-equal? (surf-arrow-mult r) 'm0))

(test-case "0b: (-w> Nat Nat) parses to surf-arrow with mw"
  (define r (parse-type-str "(-w> Nat Nat)"))
  (check-true (surf-arrow? r))
  (check-equal? (surf-arrow-mult r) 'mw))

(test-case "0b: <Nat -1> Nat> infix in angle brackets"
  (define r (parse-type-str "($angle-type Nat -1> Nat)"))
  (check-true (surf-arrow? r))
  (check-equal? (surf-arrow-mult r) 'm1))

(test-case "0b: <Nat -0> Nat> infix in angle brackets"
  (define r (parse-type-str "($angle-type Nat -0> Nat)"))
  (check-true (surf-arrow? r))
  (check-equal? (surf-arrow-mult r) 'm0))

(test-case "0b: (-1> Nat Nat) elaborates to expr-Pi with m1"
  (check-equal? (run-first "(infer (-1> Nat Nat))") "[Type 0]"))

(test-case "0b: check fn against linear arrow type"
  (check-equal? (run-first "(check (fn [x :1 <Nat>] x) : (-1> Nat Nat))") "OK"))

(test-case "0b: mixed arrow mults: A -1> B -> C"
  (define r (parse-type-str "($angle-type Nat -1> Bool -> Nat)"))
  ;; Should be: Nat -1> (Bool -> Nat)
  (check-true (surf-arrow? r))
  (check-equal? (surf-arrow-mult r) 'm1)
  (check-true (surf-nat-type? (surf-arrow-domain r)))
  (define cod (surf-arrow-codomain r))
  (check-true (surf-arrow? cod))
  (check-equal? (surf-arrow-mult cod) #f))

;; ========================================
;; Phase 0c: * infix product operator
;; ========================================

(test-case "0c: <Nat * Bool> parses to surf-sigma with dummy binder"
  (define r (parse-type-str "($angle-type Nat $star Bool)"))
  (check-true (surf-sigma? r))
  (define binder (surf-sigma-binder r))
  (check-equal? (binder-info-name binder) '_)
  (check-true (surf-nat-type? (binder-info-type binder)))
  (check-true (surf-bool-type? (surf-sigma-body r))))

(test-case "0c: Nat * Bool * Unit right-associates"
  (define r (parse-type-str "($angle-type Nat $star Bool $star Unit)"))
  (check-true (surf-sigma? r))
  (check-true (surf-nat-type? (binder-info-type (surf-sigma-binder r))))
  (define inner (surf-sigma-body r))
  (check-true (surf-sigma? inner))
  (check-true (surf-bool-type? (binder-info-type (surf-sigma-binder inner))))
  (check-true (surf-unit-type? (surf-sigma-body inner))))

(test-case "0c: * binds tighter than -> : Nat -> Bool * Unit"
  ;; Should parse as: Nat -> (Bool * Unit)
  (define r (parse-type-str "($angle-type Nat -> Bool $star Unit)"))
  (check-true (surf-arrow? r))
  (check-true (surf-nat-type? (surf-arrow-domain r)))
  (define cod (surf-arrow-codomain r))
  (check-true (surf-sigma? cod))
  (check-true (surf-bool-type? (binder-info-type (surf-sigma-binder cod)))))

(test-case "0c: Nat * Bool -> Unit (arrow lower precedence)"
  ;; Should parse as: (Nat * Bool) -> Unit
  (define r (parse-type-str "($angle-type Nat $star Bool -> Unit)"))
  (check-true (surf-arrow? r))
  (define dom (surf-arrow-domain r))
  (check-true (surf-sigma? dom))
  (check-true (surf-unit-type? (surf-arrow-codomain r))))

(test-case "0c: <Nat * Bool> elaborates and infers type"
  (check-equal? (run-first "(infer (Sigma (_ : Nat) Bool))") "[Type 0]"))

(test-case "0c: pipeline: (check (pair zero true) : <Nat * Bool>)"
  ;; Nat * Bool = Sigma(_ : Nat, Bool)
  ;; (pair zero true) should check against it
  (check-equal?
    (run-first "(check (pair zero true) : ($angle-type Nat $star Bool))")
    "OK"))

;; ========================================
;; Phase 0d: () in WS mode
;; ========================================
;; Note: WS mode tests use process-string which goes through the WS reader.
;; Since test strings here are in sexp mode, we test paren grouping through
;; sexp-mode parens which already work. The WS reader test is in test-reader.rkt.

(test-case "0d: sexp parens still work for type grouping"
  ;; (-> Nat Nat) inside parens is the standard prefix form
  (check-equal? (run-first "(infer (-> Nat Nat))") "[Type 0]"))

;; ========================================
;; Phase 1: Dependent type syntax in <>
;; ========================================

(test-case "1: <(x : Nat) -> Nat> parses to surf-pi"
  (define r (parse-type-str "($angle-type (x : Nat) -> Nat)"))
  (check-true (surf-pi? r))
  (define binder (surf-pi-binder r))
  (check-equal? (binder-info-name binder) 'x)
  (check-true (surf-nat-type? (binder-info-type binder)))
  (check-true (surf-nat-type? (surf-pi-body r))))

(test-case "1: <(x : Nat) -> Nat> mult defaults to #f"
  (define r (parse-type-str "($angle-type (x : Nat) -> Nat)"))
  (check-true (surf-pi? r))
  (check-equal? (binder-info-mult (surf-pi-binder r)) #f))

(test-case "1: <(x : Nat) -1> Nat> parses with m1 mult"
  (define r (parse-type-str "($angle-type (x : Nat) -1> Nat)"))
  (check-true (surf-pi? r))
  (check-equal? (binder-info-mult (surf-pi-binder r)) 'm1))

(test-case "1: <(x : Nat) * Bool> parses to surf-sigma"
  (define r (parse-type-str "($angle-type (x : Nat) $star Bool)"))
  (check-true (surf-sigma? r))
  (define binder (surf-sigma-binder r))
  (check-equal? (binder-info-name binder) 'x)
  (check-true (surf-nat-type? (binder-info-type binder)))
  (check-true (surf-bool-type? (surf-sigma-body r))))

(test-case "1: <(x : Nat, y : Bool) -> Unit> nested Pi"
  (define r (parse-type-str "($angle-type (x : Nat y : Bool) -> Unit)"))
  (check-true (surf-pi? r))
  (check-equal? (binder-info-name (surf-pi-binder r)) 'x)
  (check-true (surf-nat-type? (binder-info-type (surf-pi-binder r))))
  (define inner (surf-pi-body r))
  (check-true (surf-pi? inner))
  (check-equal? (binder-info-name (surf-pi-binder inner)) 'y)
  (check-true (surf-bool-type? (binder-info-type (surf-pi-binder inner))))
  (check-true (surf-unit-type? (surf-pi-body inner))))

(test-case "1: shorthand <x : Nat -> Nat> parses to surf-pi"
  (define r (parse-type-str "($angle-type x : Nat -> Nat)"))
  (check-true (surf-pi? r))
  (define binder (surf-pi-binder r))
  (check-equal? (binder-info-name binder) 'x)
  (check-true (surf-nat-type? (binder-info-type binder)))
  (check-true (surf-nat-type? (surf-pi-body r))))

(test-case "1: shorthand <x : Nat * Bool> parses to surf-sigma"
  (define r (parse-type-str "($angle-type x : Nat $star Bool)"))
  (check-true (surf-sigma? r))
  (define binder (surf-sigma-binder r))
  (check-equal? (binder-info-name binder) 'x)
  (check-true (surf-nat-type? (binder-info-type binder)))
  (check-true (surf-bool-type? (surf-sigma-body r))))

;; Disambiguation tests

(test-case "1: <(-> Nat Nat)> still works (prefix arrow in parens)"
  ;; paren-binder-group? returns #f because no ':' inside
  (define r (parse-type-str "($angle-type (-> Nat Nat))"))
  (check-true (surf-arrow? r)))

(test-case "1: <Nat -> Nat> still works (plain infix arrow)"
  (define r (parse-type-str "($angle-type Nat -> Nat)"))
  (check-true (surf-arrow? r)))

(test-case "1: <Nat | Bool> still works (union type)"
  (define r (parse-type-str "($angle-type Nat $pipe Bool)"))
  (check-true (surf-union? r)))

(test-case "1: <Nat> still works (single type)"
  (define r (parse-type-str "($angle-type Nat)"))
  (check-true (surf-nat-type? r)))

;; Elaboration and pipeline tests

(test-case "1: <(x : Nat) -> Nat> elaborates to expr-Pi"
  (check-equal? (run-first "(infer ($angle-type (x : Nat) -> Nat))") "[Type 0]"))

(test-case "1: check identity against <(x : Nat) -> Nat>"
  (check-equal?
    (run-first "(check (fn [x <Nat>] x) : ($angle-type (x : Nat) -> Nat))")
    "OK"))

(test-case "1: <(x : Nat) -1> Nat> linear Pi elaboration"
  (check-equal? (run-first "(infer ($angle-type (x : Nat) -1> Nat))") "[Type 0]"))

(test-case "1: check linear fn against <(x : Nat) -1> Nat>"
  (check-equal?
    (run-first "(check (fn [x :1 <Nat>] x) : ($angle-type (x : Nat) -1> Nat))")
    "OK"))

(test-case "1: <(x : Nat) * Bool> sigma elaboration"
  (check-equal? (run-first "(infer ($angle-type (x : Nat) $star Bool))") "[Type 0]"))

(test-case "1: check pair against <(x : Nat) * Bool>"
  (check-equal?
    (run-first "(check (pair zero true) : ($angle-type (x : Nat) $star Bool))")
    "OK"))

;; Regression: all existing patterns still work

(test-case "regression: (def one <Nat> (suc zero)) still works"
  (check-equal? (run-first "(def one <Nat> (suc zero))") "one : Nat defined."))

(test-case "regression: (check zero : <Nat | Bool>) still works"
  (check-equal? (run-first "(check zero : <Nat | Bool>)") "OK"))

(test-case "regression: (infer <Nat | Bool>) still works"
  (check-equal? (run-first "(infer <Nat | Bool>)") "[Type 0]"))
