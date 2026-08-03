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

(test-case "pattern-var?: EVERY reader sentinel is excluded — enumerated, not sampled"
  ;; D4.P1b-ii spin-off 3. `$set-literal` and `$mixfix` answered #t while their
  ;; ten siblings answered #f — the whole exclusion list exists because a
  ;; sentinel treated as a pattern variable makes `datum-subst` RAISE inside a
  ;; defmacro template, and a raise on the preparse path is a WHOLE-FILE ABORT.
  ;;
  ;; Enumerated rather than spot-checked, because the defect IS the per-member
  ;; gap: a test sampling one or two sentinels passed for the whole time these
  ;; two were missing.
  (for ([s (in-list '($angle-type $brace-params $foreign-block
                      $dot-access $nil-dot-access $postfix-index
                      $broadcast-access $dot-key $nil-dot-key
                      $retired-selection $let-error $mixfix-error
                      $reader-error $let-block $goal-rhs $let-noop-body
                      $dot-brace $select-brace $select
                      $set-literal $mixfix))])
    (check-false (pattern-var? s)
                 (format "~a is a reader sentinel, not a pattern variable" s))))

(test-case "datum-subst: a sentinel in a template passes through"
  ;; `$dot-access` is the control that was always right; the other two were
  ;; excluded from `pattern-var?` alongside it. Since the polarity inversion
  ;; below, ALL unbound `$`-symbols pass through, so this is now one case of a
  ;; general rule rather than three special ones — kept because these are the
  ;; two the D4.P1b-ii filing named.
  (check-equal? (datum-subst (list '$set-literal 1) (hasheq)) '($set-literal 1))
  (check-equal? (datum-subst (list '$mixfix 1) (hasheq)) '($mixfix 1))
  (check-equal? (datum-subst (list '$dot-access 1) (hasheq)) '($dot-access 1)))

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

(test-case "datum-subst: an unbound variable PASSES THROUGH (polarity inverted 2026-08-03)"
  ;; This test asserted a RAISE until D4.P1b-iii item 8. The raise was a
  ;; whole-file abort on the preparse path, and `pattern-var?`'s hand-kept
  ;; exclusion list was the only thing holding 23 reader sentinels out of it —
  ;; so `'[1 2]` inside a template took the file down. The polarity is now
  ;; "bound ⇒ substitute", which makes every sentinel safe by construction.
  ;;
  ;; Deliberately CHANGED, not deleted: an unbound template variable is still
  ;; wrong, it now fails at the USE site as an ordinary unbound-variable error
  ;; naming the symbol, per-command and with a srcloc.
  (check-equal? (datum-subst '$unbound (hasheq)) '$unbound))

;; ========================================
;; preparse-expand-form tests
;; ========================================

(test-case "preparse-expand-form: no match passes through"
  (check-equal? (preparse-expand-form '(foo 1 2) (hasheq)) '(foo 1 2)))

(test-case "preparse-expand-form: pattern-template macro"
  (define reg (hasheq 'double
                      (preparse-macro 'double '(double $x) '(pair $x $x))))
  (check-equal? (preparse-expand-form '(double 42N) reg) '(pair 42N 42N)))

(test-case "preparse-expand-form: procedural macro"
  (define reg (hasheq 'suc-lit
                      (lambda (datum) (list 'result (+ (cadr datum) 1)))))
  (check-equal? (preparse-expand-form '(suc-lit 5) reg) '(result 6)))

(test-case "preparse-expand-form: depth limit"
  (define reg (hasheq 'loop
                      (preparse-macro 'loop '(loop) '(loop))))
  (check-exn exn:fail?
    (lambda () (preparse-expand-form '(loop) reg))))

;; ========================================
;; Built-in let expansion
;; ========================================

(test-case "let: single binding"
  (define result (preparse-expand-form '(let ([x : Nat zero]) (suc x))))
  ;; Should produce ((fn (x : Nat) (suc x)) zero)
  (check-equal? result '((fn (x : Nat) (suc x)) zero)))

(test-case "let: two bindings (sequential)"
  (define result (preparse-expand-form '(let ([x : Nat zero] [y : Nat (suc x)]) (suc y))))
  ;; Should produce ((fn (x : Nat) ((fn (y : Nat) (suc y)) (suc x))) zero)
  (check-equal? result '((fn (x : Nat) ((fn (y : Nat) (suc y)) (suc x))) zero)))

(test-case "let: wrong arity"
  ;; LET P1 (2026-07-31): expand-let no longer RAISES — a raise on the preparse
  ;; path was a whole-file abort. Failures now return a ($let-error "msg")
  ;; marker datum that the parser converts to a per-command parse error.
  (define result (preparse-expand-form '(let)))
  (check-true (and (pair? result) (eq? (car result) '$let-error))
              (format "expected a $let-error marker, got: ~v" result))
  (check-true (regexp-match? #rx"let requires at least" (cadr result))
              (format "got: ~v" result)))

;; ========================================
;; let := expansion
;; ========================================

(test-case "let :=: no type"
  ;; (let x := zero body) → ((fn (x : _) body) zero)
  (define result (preparse-expand-form '(let x := zero body)))
  (check-equal? result '((fn (x : _) body) zero)))

(test-case "let :=: with type"
  ;; (let x : Nat := zero body) → ((fn (x : Nat) body) zero)
  (define result (preparse-expand-form '(let x : Nat := zero body)))
  (check-equal? result '((fn (x : Nat) body) zero)))

(test-case "let :=: complex type (List Nat)"
  ;; (let xs : List Nat := nil body) → ((fn (xs : (List Nat)) body) nil)
  (define result (preparse-expand-form '(let xs : List Nat := nil body)))
  (check-equal? result '((fn (xs : (List Nat)) body) nil)))

(test-case "let :=: bracket multi-binding"
  ;; (let [x := zero y := (suc zero)] body) → nested fns
  (define result (preparse-expand-form '(let (x := zero y := (suc zero)) body)))
  (check-equal? result '((fn (x : _) ((fn (y : _) body) (suc zero))) zero)))

(test-case "let :=: bracket with types"
  ;; (let [x : Nat := zero y : Nat := (suc x)] body) → nested fns with types
  (define result (preparse-expand-form '(let (x : Nat := zero y : Nat := (suc x)) body)))
  (check-equal? result '((fn (x : Nat) ((fn (y : Nat) body) (suc x))) zero)))

(test-case "let :=: with -> in type"
  ;; (let f : Nat -> Nat := (fn (x : Nat) x) body) — type contains ->
  ;; type atoms: (Nat -> Nat), value: (fn (x : Nat) x)
  ;; Since -> is a symbol in sexp mode, type = (Nat -> Nat)
  (define result (preparse-expand-form '(let f : (-> Nat Nat) := (fn (x : Nat) x) body)))
  (check-equal? result '((fn (f : (-> Nat Nat)) body) (fn (x : Nat) x))))

(test-case "let: minimal no-:= shorthand"
  ;; (let x zero body) → ((fn (x : _) body) zero)
  (define result (preparse-expand-form '(let x zero body)))
  (check-equal? result '((fn (x : _) body) zero)))

(test-case "let: existing old format still works"
  ;; (let ([x : Nat zero]) body) — must still work
  (define result (preparse-expand-form '(let ([x : Nat zero]) body)))
  (check-equal? result '((fn (x : Nat) body) zero)))

;; ========================================
;; Sibling let merging
;; ========================================

(test-case "sibling let: two lets merge"
  (define elems (list '(let a := 1) '(let b := 2 body)))
  (define merged (merge-sibling-lets elems))
  (check-equal? merged '((let (a := 1 b := 2) body))))

(test-case "sibling let: three lets merge"
  (define elems (list '(let a := 1) '(let b := 2) '(let c := 3 body)))
  (define merged (merge-sibling-lets elems))
  (check-equal? merged '((let (a := 1 b := 2 c := 3) body))))

(test-case "sibling let: no merge for non-adjacent"
  (define elems (list '(let a := 1 body1) 'something '(let b := 2 body2)))
  (define merged (merge-sibling-lets elems))
  (check-equal? merged elems))

(test-case "sibling let: typed lets merge"
  (define elems (list '(let a : Nat := 1) '(let b : Nat := 2 body)))
  (define merged (merge-sibling-lets elems))
  (check-equal? merged '((let (a : Nat := 1 b : Nat := 2) body))))

(test-case "sibling let: single let unchanged"
  (define elems (list '(let x := 42 body)))
  (define merged (merge-sibling-lets elems))
  (check-equal? merged elems))

(test-case "sibling let: merge in preparse context"
  ;; Simulate what def body looks like: (def name : type (let a ...) (let b ... body))
  (define datum '(def result : Nat (let a : Nat := zero) (let b : Nat := (suc a) (suc b))))
  (define expanded (preparse-expand-form datum))
  ;; Should merge lets, then expand to nested fn/app
  (check-equal? expanded '(def result : Nat ((fn (a : Nat) ((fn (b : Nat) (suc b)) (suc a))) zero))))

;; ========================================
;; Built-in do expansion
;; ========================================

(test-case "do: single binding"
  (define result (preparse-expand-form '(do [x : Nat = zero] (suc x))))
  ;; do expands to let first, then let expands to fn/app
  ;; First expansion: (let ([x : Nat zero]) (suc x))
  ;; Second expansion: ((fn (x : Nat) (suc x)) zero)
  (check-equal? result '((fn (x : Nat) (suc x)) zero)))

(test-case "do: just body (no bindings)"
  (define result (preparse-expand-form '(do (suc zero))))
  ;; No bindings, just the body
  (check-equal? result '(suc zero)))

;; ========================================
;; Built-in if expansion
;; ========================================

(test-case "if: expands to boolrec"
  (define result (preparse-expand-form '(if Nat true zero (suc zero))))
  ;; (if Nat true zero (suc zero))
  ;; → (boolrec Nat zero (suc zero) true)
  ;; The parser's constant motive shorthand wraps the bare Nat type.
  (check-equal? result '(boolrec Nat zero (suc zero) true)))

(test-case "if: 3-arg form expands to boolrec with hole motive"
  ;; Sprint 10: (if cond then else) — motive inferred via hole
  (define result (preparse-expand-form '(if true zero (suc zero))))
  ;; → (boolrec _ zero (suc zero) true)
  (check-equal? result '(boolrec _ zero (suc zero) true)))

(test-case "if: wrong arity"
  ;; Sprint 10: 3-arg form is now valid — (if cond then else)
  ;; Test 2-arg form which is still an error
  (check-exn exn:fail?
    (lambda () (preparse-expand-form '(if true zero)))))

;; ========================================
;; defmacro registration
;; ========================================

(test-case "process-defmacro: register and expand"
  (parameterize ([current-preparse-registry (current-preparse-registry)])
    (process-defmacro '(defmacro not ($b) (if Bool $b false true)))
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
    (define stxs (list (datum->syntax #f '(defmacro not ($b) (if Bool $b false true)))
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

;; ========================================
;; Template polarity: an UNBOUND `$`-symbol passes through (D4.P1b-iii item 8)
;; ========================================
;;
;; `datum-subst` used to RAISE on any `$`-symbol not in `bindings`, and
;; `pattern-var?`'s hand-maintained exclusion list was the only thing keeping
;; reader sentinels out of that raise. A census put the residual at 23 of 33 —
;; so a plain quoted list inside a defmacro template took the WHOLE FILE down.
;;
;; The fix is the polarity, not 23 more exclusions: the only thing that makes a
;; symbol a pattern variable is being BOUND by the macro's pattern, and
;; `bindings` knows that exactly. Every sentinel is then safe BY CONSTRUCTION.
;;
;; These tests enumerate the census rather than sampling it — the defect was a
;; per-member gap, and a test checking one or two members passed throughout.

(define reader-sentinels-in-templates
  '($clause-sep $compose $decimal-literal $exp-literal $facts-sep
    $float-literal $list-literal $list-tail $lseq-literal $mixfix
    $narrow-eq $nat-literal $pipe $pipe-gt $posit-literal $quasiquote
    $rat-literal $rest $rest-param $set-literal $typed-hole $unquote
    $vec-literal))

(test-case "datum-subst: every censused reader sentinel passes through a template"
  (for ([sym (in-list reader-sentinels-in-templates)])
    (check-equal? (datum-subst (list sym 1 2) (hasheq '$x 99))
                  (list sym 1 2)
                  (format "~a must survive a template unchanged" sym))))

(test-case "datum-subst: a BOUND variable still substitutes, scalar and spliced"
  (check-equal? (datum-subst '$x (hasheq '$x 42)) 42)
  (check-equal? (datum-subst '($x) (hasheq '$x 42)) '(42))
  (check-equal? (datum-subst '($xs ...) (hasheq '$xs '(1 2 3))) '(1 2 3)))

(test-case "datum-subst: a bound splice variable that is NOT a list still raises"
  ;; The one raise worth keeping: the variable IS bound, so this is a genuine
  ;; misuse rather than an unrecognized symbol.
  (check-exn exn:fail?
             (lambda () (datum-subst '($x ...) (hasheq '$x 1)))))

(test-case "datum-subst: a TYPO'D template variable passes through, to fail at the USE site"
  ;; What the inversion costs, pinned so it is a decision rather than a
  ;; surprise. `$typoo` is not bound and is not a sentinel; it survives
  ;; substitution and becomes an ordinary unbound-variable error where the
  ;; macro is used — per-command, with a srcloc, file intact. Better than the
  ;; whole-file abort it replaces.
  (check-equal? (datum-subst '($typoo) (hasheq '$x 1)) '($typoo)))

;; ========================================
;; pp-datum renders ACCESS SENTINELS (D4.P1b-iii spin-off 7)
;; ========================================
;;
;; Every access sentinel rendered as a RAW SENTINEL — `($dot-access foo)`
;; verbatim — while `$brace-params` rendered. Any diagnostic printing a datum
;; that contains an access form leaked compiler internals into user-facing
;; text.
;;
;; The expected spellings mirror the READER's own emission shapes
;; (parse-reader's `token-entry->stx` / `group-items`), not a guess: e.g.
;; `nil-dot-access` strips TWO leading chars from the lexeme, which is `?.`.

(require (only-in "../pretty-print.rkt" pp-datum))

(test-case "pp-datum: access sentinels render as their surface spelling"
  (check-equal? (pp-datum '($dot-access foo))       ".foo")
  (check-equal? (pp-datum '($nil-dot-access foo))   "?.foo")
  (check-equal? (pp-datum '($broadcast-access foo)) "*.foo")
  (check-equal? (pp-datum '($dot-key :k))           ".:k")
  (check-equal? (pp-datum '($nil-dot-key :k))       "?.:k")
  (check-equal? (pp-datum '($postfix-index 0))      "[0]")
  (check-equal? (pp-datum '($select-brace a b))     "{a b}")
  (check-equal? (pp-datum '($dot-brace a b))        ".{a b}"))

(test-case "pp-datum: no access sentinel survives into rendered text"
  ;; The property, independent of the individual spellings above: whatever the
  ;; rendering is, the internal `$name` must not appear in it. This is what a
  ;; user-facing diagnostic actually depends on.
  (for ([d (in-list '(($dot-access foo) ($nil-dot-access foo) ($broadcast-access foo)
                      ($dot-key :k) ($nil-dot-key :k) ($postfix-index 0)
                      ($select-brace a b) ($dot-brace a b)
                      ($brace-params A B) ($set-literal 1) ($vec-literal 1)))])
    (define out (pp-datum d))
    (check-false (regexp-match? #rx"[$]" out)
                 (format "~v leaked a sentinel: ~a" d out))))

(test-case "pp-datum: sentinels nested inside an ordinary form render too"
  ;; The realistic diagnostic shape — the sentinel is never the whole datum.
  (check-equal? (pp-datum '(f ($dot-access bar) 1)) "(f .bar 1)"))
