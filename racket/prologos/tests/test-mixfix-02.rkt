#lang racket/base

;;;
;;; PROLOGOS MIXFIX SYNTAX TESTS — Part 2
;;; Precedence groups, user-defined operators, chained comparisons,
;;; diagnostics, and pattern matching with .(...).
;;;
;;; G. Precedence-group registration + :mixfix metadata on spec
;;; H. Chained comparisons + diagnostics
;;; I. Pattern matching with .(...)
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         racket/port
         racket/file
         "test-support.rkt"
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
         (prefix-in tc: "../typing-core.rkt")
         "../namespace.rkt"
         "../trait-resolution.rkt"
         "../parse-reader.rkt")

;; ========================================
;; Shared Fixture for E2E tests
;; ========================================

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Load prelude and helpers once
(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-bundle-reg)
  (parameterize ([current-file-module-network-ref (make-module-network)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    ;; Set up a basic namespace with prelude
    (process-string "(ns test-mixfix)")
    (values (global-env-snapshot)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

;; Run sexp code using shared environment
(define (run s)
  (parameterize ([current-file-module-network-ref (module-network-add-import (make-module-network) (module-network-from-snapshot shared-global-env))]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-bundle-registry shared-bundle-reg])
    (process-string s)))

(define (run-last s) (last (run s)))

;; Run WS code via temp file using shared environment
(define (run-ws s)
  (define tmp (make-prologos-temp-file))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display s out)))
  (define result
    (parameterize ([current-file-module-network-ref (module-network-add-import (make-module-network) (module-network-from-snapshot shared-global-env))]
                   [current-ns-context shared-ns-context]
                   [current-module-registry shared-module-reg]
                   [current-lib-paths (list lib-dir)]
                   [current-preparse-registry (current-preparse-registry)]
                   [current-trait-registry shared-trait-reg]
                   [current-impl-registry shared-impl-reg]
                   [current-param-impl-registry shared-param-impl-reg]
                   [current-bundle-registry shared-bundle-reg])
      (process-file tmp)))
  (delete-file tmp)
  result)

(define (run-ws-last s) (last (run-ws s)))

;; ========================================
;; G. Phase 2 tests: precedence-group + :mixfix metadata
;; ========================================

;; --- Unit tests: precedence-group registration ---

