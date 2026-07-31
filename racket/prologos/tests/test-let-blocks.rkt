#lang racket/base

;;;
;;; LET blocks track (docs/tracking/2026-07-31_LET_BLOCKS_DESIGN.md)
;;;
;;; P1: every `let` syntax failure is a PER-COMMAND parse error, never a
;;; whole-file abort. The 13 raise sites in the expand-let family convert to
;;; `($let-error "msg")` markers via one exn:let-syntax boundary; the parser's
;;; expression dispatch turns the marker into a parse-error VALUE at any depth.
;;;
;;; Grown by later phases: P2 sibling no-:=, P3 aligned blocks, P4 fused.
;;;

(require rackunit
         racket/file
         racket/list
         "test-support.rkt"
         "../errors.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../macros.rkt")

;; ---- Shared prelude fixture (once per file; the path-selection pattern) ----
(define-values (pre-global-env pre-ns-context pre-module-reg
                pre-trait-reg pre-impl-reg pre-param-impl-reg)
  (parameterize ([current-file-module-network-ref (make-module-network)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry])
    (install-module-loader!)
    (process-string "(ns let-blocks-pre)")
    (values (global-env-snapshot) (current-ns-context) (current-module-registry)
            (current-trait-registry) (current-impl-registry)
            (current-param-impl-registry))))

;; Level 3: a real .prologos FILE through process-file — the level where
;; whole-file aborts live (a raise kills every command; a parse-error value
;; kills one). String-level runs cannot pin containment.
(define (run-file-ws s)
  (define tmp (make-temporary-file "prologos-letblocks-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display s out)))
  (define result
    (parameterize ([current-file-module-network-ref
                    (module-network-add-import (make-module-network)
                                               (module-network-from-snapshot pre-global-env))]
                   [current-ns-context pre-ns-context]
                   [current-module-registry pre-module-reg]
                   [current-trait-registry pre-trait-reg]
                   [current-impl-registry pre-impl-reg]
                   [current-param-impl-registry pre-param-impl-reg])
      (process-file (path->string tmp))))
  (delete-file tmp)
  result)

;; ============================================================
;; P1 — containment: a bad let is ONE failed command, not a dead file
;; ============================================================

(test-case "let-p1/containment: commands before AND after a bad let still report"
  ;; The load-bearing pin. Before P1 the aligned form was a raw raise killing
  ;; the WHOLE file — even `before`, which precedes it, produced no output.
  (define rs (run-file-ws (string-append
    "ns c1\n"
    "def before := 1\n"
    "spec f Int -> Int\n"
    "defn f [a]\n"
    "  let x 4\n"
    "      y 5\n"
    "    [+ a [+ x y]]\n"
    "def after := 2\n")))
  (check-equal? (length rs) 3 (format "expected 3 results, got: ~v" rs))
  (check-false (prologos-error? (first rs)) "`before` must define")
  (check-true (prologos-error? (second rs)) "the bad let must error")
  (check-false (prologos-error? (third rs)) "`after` must define"))

(test-case "let-p1/all four broken-form classes are parse errors, not raises"
  ;; One file, all four raise classes the probes hit: aligned (unrecognized
  ;; format), fused (unrecognized format via :Int), sibling no-:= (the
  ;; parse-assign-bindings site), top-level let (the guided error). Each is a
  ;; per-command error and the file reaches the trailing control.
  (define rs (run-file-ws (string-append
    "ns c2\n"
    "spec f1 Int -> Int\n"
    "defn f1 [a]\n"
    "  let x 4\n"
    "      y 5\n"
    "    [+ a [+ x y]]\n"
    "spec f2 Int -> Int\n"
    "defn f2 [a]\n"
    "  let x:Int 4\n"
    "    [+ a x]\n"
    "spec f3 Int -> Int\n"
    "defn f3 [a]\n"
    "  let x 4\n"
    "  let y 5\n"
    "    [+ a [+ x y]]\n"
    "let tl := 99\n"
    "def control := 7\n")))
  (check-equal? (length rs) 5 (format "expected 5 results, got: ~v" rs))
  (for ([r (in-list (take rs 4))] [i (in-naturals)])
    (check-true (prologos-error? r) (format "result ~a must be an error, got: ~v" i r)))
  (check-false (prologos-error? (last rs)) "the trailing control must define"))

(test-case "let-p1/message text is preserved through the marker"
  ;; The messages predate P1 and are useful; the marker must not flatten them
  ;; into a generic string. Pin one per raise family.
  (define rs (run-file-ws (string-append
    "ns c3\n"
    "spec f Int -> Int\n"
    "defn f [a]\n"
    "  let x 4\n"
    "      y 5\n"
    "    [+ a [+ x y]]\n"
    "let tl := 99\n")))
  (check-equal? (length rs) 2)
  (check-true (regexp-match? #rx"unrecognized format"
                             (prologos-error-message (first rs)))
              (format "got: ~v" (prologos-error-message (first rs))))
  (check-true (regexp-match? #rx"not allowed at top level.*def"
                             (prologos-error-message (second rs)))
              (format "got: ~v" (prologos-error-message (second rs)))))

(test-case "let-p1/a bare $let-error marker with no args does not crash the parser"
  ;; The (pair? args) guard in the parser arm is LOAD-BEARING (the
  ;; $retired-selection precedent's comment records the failure mode: an
  ;; unguarded (car args) is itself a whole-file abort). A user can type the
  ;; marker head directly, so pin the guard.
  (define rs (run-file-ws "ns c4\ndef x := ($let-error)\ndef y := 3\n"))
  (check-equal? (length rs) 2 (format "expected 2 results, got: ~v" rs))
  (check-true (prologos-error? (first rs)))
  (check-false (prologos-error? (second rs)) "the file must continue"))

(test-case "let-p1/working let forms are untouched (control)"
  ;; The := chain and the nested shorthand still work through the same seam.
  (define rs (run-file-ws (string-append
    "ns c5\n"
    "spec g Int -> Int\n"
    "defn g [a]\n"
    "  let x := 4\n"
    "  let y := 5\n"
    "    [+ a [+ x y]]\n"
    "[g 1]\n"
    "spec h Int -> Int\n"
    "defn h [a]\n"
    "  let w 4\n"
    "    [+ a w]\n"
    "[h 1]\n")))
  (check-equal? (length rs) 4 (format "got: ~v" rs))
  (for ([r (in-list rs)])
    (check-false (prologos-error? r) (format "unexpected error: ~v" r))))
