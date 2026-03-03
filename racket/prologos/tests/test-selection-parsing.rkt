#lang racket/base

;;;
;;; Tests for Phase 2a: Selection Parsing
;;; Verifies the parser correctly handles (selection Name from Schema ...)
;;; syntax and produces surf-selection AST nodes.
;;;

(require rackunit
         racket/list
         "../parser.rkt"
         "../surface-syntax.rkt"
         "../sexp-readtable.rkt"
         "../errors.rkt")

;; ========================================
;; Helper: parse a single selection form from string
;; ========================================
(define (test-parse str)
  (define port (open-input-string str))
  (define stx (prologos-sexp-read-syntax "<test>" port))
  (parse-datum stx))

;; ========================================
;; 1. Basic :requires selection
;; ========================================

(test-case "selection-parse/basic-requires"
  (define result (test-parse "(selection MovieTimesReq from User :requires [:id :zip])"))
  (check-true (surf-selection? result)
              (format "Expected surf-selection, got ~v" result))
  (check-equal? (surf-selection-name result) 'MovieTimesReq)
  (check-equal? (surf-selection-schema-name result) 'User)
  (check-equal? (surf-selection-requires-paths result) '(#:id #:zip))
  (check-equal? (surf-selection-provides-paths result) '())
  (check-equal? (surf-selection-includes-names result) '()))

;; ========================================
;; 2. :provides selection
;; ========================================

(test-case "selection-parse/provides-only"
  (define result (test-parse "(selection UserOut from User :provides [:name :email])"))
  (check-true (surf-selection? result))
  (check-equal? (surf-selection-name result) 'UserOut)
  (check-equal? (surf-selection-schema-name result) 'User)
  (check-equal? (surf-selection-requires-paths result) '())
  (check-equal? (surf-selection-provides-paths result) '(#:name #:email))
  (check-equal? (surf-selection-includes-names result) '()))

;; ========================================
;; 3. :includes selection
;; ========================================

(test-case "selection-parse/includes-only"
  (define result (test-parse "(selection FullContact from User :includes [BasicId ContactInfo])"))
  (check-true (surf-selection? result))
  (check-equal? (surf-selection-name result) 'FullContact)
  (check-equal? (surf-selection-schema-name result) 'User)
  (check-equal? (surf-selection-requires-paths result) '())
  (check-equal? (surf-selection-provides-paths result) '())
  (check-equal? (surf-selection-includes-names result) '(BasicId ContactInfo)))

;; ========================================
;; 4. Combined :requires + :includes
;; ========================================

(test-case "selection-parse/requires-and-includes"
  (define result (test-parse "(selection Full from User :requires [:address] :includes [BasicId])"))
  (check-true (surf-selection? result))
  (check-equal? (surf-selection-requires-paths result) '(#:address))
  (check-equal? (surf-selection-includes-names result) '(BasicId)))

;; ========================================
;; 5. Combined :requires + :provides + :includes
;; ========================================

(test-case "selection-parse/all-three-clauses"
  (define result (test-parse "(selection Stage from Req :requires [:id] :provides [:result] :includes [Base])"))
  (check-true (surf-selection? result))
  (check-equal? (surf-selection-requires-paths result) '(#:id))
  (check-equal? (surf-selection-provides-paths result) '(#:result))
  (check-equal? (surf-selection-includes-names result) '(Base)))

;; ========================================
;; 6. Multiple fields in :requires
;; ========================================

(test-case "selection-parse/multi-field-requires"
  (define result (test-parse "(selection Big from S :requires [:a :b :c :d :e])"))
  (check-true (surf-selection? result))
  (check-equal? (surf-selection-requires-paths result) '(#:a #:b #:c #:d #:e)))

;; ========================================
;; 7. Field order preserved
;; ========================================

(test-case "selection-parse/field-order-preserved"
  (define result (test-parse "(selection Ordered from S :requires [:z :a :m :b])"))
  (check-true (surf-selection? result))
  (check-equal? (surf-selection-requires-paths result) '(#:z #:a #:m #:b)))

;; ========================================
;; Error cases
;; ========================================

(test-case "selection-parse/error-missing-from"
  (define result (test-parse "(selection Foo of Bar :requires [:x])"))
  (check-true (prologos-error? result)
              (format "Expected error, got ~v" result)))

(test-case "selection-parse/error-no-clauses"
  (define result (test-parse "(selection Foo from Bar)"))
  (check-true (prologos-error? result)
              (format "Expected error, got ~v" result)))

(test-case "selection-parse/error-too-few-args"
  (define result (test-parse "(selection Foo)"))
  (check-true (prologos-error? result)
              (format "Expected error, got ~v" result)))

(test-case "selection-parse/error-unknown-clause"
  (define result (test-parse "(selection Foo from Bar :blah [:x])"))
  (check-true (prologos-error? result)
              (format "Expected error, got ~v" result)))

(test-case "selection-parse/error-non-keyword-field"
  ;; 123 is not a keyword field path
  (define result (test-parse "(selection Foo from Bar :requires [123])"))
  (check-true (prologos-error? result)
              (format "Expected error, got ~v" result)))

(test-case "selection-parse/error-missing-vector"
  ;; :requires without a vector
  (define result (test-parse "(selection Foo from Bar :requires)"))
  (check-true (prologos-error? result)
              (format "Expected error, got ~v" result)))