(test-case "precedence-group: basic registration"
  (parameterize ([current-user-precedence-groups (hasheq)])
    (process-precedence-group '(precedence-group my-group ($brace-params :assoc left :tighter-than additive)))
    (define g (lookup-precedence-group 'my-group))
    (check-true (prec-group? g))
    (check-equal? (prec-group-name g) 'my-group)
    (check-equal? (prec-group-assoc g) 'left)
    (check-equal? (prec-group-tighter-than g) '(additive))))

(test-case "precedence-group: right-associative"
  (parameterize ([current-user-precedence-groups (hasheq)])
    (process-precedence-group '(precedence-group my-exp ($brace-params :assoc right :tighter-than multiplicative)))
    (define g (lookup-precedence-group 'my-exp))
    (check-equal? (prec-group-assoc g) 'right)))

(test-case "precedence-group: none-associative"
  (parameterize ([current-user-precedence-groups (hasheq)])
    (process-precedence-group '(precedence-group my-cmp ($brace-params :assoc none :tighter-than logical-and)))
    (define g (lookup-precedence-group 'my-cmp))
    (check-equal? (prec-group-assoc g) 'none)))

(test-case "precedence-group: error on unknown tighter-than"
  (parameterize ([current-user-precedence-groups (hasheq)])
    (check-exn exn:fail?
      (lambda ()
        (process-precedence-group '(precedence-group bad ($brace-params :assoc left :tighter-than nonexistent)))))))

(test-case "precedence-group: error on invalid assoc"
  (parameterize ([current-user-precedence-groups (hasheq)])
    (check-exn exn:fail?
      (lambda ()
        (process-precedence-group '(precedence-group bad ($brace-params :assoc upward :tighter-than additive)))))))

(test-case "precedence-group: user group references another user group"
  (parameterize ([current-user-precedence-groups (hasheq)])
    ;; First register a base group
    (process-precedence-group '(precedence-group my-base ($brace-params :assoc left :tighter-than additive)))
    ;; Then register a group tighter than it
    (process-precedence-group '(precedence-group my-tight ($brace-params :assoc left :tighter-than my-base)))
    (define g (lookup-precedence-group 'my-tight))
    (check-equal? (prec-group-tighter-than g) '(my-base))))

;; --- Unit tests: :mixfix metadata on spec → auto-registration ---

(test-case "spec :mixfix auto-registers user operator"
  (parameterize ([current-user-precedence-groups (hasheq)]
                 [current-user-operators (hasheq)]
                 [current-spec-store (current-spec-store)])
    ;; Register a spec with :mixfix metadata
    (process-spec '(spec my-xor A -> A -> A ($brace-params :mixfix ($brace-params :symbol xor :group logical-and))))
    ;; The operator should now be registered
    (define op (hash-ref (current-user-operators) 'xor #f))
    (check-true (op-info? op))
    (check-equal? (op-info-symbol op) 'xor)
    (check-equal? (op-info-fn-name op) 'my-xor)
    (check-equal? (op-info-group op) 'logical-and)))

(test-case "spec :mixfix error on unknown group"
  (parameterize ([current-user-precedence-groups (hasheq)]
                 [current-user-operators (hasheq)]
                 [current-spec-store (current-spec-store)])
    (check-exn exn:fail?
      (lambda ()
        (process-spec '(spec my-op A -> A -> A ($brace-params :mixfix ($brace-params :symbol @@ :group nonexistent))))))))

;; --- Unit tests: user-defined operator used in Pratt parser ---

(test-case "pratt: user-defined operator in .(...)"
  (parameterize ([current-user-precedence-groups (hasheq)]
                 [current-user-operators (hasheq)]
                 [current-spec-store (current-spec-store)])
    ;; Register a custom precedence group
    (process-precedence-group '(precedence-group my-cmp ($brace-params :assoc none :tighter-than logical-and)))
    ;; Register a spec with :mixfix metadata pointing to the custom group
    (process-spec '(spec my-approx A -> A -> A ($brace-params :mixfix ($brace-params :symbol ~= :group my-cmp))))
    ;; Now parse a mixfix expression using the custom operator
    (define result (pratt-parse '(a ~= b) (effective-operator-table) (effective-precedence-groups)))
    (check-equal? result '(my-approx a b))))

(test-case "pratt: user-defined op in builtin group"
  (parameterize ([current-user-precedence-groups (hasheq)]
                 [current-user-operators (hasheq)]
                 [current-spec-store (current-spec-store)])
    ;; Register a custom operator in the existing additive group (alongside +, -, ++)
    (process-spec '(spec my-plus A -> A -> A ($brace-params :mixfix ($brace-params :symbol +++ :group additive))))
    ;; +++ at additive level, * is multiplicative (tighter)
    ;; a +++ b * c → (my-plus a (* b c))
    (define result (pratt-parse '(a +++ b * c) (effective-operator-table) (effective-precedence-groups)))
    (check-equal? result '(my-plus a (* b c)))))

;; ========================================
;; H. Phase 3 tests: chained comparisons + diagnostics
;; ========================================

;; --- Chained comparisons (Pratt parser) ---

(test-case "pratt: chained a < b <= c"
  (define result (preparse-expand-form '($mixfix a < b <= c)))
  (check-equal? result '(and (lt a b) (le b c))))

(test-case "pratt: chained a > b > c"
  (define result (preparse-expand-form '($mixfix a > b > c)))
  ;; > desugars to swapped lt: (gt a b) → (lt b a)
  (check-equal? result '(and (lt b a) (lt c b))))

(test-case "pratt: chained a < b < c < d (3-way)"
  (define result (preparse-expand-form '($mixfix a < b < c < d)))
  ;; (and (and (lt a b) (lt b c)) (lt c d))
  (check-equal? result '(and (and (lt a b) (lt b c)) (lt c d))))

(test-case "pratt: chained a == b == c"
  (define result (preparse-expand-form '($mixfix a == b == c)))
  (check-equal? result '(and (eq a b) (eq b c))))

(test-case "pratt: mixed chain a < b >= c"
  (define result (preparse-expand-form '($mixfix a < b >= c)))
  ;; >= desugars to swapped le: (ge a b) → (le b a)
  (check-equal? result '(and (lt a b) (le c b))))

;; --- Chained comparisons E2E ---

;; Note: In sexp mode, < and > are readtable macro characters (angle brackets),
;; so sexp E2E tests with < / > are only possible via WS mode's .(...) syntax.
;; The Pratt parser correctly handles them at the datum level (see unit tests above).

(test-case "e2e/ws: chained .(1 < 2 <= 3)"
  (define result
    (run-ws-last "eval .(1N < 2N <= 3N)\n"))
  (check-equal? result "true : Bool"))

(test-case "e2e/ws: chained .(3 > 2 > 1)"
  (define result
    (run-ws-last "eval .(3N > 2N > 1N)\n"))
  (check-equal? result "true : Bool"))

(test-case "e2e/ws: chained .(1 < 3 > 2) (mixed)"
  (define result
    (run-ws-last "eval .(1N < 3N > 2N)\n"))
  (check-equal? result "true : Bool"))

(test-case "e2e/sexp: chained == (no angle issues)"
  (define result
    (run-last "(eval ($mixfix 3N == 3N == 3N))"))
  (check-equal? result "true : Bool"))

;; --- Incomparable-group error ---

(test-case "pratt: incomparable groups error"
  ;; + (additive) and :: (cons) are incomparable in the DAG
  ;; However, the error only fires in a recursive context where the context-group is set.
  ;; At top level, they silently resolve by binding power.
  ;; To test properly, we need a nested scenario.
  ;; a :: b + c — :: has right-bp = 20, + has left-bp = 20
  ;; parse: a as lhs, see :: (bp 20 > 0), consume, recurse with min-bp=20, context-group=cons
  ;;   in recursion: parse b, see + (bp 20, context-group=cons), incomparable → error!
  ;; A marker datum, not a raise: see test-mixfix-01's empty-expression case.
  (define result (preparse-expand-form '($mixfix a :: b + c)))
  (check-equal? (car result) '$mixfix-error (format "got: ~v" result))
  (check-true (regexp-match? #rx"no defined precedence relationship" (cadr result))
              (format "got: ~v" result)))

;; --- Error diagnostics ---

(test-case "pratt: error on empty mixfix"
  (define result (preparse-expand-form '($mixfix)))
  (check-equal? (car result) '$mixfix-error (format "got: ~v" result))
  (check-true (regexp-match? #rx"Empty" (cadr result)) (format "got: ~v" result)))

(test-case "pratt: error on trailing operator"
  ;; `parse-primary`'s end-of-input error is a user syntax error too, so it is
  ;; on the same channel — found because the first pass converted only the three
  ;; raises in `parse-expr` and this one kept aborting.
  (define result (preparse-expand-form '($mixfix a +)))
  (check-equal? (car result) '$mixfix-error (format "got: ~v" result))
  (check-true (regexp-match? #rx"Unexpected end" (cadr result)) (format "got: ~v" result)))

;; ========================================
;; I. Phase 4 tests: pattern matching with .(...)
;; ========================================

;; --- Unit test: $mixfix expansion of :: produces cons (already works) ---

(test-case "pratt: :: in pattern produces cons"
  (define result (preparse-expand-form '($mixfix h :: t)))
  (check-equal? result '(cons h t)))

(test-case "pratt: nested :: produces right-assoc cons"
  (define result (preparse-expand-form '($mixfix a :: b :: c)))
  (check-equal? result '(cons a (cons b c))))

;; --- E2E: match with .(h :: t) patterns (sexp mode) ---

(test-case "e2e/sexp: match with $mixfix cons pattern"
  (define result
    (run-last
     (string-append
      "(eval (the Nat (match '[1N 2N 3N] (($mixfix h :: t) -> h) (nil -> 0N))))")))
  (check-equal? result "1N : Nat"))

(test-case "e2e/sexp: match $mixfix cons pattern — tail"
  (define result
    (run-last
     (string-append
      "(eval (the (List Nat) (match '[10N] (($mixfix h :: t) -> t) (nil -> nil))))")))
  (check-true (string-contains? result "nil") (format "Expected nil in: ~a" result)))

;; --- E2E: match with .(h :: t) patterns (WS mode) ---

(test-case "e2e/ws: match with .(h :: t) pattern"
  (define result
    (run-ws-last
     (string-append
      "eval\n"
      "  the Nat\n"
      "    match '[1N 2N 3N]\n"
      "      | .(h :: t) -> h\n"
      "      | nil -> 0N\n")))
  (check-equal? result "1N : Nat"))

(test-case "e2e/ws: match with .(h :: t) — access tail"
  (define result
    (run-ws-last
     (string-append
      "eval\n"
      "  the [List Nat]\n"
      "    match '[5N 6N]\n"
      "      | .(h :: t) -> t\n"
      "      | nil -> nil\n")))
  (check-true (string-contains? result "6N") (format "Expected 6N in tail: ~a" result)))

(test-case "e2e/ws: match with nil literal"
  (define result
    (run-ws-last
     (string-append
      "eval\n"
      "  the Nat\n"
      "    match (the [List Nat] nil)\n"
      "      | .(h :: t) -> h\n"
      "      | nil -> 99N\n")))
  (check-equal? result "99N : Nat"))

;; ========================================
;; J. Mixfix comparison operators + form extent (2026-07-26 swallow fix)
;; ========================================
;;
;; `.( 3N < 5N )` used to SWALLOW every following top-level line: the
;; form-extent bracket-depth scanner counted the operator `<` as an angle
;; opener (unconditionally), leaving depth 1 after `)` so all later lines
;; read as bracket continuations. The scanner now mirrors group-items'
;; mixfix suppression + matched-rangle lookahead. These tests pin BOTH the
;; operator result AND the no-swallow property (following commands run).

(test-case "e2e/ws: .( 3N < 5N ) → true via Ord dispatch"
  (check-equal? (run-ws-last ".( 3N < 5N )\n") "true : Bool"))

(test-case "e2e/ws: .( 5N <= 5N ) → true via Ord dispatch"
  (check-equal? (run-ws-last ".( 5N <= 5N )\n") "true : Bool"))

(test-case "e2e/ws: .( 5N > 3N ) → true via Ord dispatch"
  (check-equal? (run-ws-last ".( 5N > 3N )\n") "true : Bool"))

(test-case "e2e/ws: .( 3N < 5N ) does NOT swallow following top-level lines"
  (define results
    (run-ws (string-append
             ".( 3N < 5N )\n"
             "\n"
             "def swallow-marker := 42\n"
             "\n"
             "swallow-marker\n")))
  ;; All three commands must produce output — the defect ate lines 2+3.
  (check-equal? (length results) 3 (format "commands swallowed: ~a" results))
  (check-equal? (car results) "true : Bool")
  (check-equal? (last results) "42 : Int"))

(test-case "e2e/ws: .( 5N > 3N ) does NOT swallow following top-level lines"
  (define results
    (run-ws (string-append
             ".( 5N > 3N )\n"
             "\n"
             "def swallow-marker2 := 7\n"
             "\n"
             "swallow-marker2\n")))
  (check-equal? (length results) 3 (format "commands swallowed: ~a" results))
  (check-equal? (car results) "true : Bool")
  (check-equal? (last results) "7 : Int"))

(test-case "e2e/ws: unmatched < inside plain brackets does not swallow"
  ;; [< 3N 5N] is an ERROR (`<` is not a bound function — use `lt`), but it
  ;; must fail LOUDLY on its own line; following commands still run.
  (define results
    (run-ws (string-append
             "[< 3N 5N]\n"
             "\n"
             "def swallow-marker3 := 9\n"
             "\n"
             "swallow-marker3\n")))
  (check-equal? (length results) 3 (format "commands swallowed: ~a" results))
  ;; The first result is an error VALUE (unbound-variable-error struct),
  ;; not a success string — the loud failure.
  (check-true (string-contains? (format "~a" (car results)) "Unbound")
              (format "expected loud unbound-variable error for [< ...]: ~a" (car results)))
  (check-equal? (last results) "9 : Int"))

(test-case "e2e/ws: angle Pi type after a mixfix comparison still parses"
  ;; Guards the other direction: the matched-rangle lookahead must still
  ;; count genuine angle groups, including after a mixfix form.
  (define results
    (run-ws (string-append
             ".( 3N < 5N )\n"
             "\n"
             "def j-id : <(x : Nat) -> Nat> := [fn [x : Nat] x]\n"
             "\n"
             "[j-id 3N]\n")))
  (check-equal? (length results) 3 (format "commands swallowed: ~a" results))
  (check-equal? (last results) "3N : Nat"))
