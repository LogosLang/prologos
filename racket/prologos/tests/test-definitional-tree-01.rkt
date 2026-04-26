#lang racket/base

;;;
;;; Tests for Phase 1a: Definitional Tree Extraction
;;; Tests definitional-tree.rkt — tree node structs, extraction from
;;; expr-reduce patterns, registry, and utility functions.
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         "test-support.rkt"
         "../definitional-tree.rkt"
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
         "../namespace.rkt"
         "../multi-dispatch.rkt")

;; ========================================
;; Shared Fixture (modules loaded once)
;; ========================================

(define shared-preamble "(ns test)\n")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-ctor-reg
                shared-type-meta)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-ctor-registry)
            (current-type-meta))))

;; Helper: process a definition string and extract the def-tree for the given name.
;; Returns the extracted tree (or #f if the function has no pattern matching).
(define (extract-tree-for name s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-ctor-registry shared-ctor-reg]
                 [current-type-meta shared-type-meta]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg])
    (process-string s)
    (define val (global-env-lookup-value name))
    (and val (extract-definitional-tree val))))

;; Helper: process WS-mode string and extract tree.
(define (extract-tree-ws name s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-ctor-registry shared-ctor-reg]
                 [current-type-meta shared-type-meta]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg])
    (process-string-ws s)
    (define val (global-env-lookup-value name))
    (and val (extract-definitional-tree val))))

;; ========================================
;; A. Unit tests — direct struct construction
;; ========================================

