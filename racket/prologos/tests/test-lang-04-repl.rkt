#lang racket/base

;;;
;;; PROLOGOS #lang TESTS — REPL interaction
;;; Tests for REPL eval, infer, check, and implicit eval.
;;;

(require rackunit
         racket/port
         racket/runtime-path
         racket/string)

(define-runtime-path examples-dir "examples")

;; Helper: run a #lang prologos file and capture stdout.
(define (run-prologos-file filename)
  (define path (build-path examples-dir filename))
  (define ns (make-base-empty-namespace))
  (define out-port (open-output-string))
  (parameterize ([current-output-port out-port]
                 [current-namespace ns])
    (namespace-require path))
  (get-output-string out-port))

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
    (define ti-id (namespace-symbol->identifier '#%top-interaction))
    (define wrapped (datum->syntax #f (cons ti-id stx)))
    (eval wrapped mod-ns))
  (string-trim (get-output-string repl-output)))

;; ========================================
;; REPL interaction tests
;; ========================================

(test-case "REPL: eval expression using file definitions"
  (define result (repl-eval-after-file "defn.rkt" "(eval (increment zero))"))
  (check-true (string-contains? result "1N : Nat")
              (format "Expected '1 : Nat', got: ~a" result)))

(test-case "REPL: infer type of file definition"
  (define result (repl-eval-after-file "defn.rkt" "(infer increment)"))
  (check-true (string-contains? result "Nat")
              (format "Expected Nat in type, got: ~a" result)))

(test-case "REPL: check expression against type"
  (define result (repl-eval-after-file "defn.rkt" "(check (increment zero) : Nat)"))
  (check-equal? result "OK"))

(test-case "REPL: implicit eval of bare expression"
  (define result (repl-eval-after-file "hello.rkt" "(suc zero)"))
  (check-true (string-contains? result "1N : Nat")
              (format "Expected '1 : Nat', got: ~a" result)))
