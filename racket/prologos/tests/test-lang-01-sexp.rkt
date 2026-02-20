#lang racket/base

;;;
;;; PROLOGOS #lang TESTS — S-expression mode basics
;;; End-to-end tests that #lang prologos/sexp files compile and produce
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
;; 1. hello.rkt — basic definitions, check, eval
;; ================================================================
(test-case "hello.rkt: basic definitions and evaluation"
  (define output (run-prologos-file "hello.rkt"))
  (check-true (string-contains? output "one : Nat defined."))
  (check-true (string-contains? output "two : Nat defined."))
  (check-true (string-contains? output "OK"))
  (check-true (string-contains? output "2N : Nat")))

;; ================================================================
;; 2. identity.rkt — polymorphic identity with Pi types
;; ================================================================
(test-case "identity.rkt: polymorphic identity"
  (define output (run-prologos-file "identity.rkt"))
  (check-true (string-contains? output "id"))
  (check-true (string-contains? output "defined"))
  (check-true (string-contains? output "0N : Nat"))
  (check-true (string-contains? output "2N : Nat"))
  (check-true (string-contains? output "true : Bool")))

;; ================================================================
;; 3. vectors.rkt — Vec/Fin type checking
;; ================================================================
(test-case "vectors.rkt: Vec and Fin types"
  (define output (run-prologos-file "vectors.rkt"))
  (define ok-count
    (length (filter (lambda (line) (string=? (string-trim line) "OK"))
                    (string-split output "\n"))))
  (check-true (>= ok-count 3)
              (format "Expected at least 3 OK lines, got ~a" ok-count))
  (check-true (string-contains? output "1N : Nat")))

;; ================================================================
;; 4. pairs.rkt — Sigma types and dependent pairs
;; ================================================================
(test-case "pairs.rkt: Sigma types"
  (define output (run-prologos-file "pairs.rkt"))
  (check-true (string-contains? output "OK"))
  (check-true (string-contains? output "0N : Nat"))
  (check-true (string-contains? output "true : Bool")))

;; ================================================================
;; 5. Multiple definitions with forward references
;; ================================================================
(test-case "definitions can reference earlier definitions"
  (define output (run-prologos-file "hello.rkt"))
  (check-true (string-contains? output "two : Nat defined.")))
