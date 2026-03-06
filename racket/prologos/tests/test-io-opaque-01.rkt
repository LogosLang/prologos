#lang racket/base

;;;
;;; test-io-opaque-01.rkt — Opaque FFI value marshalling tests
;;;
;;; Phase IO-A1: Tests for expr-opaque struct and Opaque: type marshalling.
;;;

(require rackunit
         racket/port
         racket/string
         "../syntax.rkt"
         "../foreign.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         "../pretty-print.rkt")

;; ========================================
;; expr-opaque construction and predicates
;; ========================================

(test-case "opaque/construction"
  ;; expr-opaque wraps a Racket value with a type tag
  (define port (open-input-string "hello"))
  (define opq (expr-opaque port 'file-port))
  (check-true (expr-opaque? opq))
  (check-eq? (expr-opaque-value opq) port)
  (check-eq? (expr-opaque-tag opq) 'file-port)
  (close-input-port port))

(test-case "opaque/expr-predicate"
  ;; expr-opaque is recognized by the expr? predicate
  (check-true (expr? (expr-opaque 42 'test-tag))))

(test-case "opaque/different-tags"
  ;; Different tags produce distinct opaque wrappers
  (define opq1 (expr-opaque 'val1 'file-port))
  (define opq2 (expr-opaque 'val2 'db-conn))
  (check-eq? (expr-opaque-tag opq1) 'file-port)
  (check-eq? (expr-opaque-tag opq2) 'db-conn)
  (check-not-equal? (expr-opaque-tag opq1) (expr-opaque-tag opq2)))

;; ========================================
;; Marshalling round-trip
;; ========================================

(test-case "opaque/marshal-racket-to-prologos"
  ;; marshal-racket->prologos with Opaque: prefix creates expr-opaque
  (define port (open-input-string "test"))
  (define result (marshal-racket->prologos 'Opaque:file-port port))
  (check-true (expr-opaque? result))
  (check-eq? (expr-opaque-value result) port)
  (check-eq? (expr-opaque-tag result) 'file-port)
  (close-input-port port))

(test-case "opaque/marshal-prologos-to-racket"
  ;; marshal-prologos->racket with Opaque: prefix unwraps expr-opaque
  (define port (open-input-string "test"))
  (define opq (expr-opaque port 'file-port))
  (define result (marshal-prologos->racket 'Opaque:file-port opq))
  (check-eq? result port)
  (close-input-port port))

(test-case "opaque/marshal-round-trip"
  ;; Full round-trip: Racket value → Prologos → Racket
  (define port (open-input-string "round-trip"))
  (define prologos-val (marshal-racket->prologos 'Opaque:file-port port))
  (define racket-val (marshal-prologos->racket 'Opaque:file-port prologos-val))
  (check-eq? racket-val port)
  (close-input-port port))

(test-case "opaque/marshal-different-tags"
  ;; Opaque:db-conn and Opaque:file-port produce different tags
  (define result1 (marshal-racket->prologos 'Opaque:file-port "a-port"))
  (define result2 (marshal-racket->prologos 'Opaque:db-conn "a-conn"))
  (check-eq? (expr-opaque-tag result1) 'file-port)
  (check-eq? (expr-opaque-tag result2) 'db-conn))

;; ========================================
;; Pretty-printing
;; ========================================

(test-case "opaque/pretty-print"
  ;; pp-expr displays opaque values with their tag
  (define opq (expr-opaque #f 'file-port))
  (check-equal? (pp-expr opq '()) "#<opaque:file-port>"))

;; ========================================
;; Reduction (opaque values are self-values)
;; ========================================

(test-case "opaque/whnf-pass-through"
  ;; Opaque values are already in WHNF — whnf returns them unchanged
  (define opq (expr-opaque 42 'test-val))
  (check-equal? (whnf opq) opq))

(test-case "opaque/nf-pass-through"
  ;; Opaque values are already in NF — nf returns them unchanged
  (define opq (expr-opaque "hello" 'string-val))
  (check-equal? (nf opq) opq))

;; ========================================
;; Substitution (opaque values are pass-through)
;; ========================================

(test-case "opaque/shift-pass-through"
  ;; Opaque values have no bound variables — shift is identity
  (define opq (expr-opaque 99 'num-val))
  (check-equal? (shift 1 0 opq) opq))

(test-case "opaque/subst-pass-through"
  ;; Opaque values have no bound variables — subst is identity
  (define opq (expr-opaque "data" 'data-val))
  (check-equal? (subst 0 (expr-zero) opq) opq))

;; ========================================
;; Error preservation
;; ========================================

(test-case "opaque/error-on-unknown-type"
  ;; Non-opaque unknown types still error
  (check-exn exn:fail?
    (lambda () (marshal-prologos->racket 'UnknownType (expr-zero))))
  (check-exn exn:fail?
    (lambda () (marshal-racket->prologos 'UnknownType 42))))
