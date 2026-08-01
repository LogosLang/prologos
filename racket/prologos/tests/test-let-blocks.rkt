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
         "../macros.rkt"
         "../reader-forms.rkt")  ;; P4: split-glued-name-datum unit pins

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
  ;; The load-bearing pin: a broken let is ONE failed command. (Before P1 a
  ;; bad let was a raw raise killing the WHOLE file.) Exemplar history: aligned
  ;; (graduated P3) → fused (graduated P4) → CHAINED annotation, which is a
  ;; PERMANENT reject (reserve for UCS) — the flip-with-the-feature pattern
  ;; ends here.
  (define rs (run-file-ws (string-append
    "ns c1\n"
    "def before := 1\n"
    "spec f Int -> Int\n"
    "defn f [a]\n"
    "  let x:A:B 4\n"
    "    [+ a x]\n"
    "def after := 2\n")))
  (check-equal? (length rs) 3 (format "expected 3 results, got: ~v" rs))
  (check-false (prologos-error? (first rs)) "`before` must define")
  (check-true (prologos-error? (second rs)) "the bad let must error")
  (check-false (prologos-error? (third rs)) "`after` must define"))

(test-case "let-p1/the still-broken form classes are parse errors, not raises"
  ;; P1 pinned FOUR broken classes; all four graduated (P2 sibling no-:=,
  ;; P3 aligned, P4 fused). What remains is PERMANENT: the chained annotation
  ;; (reserve for UCS) and top-level let (the guided error). Per-command; the
  ;; file reaches the control.
  (define rs (run-file-ws (string-append
    "ns c2\n"
    "spec f2 Int -> Int\n"
    "defn f2 [a]\n"
    "  let x:A:B 4\n"
    "    [+ a x]\n"
    "let tl := 99\n"
    "def control := 7\n")))
  (check-equal? (length rs) 3 (format "expected 3 results, got: ~v" rs))
  ;; result 0 — the CHAINED annotation `x:A:B` — is the one permanent reject
  ;; here (reserved for UCS).
  (check-true (prologos-error? (first rs))
              (format "chained annotation must still error, got: ~v" (first rs)))
  ;; result 1 — `let tl := 99` — was the "top-level let" guided error until the
  ;; owner ruling of 2026-07-31 made a bodyless let legal everywhere. It is now
  ;; a no-op evaluating to its bound value; the CONTAINMENT this case exists to
  ;; pin is unchanged, and result 2 still defines.
  (check-false (prologos-error? (second rs))
               (format "a bodyless top-level let is legal now, got: ~v" (second rs)))
  (check-false (prologos-error? (last rs)) "the trailing control must define"))

