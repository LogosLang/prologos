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

(test-case "let-p1/the still-broken form classes are parse errors, not raises"
  ;; P1 pinned FOUR broken classes; the sibling no-:= chain graduated to
  ;; WORKING at P2 and moved to the let-p2 pins below. Remaining: aligned
  ;; (unrecognized format — P3's target), fused (P4's target), top-level let
  ;; (permanent guided error). Each per-command; the file reaches the control.
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
    "let tl := 99\n"
    "def control := 7\n")))
  (check-equal? (length rs) 4 (format "expected 4 results, got: ~v" rs))
  (for ([r (in-list (take rs 3))] [i (in-naturals)])
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

;; ============================================================
;; P2 — sibling no-:= chains form one scope; the tree spine defers
;; ============================================================
;; Part 1: `extract-let-binding-tokens` synthesizes `:=` for the bodyless
;; no-:= shape, closing the normalize-vs-verbatim asymmetry with
;; `split-last-let` (which always synthesized). Part 2: the tree-parser's
;; let-chain arm DEFERS to preparse (a parse-error result, excluded from
;; tree-by-line) — single let implementation, per the driver's own
;; architecture comment.
;;
;; ⚠ Unspecced cases use CONCRETE ops (int+): generic `+` over an unannotated
;; param is the documented issue-#70 limitation, unrelated to let. An earlier
;; DEFERRED filing confused the two — its repro failed for the i70 reason, not
;; the spine. Tests here control for it.

(test-case "let-p2/sibling no-:= chain forms one scope (specced)"
  ;; THE form 3 pin: was `let :=: expected := or : after name x` (a whole-file
  ;; abort before P1, a per-command error after it).
  (define rs (run-file-ws (string-append
    "ns p2a\n"
    "spec f Int -> Int\n"
    "defn f [a]\n"
    "  let x 4\n"
    "  let y 5\n"
    "  let z [+ x y]\n"
    "    [+ a z]\n"
    "[f 1]\n")))
  (check-equal? (length rs) 2 (format "got: ~v" rs))
  (for ([r (in-list rs)]) (check-false (prologos-error? r) (format "~v" r)))
  (check-true (regexp-match? #rx"10" (format "~a" (second rs)))
              (format "expected 10, got: ~v" (second rs))))

(test-case "let-p2/mixed := and no-:= spellings in one chain (owner ruling 2)"
  (define rs (run-file-ws (string-append
    "ns p2b\n"
    "spec f Int -> Int\n"
    "defn f [a]\n"
    "  let x 4\n"
    "  let y := 5\n"
    "    [+ a [+ x y]]\n"
    "[f 1]\n")))
  (for ([r (in-list rs)]) (check-false (prologos-error? r) (format "~v" r)))
  (check-true (regexp-match? #rx"10" (format "~a" (second rs)))))

(test-case "let-p2/UNSPECCED defns: both chains work — the spines agree"
  ;; The tree spine used to win for unspecced forms with its own half-
  ;; implemented let-chain; it now defers, so preparse's output (the single
  ;; implementation) serves both regimes. Concrete ops per the i70 note above.
  (define rs (run-file-ws (string-append
    "ns p2c\n"
    "defn g [a]\n"
    "  let x := 4\n"
    "  let y := 5\n"
    "    [int+ a [int+ x y]]\n"
    "[g 1]\n"
    "defn h [a]\n"
    "  let x 4\n"
    "  let y 5\n"
    "    [int+ a [int+ x y]]\n"
    "[h 1]\n"
    "defn k [a]\n"
    "  let [x 5 y 6]\n"
    "    [int+ a [int+ x y]]\n"
    "[k 1]\n")))
  (check-equal? (length rs) 6 (format "got: ~v" rs))
  (for ([r (in-list rs)]) (check-false (prologos-error? r) (format "~v" r))))

(test-case "let-p2/a standalone bodiless let is STILL an error, with containment"
  ;; Drift risk 5: `(let x 4)` with no following body must not silently become
  ;; a binding of nothing. Per-command (P1), so neighbors report.
  (define rs (run-file-ws (string-append
    "ns p2d\n"
    "def before := 1\n"
    "spec f Int -> Int\n"
    "defn f [a]\n"
    "  let x 4\n"
    "def after := 2\n")))
  (check-equal? (length rs) 3 (format "got: ~v" rs))
  (check-false (prologos-error? (first rs)))
  (check-true (prologos-error? (second rs)))
  (check-false (prologos-error? (third rs))))

(test-case "let-p2/merge normalization is byte-transparent for := inputs"
  ;; Drift risk 1: the exact-output pins in test-defmacro cover preparse
  ;; expansion; this pins the MERGE layer directly for a := chain (must be
  ;; verbatim) vs a no-:= chain (synthesized).
  (check-equal?
   (merge-sibling-lets '((let a := 1) (let b := 2 (add a b))))
   '((let (a := 1 b := 2) (add a b))))
  (check-equal?
   (merge-sibling-lets '((let a 1) (let b 2 (add a b))))
   '((let (a := 1 b := 2) (add a b)))))

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
