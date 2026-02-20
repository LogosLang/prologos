#lang racket/base

;;;
;;; PROLOGOS #lang TESTS — Whitespace-syntax mode basics
;;; End-to-end tests that #lang prologos (WS) files compile and produce
;;; correct output.
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

;; ================================================================
;; WHITESPACE-SYNTAX TESTS (#lang prologos)
;; Same expectations as sexp, using -ws.rkt example files.
;; ================================================================

(test-case "hello-ws.rkt: basic definitions and evaluation"
  (define output (run-prologos-file "hello-ws.rkt"))
  (check-true (string-contains? output "one : Nat defined."))
  (check-true (string-contains? output "two : Nat defined."))
  (check-true (string-contains? output "OK"))
  (check-true (string-contains? output "2N : Nat")))

(test-case "identity-ws.rkt: polymorphic identity"
  (define output (run-prologos-file "identity-ws.rkt"))
  (check-true (string-contains? output "id"))
  (check-true (string-contains? output "defined"))
  (check-true (string-contains? output "0N : Nat"))
  (check-true (string-contains? output "2N : Nat"))
  (check-true (string-contains? output "true : Bool")))

(test-case "vectors-ws.rkt: Vec and Fin types"
  (define output (run-prologos-file "vectors-ws.rkt"))
  (define ok-count
    (length (filter (lambda (line) (string=? (string-trim line) "OK"))
                    (string-split output "\n"))))
  (check-true (>= ok-count 3)
              (format "Expected at least 3 OK lines, got ~a" ok-count))
  (check-true (string-contains? output "1N : Nat")))

(test-case "pairs-ws.rkt: Sigma types"
  (define output (run-prologos-file "pairs-ws.rkt"))
  (check-true (string-contains? output "OK"))
  (check-true (string-contains? output "0N : Nat"))
  (check-true (string-contains? output "true : Bool")))

(test-case "hello-ws.rkt: definitions can reference earlier definitions"
  (define output (run-prologos-file "hello-ws.rkt"))
  (check-true (string-contains? output "two : Nat defined.")))
