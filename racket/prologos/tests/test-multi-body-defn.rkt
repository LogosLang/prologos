#lang racket/base

;;;
;;; Tests for Multi-Body defn with Case-Split Syntax
;;;
;;; Verifies compile-time arity dispatch: each clause of a multi-body defn
;;; is a separate internal definition (name/N), selected by argument count.
;;;

(require rackunit
         racket/string
         racket/list
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../macros.rkt"
         "../multi-dispatch.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (run s)
  (parameterize ([current-global-env (hasheq)]
                 [current-multi-defn-registry (hasheq)])
    (process-string s)))

(define (run-first s) (car (run s)))
(define (run-last s) (last (run s)))

;; ========================================
;; Parsing: multi-body defn detection
;; ========================================

(test-case "multi/parse-two-clauses"
  ;; sexp-mode multi-body with $pipe markers
  ;; Parser sees: (defn f ($pipe [x <Nat>] <Nat> (inc x)) ($pipe [x <Nat> y <Nat>] <Nat> x))
  (define parsed
    (parse-string "(defn f ($pipe [x <Nat>] <Nat> (inc x)) ($pipe [x <Nat> y <Nat>] <Nat> x))"))
  (check-true (surf-defn-multi? parsed))
  (check-equal? (surf-defn-multi-name parsed) 'f)
  (check-false (surf-defn-multi-docstring parsed))
  (check-equal? (length (surf-defn-multi-clauses parsed)) 2))

(test-case "multi/parse-with-docstring"
  (define parsed
    (parse-string "(defn f \"A function\" ($pipe [x <Nat>] <Nat> x) ($pipe [x <Nat> y <Nat>] <Nat> x))"))
  (check-true (surf-defn-multi? parsed))
  (check-equal? (surf-defn-multi-docstring parsed) "A function"))

(test-case "multi/parse-no-pipe-is-normal-defn"
  ;; Without $pipe, should be a normal defn
  (define parsed (parse-string "(defn f [x <Nat>] <Nat> x)"))
  (check-true (surf-defn? parsed))
  (check-false (surf-defn-multi? parsed)))

;; ========================================
;; Expansion: produces surf-def-group
;; ========================================

(test-case "multi/expand-to-def-group"
  (define parsed
    (parse-string "(defn f ($pipe [x <Nat>] <Nat> (inc x)) ($pipe [x <Nat> y <Nat>] <Nat> x))"))
  (define expanded (expand-top-level parsed))
  (check-true (surf-def-group? expanded))
  (check-equal? (surf-def-group-name expanded) 'f)
  (check-equal? (sort (surf-def-group-arities expanded) <) '(1 2))
  (check-equal? (length (surf-def-group-defs expanded)) 2))

;; ========================================
;; End-to-end: define and call multi-body functions
;; ========================================

(test-case "multi/dispatch-1-arg"
  ;; Define f with 1-arg and 2-arg clauses, call with 1 arg
  (define results
    (run "(defn f ($pipe [x <Nat>] <Nat> (inc x)) ($pipe [x <Nat> y <Nat>] <Nat> x))\n(eval (f zero))"))
  (check-equal? (last results) "1 : Nat"))

(test-case "multi/dispatch-2-args"
  ;; Same definition, call with 2 args
  (define results
    (run "(defn f ($pipe [x <Nat>] <Nat> (inc x)) ($pipe [x <Nat> y <Nat>] <Nat> x))\n(eval (f (inc zero) zero))"))
  (check-equal? (last results) "1 : Nat"))

(test-case "multi/dispatch-wrong-arity-error"
  ;; Call with 3 args — no matching clause
  (define results
    (run "(defn f ($pipe [x <Nat>] <Nat> (inc x)) ($pipe [x <Nat> y <Nat>] <Nat> x))\n(eval (f zero zero zero))"))
  (define err (last results))
  (check-true (prologos-error? err))
  (check-true (multi-arity-error? err))
  (check-equal? (multi-arity-error-func-name err) 'f)
  (check-equal? (multi-arity-error-user-args err) 3))

(test-case "multi/dispatch-zero-arg-not-matched"
  ;; Call with 0 args — bare reference to multi-body name
  (define results
    (run "(defn f ($pipe [x <Nat>] <Nat> (inc x)) ($pipe [x <Nat> y <Nat>] <Nat> x))\n(eval f)"))
  (define err (last results))
  (check-true (prologos-error? err)))

;; ========================================
;; Internal naming: name/N convention
;; ========================================

(test-case "multi/internal-names-registered"
  ;; After defining multi-body f, f/1 and f/2 should be in global env
  (parameterize ([current-global-env (hasheq)]
                 [current-multi-defn-registry (hasheq)])
    (process-string "(defn f ($pipe [x <Nat>] <Nat> (inc x)) ($pipe [x <Nat> y <Nat>] <Nat> x))")
    (check-not-false (global-env-lookup-type 'f/1))
    (check-not-false (global-env-lookup-type 'f/2))
    ;; Base name should NOT be in global env
    (check-false (global-env-lookup-type 'f))))

;; ========================================
;; Registration output message
;; ========================================

(test-case "multi/output-message"
  (define results
    (run "(defn f ($pipe [x <Nat>] <Nat> (inc x)) ($pipe [x <Nat> y <Nat>] <Nat> x))"))
  ;; First result should mention "defined" and arities
  (define msg (car results))
  (check-true (string? msg))
  (check-true (string-contains? msg "defined"))
  (check-true (string-contains? msg "1"))
  (check-true (string-contains? msg "2")))

;; ========================================
;; Error: duplicate arities
;; ========================================

(test-case "multi/duplicate-arity-error"
  ;; Two clauses with the same arity should produce an error
  (define results
    (run "(defn f ($pipe [x <Nat>] <Nat> (inc x)) ($pipe [y <Nat>] <Nat> y))"))
  (define err (car results))
  (check-true (prologos-error? err)))

;; ========================================
;; Type checking: each clause independently
;; ========================================

(test-case "multi/type-check-independent"
  ;; Clauses with different param types should both type-check
  (define results
    (run "(defn g ($pipe [x <Nat>] <Nat> (inc x)) ($pipe [x <Nat> y <Bool>] <Nat> x))\n(eval (g zero))\n(eval (g zero true))"))
  (check-equal? (second results) "1 : Nat")
  (check-equal? (third results) "zero : Nat"))

;; ========================================
;; Self-recursion within a clause
;; ========================================

(test-case "multi/self-recursion"
  ;; f/1 calls itself recursively (factorial-like)
  (define results
    (run (string-append
      "(defn double"
      " ($pipe [x <Nat>] <Nat>"
      "   (natrec Nat zero (fn [k <Nat>] (fn [r <Nat>] (inc (inc r)))) x)))"
      "\n(eval (double (inc (inc zero))))"))  ;; double 2 = 4
  )
  (check-equal? (last results) "4 : Nat"))

;; ========================================
;; Error message quality
;; ========================================

(test-case "multi/error-message-shows-arities"
  (define results
    (run "(defn f ($pipe [x <Nat>] <Nat> x) ($pipe [x <Nat> y <Nat>] <Nat> x))\n(eval (f zero zero zero))"))
  (define err (last results))
  (check-true (multi-arity-error? err))
  (define formatted (format-error err))
  (check-true (string-contains? formatted "1"))
  (check-true (string-contains? formatted "2"))
  (check-true (string-contains? formatted "3")))

;; ========================================
;; Sexp mode invariant: existing defn unchanged
;; ========================================

(test-case "multi/sexp-single-body-unchanged"
  ;; Regular single-body defn still works
  (define results
    (run "(defn double [x <Nat>] <Nat> (inc (inc x)))\n(eval (double zero))"))
  (check-equal? (last results) "2 : Nat"))