(test-case "let-p1/message text is preserved through the marker"
  ;; The messages predate P1 and are useful; the marker must not flatten them
  ;; into a generic string. Pin one per raise family.
  ;; ⚠ SUPERSEDED IN PART (owner ruling 2026-07-31, top-level `let`): a BODYLESS
  ;; let is now LEGAL everywhere — "it shouldn't be an error or invalid, either,
  ;; nor even a warning per se" — so the second half of this case, which pinned
  ;; `let tl := 99` as "not allowed at top level", now pins the opposite: it is
  ;; a no-op evaluating to its bound value. The `defn f [a] / let x 4` half is
  ;; ALSO no longer an error for the same reason (the bodyless let is the whole
  ;; body). What survives is the shape of the case: two forms, two results,
  ;; per-command, file continues.
  (define rs (run-file-ws (string-append
    "ns c3\n"
    "spec f Int -> Int\n"
    "defn f [a]\n"
    "  let x 4\n"
    "let tl := 99\n")))
  (check-equal? (length rs) 2 (format "got: ~v" rs))
  (check-false (prologos-error? (second rs))
               (format "a bodyless top-level let is legal now, got: ~v" (second rs)))
  (check-true (regexp-match? #rx"99" (format "~a" (second rs)))
              (format "…and evaluates to its bound value, got: ~v" (second rs))))

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

(test-case "let-p2/a standalone bodiless let is LEGAL (2026-07-31 ruling), neighbours unaffected"
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
  (check-false (prologos-error? (first rs)) "`before` defines")
  ;; SUPERSEDED (owner ruling 2026-07-31): a standalone bodiless let is no
  ;; longer an error — here it IS the whole `defn` body, and desugars to
  ;; `((fn (x : _) x) 4)`. The neighbours-still-report property this case was
  ;; written for is what remains, and it still holds.
  (check-false (prologos-error? (second rs))
               (format "a bodiless let body is legal now, got: ~v" (second rs)))
  (check-false (prologos-error? (third rs)) "`after` defines"))

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

;; ============================================================
;; P3 — aligned let blocks: strict column discipline (owner ruling 1)
;; ============================================================
;; The reader-layer transform (parse-reader.rkt § LET P3) consumes columns
;; BEFORE syntax->datum erases them, emitting ($let-block …) for valid blocks
;; and P1's $let-error marker (guided, columns named) for violations.

(test-case "let-p3/aligned block, all three spellings + typed + bare-token body"
  (define rs (run-file-ws (string-append
    "ns p3a\n"
    "spec f1 Int -> Int\n"
    "defn f1 [a]\n"
    "  let x 4\n"
    "      y 5\n"
    "      z [+ x y]\n"
    "    [+ a z]\n"
    "[f1 1]\n"
    "spec f2 Int -> Int\n"
    "defn f2 [a]\n"
    "  let x := 4\n"
    "      y := 5\n"
    "    [+ a [+ x y]]\n"
    "[f2 1]\n"
    "spec f3 Int -> Int\n"
    "defn f3 [a]\n"
    "  let x 4\n"
    "      y := 5\n"
    "    [+ a [+ x y]]\n"
    "[f3 1]\n"
    "spec f4 Int -> Int\n"
    "defn f4 [a]\n"
    "  let x : Int := 4\n"
    "      y 5\n"
    "    [+ a [+ x y]]\n"
    "[f4 1]\n"
    "spec f5 Int -> Int\n"
    "defn f5 [a]\n"
    "  let x 4\n"
    "      z [+ x 1]\n"
    "    z\n"
    "[f5 9]\n")))
  (for ([r (in-list rs)]) (check-false (prologos-error? r) (format "~v" r)))
  (check-equal? (length rs) 10))

(test-case "let-p3/STRICT: forgot-the-body gives the guided error, columns named"
  (define rs (run-file-ws (string-append
    "ns p3b\n"
    "spec f Int -> Int\n"
    "defn f [a]\n"
    "  let x 4\n"
    "      y 5\n"
    "      z [+ x y]\n"
    "def control := 7\n")))
  (check-equal? (length rs) 2 (format "got: ~v" rs))
  (check-true (prologos-error? (first rs)))
  (check-true (regexp-match? #rx"no body.*column"
                             (prologos-error-message (first rs)))
              (format "got: ~v" (prologos-error-message (first rs))))
  (check-false (prologos-error? (second rs)) "containment"))

(test-case "let-p3/STRICT: a trailing BINDING mistaken for a body is refused"
  ;; The P0-flagged top-level-guard bypass, closed structurally at the funnel:
  ;; `:=` is reserved, so a binding-shaped body can only be a mistake.
  (define rs (run-file-ws (string-append
    "ns p3c\n"
    "def before := 1\n"
    "let tl := 4\n"
    "    um := 5\n"
    "def after := 2\n")))
  (check-equal? (length rs) 3 (format "got: ~v" rs))
  (check-true (prologos-error? (second rs)))
  (check-true (regexp-match? #rx"BINDING"
                             (prologos-error-message (second rs)))
              (format "got: ~v" (prologos-error-message (second rs))))
  (check-false (prologos-error? (third rs)) "containment"))

(test-case "let-p3/controls: nested, := chain, and pipe-bodied lets untouched"
  ;; The activation gate's byte-transparency pins: 0/1-continuation forms and
  ;; pipe-headed continuations (a match body) must never be captured.
  (define rs (run-file-ws (string-append
    "ns p3d\n"
    "spec g1 Int -> Int\n"
    "defn g1 [a]\n"
    "  let x 4\n"
    "    let y 5\n"
    "      [+ x [+ a y]]\n"
    "[g1 1]\n"
    "spec g2 Int -> Int\n"
    "defn g2 [n]\n"
    "  let k := [+ n 1]\n"
    "    match k\n"
    "      | 0 -> 0\n"
    "      | m -> m\n"
    "[g2 3]\n")))
  (for ([r (in-list rs)]) (check-false (prologos-error? r) (format "~v" r))))

(test-case "let-p3/an aligned let as the LAST sibling merges (split-last-let arm)"
  (define rs (run-file-ws (string-append
    "ns p3e\n"
    "spec f Int -> Int\n"
    "defn f [a]\n"
    "  let w := 100\n"
    "  let x 4\n"
    "      y 5\n"
    "    [+ a [+ w [+ x y]]]\n"
    "[f 1]\n")))
  (for ([r (in-list rs)]) (check-false (prologos-error? r) (format "~v" r)))
  (check-true (regexp-match? #rx"110" (format "~a" (second rs)))
              (format "got: ~v" (second rs))))

(test-case "let-p3/aligned block under a def := RHS"
  (define rs (run-file-ws (string-append
    "ns p3f\n"
    "def d1 :=\n"
    "  let p 6\n"
    "      q [+ p 1]\n"
    "    [+ p q]\n"
    "d1\n")))
  (for ([r (in-list rs)]) (check-false (prologos-error? r) (format "~v" r)))
  (check-true (regexp-match? #rx"13" (format "~a" (second rs)))))

;; ============================================================
;; P4 — fused var:Type binders + multi-line values
;; ============================================================
;; The fused primitives moved to reader-forms.rkt (parser.rkt re-imports —
;; ONE definition; macros.rkt could never import them from parser.rkt, the
;; cycle). fused-type-annot? was HARDENED there: it accepted the bare `:` and
;; `:=` (neither multiplicity-shaped), which made parse-assign-bindings's
;; rewrite arm loop forever — caught live as a preparse hang.

(test-case "let-p4/fused binders in every block form"
  (define rs (run-file-ws (string-append
    "ns p4a\n"
    "spec e1 Int -> Int\n"
    "defn e1 [a]\n"
    "  let x:Int 4\n"
    "      y:Int 5\n"
    "    [+ a [+ x y]]\n"
    "[e1 1]\n"
    "spec e2 Int -> Int\n"
    "defn e2 [a]\n"
    "  let x:Int := 4\n"
    "    [+ a x]\n"
    "[e2 1]\n"
    "spec e3 Int -> Int\n"
    "defn e3 [a]\n"
    "  let x:Int 4\n"
    "  let y:Int := 5\n"
    "    [+ a [+ x y]]\n"
    "[e3 1]\n"
    "spec e4 Int -> Int\n"
    "defn e4 [a]\n"
    "  let x:Int 4\n"
    "    [+ a x]\n"
    "[e4 1]\n")))
  (for ([r (in-list rs)]) (check-false (prologos-error? r) (format "~v" r)))
  (check-equal? (length rs) 8))

(test-case "let-p4/the fused annotation is REAL — a wrong type errors"
  (define rs (run-file-ws (string-append
    "ns p4b\n"
    "spec f Int -> Int\n"
    "defn f [a]\n"
    "  let x:String 4\n"
    "    [+ a x]\n"
    "def control := 7\n")))
  (check-equal? (length rs) 2)
  (check-true (prologos-error? (first rs)) (format "~v" (first rs)))
  (check-false (prologos-error? (second rs)) "containment"))

(test-case "let-p4/multiplicity annotations and keyword values do NOT fuse"
  ;; :0-style tokens are multiplicities (digit-headed, structural exclusion);
  ;; a keyword VALUE after := is data, not an annotation.
  (define rs (run-file-ws (string-append
    "ns p4c\n"
    "def m4 := [fn [x :0 Int] 7]\n"
    "spec m5 Int -> Keyword\n"
    "defn m5 [a]\n"
    "  let k := :foo\n"
    "    k\n"
    "[m5 1]\n")))
  (for ([r (in-list rs)]) (check-false (prologos-error? r) (format "~v" r))))

(test-case "let-p4/sexp glued x:Int splits (ruling 3); module paths never split"
  ;; sexp mode: `(let x:Int 4 body)` used to bind a variable literally named
  ;; |x:Int|. It is now the annotated binding, matching defn's sexp path.
  ;; run through THIS file's fixture (mixing test-support's run-ns-* fixture
  ;; with ours trips the two-context class: net-cell-reset unknown cell).
  (define r
    (last
     (parameterize ([current-file-module-network-ref
                     (module-network-add-import (make-module-network)
                                                (module-network-from-snapshot pre-global-env))]
                    [current-ns-context pre-ns-context]
                    [current-module-registry pre-module-reg]
                    [current-trait-registry pre-trait-reg]
                    [current-impl-registry pre-impl-reg]
                    [current-param-impl-registry pre-param-impl-reg])
       (process-string "(ns p4d)\n(def g (fn (a : Int) (let x:Int (suc zero) x)))"))))
  (check-false (prologos-error? r) (format "~v" r))
  ;; the datum-level splitter: module paths (empty segments) pass through
  (define-values (n1 t1 e1) (split-glued-name-datum 'x:Int))
  (check-equal? (list n1 t1 e1) '(x Int #f))
  (define-values (n2 t2 e2) (split-glued-name-datum 'str::length))
  (check-equal? (list n2 t2 e2) '(str::length #f #f))
  (define-values (n3 t3 e3) (split-glued-name-datum 'x:A:B))
  (check-true (string? e3) "chained must reject"))

(test-case "let-p4/multi-line values — the absorb path (bracket ends the extent)"
  ;; A multi-line bracket in the head binding's value ends the let's form
  ;; extent at the reader; the continuation lines land as SIBLINGS and are
  ;; absorbed back. Without the absorb pass this silently applied y to 5.
  (define rs (run-file-ws (string-append
    "ns p4e\n"
    "spec m1 Int -> Int\n"
    "defn m1 [a]\n"
    "  let x [+ 1\n"
    "         3]\n"
    "      y 5\n"
    "    [+ a [+ x y]]\n"
    "[m1 1]\n")))
  (for ([r (in-list rs)]) (check-false (prologos-error? r) (format "~v" r)))
  (check-true (regexp-match? #rx"10" (format "~a" (second rs)))))

(test-case "let-p4/multi-line values — an ANNOTATED match value works end-to-end"
  ;; The deeper-than-binding-col fold puts a multi-line match INSIDE the
  ;; binding's value. Annotated, it checks (check-mode reaches check-reduce);
  ;; UNANNOTATED it still hits the documented QTT infer-position debt
  ;; (generic "Multiplicity violation") — the boundary is typing-side, not
  ;; layout-side, and is tracked in the QTT close notes.
  (define rs (run-file-ws (string-append
    "ns p4f\n"
    "spec m3 Int -> Int\n"
    "defn m3 [a]\n"
    "  let k : Int := match a\n"
    "                   | 1 -> 10\n"
    "                   | m -> m\n"
    "      j 5\n"
    "    [+ a [+ k j]]\n"
    "[m3 1]\n")))
  (for ([r (in-list rs)]) (check-false (prologos-error? r) (format "~v" r)))
  (check-true (regexp-match? #rx"16" (format "~a" (second rs)))
              (format "got: ~v" (second rs))))

(test-case "let-p4/chained fused annotation rejects with guidance"
  (define rs (run-file-ws (string-append
    "ns p4g\n"
    "spec f Int -> Int\n"
    "defn f [a]\n"
    "  let x:A:B 4\n"
    "    [+ a x]\n"
    "def control := 7\n")))
  (check-equal? (length rs) 2)
  (check-true (prologos-error? (first rs)))
  (check-false (prologos-error? (second rs)) "containment"))

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

;; ============================================================
;; LET × marker-channel contract (2026-07-31, found while grounding top-level
;; `let`). A let-block LAYOUT error inside a TOP-LEVEL let-headed form took the
;; WHOLE FILE down with a Racket `in-list: contract violation` instead of
;; producing the per-command error the `$let-error` marker channel exists for.
;;
;; Cause: `transform-let-blocks-elems` is documented to return an ELEMENT LIST,
;; and `tree-node->stx-elements` feeds its result straight to
;; `maybe-rewrite-infix-eq-stx` (`(in-list elems)`) — but `classify-let-block`'s
;; FAIL path returns `let-block-error`'s value, a SYNTAX OBJECT wrapping
;; `($let-error "msg")`. Verified PRE-EXISTING by neutralising the P2 goal-rhs
;; additions and reproducing the identical crash at base shape.
;;
;; These use run-file-ws deliberately: per this file's own note, a string-level
;; run cannot pin containment — only a real file can show that ONE command died
;; and the rest survived.
;; ============================================================

(test-case "let-marker/a top-level let-block LAYOUT error is contained, not a file abort"
  (define rs (run-file-ws (string-append
    "ns lbc\n"
    "def before := 1\n"
    "let z := 100\n"
    "  let p := 1\n"
    "  let q := 2\n"
    "    [+ z [+ p q]]\n"
    "def after := 2\n")))
  ;; 3 results: `before`, the ONE erroring let form (its nested lines are part of
  ;; the same command), `after`. Before the repair there were ZERO — the read
  ;; raised and the file produced nothing.
  (check-equal? (length rs) 3 (format "expected 3 results (no abort), got: ~v" rs))
  (check-false (prologos-error? (first rs))  "`before` must define")
  (check-true  (prologos-error? (second rs)) "the mis-laid-out let must ERROR")
  (check-false (prologos-error? (third rs))  "`after` must still define")
  (check-true  (regexp-match? #rx"let block"
                              (prologos-error-message (second rs)))
               (format "expected the guided let-block message, got: ~v" (second rs))))

;; ============================================================
;; TOP-LEVEL `let` (owner ruling, 2026-07-31)
;;
;;   "The scope of a top-level `let` ceases at the beginning of the next
;;    toplevel form. It's really only intended for interactive use. A program
;;    with a toplevel let would be a bit odd, and wouldn't 'do' anything, but it
;;    shouldn't be an error or invalid, either, nor even a warning per se. The
;;    let also doesn't bind for the whole file, only the limited, local scope.
;;    The real use-case is interactively building up some computation, then
;;    being able to wrap it in a `defn` afterwards as a form of iterative
;;    design."
;; ============================================================

(test-case "let-tl/THE USE CASE: a top-level sibling chain merges into one scope"
  ;; `merge-sibling-lets` ran only from preparse-expand-subforms — over the
  ;; SUBFORMS of an enclosing form — so top-level chains never merged. This is
  ;; the shape the feature exists for, and in the REPL it is a single
  ;; blank-line-terminated submission.
  (define rs (run-file-ws (string-append
    "ns tl1\n"
    "let a := 4\n"
    "let b := 5\n"
    "let c := [+ a b]\n"
    "  [* c 2]\n")))
  (check-equal? (length rs) 1 (format "the chain must be ONE form, got: ~v" rs))
  (check-true (regexp-match? #rx"18" (format "~a" (first rs))) (format "got: ~v" (first rs))))

(test-case "let-tl/scope ends at the next top-level form — no leak"
  (define rs (run-file-ws (string-append
    "ns tl2\n"
    "let a := 4\n"
    "a\n")))
  (check-equal? (length rs) 2 (format "got: ~v" rs))
  (check-false (prologos-error? (first rs)) "the bodyless let is legal")
  (check-true (prologos-error? (second rs))
              (format "`a` must NOT leak past the form, got: ~v" (second rs))))

(test-case "let-tl/all SIX bodyless spellings are legal and evaluate to the bound value"
  ;; The retired guard covered ONE of these. Two of the rest — the fused and
  ;; angle annotations — were SILENT WRONG ANSWERS (see the next case).
  (define rs (run-file-ws (string-append
    "ns tl3\n"
    "let s1 := 5\n"        ;; :=
    "let s2 7\n"           ;; bare
    "let s3:Int 5\n"       ;; fused
    "let s4 <Int> 5\n"     ;; angle
    "let s5 : Int := 5\n"  ;; spaced
    "let [s6 := 3]\n")))   ;; bracket
  (check-equal? (length rs) 6 (format "got: ~v" rs))
  (for ([r (in-list rs)] [i (in-naturals)])
    (check-false (prologos-error? r) (format "spelling ~a must be legal, got: ~v" i r))))

(test-case "let-tl/the fused + angle annotations are ENFORCED, not discarded"
  ;; THE SILENT-WRONG PIN. `let x:Int 5` used to print `5 : Int` with zero
  ;; errors while binding `x` to the DATUM `:Int` and using the value as the
  ;; body — so the annotation was silently dropped and the same number came
  ;; back. Printing the right number is therefore NOT evidence; the type must
  ;; actually reject a bad value.
  (define ok (run-file-ws (string-append
    "ns tl4\n" "let f1:Int 5\n" "  [int+ f1 1]\n")))
  (check-false (prologos-error? (first ok)) (format "got: ~v" (first ok)))
  (check-true (regexp-match? #rx"6" (format "~a" (first ok))) "the fused binding is usable")
  (define bad (run-file-ws (string-append "ns tl5\n" "let b1:Int \"hi\"\n")))
  (check-true (prologos-error? (first bad))
              (format "a fused annotation must REJECT a mismatched value, got: ~v" (first bad)))
  (define badang (run-file-ws (string-append "ns tl6\n" "let b2 <Int> \"hi\"\n")))
  (check-true (prologos-error? (first badang))
              (format "an angle annotation must REJECT a mismatched value, got: ~v" (first badang))))

(test-case "let-tl/the top-level merge never swallows a following DECLARATION"
  ;; At subform level `merge-sibling-lets` absorbs a following expression as the
  ;; body. At top level it must NOT: per the ruling the next top-level form ends
  ;; the scope, and it may be a `def`/`defn`/`data`, which is not an expression.
  (define rs (run-file-ws (string-append
    "ns tl7\n"
    "let p := 1\n"
    "let q := 2\n"
    "def d := 5\n"
    "d\n")))
  (check-equal? (length rs) 4 (format "the lets must stay separate no-ops, got: ~v" rs))
  (for ([r (in-list rs)]) (check-false (prologos-error? r) (format "got: ~v" r)))
  (check-true (regexp-match? #rx"5" (format "~a" (last rs)))))

(test-case "let-tl/a bodyless let does not disturb its neighbours' syntax properties"
  ;; The merge pass converts syntax→datum→syntax for a merged run only, and is
  ;; eq?-preserving otherwise. If it round-tripped every form it would drop
  ;; 'prologos-paren-origin / 'prologos-defrhs-command and silently break POL.9b
  ;; (`def x := (goal …)` ≡ `:= solve (…)`) — which is exactly the property the
  ;; SolveCarrier P2 sentinel depends on.
  (define rs (run-file-ws (string-append
    "ns tl8\n"
    "defr fc [?f ?c]\n  || \"apple\" \"red\"\n     \"cherry\" \"red\"\n"
    "let noise := 1\n"
    "def blues := (fc f \"red\")\n")))
  (check-false (prologos-error? (last rs)) (format "got: ~v" (last rs)))
  (check-true (regexp-match? #rx"PVec" (format "~a" (last rs)))
              (format "the implicit solve must still fire, got: ~v" (last rs))))

(test-case "let-tl/a chain merges REGARDLESS of what precedes it"
  ;; REGRESSION PIN. The first cut of the top-level merge tested the whole
  ;; MAXIMAL RUN of consecutive lets — "are all but the last bodyless?" — so a
  ;; single COMPLETE let sitting in front of a chain poisoned it: the run was
  ;; rejected wholesale and nothing merged. The run is now SEGMENTED into units
  ;; (bodyless* followed by one with-a-body), so a complete let simply forms its
  ;; own unit and the chain behind it merges normally.
  ;;
  ;; This escaped the acceptance file purely by POSITION — §A's chain sits first
  ;; in that file. It surfaced only when the same chain was written after other
  ;; material. "The fixture passes" is a claim about the fixture's SHAPE as much
  ;; as about the code.
  (define (chain-after prefix)
    (run-file-ws (string-append
      "ns tlseg\n" prefix
      "let a := 4\n"
      "let b := 5\n"
      "let c := [+ a b]\n"
      "  [* c 2]\n")))
  (define (last-is-18? rs)
    (and (not (prologos-error? (last rs)))
         (regexp-match? #rx"18" (format "~a" (last rs)))))
  ;; the chain first — the shape the acceptance file happens to use
  (check-true (last-is-18? (chain-after "")) "chain alone")
  ;; …after a declaration
  (check-true (last-is-18? (chain-after "def z := 1\n")) "after a def")
  ;; …after a bare expression
  (check-true (last-is-18? (chain-after "[+ 1 1]\n")) "after an expression")
  ;; …after a COMPLETE let — the case that was broken
  (check-true (last-is-18? (chain-after "let w := 1\n  w\n")) "after a let WITH a body")
  ;; …and directly after another chain: two units, both merge
  (define two (chain-after "let p := 1\nlet q := 2\n  [+ p q]\n"))
  (check-equal? (length two) 2 (format "two chains → two forms, got: ~v" two))
  (check-true (regexp-match? #rx"3" (format "~a" (first two))) "the first chain evaluates")
  (check-true (last-is-18? two) "…and so does the second"))
