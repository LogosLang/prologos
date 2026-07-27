#lang racket/base

;;;
;;; CIU Track 6 F1a-s1 — the expr-Record / record-field carrier PIPELINE contract.
;;;
;;; Unit-level tests that the new structural-row TYPE node threads correctly through
;;; the core pipeline (display / shift / subst / nf / serialize / union-sort) and that
;;; the generic-walker audit (S2) + union canonicalization (S1) hold. These are
;;; Racket-level (the node is internal-only — nothing MINTS it until F1a-s2), so they
;;; guard the pipeline plumbing directly. Behavioral (.prologos-level) coverage of
;;; minting + projection lands with F1a-s2 in the acceptance file.
;;;

(require rackunit
         "../syntax.rkt"
         "../pretty-print.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         "../pnet-serialize.rkt"
         "../union-types.rkt"
         "../unify.rkt"
         "../trait-resolution.rkt"
         "../metavar-store.rkt")

(define (rec . flds)   ; flds = (label . type-expr) ...
  (expr-Record 'keyword
               (for/list ([f (in-list flds)])
                 (cons (car f) (record-field (cdr f) 'present)))
               'closed))

(define ab   (rec (cons 'a (expr-Int)) (cons 'b (expr-String))))
(define nest (rec (cons 'a (rec (cons 'a1 (expr-Int))))))

;; ---- display (pretty-print) ----
(test-case "pp: keyword record"
  (check-equal? (pp-expr ab '()) "{:a Int :b String}"))
(test-case "pp: nested record"
  (check-equal? (pp-expr nest '()) "{:a {:a1 Int}}"))
(test-case "pp: nat-domain tuple"
  (check-equal? (pp-expr (expr-Record 'nat
                          (list (cons 0 (record-field (expr-Int) 'present))
                                (cons 1 (record-field (expr-String) 'present))) 'closed) '())
                "⟨Int String⟩"))
(test-case "pp: dyn tail"
  (check-equal? (pp-expr (expr-Record 'keyword
                          (list (cons 'a (record-field (expr-Int) 'present))) 'dyn) '())
                "{:a Int | _}"))

;; ---- shift / subst / nf recurse into field TYPES only ----
(test-case "shift: identity on ground record"
  (check-equal? (shift 0 0 ab) ab))
(test-case "shift: recurses into a bvar field type"
  (define r (rec (cons 'a (expr-bvar 0))))
  (check-equal? (shift 1 0 r) (rec (cons 'a (expr-bvar 1)))))
(test-case "nf: normalizes field types (identity on ground)"
  (check-equal? (nf ab) ab))

;; ---- serialization round-trip (F2 vector-impostor guard: both structs registered) ----
(test-case "pnet: record round-trips equal?"
  (check-equal? (deep-serializable->struct (deep-struct->serializable ab)) ab))
(test-case "pnet: nested record round-trips"
  (check-equal? (deep-serializable->struct (deep-struct->serializable nest)) nest))

;; ---- union canonicalization (S1): records in unions are commutative + idempotent ----
(define r1 (rec (cons 'a (expr-Int))))
(define r2 (rec (cons 'b (expr-String))))
(test-case "S1: build-union-type commutative over records"
  (check-equal? (build-union-type (list r1 r2)) (build-union-type (list r2 r1))))
(test-case "S1: build-union-type idempotent over records"
  (check-equal? (build-union-type (list r1 r1)) r1))
(test-case "S1: union-sort-key deterministic + structure-sensitive"
  (check-equal? (union-sort-key r1) (union-sort-key (rec (cons 'a (expr-Int)))))
  (check-not-equal? (union-sort-key r1) (union-sort-key r2)))

;; ---- generic-walker audit (S2): metas inside the fields list are visible ----
(define mrec (rec (cons 'a (expr-meta 999 #f)) (cons 'b (expr-Int))))
(test-case "S2: occurs? sees a meta inside a field"
  (check-true (occurs? 999 mrec))
  (check-false (occurs? 998 mrec)))
(test-case "S2: ground-expr? — ground record #t, meta-bearing #f"
  (check-true  (ground-expr? ab))
  (check-false (ground-expr? mrec)))
(test-case "S2: collect-meta-ids finds a field-embedded meta"
  (check-true (and (memq 999 (collect-meta-ids mrec)) #t)))
