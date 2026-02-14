#lang racket/base

;;;
;;; PROLOGOS #lang TESTS
;;; End-to-end tests that #lang prologos files compile and produce
;;; correct output. Each test dynamically requires an example file
;;; and captures its stdout.
;;;

(require rackunit
         racket/port
         racket/runtime-path
         racket/string)

(define-runtime-path examples-dir "examples")

;; Helper: run a #lang prologos file and capture stdout.
;; Uses a fresh empty namespace so the module is loaded and executed
;; from scratch each time, and output is captured via current-output-port.
(define (run-prologos-file filename)
  (define path (build-path examples-dir filename))
  (define ns (make-base-empty-namespace))
  (define out-port (open-output-string))
  (parameterize ([current-output-port out-port]
                 [current-namespace ns])
    (namespace-require path))
  (get-output-string out-port))

;; ================================================================
;; 1. hello.rkt — basic definitions, check, eval
;; ================================================================
(test-case "hello.rkt: basic definitions and evaluation"
  (define output (run-prologos-file "hello.rkt"))
  (check-true (string-contains? output "one : Nat defined."))
  (check-true (string-contains? output "two : Nat defined."))
  (check-true (string-contains? output "OK"))
  (check-true (string-contains? output "2 : Nat")))

;; ================================================================
;; 2. identity.rkt — polymorphic identity with Pi types
;; ================================================================
(test-case "identity.rkt: polymorphic identity"
  (define output (run-prologos-file "identity.rkt"))
  ;; id should be defined
  (check-true (string-contains? output "id"))
  (check-true (string-contains? output "defined"))
  ;; id Nat zero should evaluate to zero
  (check-true (string-contains? output "zero : Nat"))
  ;; id Nat 2 should evaluate to 2
  (check-true (string-contains? output "2 : Nat"))
  ;; id Bool true should evaluate to true
  (check-true (string-contains? output "true : Bool")))

;; ================================================================
;; 3. vectors.rkt — Vec/Fin type checking
;; ================================================================
(test-case "vectors.rkt: Vec and Fin types"
  (define output (run-prologos-file "vectors.rkt"))
  ;; All checks should pass (at least 3 OK lines)
  (define ok-count
    (length (filter (lambda (line) (string=? (string-trim line) "OK"))
                    (string-split output "\n"))))
  (check-true (>= ok-count 3)
              (format "Expected at least 3 OK lines, got ~a" ok-count))
  ;; vhead should produce 1
  (check-true (string-contains? output "1 : Nat")))

;; ================================================================
;; 4. pairs.rkt — Sigma types and dependent pairs
;; ================================================================
(test-case "pairs.rkt: Sigma types"
  (define output (run-prologos-file "pairs.rkt"))
  ;; All checks should pass
  (check-true (string-contains? output "OK"))
  ;; fst should yield zero
  (check-true (string-contains? output "zero : Nat"))
  ;; snd should yield true
  (check-true (string-contains? output "true : Bool")))

;; ================================================================
;; 5. Multiple definitions with forward references
;; ================================================================
(test-case "definitions can reference earlier definitions"
  ;; hello.rkt already tests this: two references one
  (define output (run-prologos-file "hello.rkt"))
  (check-true (string-contains? output "two : Nat defined.")))

