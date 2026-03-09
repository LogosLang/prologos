#lang racket/base

;;;
;;; Tests for Pattern-Based defn Clauses + Head-Tail List Patterns
;;; Part 1: Parser + sexp-mode patterns
;;;
;;; Verifies:
;;; - Pattern clause parsing (-> syntax after params bracket)
;;; - Pattern compilation to match trees (macro expansion)
;;; - Numeric, constructor, variable, wildcard patterns
;;; - Head-tail patterns in match arms
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
         "../reader.rkt"
         "../multi-dispatch.rkt")

;; ========================================
;; Shared Fixture (prelude loaded once)
;; ========================================

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

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
    (process-string "(ns test-pattern-defn)")
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
;; A. Parsing: pattern clause detection
;; ========================================

(test-case "pattern/parse-single-arg-pattern-clause"
  ;; Pattern clause: ($pipe (zero) -> zero)
  (define parsed
    (parse-string "(defn iz ($pipe (zero) -> true) ($pipe (n) -> false))"))
  (check-true (surf-defn-multi? parsed))
  (define clauses (surf-defn-multi-clauses parsed))
  (check-equal? (length clauses) 2)
  (check-true (defn-pattern-clause? (car clauses)))
  (check-true (defn-pattern-clause? (cadr clauses))))

(test-case "pattern/parse-compound-pattern"
  ;; Compound pattern: ($pipe ((suc m) n) -> ...)
  (define parsed
    (parse-string "(defn f ($pipe ((suc m) n) -> n))"))
  (check-true (surf-defn-multi? parsed))
  (define clause (car (surf-defn-multi-clauses parsed)))
  (check-true (defn-pattern-clause? clause))
  (define pats (defn-pattern-clause-patterns clause))
  (check-equal? (length pats) 2)
  (check-true (pat-compound? (car pats)))
  (check-equal? (pat-compound-ctor-name (car pats)) 'suc))

(test-case "pattern/parse-wildcard"
  ;; Wildcard _
  (define parsed
    (parse-string "(defn f ($pipe (_) -> zero))"))
  (define clause (car (surf-defn-multi-clauses parsed)))
  (define pats (defn-pattern-clause-patterns clause))
  (check-true (pat-atom? (car pats)))
  (check-equal? (pat-atom-kind (car pats)) 'wildcard))

(test-case "pattern/parse-numeric-literal"
  ;; Numeric literal 0N
  (define parsed
    (parse-string "(defn f ($pipe (0N) -> true))"))
  (define clause (car (surf-defn-multi-clauses parsed)))
  (define pats (defn-pattern-clause-patterns clause))
  (check-true (pat-atom? (car pats)))
  (check-equal? (pat-atom-kind (car pats)) 'numeric)
  (check-equal? (pat-atom-value (car pats)) 0))

(test-case "pattern/parse-head-tail-in-bracket"
  ;; Head-tail pattern in bracket: ($pipe ((a b $pipe rest)) -> ...)
  (define parsed
    (parse-string "(defn f ($pipe ((a b $pipe rest)) -> a))"))
  (define clause (car (surf-defn-multi-clauses parsed)))
  (define pats (defn-pattern-clause-patterns clause))
  ;; Single arg: the outer list [(a b | rest)] -> 1 pattern
  (check-equal? (length pats) 1)
  (check-true (pat-head-tail? (car pats))))

;; ========================================
;; B. Sexp-mode integration: constructor patterns
;; ========================================

(test-case "pattern/sexp-is-zero"
  ;; is-zero: pattern match on zero vs catch-all
  (check-equal?
   (run-last
    "(defn is-zero ($pipe (zero) -> true) ($pipe (n) -> false))\n(eval (is-zero zero))")
   "true : Bool")
  (check-equal?
   (run-last
    "(defn is-zero2 ($pipe (zero) -> true) ($pipe (n) -> false))\n(eval (is-zero2 (suc zero)))")
   "false : Bool"))

(test-case "pattern/sexp-add"
  ;; add with constructor patterns: zero/suc
  ;; Recursive functions need a spec for the pre-registration type
  (check-equal?
   (run-last
    (string-append
     "(spec addp Nat -> Nat -> Nat)\n"
     "(defn addp ($pipe (zero n) -> n)"
     " ($pipe ((suc m) n) -> (suc (addp m n))))\n"
     "(eval (addp (suc (suc zero)) (suc zero)))"))
   "3N : Nat"))

(test-case "pattern/sexp-not"
  ;; Bool not with true/false patterns
  (check-equal?
   (run-last
    "(defn notp ($pipe (true) -> false) ($pipe (false) -> true))\n(eval (notp true))")
   "false : Bool")
  (check-equal?
   (run-last
    "(defn notp2 ($pipe (true) -> false) ($pipe (false) -> true))\n(eval (notp2 false))")
   "true : Bool"))

(test-case "pattern/sexp-multi-arg-first-patterned"
  ;; First arg patterned, second variable
  (check-equal?
   (run-last
    (string-append
     "(defn choose ($pipe (true x) -> x)"
     " ($pipe (false x) -> zero))\n"
     "(eval (choose true (suc (suc zero))))"))
   "2N : Nat"))

(test-case "pattern/sexp-wildcard-catch-all"
  ;; Wildcard _ as catch-all
  (check-equal?
   (run-last
    "(defn always-zero ($pipe (_) -> zero))\n(eval (always-zero (suc (suc zero))))")
   "0N : Nat"))

(test-case "pattern/sexp-numeric-zero"
  ;; Numeric literal pattern 0N -> desugars to zero
  (check-equal?
   (run-last
    "(defn iz3 ($pipe (0N) -> true) ($pipe (n) -> false))\n(eval (iz3 zero))")
   "true : Bool"))

(test-case "pattern/sexp-numeric-one"
  ;; Numeric literal pattern 1N -> desugars to suc zero
  (check-equal?
   (run-last
    "(defn is-one ($pipe (0N) -> false) ($pipe (1N) -> true) ($pipe (n) -> false))\n(eval (is-one (suc zero)))")
   "true : Bool")
  (check-equal?
   (run-last
    "(defn is-one2 ($pipe (0N) -> false) ($pipe (1N) -> true) ($pipe (n) -> false))\n(eval (is-one2 (suc (suc zero))))")
   "false : Bool"))

(test-case "pattern/sexp-nested-compound"
  ;; Nested compound pattern: (suc (suc n))
  (check-equal?
   (run-last
    (string-append
     "(defn pred-pred ($pipe (zero) -> zero)"
     " ($pipe ((suc zero)) -> zero)"
     " ($pipe ((suc (suc n))) -> n))\n"
     "(eval (pred-pred (suc (suc (suc zero)))))"))
   "1N : Nat"))

;; ========================================
;; C. Head-tail patterns in match arms
;; ========================================

(test-case "pattern/sexp-head-tail-in-match"
  ;; Head-tail in a match expression: [a $pipe rest] -> cons desugaring
  ;; Note: match needs (the Type ...) wrapper since infer has no expr-reduce case
  (check-equal?
   (run-last
    (string-append
     "(def xs : (List Nat) (cons (suc zero) (cons (suc (suc zero)) nil)))\n"
     "(eval (the Nat (match xs ((a $pipe rest) -> a) (nil -> zero))))"))
   "1N : Nat"))
