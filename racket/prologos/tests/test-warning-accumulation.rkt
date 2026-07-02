#lang racket/base

;;;
;;; N6a regression tests — coercion-warning accumulation + spurious-warning lock-in.
;;;
;;; Root cause (N6a diagnosis, 2026-07-02): the whole-map warning-collection
;;; propagator folded over EVERY position in the PERSISTENT attribute map,
;;; harvesting :warnings facets deposited by ALL prior commands (facet values
;;; persist by design; P3 clears dependents only) and re-attaching them to
;;; every later result — with monotone growth over a session. Fixed by a
;;; scoped post-quiescence read (typing-propagators.rkt infer-on-network):
;;; warnings are extracted only at positions in the CURRENT command's expr
;;; tree. A second guard moves the on-network→imperative warning bridge into
;;; the success branch (fallback re-infers imperatively and emits its own).
;;;
;;; These tests MUST run through process-file — only that path initializes
;;; the persistent attribute-map cell (driver.rkt init-attribute-map-cell!),
;;; which is the leak's carrier; string paths use an ephemeral fallback.
;;;

(require rackunit
         racket/string
         racket/file
         racket/list
         "test-support.rkt"
         "../driver.rkt"
         "../macros.rkt"
         "../namespace.rkt"
         "../global-env.rkt"
         "../metavar-store.rkt"
         "../prelude.rkt"
         (only-in "../propagator.rkt" with-forked-network))

;; L3 runner: temp .prologos through process-file under fresh prelude registries
;; (mirrors test-support's run-ns-ws-last parameterization).
(define (run-file . lines)
  (define tmp (make-temporary-file "n6a-warn-~a.prologos"))
  (call-with-output-file tmp #:exists 'truncate/replace
    (lambda (out) (write-string (string-join (cons "ns t" lines) "\n") out)))
  (define results
    (parameterize ([current-file-module-network-ref (make-module-network)]
                   [current-ns-context #f]
                   [current-module-registry prelude-module-registry]
                   [current-lib-paths (list prelude-lib-dir)]
                   [current-preparse-registry prelude-preparse-registry]
                   [current-trait-registry prelude-trait-registry]
                   [current-impl-registry prelude-impl-registry]
                   [current-param-impl-registry prelude-param-impl-registry]
                   [current-persistent-registry-net-box prelude-persistent-registry-net-box]
                   [current-module-registry-cell-id #f]
                   [current-ns-context-cell-id #f])
      (with-forked-network current-prop-net-box
        (install-module-loader!)
        (process-file (path->string tmp)))))
  (delete-file tmp)
  results)

(define (warning-count r)
  (if (string? r) (length (regexp-match* #rx"warning:" r)) 0))

(define (warning-counts results) (map warning-count results))

;; ========================================
;; Bug B — accumulation regression
;; ========================================

;; NOTE (N6a values-only policy): warning-triggering commands use a BOUND
;; VALUE operand (def n : Int) — bare exact literals no longer warn, so a
;; literal form here would trivially pass with zero warnings everywhere.
;; The def contributes a "defined." result (count 0) at position 1.

(test-case "warn/no-accumulation: one float command, three exact commands"
  ;; Pre-fix: the eval-1 warning re-attached to every later result.
  (check-equal? (warning-counts
                 (run-file "def n : Int := 3"
                           "eval [+ n 1.5f64]"
                           "eval [+ 1 2]"
                           "eval [* 2/3 3/4]"
                           "eval [+ 1/2 1/4]"))
                '(0 1 0 0 0)))

(test-case "warn/no-growth: three float commands then one exact"
  ;; Pre-fix: monotone growth (with a one-command harvest lag).
  (check-equal? (warning-counts
                 (run-file "def n : Int := 3"
                           "eval [+ n 1.5f64]"
                           "eval [+ n 2.5f64]"
                           "eval [+ n 3.5f64]"
                           "eval [+ 1 2]"))
                '(0 1 1 1 0)))

(test-case "warn/own-warning-preserved: float command in a later file position"
  ;; Guards the harvest-lag class: the warning lands on ITS OWN command.
  (check-equal? (warning-counts
                 (run-file "def n : Int := 3"
                           "eval [+ 1 2]"
                           "eval [* 2/3 3/4]"
                           "eval [+ n 1.5f64]"
                           "eval [+ 1 2]"))
                '(0 0 0 1 0)))

;; ========================================
;; Bug A — spurious-warning lock-in (the owner's REPL transcript)
;; ========================================

(test-case "warn/fresh-exact-arith-is-silent: + 3.13 1.0 alone never warns"
  ;; N6b: decimals default Posit32 — both operands same family, no coercion at all
  (define rs (run-file "eval [+ 3.13 1.0]"))
  (check-equal? (warning-counts rs) '(0))
  (check-true (string-contains? (car rs) ": Posit32")))

;; ========================================
;; Values-only policy (D-N6.4c)
;; ========================================

(test-case "warn/literal-operand-silent: bare exact literal + float never warns"
  (check-equal? (warning-counts (run-file "eval [+ 3 1.5f64]")) '(0)))

;; ========================================
;; Single-emitter guard (on-network bridge only on success) + dedupe
;; ========================================

(test-case "warn/single-emission: exactly one warning line per distinct coercion"
  (define rs (run-file "def n : Int := 3"
                       "eval [+ n [from-integer Posit8 1]]"))
  (check-equal? (warning-counts rs) '(0 1)))
