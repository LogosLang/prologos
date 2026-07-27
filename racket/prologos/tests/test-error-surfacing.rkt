#lang racket/base

;;;
;;; Tests for error surfacing — Numerics N6e-E5.2 (issue #69(b)).
;;;
;;; The driver's merge (merge-preparse-and-tree-parser) silently DROPPED any
;;; preparse ERROR surf: a mangled form vanished from process-file results
;;; with zero diagnostics — and the tree parser's successful recovery of that
;;; form was discarded with it (tree surfs only surface via the preparse
;;; spine). Sibling drops lived in form-cells.rkt (the L2 path) and a dead
;;; merge-cell-surfs-with-preparse (deleted).
;;;
;;; Post-fix: recovery-first — the tree parse is used when it exists for the
;;; errored source line; otherwise the error surf is KEPT and reported.
;;;

(require rackunit
         racket/list
         racket/file
         racket/string
         ;; NOTE: source-location.rkt defines the compiler's OWN `srcloc`
         ;; struct (shadowing racket/base's) — error srclocs are THAT struct,
         ;; so its accessors must be used, prefixed to avoid ambiguity.
         (prefix-in sl: "../source-location.rkt")
         "../driver.rkt"
         "../namespace.rkt"
         "../errors.rkt"
         "test-support.rkt")

;; process-file a fixture string under a fresh per-file mnr (isolation).
(define (run-file-fixture str)
  (define tmp (make-temporary-file "errsurf-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display str out)))
  (define result
    (parameterize ([current-file-module-network-ref (make-module-network)]
                   [current-ns-context #f])
      (process-file (path->string tmp))))
  (delete-file tmp)
  result)

;; The two commands E5.1's probes found silently swallowed: their `[fn [a b]
;; …]` spelling is INVALID (multi-param untyped fn is `[fn a b body]` — bare
;; params); the swallow hid the parse error entirely. Post-fix the wrong
;; spelling errors LOUDLY and the right spelling works.
(define results-fn
  (run-ns-ws-all (string-join
                  (list "ns e52c"
                        "eval [reduce [fn a b [+ a b]] 0 '[1 2 3]]"
                        "eval [zip-with [fn x y [+ x y]] '[1 2] '[10 20]]")
                  "\n")))

(test-case "e52/multi-param-fn-correct-spelling-works-under-hofs"
  ;; also exercises E5.1 R2-spine generalization: reduce's init solves ?B;
  ;; zip-with's two containers solve ?A/?B
  (check-equal? (format "~a" (list-ref results-fn 0)) "6 : Int")
  (check-equal? (format "~a" (list-ref results-fn 1))
                "'[11 22] : [prologos::data::list::List Int]"))

;; ========================================
;; E5.3 — op-spelling hints at the unbound-variable site
;; ========================================
;; Keywords with no value form (mod, quire, p*-if-nar) and the angle-bracket
;; comparison spellings get an actionable hint on the unbound error; ordinary
;; unbound names stay hint-free. (Bare lt/eq never reach the unbound site —
;; they resolve to String foreigns: the silent-shadow class, filed separately.)

(define results-hints
  (run-ns-ws-all (string-join
                  (list "ns e53"
                        "eval [reduce mod 0 '[5 3]]"
                        "eval [map le '[1 2]]"
                        "eval [map frobnicate '[1]]")
                  "\n")))

(test-case "e53/unbound-op-hints"
  (check-true (string-contains? (format "~a" (list-ref results-hints 0)) "[mod _ _]"))
  (check-true (string-contains? (format "~a" (list-ref results-hints 1)) "ord-le")))

(test-case "e53/no-hint-on-ordinary-unbound"
  (define s (format "~a" (list-ref results-hints 2)))
  (check-true (string-contains? s "Unbound variable"))
  (check-false (string-contains? s "hint:")))


;; ---- L3 process-file fixtures BELOW (they pollute the global context-cell —
;; the N3d lesson: L3 tests run LAST in a module) ----

(test-case "e52/mangled-form-errors-loudly-and-tail-survives"
  ;; Pre-fix: the mangled defn AND nothing else — it silently vanished,
  ;; results had 2 entries and no error. Post-fix: 3 entries, the middle a
  ;; parse-error, neighbors (incl. the TAIL) intact.
  (define results
    (run-file-fixture "ns e52a\ndef a := 1N\ndefn f [1] 1\ndef c := 3N\n"))
  (check-equal? (length results) 3)
  (check-false (prologos-error? (first results)))
  (check-true (prologos-error? (second results)))
  (check-true (string-contains? (format "~a" (second results)) "defn"))
  (check-false (prologos-error? (third results))))

(test-case "e52/error-carries-source-location"
  (define results
    (run-file-fixture "ns e52b\ndefn g [2] 2\n"))
  (check-equal? (length results) 1)
  (check-true (prologos-error? (first results)))
  ;; srcloc line 2 (the mangled defn's line) — the compiler's srcloc struct
  (define loc (prologos-error-srcloc (first results)))
  (check-equal? (sl:srcloc-line loc) 2))

(test-case "e52/multi-param-fn-wrong-spelling-errors-loudly"
  (define results
    (run-file-fixture
     "ns e52d\neval [reduce [fn [a b] [+ a b]] 0 '[1 2 3]]\n"))
  (check-equal? (length results) 1)
  (check-true (prologos-error? (first results)))
  (check-true (string-contains? (format "~a" (first results)) "binder")))
