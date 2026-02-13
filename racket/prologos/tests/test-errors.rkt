#lang racket/base

;;;
;;; Tests for source-location.rkt and errors.rkt
;;;

(require rackunit
         racket/string
         "../source-location.rkt"
         "../errors.rkt")

;; ========================================
;; Source location tests
;; ========================================

(test-case "srcloc: format with file/line/col"
  (check-equal? (format-srcloc (srcloc "test.prl" 10 5 3))
                "test.prl:10:5"))

(test-case "srcloc: format unknown"
  (check-equal? (format-srcloc srcloc-unknown)
                "<unknown>"))

;; ========================================
;; Error construction tests
;; ========================================

(test-case "type-mismatch-error: is prologos-error"
  (check-true
   (prologos-error?
    (type-mismatch-error srcloc-unknown "Type mismatch" "Nat" "Bool" #f))))

(test-case "unbound-variable-error: is prologos-error"
  (check-true
   (prologos-error?
    (unbound-variable-error srcloc-unknown "Unbound variable" 'x))))

(test-case "multiplicity-error: is prologos-error"
  (check-true
   (prologos-error?
    (multiplicity-error srcloc-unknown "Multiplicity mismatch" 'x 'm1 'mw))))

(test-case "parse-error: is prologos-error"
  (check-true
   (prologos-error?
    (parse-error srcloc-unknown "Unexpected form" '(bad thing)))))

;; ========================================
;; Error formatting tests
;; ========================================

(test-case "format-error: type mismatch"
  (let ([err (type-mismatch-error (srcloc "test.prl" 5 2 10)
                                   "Type mismatch in application"
                                   "Nat" "Bool" "(f x)")])
    (check-true (string-contains? (format-error err) "test.prl:5:2"))
    (check-true (string-contains? (format-error err) "Expected: Nat"))
    (check-true (string-contains? (format-error err) "Got:      Bool"))
    (check-true (string-contains? (format-error err) "(f x)"))))

(test-case "format-error: unbound variable"
  (let ([err (unbound-variable-error (srcloc "test.prl" 3 0 1)
                                      "Unbound variable"
                                      'foo)])
    (check-true (string-contains? (format-error err) "Unbound variable: foo"))))

(test-case "format-error: multiplicity"
  (let ([err (multiplicity-error (srcloc "test.prl" 7 4 5)
                                  "Multiplicity violation"
                                  'x 'm1 'mw)])
    (check-true (string-contains? (format-error err) "Variable: x"))
    (check-true (string-contains? (format-error err) "Declared multiplicity: m1"))
    (check-true (string-contains? (format-error err) "Actual usage: mw"))))

(test-case "format-error: parse error"
  (let ([err (parse-error srcloc-unknown "Unexpected form" '(bad stuff))])
    (check-true (string-contains? (format-error err) "Unexpected form"))
    (check-true (string-contains? (format-error err) "(bad stuff)"))))

(test-case "format-error: inference failed"
  (let ([err (inference-failed-error (srcloc "test.prl" 1 0 5)
                                      "Could not infer type"
                                      "(lam (x : Nat) x)")])
    (check-true (string-contains? (format-error err) "Could not infer type"))
    (check-true (string-contains? (format-error err) "(lam (x : Nat) x)"))))

(test-case "format-error: arity error"
  (let ([err (arity-error (srcloc "test.prl" 2 3 10)
                           "Wrong number of arguments"
                           "suc" 1 2 #f)])
    (check-true (string-contains? (format-error err) "suc"))
    (check-true (string-contains? (format-error err) "1"))
    (check-true (string-contains? (format-error err) "2"))))

(test-case "format-error: base prologos-error"
  (let ([err (prologos-error (srcloc "test.prl" 1 0 0) "Something went wrong")])
    (check-true (string-contains? (format-error err) "Something went wrong"))))