(test-case "dt/peel-lambdas-nested"
  ;; (fn [x] (fn [y] body)) -> arity 2, inner = body
  (define body (expr-fvar 'x))
  (define e (expr-lam 'mw (expr-Nat) (expr-lam 'mw (expr-Nat) body)))
  (define-values (arity inner) (peel-lambdas e))
  (check-equal? arity 2)
  (check-equal? inner body))

(test-case "dt/peel-lambdas-zero"
  ;; Non-lambda expression -> arity 0
  (define body (expr-fvar 'x))
  (define-values (arity inner) (peel-lambdas body))
  (check-equal? arity 0)
  (check-equal? inner body))

(test-case "dt/extract-simple-nat-match"
  ;; fn [x y] -> match x | zero -> y | suc k -> k
  ;; arity=2, scrutinee=bvar(1) -> position 0
  (define reduce
    (expr-reduce
     (expr-bvar 1)  ;; x (bvar 1 inside 2 lambdas)
     (list
      (expr-reduce-arm 'zero 0 (expr-bvar 0))       ;; zero -> y
      (expr-reduce-arm 'suc 1 (expr-bvar 0)))        ;; suc k -> k
     #t))
  (define body (expr-lam 'mw (expr-Nat) (expr-lam 'mw (expr-Nat) reduce)))
  (define tree (extract-definitional-tree body))
  (check-pred dt-branch? tree)
  (check-equal? (dt-branch-position tree) 0)
  (check-equal? (dt-branch-type-name tree) 'Nat)
  ;; Should have zero and suc children (both present, no exempt)
  (define children (dt-branch-children tree))
  (check-equal? (length children) 2)
  (check-equal? (caar children) 'zero)
  (check-pred dt-rule? (cdar children))
  (check-equal? (caadr children) 'suc)
  (check-pred dt-rule? (cdadr children)))

(test-case "dt/extract-bool-match"
  ;; fn [b] -> match b | true -> false | false -> true
  ;; arity=1, scrutinee=bvar(0) -> position 0
  (define reduce
    (expr-reduce
     (expr-bvar 0)
     (list
      (expr-reduce-arm 'true 0 (expr-false))
      (expr-reduce-arm 'false 0 (expr-true)))
     #t))
  (define body (expr-lam 'mw (expr-Bool) reduce))
  (define tree (extract-definitional-tree body))
  (check-pred dt-branch? tree)
  (check-equal? (dt-branch-position tree) 0)
  (check-equal? (dt-branch-type-name tree) 'Bool)
  (check-equal? (length (dt-branch-children tree)) 2))

(test-case "dt/extract-match-second-arg"
  ;; fn [x y] -> match y | zero -> x | suc k -> k
  ;; arity=2, scrutinee=bvar(0) -> position 1
  (define reduce
    (expr-reduce
     (expr-bvar 0)  ;; y (bvar 0 inside 2 lambdas)
     (list
      (expr-reduce-arm 'zero 0 (expr-bvar 1))
      (expr-reduce-arm 'suc 1 (expr-bvar 0)))
     #t))
  (define body (expr-lam 'mw (expr-Nat) (expr-lam 'mw (expr-Nat) reduce)))
  (define tree (extract-definitional-tree body))
  (check-pred dt-branch? tree)
  (check-equal? (dt-branch-position tree) 1))

(test-case "dt/extract-no-reduce"
  ;; fn [x] -> x  (no pattern matching)
  ;; Phase 3a: non-matching functions with arity > 0 get a trivial dt-rule
  (define body (expr-lam 'mw (expr-Nat) (expr-bvar 0)))
  (define tree (extract-definitional-tree body))
  (check-pred dt-rule? tree))

(test-case "dt/extract-partial-match-exempt"
  ;; fn [x] -> match x | zero -> true  (suc is missing)
  (define reduce
    (expr-reduce
     (expr-bvar 0)
     (list (expr-reduce-arm 'zero 0 (expr-true)))
     #t))
  (define body (expr-lam 'mw (expr-Nat) reduce))
  (define tree (extract-definitional-tree body))
  (check-pred dt-branch? tree)
  ;; Should have 2 children: zero (rule) and suc (exempt)
  (define children (dt-branch-children tree))
  (check-equal? (length children) 2)
  (check-pred dt-rule? (cdr (assq 'zero children)))
  (check-pred dt-exempt? (cdr (assq 'suc children))))

(test-case "dt/extract-nested-match"
  ;; fn [xs] -> match xs | nil -> nil | cons a as -> match as | nil -> a | cons _ _ -> a
  ;; Outer: arity=1, scrutinee=bvar(0) -> position 0
  ;; Inner: arity=1+2=3, scrutinee=bvar(0) -> position 2 (inner sub-position)
  (define inner-reduce
    (expr-reduce
     (expr-bvar 0)  ;; 'as' is bvar(0) inside cons arm (2 bindings)
     (list
      (expr-reduce-arm 'nil 0 (expr-bvar 1))      ;; nil -> a
      (expr-reduce-arm 'cons 2 (expr-bvar 3)))     ;; cons _ _ -> a
     #t))
  (define outer-reduce
    (expr-reduce
     (expr-bvar 0)  ;; xs
     (list
      (expr-reduce-arm 'nil 0 (expr-fvar 'nil))        ;; nil -> nil
      (expr-reduce-arm 'cons 2 inner-reduce))           ;; cons a as -> inner match
     #t))
  (define body (expr-lam 'mw (expr-Nat) outer-reduce))
  (define tree (extract-definitional-tree body))
  (check-pred dt-branch? tree)
  (check-equal? (dt-branch-position tree) 0)
  ;; The cons child should be a nested dt-branch
  (define cons-child (cdr (assq 'cons (dt-branch-children tree))))
  (check-pred dt-branch? cons-child)
  ;; Depth should be 2
  (check-equal? (def-tree-depth tree) 2))

(test-case "dt/extract-overlapping-or"
  ;; fn [x] -> match x | zero -> true | zero -> false
  ;; Overlapping: same ctor in two arms -> dt-or
  (define reduce
    (expr-reduce
     (expr-bvar 0)
     (list
      (expr-reduce-arm 'zero 0 (expr-true))
      (expr-reduce-arm 'zero 0 (expr-false)))
     #t))
  (define body (expr-lam 'mw (expr-Nat) reduce))
  (define tree (extract-definitional-tree body))
  (check-pred dt-or? tree))

(test-case "dt/has-exempt-true"
  (define tree (dt-branch 0 'Nat
                 (list (cons 'zero (dt-rule (expr-true)))
                       (cons 'suc (dt-exempt)))))
  (check-true (def-tree-has-exempt? tree)))

(test-case "dt/has-exempt-false"
  (define tree (dt-branch 0 'Nat
                 (list (cons 'zero (dt-rule (expr-true)))
                       (cons 'suc (dt-rule (expr-false))))))
  (check-false (def-tree-has-exempt? tree)))

(test-case "dt/has-or-true"
  (define tree (dt-or (list (dt-rule (expr-true)) (dt-rule (expr-false)))))
  (check-true (def-tree-has-or? tree)))

(test-case "dt/has-or-false"
  (define tree (dt-branch 0 'Nat
                 (list (cons 'zero (dt-rule (expr-true)))
                       (cons 'suc (dt-rule (expr-false))))))
  (check-false (def-tree-has-or? tree)))

(test-case "dt/tree-depth"
  ;; Flat branch: depth 1
  (define flat (dt-branch 0 'Nat
                 (list (cons 'zero (dt-rule (expr-true)))
                       (cons 'suc (dt-rule (expr-false))))))
  (check-equal? (def-tree-depth flat) 1)
  ;; Nested branch: depth 2
  (define nested (dt-branch 0 'Nat
                   (list (cons 'zero (dt-rule (expr-true)))
                         (cons 'suc flat))))
  (check-equal? (def-tree-depth nested) 2)
  ;; Leaf: depth 0
  (check-equal? (def-tree-depth (dt-rule (expr-true))) 0)
  (check-equal? (def-tree-depth (dt-exempt)) 0))

(test-case "dt/tree-leaves"
  (define tree (dt-branch 0 'Nat
                 (list (cons 'zero (dt-rule (expr-true)))
                       (cons 'suc (dt-exempt)))))
  (define leaves (def-tree-leaves tree))
  (check-equal? (length leaves) 2)
  (check-pred dt-rule? (car leaves))
  (check-pred dt-exempt? (cadr leaves)))

(test-case "dt/registry-round-trip"
  (parameterize ([current-def-tree-registry (hasheq)])
    (define tree (dt-branch 0 'Nat
                   (list (cons 'zero (dt-rule (expr-true))))))
    (register-def-tree! 'my-fn tree)
    (check-equal? (lookup-def-tree 'my-fn) tree)
    (check-false (lookup-def-tree 'nonexistent))))

;; ========================================
;; B. Integration tests — via process-string
;; ========================================

(test-case "dt/integration-add"
  ;; add: match first arg on zero/suc
  (define tree
    (extract-tree-for
     'my-add
     "(def my-add : (-> Nat (-> Nat Nat)) (fn (x : Nat) (fn (y : Nat) (match x (zero -> y) (suc k -> (suc (my-add k y)))))))"))
  (check-pred dt-branch? tree)
  (check-equal? (dt-branch-position tree) 0)
  (check-equal? (dt-branch-type-name tree) 'Nat)
  (define children (dt-branch-children tree))
  (check-equal? (length children) 2)
  (check-pred dt-rule? (cdr (assq 'zero children)))
  (check-pred dt-rule? (cdr (assq 'suc children))))

(test-case "dt/integration-not"
  ;; not: match on Bool (true/false)
  (define tree
    (extract-tree-for
     'my-not
     "(def my-not : (-> Bool Bool) (fn (b : Bool) (match b (true -> false) (false -> true))))"))
  (check-pred dt-branch? tree)
  (check-equal? (dt-branch-position tree) 0)
  (check-equal? (dt-branch-type-name tree) 'Bool)
  (check-equal? (length (dt-branch-children tree)) 2)
  (check-false (def-tree-has-exempt? tree)))

(test-case "dt/integration-is-zero"
  ;; is-zero: match on Nat -> Bool
  (define tree
    (extract-tree-for
     'my-is-zero
     "(def my-is-zero : (-> Nat Bool) (fn (n : Nat) (match n (zero -> true) (suc _ -> false))))"))
  (check-pred dt-branch? tree)
  (check-equal? (dt-branch-position tree) 0)
  (check-equal? (dt-branch-type-name tree) 'Nat))

(test-case "dt/integration-pred"
  ;; pred: both constructors covered
  (define tree
    (extract-tree-for
     'my-pred
     "(def my-pred : (-> Nat Nat) (fn (n : Nat) (match n (zero -> zero) (suc k -> k))))"))
  (check-pred dt-branch? tree)
  (check-false (def-tree-has-exempt? tree)))

(test-case "dt/integration-no-match"
  ;; identity: no pattern matching → Phase 3a trivial dt-rule
  (define tree
    (extract-tree-for
     'my-id
     "(def my-id : (-> Nat Nat) (fn (n : Nat) n))"))
  (check-pred dt-rule? tree))

(test-case "dt/integration-3-ctors"
  ;; Ordering type from prelude has 3 constructors: lt-ord, eq-ord, gt-ord
  (define tree
    (extract-tree-for
     'ord-to-nat
     "(def ord-to-nat : (-> Ordering Nat) (fn (o : Ordering) (match o (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))"))
  (check-pred dt-branch? tree)
  (check-equal? (dt-branch-type-name tree) 'Ordering)
  (check-equal? (length (dt-branch-children tree)) 3)
  (check-false (def-tree-has-exempt? tree)))

(test-case "dt/integration-partial-3-ctors"
  ;; Ordering has 3 ctors, only 2 matched -> Exempt for gt-ord
  (define tree
    (extract-tree-for
     'ord-partial
     "(def ord-partial : (-> Ordering Nat) (fn (o : Ordering) (match o (lt-ord -> zero) (eq-ord -> (suc zero)))))"))
  (check-pred dt-branch? tree)
  (check-true (def-tree-has-exempt? tree))
  ;; Should have 3 children: lt-ord, eq-ord (rules), gt-ord (exempt)
  (check-equal? (length (dt-branch-children tree)) 3)
  (check-pred dt-exempt? (cdr (assq 'gt-ord (dt-branch-children tree)))))

(test-case "dt/integration-match-second-arg"
  ;; Match on second argument -> position 1
  (define tree
    (extract-tree-for
     'match-second
     "(def match-second : (-> Nat (-> Nat Nat)) (fn (x : Nat) (fn (y : Nat) (match y (zero -> x) (suc k -> k)))))"))
  (check-pred dt-branch? tree)
  (check-equal? (dt-branch-position tree) 1))

(test-case "dt/integration-nested-match"
  ;; Nested match: outer on first arg, inner on field of constructor
  (define tree
    (extract-tree-for
     'nested-fn
     (string-append
      "(def nested-fn : (-> Nat Nat) "
      "(fn (n : Nat) (match n "
      "  (zero -> zero) "
      "  (suc k -> (match k (zero -> (suc zero)) (suc j -> j))))))")))
  (check-pred dt-branch? tree)
  (check-equal? (dt-branch-position tree) 0)
  ;; The suc child should be a nested dt-branch
  (define suc-child (cdr (assq 'suc (dt-branch-children tree))))
  (check-pred dt-branch? suc-child)
  ;; Depth should be 2
  (check-equal? (def-tree-depth tree) 2))

(test-case "dt/integration-tree-depth"
  ;; Verify depth for a flat match
  (define tree
    (extract-tree-for
     'flat-fn
     "(def flat-fn : (-> Bool Bool) (fn (b : Bool) (match b (true -> false) (false -> true))))"))
  (check-equal? (def-tree-depth tree) 1))

(test-case "dt/integration-tree-leaves"
  ;; Verify leaf collection
  (define tree
    (extract-tree-for
     'leaf-fn
     "(def leaf-fn : (-> Nat Bool) (fn (n : Nat) (match n (zero -> true) (suc _ -> false))))"))
  (define leaves (def-tree-leaves tree))
  (check-equal? (length leaves) 2)
  (check-true (andmap dt-rule? leaves)))

;; ========================================
;; C. WS-mode integration tests
;; ========================================

(test-case "dt/ws-mode-add"
  ;; WS-mode: add function
  (define tree
    (extract-tree-ws
     'ws-add
     "ns test\n\ndef ws-add : <Nat -> Nat -> Nat>\n  fn [x : Nat]\n    fn [y : Nat]\n      match x\n        | zero -> y\n        | suc k -> [suc [ws-add k y]]\n"))
  (check-pred dt-branch? tree)
  (check-equal? (dt-branch-position tree) 0)
  (check-equal? (dt-branch-type-name tree) 'Nat))

(test-case "dt/ws-mode-ordering"
  ;; WS-mode: match on Ordering (3 constructors from prelude)
  (define tree
    (extract-tree-ws
     'ws-ord-fn
     "ns test\n\ndef ws-ord-fn : <Ordering -> Nat>\n  fn [o : Ordering]\n    match o\n      | lt-ord -> zero\n      | eq-ord -> [suc zero]\n      | gt-ord -> [suc [suc zero]]\n"))
  (check-pred dt-branch? tree)
  (check-equal? (dt-branch-type-name tree) 'Ordering)
  (check-equal? (length (dt-branch-children tree)) 3)
  (check-false (def-tree-has-exempt? tree)))

(test-case "dt/ws-mode-nested"
  ;; WS-mode: nested match
  (define tree
    (extract-tree-ws
     'ws-nested
     "ns test\n\ndef ws-nested : <Nat -> Nat>\n  fn [n : Nat]\n    match n\n      | zero -> zero\n      | suc k -> match k\n        | zero -> [suc zero]\n        | suc j -> j\n"))
  (check-pred dt-branch? tree)
  (check-equal? (def-tree-depth tree) 2))

;; ========================================
;; D. Edge cases
;; ========================================

(test-case "dt/wildcard-bindings"
  ;; Wildcard _ in arm still counts as binding
  (define tree
    (extract-tree-for
     'wild-fn
     "(def wild-fn : (-> Nat Bool) (fn (n : Nat) (match n (zero -> true) (suc _ -> false))))"))
  (check-pred dt-branch? tree)
  (define suc-child (cdr (assq 'suc (dt-branch-children tree))))
  (check-pred dt-rule? suc-child))

(test-case "dt/zero-binding-ctor"
  ;; Constructor with zero bindings (nullary): zero, true, false, nil
  (define tree
    (extract-tree-for
     'zero-bind
     "(def zero-bind : (-> Bool Nat) (fn (b : Bool) (match b (true -> zero) (false -> (suc zero)))))"))
  (check-pred dt-branch? tree)
  (check-equal? (dt-branch-type-name tree) 'Bool))

(test-case "dt/unit-type-match"
  ;; Unit type match — single constructor, no exempt
  (define tree
    (extract-tree-for
     'unit-fn
     "(def unit-fn : (-> Unit Nat) (fn (u : Unit) (match u (unit -> zero))))"))
  (check-pred dt-branch? tree)
  (check-equal? (dt-branch-type-name tree) 'Unit)
  (check-false (def-tree-has-exempt? tree)))

;; ========================================
;; E. Pattern-compiled defn → DT extraction
;; ========================================
;; Verify that defn with pattern clauses (| [patterns...] -> body)
;; produces the same DT structures as hand-written match.

(test-case "dt/pattern-defn-add"
  ;; Pattern-compiled add: two-arg, match on first
  (define tree
    (extract-tree-for
     'addp-dt
     (string-append
      "(spec addp-dt Nat -> Nat -> Nat)\n"
      "(defn addp-dt ($pipe (zero n) -> n)"
      " ($pipe ((suc m) n) -> (suc (addp-dt m n))))")))
  (check-pred dt-branch? tree)
  (check-equal? (dt-branch-position tree) 0)
  (check-equal? (dt-branch-type-name tree) 'Nat)
  (define children (dt-branch-children tree))
  (check-equal? (length children) 2)
  (check-pred dt-rule? (cdr (assq 'zero children)))
  (check-pred dt-rule? (cdr (assq 'suc children)))
  (check-false (def-tree-has-exempt? tree)))

(test-case "dt/pattern-defn-not"
  ;; Bool negation via pattern clauses
  (define tree
    (extract-tree-for
     'notp-dt
     "(defn notp-dt ($pipe (true) -> false) ($pipe (false) -> true))"))
  (check-pred dt-branch? tree)
  (check-equal? (dt-branch-position tree) 0)
  (check-equal? (dt-branch-type-name tree) 'Bool)
  (check-equal? (length (dt-branch-children tree)) 2)
  (check-false (def-tree-has-exempt? tree)))

(test-case "dt/pattern-defn-is-zero"
  ;; is-zero: constructor + variable catch-all
  (define tree
    (extract-tree-for
     'iz-dt
     "(defn iz-dt ($pipe (zero) -> true) ($pipe (n) -> false))"))
  (check-pred dt-branch? tree)
  (check-equal? (dt-branch-position tree) 0)
  (check-equal? (dt-branch-type-name tree) 'Nat))

(test-case "dt/pattern-defn-wildcard"
  ;; Wildcard _ pattern
  (define tree
    (extract-tree-for
     'wild-dt
     "(defn wild-dt ($pipe (_) -> zero))"))
  ;; Wildcard compiles to a match with variable — no expr-reduce
  ;; because it's a catch-all with no constructor dispatch.
  ;; Phase 3a: non-matching functions with arity > 0 get a trivial dt-rule.
  (check-pred dt-rule? tree))

(test-case "dt/pattern-defn-ws-add"
  ;; WS-mode pattern-compiled add
  (define tree
    (extract-tree-ws
     'addp-ws-dt
     (string-append
      "ns test\n\n"
      "spec addp-ws-dt Nat -> Nat -> Nat\n"
      "defn addp-ws-dt\n"
      "  | [zero n] -> n\n"
      "  | [[suc m] n] -> suc [addp-ws-dt m n]\n")))
  (check-pred dt-branch? tree)
  (check-equal? (dt-branch-position tree) 0)
  (check-equal? (dt-branch-type-name tree) 'Nat)
  (check-equal? (length (dt-branch-children tree)) 2)
  (check-false (def-tree-has-exempt? tree)))

(test-case "dt/pattern-defn-ws-not"
  ;; WS-mode pattern-compiled Bool negation
  (define tree
    (extract-tree-ws
     'notp-ws-dt
     "ns test\n\ndefn notp-ws-dt\n  | [true] -> false\n  | [false] -> true\n"))
  (check-pred dt-branch? tree)
  (check-equal? (dt-branch-type-name tree) 'Bool)
  (check-false (def-tree-has-exempt? tree)))
