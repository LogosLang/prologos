#lang racket/base

;;;
;;; PROLOGOS MIXFIX SYNTAX TESTS — Part 1
;;; Unit tests + basic E2E for .{...} delimited infix syntax.
;;;
;;; A. Tokenizer: .{ produces dot-lbrace token
;;; B. WS Reader: .{a + b} reads as ($mixfix a + b)
;;; C. Pratt Parser: ($mixfix 1 + 2 * 3) → (add 1 (mul 2 3))
;;; D. E2E: sexp mode ($mixfix ...)
;;; E. E2E: WS mode (.{...})
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
         "../parse-reader.rkt")

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
  ;; = (or (and (lt a b) (lt d c)) (eq e f))   [> desugars to swapped lt]
  (check-equal? result '(or (and (lt a b) (lt d c)) (eq e f))))

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
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
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
    (parameterize ([current-prelude-env shared-global-env]
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
;; D. E2E tests: sexp mode ($mixfix ...)
;; ========================================

(test-case "e2e/sexp: basic addition via $mixfix"
  (define result
    (run-last "(eval ($mixfix 1N + 2N))"))
  (check-equal? result "3N : Nat"))

(test-case "e2e/sexp: precedence — multiplication before addition"
  (define result
    (run-last "(eval ($mixfix 1N + 2N * 3N))"))
  (check-equal? result "7N : Nat"))

(test-case "e2e/sexp: generic + as function via fn"
  (define result
    (run-last
     (string-append
      "(def double : (-> Nat Nat) (fn [x] (+ x x)))\n"
      "(eval (double 3N))")))
  (check-equal? result "6N : Nat"))

;; ========================================
;; E. E2E tests: WS mode (.{...})
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
