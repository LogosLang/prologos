#lang racket/base

;;;
;;; CIU Track 6 F1a-s3 (B3) — Record-vs-Record unification in collections.
;;;
;;; Same-shape (same key-domain + label-set + tail) records with field types that
;;; DIFFER but UNIFY must decompose to per-field goals so field metas get solved —
;;; e.g. a list whose element records carry a polymorphic (meta-bearing) field.
;;; PRELUDE-LOADED (the '[…] list literal + none/some need the prelude), so this
;;; test cannot live in the :no-prelude acceptance file. Kept minimal to bound the
;;; prelude-load cost.
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../reduction.rkt"
         "../namespace.rkt"
         "../trait-resolution.rkt"
         "../parse-reader.rkt")

;; ---- Shared prelude fixture (loaded once) ----
(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-bundle-reg)
  (parameterize ([current-file-module-network-ref (make-module-network)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string "(ns test-record-collections)")
    (values (global-env-snapshot)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

(define (run-ws s)
  (parameterize ([current-file-module-network-ref (module-network-add-import (make-module-network) (module-network-from-snapshot shared-global-env))]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-bundle-registry shared-bundle-reg])
    (process-string-ws s)))

(define (run-ws-last s) (last (run-ws s)))
;; #t iff the last result is an error (clean type error, NOT a crash — a crash
;; would raise, failing the test outright).
(define (errored? s) (prologos-error? (run-ws-last s)))
(define (result-str s)
  (define r (run-ws-last s))
  (if (string? r) r (format "~a" r)))

;; ========================================
;; B3: same-shape records with a META-BEARING field unify (the field meta solves)
;; ========================================

(test-case "B3: same-label records with a polymorphic field unify (meta solved)"
  ;; {:a (Option ?m)} vs {:a (Option Int)} → per-field 'sub solves ?m := Int.
  ;; Pre-B3 this fell to conv-nf's equal? and failed (meta never solved).
  (define r (result-str "\nns t\n'[{:a none} {:a [some 1]}]\n"))
  (check-true (string-contains? r "List") (format "expected a List type, got: ~a" r))
  (check-true (string-contains? r "Option") (format "expected Option field, got: ~a" r))
  (check-true (string-contains? r "Int") (format "expected Int solved, got: ~a" r)))

;; ========================================
;; col-1: literal-extent homogeneity is UNIFICATION-based, not equal?-based
;; ========================================

(test-case "col-1: @[none [some 1]] collapses to PVec (Option Int)"
  ;; The literal-extent node unifies element types (rollback-probed; success
  ;; commits), so meta-bearing homogeneous literals collapse to PVec exactly as
  ;; the old meta-seeded chain did. An equal?-based homogeneity test would mint
  ;; a spurious tuple here ((Option ?m) is not equal? to (Option Int)).
  (define r (result-str "\nns t\n@[none [some 1]]\n"))
  (check-true (string-contains? r "PVec") (format "expected PVec collapse, got: ~a" r))
  (check-true (string-contains? r "Option") (format "~a" r))
  (check-true (string-contains? r "Int") (format "~a" r)))

;; ========================================
;; B3: same-shape-identical still works (was already ok via the equal? fast-path)
;; ========================================

(test-case "B3: same-label identical-type records still unify"
  (define r (result-str "\nns t\n'[{:a 1} {:a 2}]\n"))
  (check-true (string-contains? r "List"))
  (check-true (string-contains? r ":a Int")))

;; ========================================
;; B3: genuine mismatches stay CLEAN ERRORS (not a crash, not a wrong success)
;; ========================================

;; ========================================
;; F1a-col-2 (D15): heterogeneous '[…] literals are OBSERVED as 'nat rows
;; ========================================
;; These two flipped from clean-error pins (pre-col-2) to row successes: under
;; observational literal typing the elements are never pairwise-unified — the
;; literal's type is what was observed, per position.

(test-case "col-2: same-label DIFFERING types → observed row (was: clean error)"
  (define r (result-str "\nns t\n'[{:a 1} {:a \"x\"}]\n"))
  (check-true (string-contains? r "⟨") (format "expected a row, got: ~a" r))
  (check-true (string-contains? r "{:a Int}") (format "~a" r))
  (check-true (string-contains? r "{:a String}") (format "~a" r)))

(test-case "col-2: DIFFERENT-shape records → observed row (the named regression CLOSES)"
  (define r (result-str "\nns t\ndef xs := '[{:a 1} {:b 2}]\nxs[0].a\n"))
  (check-true (string-contains? r "1 : Int") (format "row projection failed: ~a" r)))

(test-case "col-2: scalar heterogeneous list → row; homogeneous list unchanged"
  (define r1 (result-str "\nns t\n'[1 \"a\"]\n"))
  (check-true (string-contains? r1 "⟨Int String⟩") (format "~a" r1))
  (define r2 (result-str "\nns t\n'[1 2 3]\n"))
  (check-true (string-contains? r2 "List Int") (format "~a" r2)))

(test-case "col-2: the Tuple→List α — row-list satisfies a (List (Map K V)) spec"
  (define r (result-str
             (string-append
              "\nns t\n"
              "spec idl (List (Map Keyword Int)) -> (List (Map Keyword Int))\n"
              "defn idl [ll] ll\n"
              "idl '[{:a 1} {:b 2}]\n")))
  (check-true (string-contains? r "List") (format "~a" r))
  (check-true (string-contains? r "Map Keyword Int") (format "~a" r)))

(test-case "col-2: generic fold over a ROW-typed list — type sound (value-stall = known v1 limit)"
  ;; length over a row-list types Nat; the VALUE may print as a stuck term when
  ;; implicit/dict resolution can't see a row instance head (S10 posture at the
  ;; list level; CIU T3/T5 turf). Escape hatch: pass through the α (a (List (Map …))
  ;; spec) first. Pin only the TYPE.
  (define r (result-str "\nns t\ndef xs := '[{:a 1} {:b 2}]\nlength xs\n"))
  (check-true (string-contains? r ": Nat") (format "~a" r)))
