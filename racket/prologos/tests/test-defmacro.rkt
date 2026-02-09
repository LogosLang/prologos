#lang racket/base

;;;
;;; Tests for pre-parse macro system (macros.rkt layer 1)
;;; Tests datum-match, datum-subst, defmacro, and built-in macros.
;;;

(require rackunit
         "../macros.rkt")

;; ========================================
;; datum-match tests
;; ========================================

(test-case "datum-match: literal symbol"
  (check-equal? (datum-match 'foo 'foo) (hasheq))
  (check-false (datum-match 'foo 'bar)))

(test-case "datum-match: literal number"
  (check-equal? (datum-match 42 42) (hasheq))
  (check-false (datum-match 42 43)))

(test-case "datum-match: literal boolean"
  (check-equal? (datum-match #t #t) (hasheq))
  (check-false (datum-match #t #f)))

(test-case "datum-match: pattern variable"
  (define result (datum-match '$x 'hello))
  (check-equal? result (hasheq '$x 'hello)))

(test-case "datum-match: list pattern"
  (define result (datum-match '(foo $x $y) '(foo 1 2)))
  (check-equal? result (hasheq '$x 1 '$y 2)))

(test-case "datum-match: nested list pattern"
  (define result (datum-match '(foo ($x $y)) '(foo (1 2))))
  (check-equal? result (hasheq '$x 1 '$y 2)))

(test-case "datum-match: list length mismatch"
  (check-false (datum-match '(foo $x $y) '(foo 1)))
  (check-false (datum-match '(foo $x) '(foo 1 2))))

(test-case "datum-match: rest pattern with ..."
  (define result (datum-match '(foo $x ...) '(foo 1 2 3)))
  (check-equal? result (hasheq '$x '(1 2 3))))

(test-case "datum-match: rest pattern empty"
  (define result (datum-match '(foo $x ...) '(foo)))
  (check-equal? result (hasheq '$x '())))

(test-case "datum-match: mixed fixed and rest"
  (define result (datum-match '(foo $a $rest ...) '(foo 1 2 3 4)))
  (check-equal? result (hasheq '$a 1 '$rest '(2 3 4))))

(test-case "datum-match: type mismatch"
  (check-false (datum-match 'foo 42))
  (check-false (datum-match '() 'foo)))

;; ========================================
;; pattern-var? tests
;; ========================================

(test-case "pattern-var?: $ prefix"
  (check-true (pattern-var? '$x))
  (check-true (pattern-var? '$longname))
  (check-false (pattern-var? 'x))
  (check-false (pattern-var? 42))
  ;; Single $ is not a pattern var (need at least one char after $)
  (check-false (pattern-var? '$)))

;; ========================================
;; datum-subst tests
;; ========================================

(test-case "datum-subst: simple variable"
  (check-equal? (datum-subst '$x (hasheq '$x 42)) 42))

(test-case "datum-subst: literal passthrough"
  (check-equal? (datum-subst 'foo (hasheq)) 'foo)
  (check-equal? (datum-subst 42 (hasheq)) 42))

(test-case "datum-subst: list substitution"
  (check-equal? (datum-subst '(foo $x $y) (hasheq '$x 1 '$y 2))
                '(foo 1 2)))

(test-case "datum-subst: nested substitution"
  (check-equal? (datum-subst '(foo ($x $y)) (hasheq '$x 1 '$y 2))
                '(foo (1 2))))

(test-case "datum-subst: splice with ..."
  (check-equal? (datum-subst '(foo $args ...) (hasheq '$args '(1 2 3)))
                '(foo 1 2 3)))

(test-case "datum-subst: splice empty list"
  (check-equal? (datum-subst '(foo $args ...) (hasheq '$args '()))
                '(foo)))

(test-case "datum-subst: splice with more elements after"
  (check-equal? (datum-subst '(foo $args ... bar) (hasheq '$args '(1 2 3)))
                '(foo 1 2 3 bar)))

(test-case "datum-subst: unbound variable error"
  (check-exn exn:fail?
    (lambda () (datum-subst '$unbound (hasheq)))))

;; ========================================
;; preparse-expand-form tests
;; ========================================

(test-case "preparse-expand-form: no match passes through"
  (check-equal? (preparse-expand-form '(foo 1 2) (hasheq)) '(foo 1 2)))

(test-case "preparse-expand-form: pattern-template macro"
  (define reg (hasheq 'double
                      (preparse-macro 'double '(double $x) '(pair $x $x))))
  (check-equal? (preparse-expand-form '(double 42) reg) '(pair 42 42)))

(test-case "preparse-expand-form: procedural macro"
  (define reg (hasheq 'inc-lit
                      (lambda (datum) (list 'result (+ (cadr datum) 1)))))
  (check-equal? (preparse-expand-form '(inc-lit 5) reg) '(result 6)))

(test-case "preparse-expand-form: depth limit"
  (define reg (hasheq 'loop
                      (preparse-macro 'loop '(loop) '(loop))))
  (check-exn exn:fail?
    (lambda () (preparse-expand-form '(loop) reg))))

;; ========================================
;; Built-in let expansion
;; ========================================

(test-case "let: single binding"
  (define result (preparse-expand-form '(let ([x : Nat zero]) (inc x))))
  ;; Should produce ((fn (x : Nat) (inc x)) zero)
  (check-equal? result '((fn (x : Nat) (inc x)) zero)))

(test-case "let: two bindings (sequential)"
  (define result (preparse-expand-form '(let ([x : Nat zero] [y : Nat (inc x)]) (inc y))))
  ;; Should produce ((fn (x : Nat) ((fn (y : Nat) (inc y)) (inc x))) zero)
  (check-equal? result '((fn (x : Nat) ((fn (y : Nat) (inc y)) (inc x))) zero)))

(test-case "let: wrong arity"
  (check-exn exn:fail?
    (lambda () (preparse-expand-form '(let)))))

;; ========================================
;; Built-in do expansion
;; ========================================

(test-case "do: single binding"
  (define result (preparse-expand-form '(do [x : Nat = zero] (inc x))))
  ;; do expands to let first, then let expands to fn/app
  ;; First expansion: (let ([x : Nat zero]) (inc x))
  ;; Second expansion: ((fn (x : Nat) (inc x)) zero)
  (check-equal? result '((fn (x : Nat) (inc x)) zero)))

(test-case "do: just body (no bindings)"
  (define result (preparse-expand-form '(do (inc zero))))
  ;; No bindings, just the body
  (check-equal? result '(inc zero)))

;; ========================================
;; Built-in if expansion
;; ========================================

(test-case "if: expands to boolrec"
  (define result (preparse-expand-form '(if Nat true zero (inc zero))))
  ;; (if Nat true zero (inc zero))
  ;; → (boolrec Nat zero (inc zero) true)
  ;; The parser's constant motive shorthand wraps the bare Nat type.
  (check-equal? result '(boolrec Nat zero (inc zero) true)))

(test-case "if: wrong arity"
  (check-exn exn:fail?
    (lambda () (preparse-expand-form '(if Nat true zero)))))

;; ========================================
;; defmacro registration
;; ========================================

(test-case "process-defmacro: register and expand"
  (parameterize ([current-preparse-registry (current-preparse-registry)])
    (process-defmacro '(defmacro (not $b) (if Bool $b false true)))
    ;; Now 'not should be registered
    (define expanded (preparse-expand-form '(not true)))
    ;; not true → (if Bool true false true) → (boolrec Bool false true true)
    (check-equal? expanded '(boolrec Bool false true true))))

(test-case "process-defmacro: wrong format"
  (check-exn exn:fail?
    (lambda () (process-defmacro '(defmacro)))))

;; ========================================
;; deftype registration
;; ========================================

(test-case "process-deftype: simple alias (bare symbol)"
  (parameterize ([current-preparse-registry (current-preparse-registry)])
    (process-deftype '(deftype Endo (-> Nat Nat)))
    ;; Bare symbol Endo should expand to body
    (check-equal? (preparse-expand-form 'Endo) '(-> Nat Nat))))

(test-case "process-deftype: parameterized alias"
  (parameterize ([current-preparse-registry (current-preparse-registry)])
    (process-deftype '(deftype (Pair $A $B) (Sigma (x : $A) $B)))
    (define expanded (preparse-expand-form '(Pair Nat Bool)))
    (check-equal? expanded '(Sigma (x : Nat) Bool))))

;; ========================================
;; preparse-expand-all tests
;; ========================================

(test-case "preparse-expand-all: consume defmacro, expand usage"
  (parameterize ([current-preparse-registry (current-preparse-registry)])
    (define stxs (list (datum->syntax #f '(defmacro (not $b) (if Bool $b false true)))
                       (datum->syntax #f '(not true))))
    (define results (preparse-expand-all stxs))
    ;; defmacro should be consumed
    (check-equal? (length results) 1)
    ;; The remaining form should be expanded
    (define expanded (syntax->datum (car results)))
    ;; not true → if Bool true false true → boolrec Bool ...
    (check-equal? expanded '(boolrec Bool false true true))))

(test-case "preparse-expand-all: consume deftype, bare symbol at head"
  (parameterize ([current-preparse-registry (current-preparse-registry)])
    (define stxs (list (datum->syntax #f '(deftype Endo (-> Nat Nat)))
                       (datum->syntax #f 'Endo)))
    (define results (preparse-expand-all stxs))
    ;; deftype consumed
    (check-equal? (length results) 1)
    ;; Bare symbol Endo should be expanded
    (define expanded (syntax->datum (car results)))
    (check-equal? expanded '(-> Nat Nat))))

(test-case "preparse-expand-all: preserves non-macro forms"
  (parameterize ([current-preparse-registry (current-preparse-registry)])
    (define stxs (list (datum->syntax #f '(check zero : Nat))
                       (datum->syntax #f '(eval zero))))
    (define results (preparse-expand-all stxs))
    (check-equal? (length results) 2)
    (check-equal? (syntax->datum (car results)) '(check zero : Nat))
    (check-equal? (syntax->datum (cadr results)) '(eval zero))))
