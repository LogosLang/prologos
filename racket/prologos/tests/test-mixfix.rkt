#lang racket/base

;;;
;;; PROLOGOS MIXFIX SYNTAX TESTS
;;; Tests for .{...} delimited infix syntax.
;;;
;;; Phase 1: Core Reader & Pratt Parser (fixed precedence table)
;;;
;;; A. Tokenizer: .{ produces dot-lbrace token
;;; B. WS Reader: .{a + b} reads as ($mixfix a + b)
;;; C. Pratt Parser: ($mixfix 1 + 2 * 3) → (add 1 (mul 2 3))
;;; D. E2E: full pipeline with prelude
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
         "../reader.rkt")

;; ========================================
;; A. Tokenizer tests
;; ========================================

;; Helper: filter out newline/eof tokens
(define (content-tokens s)
  (filter (lambda (t)
            (not (memq (token-type t) '(newline eof))))
          (tokenize-string s)))

(test-case "tokenize: .{ produces dot-lbrace token"
  (define toks (content-tokens ".{"))
  (check-equal? (length toks) 1)
  (check-equal? (token-type (car toks)) 'dot-lbrace))

(test-case "tokenize: .{a + b} produces dot-lbrace, symbols, rbrace"
  (define toks (content-tokens ".{a + b}"))
  (check-equal? (token-type (car toks)) 'dot-lbrace)
  (check-equal? (token-type (last toks)) 'rbrace))

(test-case "tokenize: .{ does not conflict with .ident"
  (define toks (content-tokens ".name"))
  (check-equal? (token-type (car toks)) 'dot-access)
  (check-equal? (token-value (car toks)) 'name))

;; ========================================
;; B. WS Reader tests
;; ========================================

(test-case "reader: .{a + b} reads as ($mixfix a + b)"
  (define forms (read-all-forms-string ".{a + b}"))
  (check-equal? (length forms) 1)
  (define form (car forms))
  (check-true (pair? form))
  (check-equal? (car form) '$mixfix)
  (check-equal? (cdr form) '(a + b)))

(test-case "reader: .{1 + 2 * 3} reads as ($mixfix 1 + 2 * 3)"
  (define forms (read-all-forms-string ".{1 + 2 * 3}"))
  (define form (car forms))
  (check-equal? (car form) '$mixfix)
  (check-equal? (length (cdr form)) 5))

(test-case "reader: .{} reads as ($mixfix)"
  (define forms (read-all-forms-string ".{}"))
  (define form (car forms))
  (check-equal? form '($mixfix)))

(test-case "reader: .{[f x] + [g y]} reads with nested brackets"
  (define forms (read-all-forms-string ".{[f x] + [g y]}"))
  (define form (car forms))
  (check-equal? (car form) '$mixfix)
  (check-equal? (length (cdr form)) 3)
  ;; First element should be a list (bracket form)
  (check-true (list? (cadr form)))
  (check-equal? (cadr form) '(f x)))

;; ========================================
;; C. Pratt Parser unit tests
;; ========================================

(test-case "pratt: single value passes through"
  (define result (preparse-expand-form '($mixfix 42)))
  (check-equal? result 42))

(test-case "pratt: simple addition"
  (define result (preparse-expand-form '($mixfix a + b)))
  (check-equal? result '(+ a b)))

(test-case "pratt: multiplication before addition"
  (define result (preparse-expand-form '($mixfix a + b * c)))
  (check-equal? result '(+ a (* b c))))

(test-case "pratt: multiplication before addition (reversed)"
  (define result (preparse-expand-form '($mixfix a * b + c)))
  (check-equal? result '(+ (* a b) c)))

(test-case "pratt: left-associative addition"
  (define result (preparse-expand-form '($mixfix a + b + c)))
  (check-equal? result '(+ (+ a b) c)))

(test-case "pratt: right-associative exponentiation"
  (define result (preparse-expand-form '($mixfix a ** b ** c)))
  (check-equal? result '(pow a (pow b c))))

(test-case "pratt: right-associative cons"
  (define result (preparse-expand-form '($mixfix a :: b :: c)))
  (check-equal? result '(cons a (cons b c))))

(test-case "pratt: comparison operators"
  (define result (preparse-expand-form '($mixfix a < b)))
  (check-equal? result '(lt a b)))

(test-case "pratt: equality"
  (define result (preparse-expand-form '($mixfix a == b)))
  (check-equal? result '(eq a b)))

(test-case "pratt: logical and"
  (define result (preparse-expand-form '($mixfix a and b)))
  (check-equal? result '(and a b)))

(test-case "pratt: logical or"
  (define result (preparse-expand-form '($mixfix a or b)))
  (check-equal? result '(or a b)))

(test-case "pratt: comparison < logical-and < logical-or"
  (define result (preparse-expand-form '($mixfix a < b and c > d or e == f)))
  ;; or is loosest, then and, then < > ==
  ;; a < b and c > d or e == f
  ;; = (or (and (lt a b) (gt c d)) (eq e f))
  (check-equal? result '(or (and (lt a b) (gt c d)) (eq e f))))

(test-case "pratt: unary minus"
  (define result (preparse-expand-form '($mixfix - a)))
  (check-equal? result '(negate a)))

(test-case "pratt: unary minus with binary"
  (define result (preparse-expand-form '($mixfix - a + b)))
  (check-equal? result '(+ (negate a) b)))

(test-case "pratt: nested bracket form passes through"
  (define result (preparse-expand-form '($mixfix (f x) + (g y))))
  (check-equal? result '(+ (f x) (g y))))

(test-case "pratt: wildcards pass through"
  (define result (preparse-expand-form '($mixfix _ + 1)))
  (check-equal? result '(+ _ 1)))

(test-case "pratt: two wildcards"
  (define result (preparse-expand-form '($mixfix _ * _)))
  (check-equal? result '(* _ _)))

(test-case "pratt: division and modulo"
  (define result (preparse-expand-form '($mixfix a / b % c)))
  (check-equal? result '(mod (/ a b) c)))

(test-case "pratt: append in additive group"
  (define result (preparse-expand-form '($mixfix xs ++ ys)))
  (check-equal? result '(append xs ys)))

(test-case "pratt: empty expression errors"
  (check-exn exn:fail?
    (lambda () (preparse-expand-form '($mixfix)))))

;; ========================================
;; D. Shared Fixture for E2E tests
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
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    ;; Set up a basic namespace with prelude
    (process-string "(ns test-mixfix)")
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

;; Run sexp code using shared environment
(define (run s)
  (parameterize ([current-global-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
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
    (parameterize ([current-global-env shared-global-env]
                   [current-ns-context shared-ns-context]
                   [current-module-registry shared-module-reg]
                   [current-lib-paths (list lib-dir)]
                   [current-mult-meta-store (make-hasheq)]
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
;; E. E2E tests: sexp mode ($mixfix ...)
;; ========================================

(test-case "e2e/sexp: basic addition via $mixfix"
  (define result
    (run-last "(eval ($mixfix 1N + 2N))"))
  (check-equal? result "3N : Nat"))

(test-case "e2e/sexp: precedence — multiplication before addition"
  (define result
    (run-last "(eval ($mixfix 1N + 2N * 3N))"))
  (check-equal? result "7N : Nat"))

(test-case "e2e/sexp: wildcard partial application"
  (define result
    (run-last
     (string-append
      "(def double : (-> Nat Nat) ($mixfix _ + _))\n"
      "(eval (double 3N))")))
  (check-equal? result "6N : Nat"))

;; ========================================
;; F. E2E tests: WS mode (.{...})
;; ========================================

(test-case "e2e/ws: basic .{1 + 2}"
  (define result
    (run-ws-last "eval .{1N + 2N}\n"))
  (check-equal? result "3N : Nat"))

(test-case "e2e/ws: precedence .{1 + 2 * 3}"
  (define result
    (run-ws-last "eval .{1N + 2N * 3N}\n"))
  (check-equal? result "7N : Nat"))

(test-case "e2e/ws: left-associative .{1 + 2 + 3}"
  (define result
    (run-ws-last "eval .{1N + 2N + 3N}\n"))
  (check-equal? result "6N : Nat"))

(test-case "e2e/ws: nested brackets .{[+ 1N 2N] + 3N}"
  (define result
    (run-ws-last "eval .{[+ 1N 2N] + 3N}\n"))
  (check-equal? result "6N : Nat"))

(test-case "e2e/ws: comparison .{1 < 2}"
  (define result
    (run-ws-last "eval .{1N < 2N}\n"))
  (check-equal? result "true : Bool"))

(test-case "e2e/ws: equality .{3 == 3}"
  (define result
    (run-ws-last "eval .{3N == 3N}\n"))
  (check-equal? result "true : Bool"))

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

(test-case "pratt: user-defined operator in .{...}"
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

(test-case "pratt: user-defined op mixed with builtins"
  (parameterize ([current-user-precedence-groups (hasheq)]
                 [current-user-operators (hasheq)]
                 [current-spec-store (current-spec-store)])
    ;; Register a custom operator in the additive group
    (process-precedence-group '(precedence-group my-add ($brace-params :assoc left :tighter-than comparison)))
    (process-spec '(spec my-plus A -> A -> A ($brace-params :mixfix ($brace-params :symbol +++ :group my-add))))
    ;; +++ at additive level, * is multiplicative (tighter)
    ;; a +++ b * c → (my-plus a (* b c))
    (define result (pratt-parse '(a +++ b * c) (effective-operator-table) (effective-precedence-groups)))
    (check-equal? result '(my-plus a (* b c)))))
