#lang racket/base

;;;
;;; Tests for pre-parse macro system (macros.rkt layer 1)
;;; Tests datum-match, datum-subst, defmacro, and built-in macros.
;;;

(require rackunit
         racket/file
         racket/list
         "../macros.rkt"
         "../errors.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "test-support.rkt")

;; ---- Level 3 fixture (used only by the containment block at the end) --------
;; A raise during preparse is a WHOLE-FILE abort, and that is observable ONLY
;; through a real file with sibling commands on both sides of the offending one.
;; The datum-level pins above cannot see it: they call `datum-subst` directly.
(define-values (pre-global-env pre-ns-context pre-module-reg
                pre-trait-reg pre-impl-reg pre-param-impl-reg)
  (parameterize ([current-file-module-network-ref (make-module-network)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry])
    (install-module-loader!)
    (process-string "(ns defmacro-pre)")
    (values (global-env-snapshot) (current-ns-context) (current-module-registry)
            (current-trait-registry) (current-impl-registry)
            (current-param-impl-registry))))

(define (run-file-ws s)
  (define tmp (make-temporary-file "prologos-defmacro-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace (lambda (out) (display s out)))
  (define result
    (parameterize ([current-file-module-network-ref
                    (module-network-add-import (make-module-network)
                                               (module-network-from-snapshot pre-global-env))]
                   [current-ns-context pre-ns-context]
                   [current-module-registry pre-module-reg]
                   [current-trait-registry pre-trait-reg]
                   [current-impl-registry pre-impl-reg]
                   [current-param-impl-registry pre-param-impl-reg])
      (process-file (path->string tmp))))
  (delete-file tmp)
  result)

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

;; ========================================
;; A template's pattern variables are the ones the PATTERN BOUND (2026-08-01)
;; ========================================
;; ⚠ THE PIN BELOW WAS FLIPPED, and it is the whole point of this block.
;;
;; `datum-subst` used to `error` on any `$`-headed symbol missing from the
;; bindings. `pattern-var?` decides by NAME — `$`-prefixed minus a
;; hand-maintained denylist — but the READER mints `$`-headed sentinels for
;; ordinary surface syntax, and `datum-subst` recurses into every element
;; including list heads. So the error did not fire on typos; it fired on
;; SENTINELS, as a raise at preparse, i.e. a WHOLE-FILE ABORT.
;;
;; Measured at 969bfd6c: a defmacro template containing `5N`, `1/2` or `|>`
;; each took the whole file down with zero results. The denylist was missing
;; TWENTY-FOUR reader-minted sentinels. A denylist cannot be the answer — it
;; must re-enumerate every sentinel the reader will ever mint, and it had
;; already failed twice before (`$dot-brace` and `$select` both carry
;; "whole-file abort in a defmacro template" notes in macros.rkt) and a third
;; time for `$bcast-step`, minted one commit earlier by the `:` mint.
;;
;; `bindings` is the authority: a pattern variable is one the PATTERN bound.
;; Anything else is a literal. Sentinels then work BY CONSTRUCTION.

(test-case "datum-subst: an UNBOUND $-symbol is a literal, not an error"
  ;; Was `(check-exn exn:fail? …)`. That pin encoded the abort as intended
  ;; behaviour, which is why the sentinel class survived three sightings.
  (check-equal? (datum-subst '$unbound (hasheq)) '$unbound)
  ;; …and a BOUND one still substitutes, which is the property that matters.
  (check-equal? (datum-subst '$x (hasheq '$x 42)) 42))

(test-case "datum-subst: reader sentinels survive a template by construction"
  ;; The four measured aborts, at the datum level. These are not exotic: they
  ;; are a Nat literal, a rational, a list literal and a pipeline.
  (for ([sentinel (in-list '($nat-literal $rat-literal $list-literal $pipe-gt
                             $bcast-step $mixfix $quasiquote $typed-hole))])
    (define template (list 'f (list sentinel 5) '$u))
    (check-equal? (datum-subst template (hasheq '$u 'arg))
                  (list 'f (list sentinel 5) 'arg)
                  (format "~a must pass through a template untouched" sentinel))))

(test-case "L3: a sentinel-bearing macro template does NOT abort the file"
  ;; THE CONTAINMENT PIN. Before the fix each of these returned NOTHING —
  ;; `process-file` raised out of preparse, so `def before-marker` (written
  ;; ABOVE the macro use) never ran either. The datum-level pins above cannot
  ;; observe that; only a real file with siblings can.
  (for ([lit (in-list '("5N" "1/2" "'[1 2 3]"))])
    (define rs (run-file-ws
                (string-append
                 "ns dm-l3\n"
                 "def before-marker := 1\n"
                 "defn pair [p q] p\n"
                 "defmacro mk [$u]\n"
                 "  [pair $u " lit "]\n"
                 "def used := [mk 9]\n"
                 "def after-marker := 2\n")))
    ;; 4 results: before-marker, pair, used, after-marker (defmacro is consumed)
    (check-equal? (length rs) 4
                  (format "template with ~a must not kill the file; got: ~v" lit rs))
    (check-false (prologos-error? (first rs))
                 (format "~a: the command BEFORE the macro must run" lit))
    (check-false (prologos-error? (last rs))
                 (format "~a: the command AFTER it must run" lit))))

(test-case "L3: a `name:key` template stays contained (the `$bcast-step` sighting)"
  ;; ⚠ THIS PIN WAS NARROWED, and the reason is worth keeping.
  ;;
  ;; It originally also asserted the message text — that the sentinel reached
  ;; P4c-2's guided "broadcast `:field` is not implemented yet" diagnostic,
  ;; which the abort had been MASKING. That held while the `:` mint was ON by
  ;; default: `$u:field` read as `($u ($bcast-step :field))`, and `$bcast-step`
  ;; was the third sentinel to trip the pattern-variable abort.
  ;;
  ;; CIU T6 D4.P4c-2 then INVERTED THE MINT DEFAULT (`68cdaae7`), so at HEAD
  ;; `$u:field` reads as plain `($u :field)` and mints no sentinel at all. The
  ;; message assertion was therefore pinned to a reader default, not to this
  ;; seam's behaviour, and it went red the moment that default flipped — caught
  ;; on merging main, before it could reach anyone else.
  ;;
  ;; What survives here is the property that is actually THIS file's business:
  ;; the form stays CONTAINED. Coverage of `$bcast-step` itself is unaffected —
  ;; it is named explicitly in the datum-level "reader sentinels survive a
  ;; template by construction" pin above, which does not depend on whether the
  ;; reader currently mints it. That is the durable half; this is the L3 half.
  (define rs (run-file-ws (string-append
                           "ns dm-bcast\n"
                           "def before-marker := 1\n"
                           "defmacro getb [$u]\n"
                           "  [$u:field]\n"
                           "def m := {:field 7}\n"
                           "getb m\n"
                           "def after-marker := 2\n")))
  (check-equal? (length rs) 4 (format "got: ~v" rs))
  (check-false (prologos-error? (first rs)) "the command BEFORE must run")
  (check-false (prologos-error? (last rs)) "the command AFTER must run")
  (define msgs (for/list ([r (in-list rs)] #:when (prologos-error? r))
                 (prologos-error-message r)))
  (check-equal? (length msgs) 1 (format "expected exactly one error; got: ~v" rs)))

(test-case "datum-subst: the SPLICE branch keeps its unbound error"
  ;; Deliberately NOT relaxed. A sentinel is a list HEAD followed by its
  ;; payload, never a bare symbol followed by `...`, so this arm cannot be
  ;; tripped by one and its typo signal stays clean.
  (check-exn exn:fail?
    (lambda () (datum-subst '(foo $args ...) (hasheq)))))

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
