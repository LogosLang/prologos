#lang racket/base

;;;
;;; QTT union/meta fixes — CIU T6 F1a.2 p0.
;;;
;;; Two spurious-"Multiplicity violation" classes localized by the F1a.2
;;; grounding audit (both misreports from checkQ-top's generic reporter):
;;;   (1) inferQ had NO expr-meta arm — an unsolved meta in a type-argument
;;;       position (bare {}'s key-domain meta through map-empty) tu-errored.
;;;   (2) the union-EXPECTED arms in checkQ AND typing-core check only tried
;;;       the branches — a term whose inferred type IS the whole union (any
;;;       dynamic ⋃-fields/⋃-positions projection) failed both branch checks,
;;;       so every bare-union-typed def died. Fixed with a whole-union
;;;       conversion fallback after the (now both-rollback-wrapped) split.
;;; The class became reachable with the F1a record/tuple union-producing arms;
;;; type-check never re-checks an unannotated def against its inferred type,
;;; checkQ-top does — which is why only defs (not bare evals) were hit.
;;;

(require rackunit
         racket/list
         racket/string
         racket/file
         racket/runtime-path
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

(define-runtime-path lib-dir "../lib")

;; ---- Shared fixture (loaded once; :no-prelude) ----
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
    (process-string "(ns qtt-union-meta-test :no-prelude)")
    (values (global-env-snapshot)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

(define (run-ws s)
  (define tmp (make-temporary-file "prologos-qttum-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display s out)))
  (define result
    (parameterize ([current-file-module-network-ref (module-network-add-import (make-module-network) (module-network-from-snapshot shared-global-env))]
                   [current-ns-context shared-ns-context]
                   [current-module-registry shared-module-reg]
                   [current-lib-paths (list lib-dir)]
                   [current-preparse-registry (current-preparse-registry)]
                   [current-trait-registry shared-trait-reg]
                   [current-impl-registry shared-impl-reg]
                   [current-param-impl-registry shared-param-impl-reg]
                   [current-bundle-registry shared-bundle-reg])
      (process-file tmp)))
  (delete-file tmp)
  result)

(define evals
  (list-tail
   (run-ws
    (string-append
     "def tr := @[1 \"a\" true]\n"
     "def idx : Nat := 1N\n"
     "def u1 := [pvec-nth tr idx]\n"                       ; 1 — unannotated bare-union def
     "u1\n"                                                ; 2
     "def a1 : <Bool | Int | String> := [pvec-nth tr idx]\n" ; 3 — annotated (check path)
     "def b1 : <Int | String> := 1\n"                      ; 4 — single-branch preserved
     "def kw := :a\n"
     "def g1 := [map-get {:a 1 :b \"s\"} kw]\n"            ; 6 — heterogeneous dyn-key (bug 2 repro)
     "g1\n"                                                ; 7
     "def hg := [map-get {:a 1 :b 2} kw]\n"                ; 8 — homogeneous sibling (always passed)
     "def m0 := {}\n"))                                    ; 9 — bare {} (bug 1 repro)
   1))
(define (R i) (list-ref evals i))
(define (S i) (let ([r (R i)]) (if (string? r) r (format "~a" r))))

(test-case "unannotated bare-union def type-checks (was: Multiplicity violation)"
  (check-true (string-contains? (S 1) "u1") (S 1))
  (check-equal? (R 2) "\"a\" : Bool | Int | String"))

(test-case "annotated bare-union def type-checks (typing-core check union arm)"
  (check-true (string-contains? (S 3) "a1") (S 3)))

(test-case "single-branch union check still works (branch split preserved)"
  (check-true (string-contains? (S 4) "b1") (S 4)))

(test-case "heterogeneous-record dynamic-key get def (was: Multiplicity violation)"
  (check-true (string-contains? (S 6) "g1") (S 6))
  (check-equal? (R 7) "1 : Int | String"))

(test-case "homogeneous sibling unchanged"
  (check-true (string-contains? (S 8) ": Int") (S 8)))

(test-case "bare {} def type-checks (was: Multiplicity violation; inferQ expr-meta arm)"
  ;; Displays the unsolved key-domain meta + Open today (D19/Q4 posture);
  ;; F1a.2 p1b (D17) flips this to the keyword-committed empty dyn row.
  (check-true (string-contains? (S 9) "m0") (S 9))
  (check-false (prologos-error? (R 9))))
