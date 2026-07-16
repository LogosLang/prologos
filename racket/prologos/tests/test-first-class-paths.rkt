#lang racket/base

;;;
;;; FIRST-CLASS PATHS — WS-mode regression tests (CIU Track 6)
;;;
;;; WS-syntax coverage for the path-selection surfaces: dot-access, #p(...) path
;;; literals, get-in / update-in, broadcast .*, and the `:key^alias` rename
;;; tokenizer. This file exists because the pre-existing test-path-expressions.rkt
;;; is sexp/parse-level only — which is why the .pnet gap (F2) and the WS ^-rename
;;; break (F3) went unnoticed. Tests are written in WS `.prologos` syntax (run-ws).
;;;
;;; NOTE: field-access values are currently typed `Open`; CIU Track 6 F1 (retire
;;; Open -> structural record typing) will change `1 : Open` to `1 : Int` — update
;;; the scalar-type assertions here when that lands.
;;;

(require rackunit
         racket/list
         racket/string
         racket/file
         racket/port
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

;; ---- Shared prelude fixture (loaded once) ----
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
    (process-string "(ns fcp-test :no-prelude)")
    (values (global-env-snapshot)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

;; ---- Run WS code via temp file against the shared env ----
(define (run-ws s)
  (define tmp (make-temporary-file "prologos-fcp-~a.prologos"))
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

;; One WS program: a shared record fixture, then the expressions under test.
;; Run once (fast); drop the `def` result and assert on the evals. Fixture is
;; :no-prelude (path surfaces are language-level) — the full prelude load is ~48s
;; under suite-worker contention; skipping it keeps this file ~4s.
;; (Broadcast .*field needs `'[…]` list literals = prelude; verified via probe,
;;  re-add here once WS-test prelude-load cost is addressed. CIU T6.)
(define evals
  (list-tail
   (run-ws
    (string-append
     "def m := {:a {:a1 1 :a2 2} :b {:b1 11}}\n"
     "m.a.a1\n"                             ; 0 — dot-access scalar leaf
     "m.a\n"                                ; 1 — dot-access sub-record
     "#p(a.a1)\n"                           ; 2 — path literal
     "get-in m #p(a.a1)\n"                  ; 3 — get-in via #p literal
     "update-in m #p(a.a1) [int+ _ 100]\n" ; 4 — update-in deep
     "get-in m :a^first\n"                  ; 5 — ^ rename tokenizes (F3)
     ;; ---- DYNAMIC paths (def-bound Path values → expr-update-in/expr-get-in
     ;; nodes; literal #p paths above desugar statically and never mint them).
     ;; Regression for the 2026-07-16 P6 value-loss fix: whnf arms + the
     ;; definitely-not-map? exemptions + nf spine normalization.
     "def pa := #p(a)\n"                                                   ; 6
     "def strip1 := [fn [sub : [Map Keyword Int]] [map-dissoc sub :a1]]\n" ; 7
     "def rr := [update-in m pa strip1]\n"                                 ; 8
     "[map-get rr :b]\n"                    ; 9 — sibling value (was none)
     "[map-get [update-in m pa strip1] :b]\n" ; 10 — inline composition (was none)
     "map-keys rr\n"                        ; 11 — spine normalized (was stuck)
     "map-size rr\n"                        ; 12 — (was stuck)
     "get-in rr pa\n"))                     ; 13 — dynamic get-in over the result
   1))
(define (R i) (list-ref evals i))

;; ========================================
;; Dot-access
;; ========================================

(test-case "ws: dot-access scalar leaf"
  (check-equal? (R 0) "1 : Int"))   ; CIU T6 F1a-s2: was "1 : Open" — records now project the observed type

(test-case "ws: dot-access sub-record contains its keys"
  (check-true (string-contains? (R 1) ":a1"))
  (check-true (string-contains? (R 1) ":a2")))

;; ========================================
;; #p(...) path literals + get-in / update-in
;; ========================================

(test-case "ws: #p(...) is a first-class Path value"
  (check-equal? (R 2) "#p(a.a1) : Path"))

(test-case "ws: get-in with a #p literal → scalar leaf"
  (check-equal? (R 3) "1 : Int"))   ; CIU T6 F1a-s2: was "1 : Open"

(test-case "ws: update-in deep sets the leaf"
  (check-true (string-contains? (R 4) "101")))

;; ========================================
;; Dynamic paths — P6 value-loss regression (2026-07-16)
;; map-get over a dynamic update-in/get-in result must yield the VALUE,
;; never degrade to none (definitely-not-map? exemption + whnf arms), and
;; map-keys/map-size over the result must reduce (nf spine normalization).
;; ========================================

(test-case "ws: map-get over def-bound dynamic update-in result — sibling value survives (was none)"
  (check-true (string-contains? (R 9) ":b1"))
  (check-false (string-contains? (R 9) "none")))

(test-case "ws: map-get over INLINE dynamic update-in result (the P6 #8 bug shape)"
  (check-true (string-contains? (R 10) ":b1"))
  (check-false (string-contains? (R 10) "none")))

(test-case "ws: map-keys over dynamic update-in result reduces (was stuck spine)"
  (check-true (string-contains? (R 11) ":a"))
  (check-true (string-contains? (R 11) ":b"))
  (check-false (string-contains? (R 11) "map-keys")))

(test-case "ws: map-size over dynamic update-in result reduces"
  (check-true (string-contains? (R 12) "2N")))

(test-case "ws: dynamic get-in over dynamic update-in result — updated sub-map"
  (check-true (string-contains? (R 13) ":a2"))
  (check-false (string-contains? (R 13) ":a1")))

;; ========================================
;; ^ rename tokenizes in WS (CIU Track 6 F3 regression)
;; ========================================

(test-case "ws: :key^alias rename tokenizes (no parse error)"
  (check-false (string-contains? (R 5) "expected keyword field path"))
  (check-true (string-contains? (R 5) ":a1")))
