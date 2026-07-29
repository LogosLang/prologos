#lang racket/base

;;;
;;; Tests for Phase 3c: Constraint Chain Syntax ?var:C1:C2
;;; Verifies: reader greedy consumption, parser helpers, type-guard
;;; forward-check, and end-to-end constrained narrowing.
;;;

(require rackunit
         racket/list
         racket/string
         racket/port
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../parser.rkt"
         "../global-constraints.rkt")

;; ========================================
;; Shared Fixture (prelude loaded once)
;; ========================================

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
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string "(ns test-constraint-chain)")
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
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-bundle-registry shared-bundle-reg])
    (process-string s)))

(define (run-last s) (last (run s)))

;; Run WS-mode code using shared environment
(define (run-ws s)
  (parameterize ([current-file-module-network-ref (module-network-add-import (make-module-network) (module-network-from-snapshot shared-global-env))]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-bundle-registry shared-bundle-reg])
    (process-string-ws s)))

(define (run-ws-last s) (last (run-ws s)))

;; ========================================
;; A. Parser helper unit tests
;; ========================================

(test-case "narrow-var-base-name: plain ?x → ?x"
  (check-equal? (narrow-var-base-name '?x) '?x))

(test-case "narrow-var-base-name: ?x:Nat → ?x"
  (check-equal? (narrow-var-base-name '?x:Nat) '?x))

(test-case "narrow-var-base-name: ?foo:Nat:Even → ?foo"
  (check-equal? (narrow-var-base-name '?foo:Nat:Even) '?foo))

(test-case "narrow-var-constraints: plain ?x → empty"
  (check-equal? (narrow-var-constraints '?x) '()))

(test-case "narrow-var-constraints: ?x:Nat → (Nat)"
  (check-equal? (narrow-var-constraints '?x:Nat) '(Nat)))

(test-case "narrow-var-constraints: ?x:Nat:Even → (Nat Even)"
  (check-equal? (narrow-var-constraints '?x:Nat:Even) '(Nat Even)))

(test-case "collect-narrow-vars+constraints: mixed datum"
  (define-values (vars cmap)
    (collect-narrow-vars+constraints '(add ?x:Nat ?y)))
  (check-equal? vars '(?x ?y))
  (check-equal? (hash-ref cmap '?x #f) '(Nat))
  (check-equal? (hash-ref cmap '?y #f) '()))

(test-case "collect-narrow-vars+constraints: multi-constraint"
  (define-values (vars cmap)
    (collect-narrow-vars+constraints '(f ?a:Nat:Even ?b:Bool)))
  (check-equal? vars '(?a ?b))
  (check-equal? (hash-ref cmap '?a #f) '(Nat Even))
  (check-equal? (hash-ref cmap '?b #f) '(Bool)))

(test-case "collect-narrow-vars+constraints: no narrow vars → empty"
  (define-values (vars cmap)
    (collect-narrow-vars+constraints '(add 1 2)))
  (check-equal? vars '())
  (check-true (hash-empty? cmap)))

(test-case "rewrite-constrained-vars: ?x:Nat → ?x"
  (check-equal? (rewrite-constrained-vars '?x:Nat) '?x))

(test-case "rewrite-constrained-vars: nested datum"
  (check-equal? (rewrite-constrained-vars '(add ?x:Nat ?y:Bool))
                '(add ?x ?y)))

(test-case "rewrite-constrained-vars: unconstrained passthrough"
  (check-equal? (rewrite-constrained-vars '(f ?x ?y 42))
                '(f ?x ?y 42)))

;; ========================================
;; B. value-matches-type? unit tests
;; ========================================

(test-case "value-matches-type?: zero is Nat"
  (check-true (value-matches-type? (expr-zero) 'Nat)))

(test-case "value-matches-type?: suc(zero) is Nat"
  (check-true (value-matches-type? (expr-suc (expr-zero)) 'Nat)))

(test-case "value-matches-type?: nat-val is Nat"
  (check-true (value-matches-type? (expr-nat-val 5) 'Nat)))

(test-case "value-matches-type?: true is Bool"
  (check-true (value-matches-type? (expr-true) 'Bool)))

(test-case "value-matches-type?: false is Bool"
  (check-true (value-matches-type? (expr-false) 'Bool)))

(test-case "value-matches-type?: int is Int"
  (check-true (value-matches-type? (expr-int 42) 'Int)))

(test-case "value-matches-type?: string is String"
  (check-true (value-matches-type? (expr-string "hi") 'String)))

(test-case "value-matches-type?: zero is NOT Bool"
  (check-false (value-matches-type? (expr-zero) 'Bool)))

(test-case "value-matches-type?: true is NOT Nat"
  (check-false (value-matches-type? (expr-true) 'Nat)))

;; ========================================
;; C. End-to-end: constrained narrowing (sexp mode)
;; ========================================

(test-case "constrained narrow: [add ?x:Nat ?y:Nat] = 5N produces Nat solutions"
  ;; D4.P1b-i: this pin WAS vacuous — it passed on any output containing "?"
  ;; OR "x" OR "nil", which includes the empty result `nil`. Now it asserts
  ;; the actual solution set: the six (x,y) pairs of Nats summing to 5.
  (define result (run-last "(= (add ?x:Nat ?y:Nat) 5)"))
  (check-true (string? result))
  (check-false (regexp-match? #rx"^nil" result)
               (format "narrowing produced NO solutions: ~a" result))
  (for ([pair (in-list '(("0N" "5N") ("1N" "4N") ("2N" "3N")
                         ("3N" "2N") ("4N" "1N") ("5N" "0N")))])
    (check-true (regexp-match? (regexp (format ":y ~a, :x ~a" (car pair) (cadr pair)))
                               result)
                (format "missing solution y=~a x=~a in: ~a"
                        (car pair) (cadr pair) result))))

;; ========================================
;; D. End-to-end: WS-mode constraint chain
;; ========================================

(test-case "WS constrained narrow: [add ?x:Nat ?y:Nat] = 5N — CONVERGES with sexp mode"
  ;; D4.P1b-i (owner ruling Q_L1's scoped-in repair). This was a LIVE
  ;; silent-wrong-answer: WS returned `nil` (ZERO solutions, 0 errors) where
  ;; sexp returns six — because the WS reader delivers `?x` and `:Nat` as
  ;; SEPARATE datums, so `add` was applied to FOUR arguments and the
  ;; string-split in narrow-var-constraints never saw a colon. The old pin
  ;; passed on the substring "nil", i.e. it passed BECAUSE of the bug.
  ;; The repair is a JOINER at the narrowing seam (not a second splitter).
  (define ws (run-ws-last "[add ?x:Nat ?y:Nat] = 5N"))
  (define sexp (run-last "(= (add ?x:Nat ?y:Nat) 5)"))
  (check-true (string? ws))
  (check-false (regexp-match? #rx"^nil" ws)
               (format "WS narrowing produced NO solutions: ~a" ws))
  (check-equal? ws sexp
                "WS and sexp constrained narrowing must produce the SAME solution set"))

;; ---- The repair's BLAST RADIUS, pinned. The first attempt fused `?x` + the
;; following colon-symbol at the DATUM layer, where adjacency is already
;; destroyed — so it absorbed ANY keyword after a logic variable and silently
;; rewrote the goal (`[add ?x :foo ?y]` returned six solutions instead of nil;
;; a map-literal key got swallowed). Caught by two independent skeptics. The
;; repair now lives in the TOKENIZER, where contiguity is inherent. These pin
;; that SPACE-separated colon-symbols are untouched. ----

(test-case "P1b-i: a SPACE-separated keyword after a ?-var is NOT absorbed"
  ;; `[add ?x :foo ?y]` is a THREE-argument goal and must stay one.
  (check-regexp-match #rx"^nil" (run-ws-last "[add ?x :foo ?y] = 5N")))

(test-case "P1b-i: a keyword ARGUMENT after a ?-var still parses (no arity corruption)"
  (define r (run-ws-last "def users := {:alice 30}\n[map-get ?m :name] = \"alice\""))
  (check-false (regexp-match? #rx"expects 2 arguments|arity" r)
               (format "the keyword argument was absorbed: ~a" r)))

(test-case "P1b-i: a ?-var inside a MAP LITERAL does not swallow the next key"
  (define r (run-ws-last "def target := {:name \"alice\" :age 30}\n{:name ?n :age 30} = target"))
  (check-false (regexp-match? #rx"even number of elements" r)
               (format "the map key was absorbed: ~a" r)))

(test-case "P1b-i: chained constraints still fuse when CONTIGUOUS"
  (check-equal? (narrow-var-constraints '?foo:Nat:Even) '(Nat Even)))

;; ========================================
;; E. Regression: unconstrained narrowing still works
;; ========================================

(test-case "regression: unconstrained [add ?x ?y] = 5N"
  (define result (run-last "(= (add ?x ?y) 5)"))
  (check-true (string? result))
  ;; Standard narrowing — should still produce solutions
  (check-true (or (string-contains? result "?")
                  (string-contains? result "x")
                  (string-contains? result "nil"))
              (format "Expected narrowing result, got: ~a" result)))

(test-case "regression: unconstrained WS [add ?x ?y] = 5N"
  (define result (run-ws-last "[add ?x ?y] = 5N"))
  (check-true (string? result))
  (check-true (or (string-contains? result "?")
                  (string-contains? result "x")
                  (string-contains? result "nil"))
              (format "Expected narrowing result, got: ~a" result)))
