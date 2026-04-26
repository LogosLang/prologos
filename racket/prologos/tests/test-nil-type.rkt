#lang racket/base

;;;
;;; Tests for Nil type, nil value, nil-safe-get, #./#: safe navigation,
;;; A? nilable type sugar, and nil? predicate.
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         racket/port
         racket/file
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
         "../parse-reader.rkt"
         "../champ.rkt")

;; ========================================
;; A. Core AST: Nil type formation
;; ========================================

(test-case "Nil type formation"
  (with-fresh-meta-env
    (check-equal? (tc:infer ctx-empty (expr-Nil))
                  (expr-Type (lzero))
                  "Nil : Type 0")
    (check-true (tc:is-type ctx-empty (expr-Nil))
                "Nil is a type")))

(test-case "Nil pretty-print"
  (check-equal? (pp-expr (expr-Nil) '()) "Nil"))

(test-case "nil pretty-print"
  (check-equal? (pp-expr (expr-nil) '()) "nil"))

(test-case "nil-safe-get pretty-print"
  (check-equal? (pp-expr (expr-nil-safe-get (expr-fvar 'x) (expr-keyword 'name)) '())
                "[nil-safe-get x :name]"))

(test-case "nil-check pretty-print"
  (check-equal? (pp-expr (expr-nil-check (expr-fvar 'x)) '())
                "[nil? x]"))

;; ========================================
;; B. Core AST: nil value typing
;; ========================================

(test-case "nil value infer → Nil (without List constructor)"
  (with-fresh-meta-env
    ;; When List nil constructor is NOT in global env, expr-nil infers to Nil
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
      (check-equal? (tc:infer ctx-empty (expr-nil))
                    (expr-Nil)
                    "nil : Nil (no list constructor)"))))

(test-case "nil value check against Nil"
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
      (check-true (tc:check ctx-empty (expr-nil) (expr-Nil))
                  "nil checks as Nil"))))

(test-case "nil-check typing returns Bool"
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
      (check-equal? (tc:infer ctx-empty (expr-nil-check (expr-nil)))
                    (expr-Bool)
                    "nil? : _ → Bool"))))

;; ========================================
;; C. Core AST: reduction rules
;; ========================================

(test-case "nil-check reduction: nil → true"
  (check-equal? (whnf (expr-nil-check (expr-nil)))
                (expr-true)))

(test-case "nil-check reduction: zero → false"
  (check-equal? (whnf (expr-nil-check (expr-zero)))
                (expr-false)))

(test-case "nil-check reduction: string → false"
  (check-equal? (whnf (expr-nil-check (expr-string "hello")))
                (expr-false)))

(test-case "nil-check reduction: int → false"
  (check-equal? (whnf (expr-nil-check (expr-int 42)))
                (expr-false)))

(test-case "nil-safe-get reduction: nil input → nil"
  (check-equal? (whnf (expr-nil-safe-get (expr-nil) (expr-keyword 'name)))
                (expr-nil)))

(test-case "nil-safe-get reduction: champ hit"
  (let* ([m (whnf (expr-map-assoc (expr-map-empty (expr-Keyword) (expr-String))
                                   (expr-keyword 'name)
                                   (expr-string "alice")))]
         [result (whnf (expr-nil-safe-get m (expr-keyword 'name)))])
    (check-equal? result (expr-string "alice"))))

(test-case "nil-safe-get reduction: champ miss → nil"
  (let* ([m (whnf (expr-map-assoc (expr-map-empty (expr-Keyword) (expr-String))
                                   (expr-keyword 'name)
                                   (expr-string "alice")))]
         [result (whnf (expr-nil-safe-get m (expr-keyword 'age)))])
    (check-equal? result (expr-nil))))

;; ========================================
;; D. Unit tests: rewrite-nil-dot-access
;; ========================================

(test-case "rewrite-nil-dot-access: basic postfix"
  (check-equal?
   (rewrite-nil-dot-access '(user ($nil-dot-access name)))
   '(nil-safe-get user :name)))

(test-case "rewrite-nil-dot-access: chained postfix"
  (check-equal?
   (rewrite-nil-dot-access '(user ($nil-dot-access address) ($nil-dot-access city)))
   '(nil-safe-get (nil-safe-get user :address) :city)))

(test-case "rewrite-nil-dot-access: nil-dot-key prefix"
  (check-equal?
   (rewrite-nil-dot-access '(($nil-dot-key :name) user))
   '(nil-safe-get user :name)))

(test-case "rewrite-nil-dot-access: in larger form"
  (check-equal?
   (rewrite-nil-dot-access '(f user ($nil-dot-access name) x))
   '(f (nil-safe-get user :name) x)))

(test-case "rewrite-nil-dot-access: no sentinels passthrough"
  (check-equal?
   (rewrite-nil-dot-access '(f x y))
   '(f x y)))

(test-case "rewrite-nil-dot-access: standalone nil-dot-key → lambda"
  (define result (rewrite-nil-dot-access '(($nil-dot-key :name))))
  (check-true (list? result))
  (check-equal? (car result) 'fn)
  ;; Should produce (fn ($x : _) (nil-safe-get $x :name))
  (check-equal? (length result) 3))

;; ========================================
;; E. Reader tokenization: #. and #:
;; ========================================

;; Use exported tokenize-string; filter out EOF and newline tokens
(define (tokenize-ws str)
  (filter (lambda (t)
            (not (or (eq? (token-type t) 'eof)
                     (eq? (token-type t) 'newline))))
          (tokenize-string str)))

(test-case "reader: #.field → nil-dot-access token"
  (define tokens (tokenize-ws "x#.name"))
  (check-equal? (length tokens) 2)
  (check-equal? (token-type (first tokens)) 'symbol)
  (check-equal? (token-value (first tokens)) 'x)
  (check-equal? (token-type (second tokens)) 'nil-dot-access)
  (check-equal? (token-value (second tokens)) 'name))

(test-case "reader: #:field → nil-dot-key token"
  (define tokens (tokenize-ws "x#:name"))
  (check-equal? (length tokens) 2)
  (check-equal? (token-type (first tokens)) 'symbol)
  (check-equal? (token-value (first tokens)) 'x)
  (check-equal? (token-type (second tokens)) 'nil-dot-key)
  (check-equal? (token-value (second tokens)) ':name))

(test-case "reader: chained #.a#.b"
  (define tokens (tokenize-ws "x#.a#.b"))
  (check-equal? (length tokens) 3)
  (check-equal? (token-type (second tokens)) 'nil-dot-access)
  (check-equal? (token-value (second tokens)) 'a)
  (check-equal? (token-type (third tokens)) 'nil-dot-access)
  (check-equal? (token-value (third tokens)) 'b))

(test-case "reader: #{ still works for sets"
  (define tokens (tokenize-ws "#{"))
  (check-true (>= (length tokens) 1))
  (check-equal? (token-type (first tokens)) 'hash-lbrace))

(test-case "reader: #.:kw → nil-dot-key token"
  (define tokens (tokenize-ws "x#.:name"))
  (check-equal? (length tokens) 2)
  (check-equal? (token-type (second tokens)) 'nil-dot-key)
  (check-equal? (token-value (second tokens)) ':name))

;; ========================================
;; F. Shared prelude environment setup
;; ========================================

(define lib-dir
  (simplify-path
   (build-path (path-only (syntax-source #'here)) ".." ".." "lib" "prologos")))

(define-values (shared-global-env shared-ns-context shared-module-reg
                shared-trait-reg shared-impl-reg shared-param-impl-reg
                shared-bundle-reg)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (make-hash)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string "(ns test-nil-type)")
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

;; Run sexp code using shared environment
(define (run s)
  (parameterize ([current-prelude-env shared-global-env]
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
  (define tmp (make-temporary-file "prologos-test-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display s out)))
  (define result
    (parameterize ([current-prelude-env shared-global-env]
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
;; G. E2E: Nil type annotation + nil value
;; ========================================

(test-case "e2e/sexp: Nil type in annotation"
  (check-not-exn (lambda () (run "(def x : Nil nil)"))))

(test-case "e2e/sexp: Nil in union type"
  (check-not-exn (lambda () (run "(def x : (Nat | Nil) 42N)"))))

(test-case "e2e/sexp: Nil in union type with nil value"
  (check-not-exn (lambda () (run "(def x : (Nat | Nil) nil)"))))

(test-case "e2e/sexp: nil infers as list"
  (check-not-exn (lambda () (run "(def x nil)"))))

(test-case "e2e/sexp: nil as empty list (backward compat)"
  (check-not-exn (lambda () (run "(def xs : (List Nat) nil)"))))

;; ========================================
;; H. E2E: nil-safe-get (sexp mode)
;; ========================================

(test-case "e2e/sexp: nil-safe-get on map — key exists"
  (define result
    (run-last
     (string-append
      "(def m : (Map Keyword String) {:name \"alice\"})\n"
      "(eval (nil-safe-get m :name))")))
  (check-true (string? result))
  (check-true (string-contains? result "\"alice\"")))

(test-case "e2e/sexp: nil-safe-get on map — key missing → nil"
  (define result
    (run-last
     (string-append
      "(def m2 : (Map Keyword String) {:name \"alice\"})\n"
      "(eval (nil-safe-get m2 :age))")))
  (check-true (string? result))
  (check-true (string-contains? result "nil")))

(test-case "e2e/sexp: nil-safe-get chained"
  (define result
    (run-last
     (string-append
      "(def inner : (Map Keyword Nat) {:val 42N})\n"
      "(def outer : (Map Keyword (Map Keyword Nat)) {:inner inner})\n"
      "(eval (nil-safe-get (nil-safe-get outer :inner) :val))")))
  (check-true (string? result))
  (check-true (string-contains? result "42N")))

;; ========================================
;; I. E2E: nil? predicate
;; ========================================

(test-case "e2e/sexp: nil? on nil → true"
  (define result (run-last "(eval (nil? (the Nil nil)))"))
  (check-true (string? result))
  (check-true (string-contains? result "true")))

(test-case "e2e/sexp: nil? on nat → false"
  (define result (run-last "(eval (nil? 42N))"))
  (check-true (string? result))
  (check-true (string-contains? result "false")))

(test-case "e2e/sexp: nil? on string → false"
  (define result (run-last "(eval (nil? \"hello\"))"))
  (check-true (string? result))
  (check-true (string-contains? result "false")))

;; ========================================
;; J. E2E: A? nilable type sugar
;; ========================================

(test-case "e2e/sexp: Nat? sugar"
  (check-not-exn (lambda () (run "(def x : Nat? 42N)"))))

(test-case "e2e/sexp: String? sugar"
  (check-not-exn (lambda () (run "(def x : String? \"hello\")"))))

(test-case "e2e/sexp: String? with nil"
  (check-not-exn (lambda () (run "(def x : String? nil)"))))

(test-case "e2e/sexp: Nat? equivalent to (Nat | Nil)"
  (check-not-exn (lambda () (run "(def x : Nat? 42N) (def y : (Nat | Nil) 42N)"))))

(test-case "e2e/sexp: Bool? sugar"
  (check-not-exn (lambda () (run "(def x : Bool? true)"))))

(test-case "e2e/sexp: lowercase? not sugar"
  ;; lowercase names ending in ? are NOT nilable sugar — they're regular vars
  (check-not-exn (lambda () (run "(def empty? : Bool true)"))))

;; ========================================
;; K. Backward compatibility
;; ========================================
;; Backward compat of nil with List operations is tested by the full
;; test suite (4538 existing tests). Here we just verify nil keyword
;; integrates correctly with basic typed definitions.

(test-case "backward-compat: nil in typed list def"
  (check-not-exn (lambda () (run "(def xs : (List Nat) nil)"))))

(test-case "backward-compat: nil keyword with explicit type arg"
  (check-not-exn (lambda () (run "(def xs : (List Nat) (nil Nat))"))))
