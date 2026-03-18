#lang racket/base

;;;
;;; PROLOGOS INTROSPECTION TESTS
;;; Tests for Phase II introspection tooling: expand-1, expand-full, REPL commands.
;;; See docs/tracking/2026-02-19_HOMOICONICITY_ROADMAP.md (Phase II).
;;;
;;; Tests added 2026-02-19 as part of Phase II: Introspection Tooling.
;;;

(require rackunit
         racket/list
         racket/port
         racket/string
         racket/file
         racket/path
         "test-support.rkt"
         "../sexp-readtable.rkt"
         "../reader.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../reduction.rkt"
         "../namespace.rkt"
         "../trait-resolution.rkt")

;; ========================================
;; Helpers
;; ========================================

;; Run sexp-mode code
(define (run s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-bundle-registry (current-bundle-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string s)))

(define (run-last s) (last (run s)))

;; ========================================
;; A. preparse-expand-1 unit tests
;; ========================================

(test-case "expand-1: do macro with no bindings strips to body"
  ;; (do expr) with no bindings is stripped to just the body by expand-do
  (define result (preparse-expand-1 '(do (add 1 2))))
  ;; expand-do with single body: returns the body directly
  (check-equal? result '(add 1 2)))

(test-case "expand-1: if macro expands one step to boolrec"
  ;; (if cond then else) → (boolrec _ then else cond)
  (define result (preparse-expand-1 '(if True (suc zero) zero)))
  (check-true (pair? result))
  (check-equal? (car result) 'boolrec))

(test-case "expand-1: non-macro form returns unchanged"
  (define result (preparse-expand-1 '(add 1 2)))
  (check-equal? result '(add 1 2)))

(test-case "expand-1: bare symbol non-macro returns unchanged"
  (define result (preparse-expand-1 'foo))
  (check-equal? result 'foo))

(test-case "expand-1: number returns unchanged"
  (define result (preparse-expand-1 42))
  (check-equal? result 42))

(test-case "expand-1: $foreign-block is opaque"
  (define result (preparse-expand-1 '($foreign-block racket (+ 1 2))))
  (check-equal? result '($foreign-block racket (+ 1 2))))

(test-case "expand-1: does NOT recurse into subforms"
  ;; (fn (x) (if True x zero)) — the if is inside a subform
  ;; expand-1 should NOT expand the inner if
  (define result (preparse-expand-1 '(fn (x) (if True x zero))))
  ;; fn is not a macro, so the form should be unchanged
  (check-equal? result '(fn (x) (if True x zero))))

(test-case "expand-1: $list-literal procedural macro expands"
  (define result (preparse-expand-1 '($list-literal 1 2 3)))
  ;; Should be expanded by the list literal macro
  (check-true (pair? result))
  ;; Should not still be $list-literal
  (check-not-equal? (car result) '$list-literal))

(test-case "expand-1: let procedural macro transforms to fn application"
  ;; let is a procedural macro that transforms to ((fn (x : _) body) value)
  (define result (preparse-expand-1 '(let x := 42 (add x 1))))
  (check-true (pair? result))
  ;; Result is ((fn (x : _) (add x 1)) 42) — an application
  (check-true (pair? (car result)))  ;; car is the fn form
  (check-equal? (caar result) 'fn)   ;; first of fn form is 'fn
  (check-equal? (cadr result) 42))

(test-case "expand-1: user defmacro (pattern-template) works"
  ;; Register a user macro and test single-step expansion
  ;; defmacro expects: (defmacro name (params...) template)
  (parameterize ([current-preparse-registry prelude-preparse-registry])
    (process-defmacro '(defmacro my-double ($x) (add $x $x)))
    (define result (preparse-expand-1 '(my-double zero)))
    (check-equal? result '(add zero zero))))

(test-case "expand-1: user defmacro non-matching pattern unchanged"
  (parameterize ([current-preparse-registry prelude-preparse-registry])
    (process-defmacro '(defmacro my-double ($x) (add $x $x)))
    ;; Too many args — pattern won't match
    (define result (preparse-expand-1 '(my-double a b)))
    ;; Should return unchanged since pattern doesn't match
    (check-equal? result '(my-double a b))))

;; ========================================
;; B. preparse-expand-full unit tests
;; ========================================

(test-case "expand-full: basic form returns at least input step"
  (define steps (preparse-expand-full '(add 1 2)))
  (check-true (pair? steps))
  (check-equal? (caar steps) "input")
  (check-equal? (cdar steps) '(add 1 2)))

(test-case "expand-full: if macro shows macro-expand step"
  (define steps (preparse-expand-full '(if True (suc zero) zero)))
  (define labels (map car steps))
  (check-not-false (member "input" labels))
  (check-not-false (member "macro-expand" labels)))

(test-case "expand-full: do strips to body shows macro-expand"
  ;; (do expr) strips to body — which differs from input, so macro-expand recorded
  (define steps (preparse-expand-full '(do (add 1 2))))
  (define labels (map car steps))
  (check-not-false (member "input" labels))
  (check-not-false (member "macro-expand" labels)))

(test-case "expand-full: no-change form has only input step"
  (define steps (preparse-expand-full '(add 1 2)))
  (define labels (map car steps))
  (check-equal? labels '("input")))

(test-case "expand-full: defn with spec shows spec-inject step"
  (parameterize ([current-spec-store (hasheq)]
                 [current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-preparse-registry prelude-preparse-registry])
    (process-spec '(spec my-id Nat -> Nat))
    (define steps (preparse-expand-full '(defn my-id [x] x)))
    (define labels (map car steps))
    (check-not-false (member "input" labels))
    (check-not-false (member "spec-inject" labels))))

(test-case "expand-full: infix >> shows infix-rewrite step"
  (define steps (preparse-expand-full '(f >> g)))
  (define labels (map car steps))
  (check-not-false (member "input" labels))
  (check-not-false (member "infix-rewrite" labels)))

(test-case "expand-full: result steps start with input"
  (define steps (preparse-expand-full '(if True zero zero)))
  (check-equal? (caar steps) "input"))

(test-case "expand-full: where-clause defn shows where-inject step"
  ;; Set up a trait and spec with where clause
  (parameterize ([current-spec-store (hasheq)]
                 [current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-bundle-registry (current-bundle-registry)])
    ;; Register a trait — use brace-params format, method with colon annotation
    (process-trait '(trait Eq ($brace-params A) (eq-method : A A -> Bool)))
    ;; Register a spec with where clause
    (process-spec '(spec is-equal ($brace-params A) A A -> Bool where (Eq A)))
    (define steps (preparse-expand-full '(defn is-equal [x y] (eq-method x y))))
    (define labels (map car steps))
    (check-not-false (member "input" labels))
    ;; Should see both spec-inject and where-inject
    (check-not-false (member "spec-inject" labels))
    (check-not-false (member "where-inject" labels))))

;; ========================================
;; C. End-to-end sexp-mode tests
;; ========================================

(test-case "introspection/e2e: (expand (do (add 1N 2))) works"
  (define result
    (run-last (string-append
      "(ns t-intr-1)\n"
      "(expand (do (add 1 2)))")))
  (check-true (string? result))
  ;; (do expr) strips to body; expand shows final result
  (check-true (string-contains? result "add")))

(test-case "introspection/e2e: (expand-1 (if True zero zero)) shows boolrec"
  (define result
    (run-last (string-append
      "(ns t-intr-2)\n"
      "(expand-1 (if True zero zero))")))
  (check-true (string? result))
  ;; if → boolrec in one step
  (check-true (string-contains? result "boolrec")))

(test-case "introspection/e2e: (expand-1 (add 1N 2)) unchanged"
  (define result
    (run-last (string-append
      "(ns t-intr-3)\n"
      "(expand-1 (add 1 2))")))
  (check-true (string? result))
  (check-true (string-contains? result "add")))

(test-case "introspection/e2e: (expand-full (if True zero zero)) shows input"
  ;; NOTE: When used inline, the if macro is already expanded by the preparse
  ;; pipeline before expand-full sees it. So we see the already-expanded form.
  ;; Macro expansion steps are best seen via unit tests or REPL :expand-full.
  (define result
    (run-last (string-append
      "(ns t-intr-4)\n"
      "(expand-full (if True zero zero))")))
  (check-true (string? result))
  ;; Should contain at least the "input:" label
  (check-true (string-contains? result "input:"))
  ;; The input is already boolrec (pre-expanded by pipeline)
  (check-true (string-contains? result "boolrec")))

(test-case "introspection/e2e: (expand-full (add 1N 2)) only input step"
  (define result
    (run-last (string-append
      "(ns t-intr-5)\n"
      "(expand-full (add 1 2))")))
  (check-true (string? result))
  (check-true (string-contains? result "input:"))
  ;; Should NOT have macro-expand since add is not a macro
  (check-false (string-contains? result "macro-expand:")))

(test-case "introspection/e2e: (expand-full (defn ...)) with spec injection"
  (define result
    (run-last (string-append
      "(ns t-intr-6)\n"
      "(spec my-suc Nat -> Nat)\n"
      "(expand-full (defn my-suc [x] (suc x)))")))
  (check-true (string? result))
  (check-true (string-contains? result "input:"))
  (check-true (string-contains? result "spec-inject:")))

;; ========================================
;; D. Regression: existing expand/parse/elaborate still work
;; ========================================

(test-case "introspection/regression: (expand ...) unchanged behavior"
  (define result
    (run-last (string-append
      "(ns t-intr-r1)\n"
      "(expand (if True zero zero))")))
  (check-true (string? result))
  ;; if → boolrec after full expansion
  (check-true (string-contains? result "boolrec")))

(test-case "introspection/regression: (parse ...) unchanged behavior"
  (define result
    (run-last (string-append
      "(ns t-intr-r2)\n"
      "(parse (add 1 2))")))
  (check-true (string? result))
  ;; Should contain surf-app (parsed AST representation)
  (check-true (string-contains? result "surf-app")))

(test-case "introspection/regression: (elaborate ...) unchanged behavior"
  (define result
    (run-last (string-append
      "(ns t-intr-r3)\n"
      "(elaborate (suc zero))")))
  (check-true (string? result)))

;; ========================================
;; E. :macros and :specs registry tests (unit-level)
;; ========================================

(test-case "introspection/macros: preparse registry is non-empty"
  (define reg (current-preparse-registry))
  (check-false (hash-empty? reg))
  ;; Should have at least do, let, if
  (check-true (hash-has-key? reg 'do))
  (check-true (hash-has-key? reg 'let))
  (check-true (hash-has-key? reg 'if)))

(test-case "introspection/macros: built-in macros are procedural"
  ;; do, let, if are all registered as procedures (not pattern-template)
  (define entry-do (hash-ref (current-preparse-registry) 'do #f))
  (check-not-false entry-do)
  (check-true (procedure? entry-do))
  (check-false (preparse-macro? entry-do))

  (define entry-let (hash-ref (current-preparse-registry) 'let #f))
  (check-not-false entry-let)
  (check-true (procedure? entry-let))

  (define entry-if (hash-ref (current-preparse-registry) 'if #f))
  (check-not-false entry-if)
  (check-true (procedure? entry-if)))

(test-case "introspection/macros: $list-literal is procedural"
  (define entry (hash-ref (current-preparse-registry) '$list-literal #f))
  (check-not-false entry)
  (check-true (procedure? entry)))

(test-case "introspection/macros: user defmacro creates preparse-macro struct"
  (parameterize ([current-preparse-registry prelude-preparse-registry])
    (process-defmacro '(defmacro my-double ($x) (add $x $x)))
    (define entry (hash-ref (current-preparse-registry) 'my-double #f))
    (check-not-false entry)
    (check-true (preparse-macro? entry))))

(test-case "introspection/specs: spec store accessible"
  (parameterize ([current-spec-store (hasheq)]
                 [current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-preparse-registry prelude-preparse-registry])
    (process-spec '(spec test-fn Nat -> Nat))
    (define store (current-spec-store))
    (check-false (hash-empty? store))
    (check-true (hash-has-key? store 'test-fn))))

(test-case "introspection/specs: spec-entry-type-datums accessible"
  (parameterize ([current-spec-store (hasheq)]
                 [current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-preparse-registry prelude-preparse-registry])
    (process-spec '(spec test-fn Nat Nat -> Bool))
    (define entry (lookup-spec 'test-fn))
    (check-not-false entry)
    (define types (spec-entry-type-datums entry))
    (check-true (pair? types))))

;; ========================================
;; Section F: pp-datum unit tests (C6)
;; ========================================

(test-case "pp-datum: plain symbol"
  (check-equal? (pp-datum 'foo) "foo"))

(test-case "pp-datum: plain number"
  (check-equal? (pp-datum 42) "42"))

(test-case "pp-datum: rational"
  (check-equal? (pp-datum 1/3) "1/3"))

(test-case "pp-datum: boolean"
  (check-equal? (pp-datum #t) "true")
  (check-equal? (pp-datum #f) "false"))

(test-case "pp-datum: null"
  (check-equal? (pp-datum '()) "()"))

(test-case "pp-datum: string"
  (check-equal? (pp-datum "hello") "\"hello\""))

(test-case "pp-datum: $quote sentinel"
  (check-equal? (pp-datum '($quote foo)) "'foo"))

(test-case "pp-datum: $angle-type sentinel"
  (check-equal? (pp-datum '($angle-type Nat -> Bool)) "<Nat -> Bool>"))

(test-case "pp-datum: $brace-params sentinel"
  (check-equal? (pp-datum '($brace-params A B)) "{A B}"))

(test-case "pp-datum: $pipe-gt sentinel symbol"
  (check-equal? (pp-datum '$pipe-gt) "|>"))

(test-case "pp-datum: $compose sentinel symbol"
  (check-equal? (pp-datum '$compose) ">>"))

(test-case "pp-datum: $pipe sentinel symbol"
  (check-equal? (pp-datum '$pipe) "|"))

(test-case "pp-datum: $list-literal sentinel"
  (check-equal? (pp-datum '($list-literal 1 2 3)) "'[1 2 3]"))

(test-case "pp-datum: $list-literal with $list-tail"
  (check-equal? (pp-datum '($list-literal 1 2 ($list-tail xs))) "'[1 2 | xs]"))

(test-case "pp-datum: $set-literal sentinel"
  (check-equal? (pp-datum '($set-literal 1 2 3)) "#{1 2 3}"))

(test-case "pp-datum: $vec-literal sentinel"
  (check-equal? (pp-datum '($vec-literal 1 2 3)) "@[1 2 3]"))

(test-case "pp-datum: $lseq-literal sentinel"
  (check-equal? (pp-datum '($lseq-literal 1 2 3)) "~[1 2 3]"))

(test-case "pp-datum: $rest sentinel"
  (check-equal? (pp-datum '$rest) "..."))

(test-case "pp-datum: $rest-param sentinel"
  (check-equal? (pp-datum '($rest-param xs)) "...xs"))

(test-case "pp-datum: $approx-literal sentinel"
  (check-equal? (pp-datum '($approx-literal 3.14)) "~3.14"))

(test-case "pp-datum: regular list"
  (check-equal? (pp-datum '(add 1 2)) "(add 1 2)"))

(test-case "pp-datum: nested sentinels"
  (check-equal? (pp-datum '($quote ($angle-type Nat -> Bool)))
                "'<Nat -> Bool>"))

(test-case "pp-datum: nested list"
  (check-equal? (pp-datum '(defn foo (x) (add x 1)))
                "(defn foo (x) (add x 1))"))

(test-case "pp-datum: $quasiquote sentinel"
  (check-equal? (pp-datum '($quasiquote (add 1 2))) "`(add 1 2)"))

(test-case "pp-datum: $unquote sentinel"
  (check-equal? (pp-datum '($unquote x)) ",x"))

(test-case "pp-datum: quasiquote with unquote"
  (check-equal? (pp-datum '($quasiquote (add ($unquote x) 2)))
                "`(add ,x 2)"))

;; ========================================
;; Section G: pp-datum integration with expand (C6)
;; ========================================

(test-case "pp-datum/e2e: expand uses pp-datum output"
  (define result
    (run-last (string-append
      "(ns t-intr-pp1)\n"
      "(expand (if True zero zero))")))
  ;; expand output now uses pp-datum, not Racket ~s
  ;; The if macro expands to boolrec — check it's readable
  (check-true (string? result))
  (check-true (string-contains? result "boolrec")))

(test-case "pp-datum/e2e: expand-1 uses pp-datum output"
  (define result
    (run-last (string-append
      "(ns t-intr-pp2)\n"
      "(expand-1 (if True zero zero))")))
  (check-true (string? result))
  ;; pp-datum output: no $ prefixes on sentinel symbols in standard expansions
  (check-true (string-contains? result "boolrec")))