;; ================================================================
;; WHITESPACE-SYNTAX TESTS (#lang prologos)
;; Same expectations as above, using -ws.rkt example files.
;; ================================================================

(test-case "hello-ws.rkt: basic definitions and evaluation"
  (define output (run-prologos-file "hello-ws.rkt"))
  (check-true (string-contains? output "one : Nat defined."))
  (check-true (string-contains? output "two : Nat defined."))
  (check-true (string-contains? output "OK"))
  (check-true (string-contains? output "2 : Nat")))

(test-case "identity-ws.rkt: polymorphic identity"
  (define output (run-prologos-file "identity-ws.rkt"))
  (check-true (string-contains? output "id"))
  (check-true (string-contains? output "defined"))
  (check-true (string-contains? output "zero : Nat"))
  (check-true (string-contains? output "2 : Nat"))
  (check-true (string-contains? output "true : Bool")))

(test-case "vectors-ws.rkt: Vec and Fin types"
  (define output (run-prologos-file "vectors-ws.rkt"))
  (define ok-count
    (length (filter (lambda (line) (string=? (string-trim line) "OK"))
                    (string-split output "\n"))))
  (check-true (>= ok-count 3)
              (format "Expected at least 3 OK lines, got ~a" ok-count))
  (check-true (string-contains? output "1 : Nat")))

(test-case "pairs-ws.rkt: Sigma types"
  (define output (run-prologos-file "pairs-ws.rkt"))
  (check-true (string-contains? output "OK"))
  (check-true (string-contains? output "zero : Nat"))
  (check-true (string-contains? output "true : Bool")))

(test-case "hello-ws.rkt: definitions can reference earlier definitions"
  (define output (run-prologos-file "hello-ws.rkt"))
  (check-true (string-contains? output "two : Nat defined.")))

;; ========================================
;; defn and implicit eval tests
;; ========================================

(test-case "defn.rkt: sexp defn macro"
  (define output (run-prologos-file "defn.rkt"))
  (check-true (string-contains? output "increment") "should define increment")
  (check-true (string-contains? output "1 : Nat") "increment zero = 1")
  (check-true (string-contains? output "2 : Nat") "increment (inc zero) = 2")
  (check-true (string-contains? output "id") "should define id")
  (check-true (string-contains? output "zero : Nat") "id Nat zero")
  (check-true (string-contains? output "true : Bool") "id Bool true"))

(test-case "defn-ws.rkt: whitespace defn macro"
  (define output (run-prologos-file "defn-ws.rkt"))
  (check-true (string-contains? output "increment") "should define increment")
  (check-true (string-contains? output "1 : Nat") "increment zero = 1")
  (check-true (string-contains? output "2 : Nat") "increment (inc zero) = 2")
  (check-true (string-contains? output "id") "should define id")
  (check-true (string-contains? output "zero : Nat") "id Nat zero")
  (check-true (string-contains? output "true : Bool") "id Bool true"))

;; ========================================
;; Macro tests (defmacro, let, if, deftype)
;; ========================================

(test-case "macros.rkt: defmacro, deftype, let, if"
  (define output (run-prologos-file "macros.rkt"))
  ;; double should be defined
  (check-true (string-contains? output "double : Nat -> Nat defined.")
              "should define double")
  ;; double (inc (inc zero)) = 4
  (check-true (string-contains? output "4 : Nat")
              "double 2 = 4")
  ;; not true = false, not false = true
  (check-true (string-contains? output "false : Bool")
              "not true = false")
  (check-true (string-contains? output "true : Bool")
              "not false = true")
  ;; let with double and inc
  (check-true (string-contains? output "3 : Nat")
              "let result = 3")
  ;; if true (inc zero) zero = 1
  (check-true (string-contains? output "1 : Nat")
              "if true = 1")
  ;; if false (inc zero) zero = zero
  (check-true (string-contains? output "zero : Nat")
              "if false = zero")
  ;; check pair against Pair alias = OK
  (check-true (string-contains? output "OK")
              "Pair type alias check"))

(test-case "macros-ws.rkt: if, boolrec, let in whitespace mode"
  (define output (run-prologos-file "macros-ws.rkt"))
  ;; double should be defined
  (check-true (string-contains? output "double : Nat -> Nat defined.")
              "should define double")
  ;; double (inc (inc zero)) = 4
  (check-true (string-contains? output "4 : Nat")
              "double 2 = 4")
  ;; if true = 1, if false = zero
  (check-true (string-contains? output "1 : Nat")
              "if true = 1")
  (check-true (string-contains? output "zero : Nat")
              "if false / boolrec true = zero")
  ;; let result = 3
  (check-true (string-contains? output "3 : Nat")
              "let result = 3"))

;; ========================================
;; REPL interaction tests
;; ========================================

;; Helper: load a module and then eval a REPL form against its env.
;; Returns captured stdout from the REPL eval.
;; Helper: load a #lang prologos/sexp module and eval a REPL form via #%top-interaction.
;; Simulates what DrRacket does: load the file, then eval REPL forms
;; in the module's namespace, wrapping each in #%top-interaction.
(define (repl-eval-after-file filename repl-form-str)
  (define path (build-path examples-dir filename))
  (define ns (make-base-empty-namespace))
  (define mod-name `(file ,(path->string path)))
  (define load-output (open-output-string))
  (parameterize ([current-output-port load-output]
                 [current-namespace ns])
    (namespace-require mod-name))
  ;; Get the module's namespace — has #%top-interaction etc.
  (define mod-ns (module->namespace mod-name ns))
  ;; Eval with explicit #%top-interaction wrapping (what Racket REPL does)
  (define repl-output (open-output-string))
  (parameterize ([current-output-port repl-output]
                 [current-namespace mod-ns])
    (define port (open-input-string repl-form-str))
    (port-count-lines! port)
    (define stx (read-syntax "<repl>" port))
    ;; Create (#%top-interaction . form) with the #%top-interaction identifier
    ;; resolved in the module's namespace
    (define ti-id (namespace-symbol->identifier '#%top-interaction))
    (define wrapped (datum->syntax #f (cons ti-id stx)))
    (eval wrapped mod-ns))
  (string-trim (get-output-string repl-output)))

(test-case "REPL: eval expression using file definitions"
  (define result (repl-eval-after-file "defn.rkt" "(eval (increment zero))"))
  (check-true (string-contains? result "1 : Nat")
              (format "Expected '1 : Nat', got: ~a" result)))

(test-case "REPL: infer type of file definition"
  (define result (repl-eval-after-file "defn.rkt" "(infer increment)"))
  (check-true (string-contains? result "Nat")
              (format "Expected Nat in type, got: ~a" result)))

(test-case "REPL: check expression against type"
  (define result (repl-eval-after-file "defn.rkt" "(check (increment zero) : Nat)"))
  (check-equal? result "OK"))

(test-case "REPL: implicit eval of bare expression"
  (define result (repl-eval-after-file "hello.rkt" "(inc zero)"))
  (check-true (string-contains? result "1 : Nat")
              (format "Expected '1 : Nat', got: ~a" result)))

;; ========================================
;; Let :=, sibling lets, uncurried arrows (WS mode)
;; ========================================

(test-case "let-arrow-ws.rkt: let :=, sibling lets, uncurried arrows"
  (define output (run-prologos-file "let-arrow-ws.rkt"))
  ;; let := basic: one = 1
  (check-true (string-contains? output "one : Nat defined.")
              "should define one")
  (check-true (string-contains? output "1 : Nat")
              "one = 1")
  ;; sibling lets: three = 3
  (check-true (string-contains? output "three : Nat defined.")
              "should define three")
  (check-true (string-contains? output "3 : Nat")
              "three = 3 via sibling lets")
  ;; uncurried arrow: add has Nat Nat -> Nat type
  (check-true (string-contains? output "add : Nat Nat -> Nat defined.")
              "add should have uncurried arrow type")
  ;; apply-fn and inc2
  (check-true (string-contains? output "apply-fn")
              "should define apply-fn")
  (check-true (string-contains? output "inc2")
              "should define inc2"))

(test-case "spec-ws.rkt: spec form with WS mode"
  (define output (run-prologos-file "spec-ws.rkt"))
  ;; add with spec: Nat Nat -> Nat
  (check-true (string-contains? output "add : Nat Nat -> Nat defined.")
              "spec'd add should have uncurried arrow type")
  (check-true (string-contains? output "3 : Nat")
              "add 1 2 = 3")
  ;; inc2 with docstring spec
  (check-true (string-contains? output "inc2 : Nat -> Nat defined.")
              "spec'd inc2 should have Nat -> Nat type")
  ;; HOF apply-fn
  (check-true (string-contains? output "apply-fn : [Nat -> Nat] Nat -> Nat defined.")
              "spec'd apply-fn should wrap HOF domain in brackets")
  (check-true (string-contains? output "2 : Nat")
              "apply-fn inc2 zero = 2"))
