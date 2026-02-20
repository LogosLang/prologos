#lang racket/base

;;;
;;; PROLOGOS #lang ERROR TESTS — S-expression mode
;;; Tests that #lang prologos/sexp files produce proper Racket exceptions
;;; with source locations when type errors occur.
;;;

(require rackunit
         racket/list
         racket/runtime-path
         racket/string)

(define-runtime-path examples-dir "examples")

;; Helper: require a prologos file in a fresh namespace.
(define (require-prologos-file filename)
  (define path (build-path examples-dir filename))
  (define ns (make-base-empty-namespace))
  (parameterize ([current-namespace ns])
    (namespace-require path)))

;; ================================================================
;; 1. Type mismatch produces exn:fail
;; ================================================================
(test-case "type-error.rkt raises exn:fail"
  (check-exn exn:fail?
    (lambda () (require-prologos-file "type-error.rkt"))))

;; ================================================================
;; 2. Type mismatch message mentions the issue
;; ================================================================
(test-case "type error message mentions type mismatch"
  (check-exn
    (lambda (e)
      (and (exn:fail? e)
           (string-contains? (exn-message e) "Type mismatch")))
    (lambda () (require-prologos-file "type-error.rkt"))))

;; ================================================================
;; 3. Type error mentions expected and actual types
;; ================================================================
(test-case "type error mentions expected and actual types"
  (check-exn
    (lambda (e)
      (and (exn:fail? e)
           (string-contains? (exn-message e) "Nat")
           (string-contains? (exn-message e) "Bool")))
    (lambda () (require-prologos-file "type-error.rkt"))))

;; ================================================================
;; 4. Unbound variable produces exn:fail
;; ================================================================
(test-case "unbound-var.rkt raises exn:fail"
  (check-exn exn:fail?
    (lambda () (require-prologos-file "unbound-var.rkt"))))

;; ================================================================
;; 5. Unbound variable message mentions the variable name
;; ================================================================
(test-case "unbound variable error mentions the variable name"
  (check-exn
    (lambda (e)
      (and (exn:fail? e)
           (string-contains? (exn-message e) "undefined_var")))
    (lambda () (require-prologos-file "unbound-var.rkt"))))

;; ================================================================
;; 6. Type error has source location in message
;; ================================================================
(test-case "type error message has source location"
  (with-handlers
    ([exn:fail?
      (lambda (e)
        (define msg (exn-message e))
        (check-true (string-contains? msg "type-error.rkt")
                    "Error message should mention the file")
        (check-true (string-contains? msg ":3:")
                    "Error message should mention line 3"))])
    (require-prologos-file "type-error.rkt")))

;; ================================================================
;; 7. Unbound variable error has source location in message
;; ================================================================
(test-case "unbound variable error message has source location"
  (with-handlers
    ([exn:fail?
      (lambda (e)
        (define msg (exn-message e))
        (check-true (string-contains? msg "unbound-var.rkt")
                    "Error message should mention the file")
        (check-true (string-contains? msg ":3:")
                    "Error message should mention line 3"))])
    (require-prologos-file "unbound-var.rkt")))

;; ================================================================
;; 8. Type error mentions expression context
;; ================================================================
(test-case "type error mentions the expression"
  (check-exn
    (lambda (e)
      (and (exn:fail? e)
           (string-contains? (exn-message e) "true")))
    (lambda () (require-prologos-file "type-error.rkt"))))

;; ================================================================
;; 9. Error has prop:exn:srclocs for DrRacket highlighting
;; ================================================================
(test-case "error has source locations for DrRacket"
  (with-handlers
    ([exn:fail?
      (lambda (e)
        (define has-srclocs?
          (with-handlers ([exn:fail? (lambda (_) #f)])
            (define accessor (exn:srclocs-accessor e))
            (define locs (accessor e))
            (and (list? locs) (pair? locs))))
        (check-true has-srclocs?
                    "Error should provide srclocs for DrRacket"))])
    (require-prologos-file "type-error.rkt")))
