#lang racket/base

;; test-low-pnet-ir.rkt — SH Track 2 Phase 2.A unit tests.
;;
;; Validates: data structures, parse, pretty-print, validator, and
;; the round-trip property (parse ∘ pp = id).

(require rackunit
         "../low-pnet-ir.rkt")

;; A canonical N0-style program: 1 domain, 1 cell, 1 write, 1 entry.
(define n0-sexp
  '(low-pnet
    :version (1 0)
    (domain-decl 0 int merge-int-monotone 0 never)
    (cell-decl   0 0 0)
    (write-decl  0 42 0)
    (entry-decl  0)))

;; A 1-propagator program: 2 inputs, 1 output, 1 fire-fn-tagged propagator.
(define one-prop-sexp
  '(low-pnet
    :version (1 0)
    (domain-decl 0 int merge-int-monotone 0 never)
    (cell-decl   0 0 0)
    (cell-decl   1 0 0)
    (cell-decl   2 0 0)
    (write-decl  0 1 0)
    (write-decl  1 2 0)
    (propagator-decl 0 (0 1) (2) int-add 0)
    (dep-decl    0 0 all)
    (dep-decl    0 1 all)
    (entry-decl  2)))

;; ============================================================
;; Parsing
;; ============================================================

(test-case "parse-low-pnet: minimal n0 program"
  (define p (parse-low-pnet n0-sexp))
  (check-true (low-pnet? p))
  (check-equal? (low-pnet-version p) '(1 0))
  (check-equal? (length (low-pnet-nodes p)) 4))

(test-case "parse-low-pnet: 1-propagator program"
  (define p (parse-low-pnet one-prop-sexp))
  (check-true (low-pnet? p))
  (check-equal? (length (low-pnet-nodes p)) 10))

(test-case "parse-low-pnet: missing :version uses default"
  (define p (parse-low-pnet '(low-pnet (entry-decl 0) (cell-decl 0 0 0) (domain-decl 0 x f 0 never))))
  (check-equal? (low-pnet-version p) LOW_PNET_FORMAT_VERSION))

(test-case "parse-low-pnet: rejects non-low-pnet head"
  (check-exn low-pnet-parse-error?
    (lambda () (parse-low-pnet '(other-form (entry-decl 0))))))

(test-case "parse-low-pnet: rejects unknown decl head"
  (check-exn low-pnet-parse-error?
    (lambda () (parse-low-pnet '(low-pnet (bogus-decl 1 2 3))))))

(test-case "parse-low-pnet: rejects non-symbol fire-fn-tag"
  (check-exn low-pnet-parse-error?
    (lambda () (parse-low-pnet
                '(low-pnet (propagator-decl 0 (0) (1) "not-a-symbol" 0))))))

(test-case "parse-low-pnet: rejects negative cell-id"
  (check-exn low-pnet-parse-error?
    (lambda () (parse-low-pnet '(low-pnet (cell-decl -1 0 0))))))

;; ============================================================
;; Pretty-printer
;; ============================================================

(test-case "pp-low-pnet: round-trips parse-low-pnet (n0)"
  (define p (parse-low-pnet n0-sexp))
  (check-equal? (pp-low-pnet p) n0-sexp))

(test-case "pp-low-pnet: round-trips parse-low-pnet (1-propagator)"
  (define p (parse-low-pnet one-prop-sexp))
  (check-equal? (pp-low-pnet p) one-prop-sexp))

(test-case "pp ∘ parse ∘ pp = pp (idempotent)"
  (define p1 (parse-low-pnet n0-sexp))
  (define s1 (pp-low-pnet p1))
  (define p2 (parse-low-pnet s1))
  (define s2 (pp-low-pnet p2))
  (check-equal? s1 s2))

;; ============================================================
;; Validator
;; ============================================================

(test-case "validate-low-pnet: accepts n0 program"
  (define p (parse-low-pnet n0-sexp))
  (check-true (validate-low-pnet p)))

(test-case "validate-low-pnet: accepts 1-propagator program"
  (define p (parse-low-pnet one-prop-sexp))
  (check-true (validate-low-pnet p)))

(test-case "validate-low-pnet: rejects duplicate cell-decl ids"
  (define p (parse-low-pnet
             '(low-pnet
               (domain-decl 0 int f 0 never)
               (cell-decl 0 0 0)
               (cell-decl 0 0 1)            ; duplicate id
               (entry-decl 0))))
  (check-exn low-pnet-validate-error?
    (lambda () (validate-low-pnet p))))

(test-case "validate-low-pnet: rejects unknown domain reference"
  (define p (parse-low-pnet
             '(low-pnet
               (cell-decl 0 99 0)            ; domain 99 doesn't exist
               (entry-decl 0))))
  (check-exn low-pnet-validate-error?
    (lambda () (validate-low-pnet p))))

(test-case "validate-low-pnet: rejects unknown cell ref in propagator"
  (define p (parse-low-pnet
             '(low-pnet
               (domain-decl 0 int f 0 never)
               (cell-decl 0 0 0)
               (propagator-decl 0 (0 99) (0) f 0)  ; cell 99 doesn't exist
               (entry-decl 0))))
  (check-exn low-pnet-validate-error?
    (lambda () (validate-low-pnet p))))

(test-case "validate-low-pnet: rejects missing entry-decl"
  (define p (parse-low-pnet
             '(low-pnet
               (domain-decl 0 int f 0 never)
               (cell-decl 0 0 0))))
  (check-exn low-pnet-validate-error?
    (lambda () (validate-low-pnet p))))

(test-case "validate-low-pnet: rejects multiple entry-decls"
  (define p (parse-low-pnet
             '(low-pnet
               (domain-decl 0 int f 0 never)
               (cell-decl 0 0 0)
               (entry-decl 0)
               (entry-decl 0))))
  (check-exn low-pnet-validate-error?
    (lambda () (validate-low-pnet p))))

(test-case "validate-low-pnet: rejects entry-decl with unknown cell"
  (define p (parse-low-pnet
             '(low-pnet
               (domain-decl 0 int f 0 never)
               (cell-decl 0 0 0)
               (entry-decl 99))))
  (check-exn low-pnet-validate-error?
    (lambda () (validate-low-pnet p))))

(test-case "validate-low-pnet: rejects out-of-order references"
  ;; cell-decl uses domain-id 0 but the domain-decl is declared after
  (define p (parse-low-pnet
             '(low-pnet
               (cell-decl 0 0 0)
               (domain-decl 0 int f 0 never)
               (entry-decl 0))))
  (check-exn low-pnet-validate-error?
    (lambda () (validate-low-pnet p))))

(test-case "validate-low-pnet: dep-decl with unknown prop-id"
  (define p (parse-low-pnet
             '(low-pnet
               (domain-decl 0 int f 0 never)
               (cell-decl 0 0 0)
               (dep-decl 99 0 all)
               (entry-decl 0))))
  (check-exn low-pnet-validate-error?
    (lambda () (validate-low-pnet p))))

;; ============================================================
;; Misc
;; ============================================================

(test-case "LOW_PNET_FORMAT_VERSION is (1 0)"
  (check-equal? LOW_PNET_FORMAT_VERSION '(1 0)))

(test-case "structures are introspectable"
  (define p (parse-low-pnet n0-sexp))
  (define cell0 (cadr (low-pnet-nodes p)))   ; second node is cell-decl 0
  (check-true (cell-decl? cell0))
  (check-equal? (cell-decl-id cell0) 0)
  (check-equal? (cell-decl-domain-id cell0) 0)
  (check-equal? (cell-decl-init-value cell0) 0))
