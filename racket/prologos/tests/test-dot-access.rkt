#lang racket/base

;;;
;;; Tests for dot-access syntax: user.name, .:name, chained access
;;;
;;; Phase C of Map Key Access Syntax implementation.
;;; Dot-access desugars to map-get calls via preparse macro rewriting.
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
;; A. Unit tests: rewrite-dot-access
;; ========================================

(test-case "rewrite-dot-access: basic postfix"
  (check-equal?
   (rewrite-dot-access '(user ($dot-access name)))
   '(map-get user :name)))

(test-case "rewrite-dot-access: chained postfix"
  (check-equal?
   (rewrite-dot-access '(user ($dot-access address) ($dot-access city)))
   '(map-get (map-get user :address) :city)))

(test-case "rewrite-dot-access: dot-key prefix"
  (check-equal?
   (rewrite-dot-access '(($dot-key :name) user))
   '(map-get user :name)))

(test-case "rewrite-dot-access: in larger form"
  (check-equal?
   (rewrite-dot-access '(f user ($dot-access name) x))
   '(f (map-get user :name) x)))

(test-case "rewrite-dot-access: no sentinels passthrough"
  (check-equal?
   (rewrite-dot-access '(f x y))
   '(f x y)))

(test-case "rewrite-dot-access: standalone dot-key → lambda"
  (check-equal?
   (rewrite-dot-access '(($dot-key :name)))
   '(fn ($x : _) (map-get $x :name))))

(test-case "rewrite-dot-access: non-list passthrough"
  (check-equal? (rewrite-dot-access 'x) 'x)
  (check-equal? (rewrite-dot-access 42) 42))

;; ========================================
;; B. Reader tokenization tests
;; ========================================

;; Helper: filter out newline/eof tokens to get just content tokens
(define (content-tokens s)
  (filter (lambda (t)
            (not (memq (token-type t) '(newline eof))))
          (tokenize-string s)))

(test-case "reader: .field produces dot-access token"
  (define toks (content-tokens ".name"))
  (check-equal? (length toks) 1)
  (check-equal? (token-type (car toks)) 'dot-access)
  (check-equal? (token-value (car toks)) 'name))

(test-case "reader: .:kw produces dot-key token"
  (define toks (content-tokens ".:name"))
  (check-equal? (length toks) 1)
  (check-equal? (token-type (car toks)) 'dot-key)
  (check-equal? (token-value (car toks)) ':name))

(test-case "reader: user.name splits into two tokens"
  (define toks (content-tokens "user.name"))
  (check-equal? (length toks) 2)
  (check-equal? (token-type (car toks)) 'symbol)
  (check-equal? (token-value (car toks)) 'user)
  (check-equal? (token-type (cadr toks)) 'dot-access)
  (check-equal? (token-value (cadr toks)) 'name))

(test-case "reader: chained user.addr.city splits into three tokens"
  (define toks (content-tokens "user.addr.city"))
  (check-equal? (length toks) 3)
  (check-equal? (token-type (car toks)) 'symbol)
  (check-equal? (token-value (car toks)) 'user)
  (check-equal? (token-type (cadr toks)) 'dot-access)
  (check-equal? (token-value (cadr toks)) 'addr)
  (check-equal? (token-type (caddr toks)) 'dot-access)
  (check-equal? (token-value (caddr toks)) 'city))

(test-case "reader: ... still works"
  (define toks (content-tokens "..."))
  (check-equal? (token-type (car toks)) 'symbol)
  (check-equal? (token-value (car toks)) '$rest))

(test-case "reader: ...args still works"
  (define toks (content-tokens "...args"))
  (check-equal? (token-type (car toks)) 'rest-param)
  (check-equal? (token-value (car toks)) 'args))

(test-case "reader: :: qualified names still work"
  (define toks (content-tokens "nat::add"))
  (check-equal? (length toks) 1)
  (check-equal? (token-type (car toks)) 'symbol)
  (check-equal? (token-value (car toks)) 'nat::add))

;; ========================================
;; C. Shared Fixture for E2E tests
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
    (process-string "(ns test-dot-access)")
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
;; D. E2E tests: dot-access via sexp mode
;; ========================================
;; These test the preparse macro path using ($dot-access ...) sentinels directly.

(test-case "e2e/sexp: map-get via dot-access sentinel"
  ;; ($dot-access name) in sexp mode desugars to (map-get m :name)
  (define result
    (run-last
     (string-append
      "(def m : (Map Keyword Nat) {:name 1N})\n"
      "(eval (m ($dot-access name)))")))
  (check-equal? result "1N : Nat"))

(test-case "e2e/sexp: chained dot-access"
  ;; m ($dot-access inner) ($dot-access val)
  ;; → (map-get (map-get m :inner) :val)
  (define result
    (run-last
     (string-append
      "(def inner-m : (Map Keyword Nat) {:val 42N})\n"
      "(def outer-m : (Map Keyword (Map Keyword Nat)) {:inner inner-m})\n"
      "(eval (outer-m ($dot-access inner) ($dot-access val)))")))
  (check-equal? result "42N : Nat"))

(test-case "e2e/sexp: dot-key prefix"
  ;; (($dot-key :name) m) → (map-get m :name)
  (define result
    (run-last
     (string-append
      "(def m : (Map Keyword Nat) {:name 5N})\n"
      "(eval (($dot-key :name) m))")))
  (check-equal? result "5N : Nat"))

;; ========================================
;; E. E2E tests: dot-access via WS mode
;; ========================================
;; These test the full reader → preparse → elaboration path.

(test-case "e2e/ws: basic m.name access"
  (define result
    (run-ws-last
     (string-append
      "def m : [Map Keyword Nat] {:name 1N}\n"
      "eval m.name\n")))
  (check-equal? result "1N : Nat"))

(test-case "e2e/ws: chained m.inner.val access"
  (define result
    (run-ws-last
     (string-append
      "def inner : [Map Keyword Nat] {:val 42N}\n"
      "def outer : [Map Keyword [Map Keyword Nat]] {:inner inner}\n"
      "eval outer.inner.val\n")))
  (check-equal? result "42N : Nat"))

(test-case "e2e/ws: dot-key prefix .:name"
  (define result
    (run-ws-last
     (string-append
      "def m : [Map Keyword Nat] {:name 5N}\n"
      "eval [.:name m]\n")))
  (check-equal? result "5N : Nat"))

(test-case "e2e/ws: dot-access in bracket form [f m.name]"
  (define result
    (run-ws-last
     (string-append
      "def m : [Map Keyword Nat] {:val 3N}\n"
      "eval [add m.val 2N]\n")))
  (check-equal? result "5N : Nat"))
