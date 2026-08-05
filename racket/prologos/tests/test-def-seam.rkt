#lang racket/base

;;;
;;; test-def-seam.rkt — the `def` := seam: annotation spellings + error CHANNEL.
;;;
;;; WHY THIS FILE EXISTS (the hiding mechanism, 2026-08-01):
;;;
;;; `def x:Int := 5` — the FUSED type-annotation spelling — was a WHOLE-FILE
;;; ABORT. Not a per-command error: no other command in the file ran. Meanwhile
;;; `tests/test-path-selection.rkt` carried a GREEN pin for that exact input:
;;;
;;;     (check-equal? (read-all-forms-string "def x:Int := 5")
;;;                   '((def x :Int := 5)))
;;;
;;; It passed, and stayed passing, because the READER is correct. The defect was
;;; one layer down, in `expand-def-assign` (macros.rkt) at PREPARSE. Every pin in
;;; that block — and every pin in `test-def-multiline-ws.rkt`'s datum section —
;;; is reader-level, so the whole suite was green over a live whole-file abort.
;;;
;;; The lesson is structural, not incidental: a reader pin cannot see a preparse
;;; defect, and a `process-string`/`process-string-ws` pin cannot see a
;;; WHOLE-FILE abort (it has only one command to lose). Only Level 3 — a real
;;; `.prologos` FILE through `process-file`, with SIBLING commands on both sides
;;; of the bad one — pins containment. That is what `run-file-ws` below is for,
;;; and it is why this file exists rather than more cases in the reader files.
;;;
;;; THE TWO THINGS PINNED HERE, and they are separable:
;;;
;;;   (1) ACCEPTANCE — the fused spelling `def x:Int := 5` means exactly what the
;;;       spaced spelling `def x : Int := 5` means. Pinned as PARITY (§A, §B), so
;;;       the two spellings cannot drift apart: the fused arm is asserted equal to
;;;       the spaced arm's output, never to a separately-written expectation.
;;;
;;;   (2) CHANNEL — a `def` head the expander cannot make sense of is a
;;;       PER-COMMAND error VALUE, never a raise (§C). This is the POL.4
;;;       conversion rule, and the `$let-error` marker channel (LET P1,
;;;       macros.rkt § "the retired-selection diagnostic seat") is its precedent.
;;;       Preparse runs OUTSIDE driver.rkt's per-command loop, so ANY raise there
;;;       kills the file — which is why (2) is a correctness property and not
;;;       merely a diagnostics nicety.
;;;
;;; §C's inputs are deliberately the shapes that are NOT types — chained
;;; (`x:A:B`, reserved for UCS) and multiplicity-shaped (`x:0`, `x:w`). Fix (1)
;;; must NOT swallow them as type names (that is the Q_N4 defect: the four-lexeme
;;; list silently ate `:7` as a type), and fix (2) must make them land as clean
;;; per-command errors. The two fixes compose exactly there.
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

;; ---- Shared prelude fixture (once per file; the test-let-blocks pattern) ----
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
    (process-string "(ns def-seam-pre)")
    (values (global-env-snapshot) (current-ns-context) (current-module-registry)
            (current-trait-registry) (current-impl-registry)
            (current-param-impl-registry))))

;; Level 3: a real .prologos FILE through process-file — the ONLY level at which
;; a whole-file abort is observable (a raise kills every command; a parse-error
;; value kills exactly one). String-level runs cannot pin containment.
(define (run-file-ws s)
  (define tmp (make-temporary-file "prologos-defseam-~a.prologos"))
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

;; Level 1 (sexp): the SAME fixture, through process-string. Needed because the
;; GLUED name `x:Int` is a sexp-only surface — the WS reader splits it, so no
;; .prologos file can produce it and `run-file-ws` cannot reach §E2's subject.
;; NB it must share this file's fixture rather than call test-support's
;; `run-ns-all`: that helper installs its own forked network, which collides
;; with the module-level snapshot above (`net-cell-reset: unknown cell`).
(define (run-sexp s)
  (parameterize ([current-file-module-network-ref
                  (module-network-add-import (make-module-network)
                                             (module-network-from-snapshot pre-global-env))]
                 [current-ns-context pre-ns-context]
                 [current-module-registry pre-module-reg]
                 [current-trait-registry pre-trait-reg]
                 [current-impl-registry pre-impl-reg]
                 [current-param-impl-registry pre-param-impl-reg])
    (process-string s)))

;; A file whose MIDDLE command is `body`, flanked by two innocent defs. The
;; flanking defs are the containment probe: under a whole-file abort they never
;; run, so `(length rs)` is not 3 — it raises before returning anything at all.
(define (sandwich ns-name body)
  (string-append "ns " ns-name "\n"
                 "def before-marker := 1\n"
                 body "\n"
                 "def after-marker := 2\n"))

;; ========================================
;; §A — Level 1 (datum): fused ≡ spaced, through expand-def-assign
;; ========================================
;; The expander is the defect site, so pin it directly as well as end-to-end.
;; PARITY, not a hand-written expectation: the fused arm must emit byte-identical
;; output to the spaced arm, so the two spellings cannot drift.

(test-case "def-seam/A1 fused `x:Int` expands identically to spaced `x : Int`"
  ;; After the WS reader's binder unwrap, `def x:Int := 5` arrives as the datum
  ;; (def x :Int := 5) — a SINGLE colon-symbol token where the spaced form has
  ;; two (`:` then `Int`). Pinned live at 9053e978: reader output verified, and
  ;; expand-def-assign RAISED `def: unexpected tokens before :=: (:Int)`.
  (define spaced (expand-def-assign '(def x : Int := 5)))
  (define fused  (expand-def-assign '(def x :Int := 5)))
  (check-equal? spaced '(def x ($angle-type Int) 5)
                "baseline: the spaced arm's emission (regression guard on the target shape)")
  (check-equal? fused spaced
                "the fused spelling must emit exactly what the spaced spelling emits"))

(test-case "def-seam/A2 fused annotation WITHOUT `:=` normalizes to the spaced form"
  ;; ⚠ THIS PIN WAS INVERTED, deliberately, and the history is the point.
  ;; It first read `(expand-def-assign '(def x :Int 5))` → UNCHANGED, on the
  ;; reasoning that a form with no `:=` is not an assignment and so not this
  ;; function's business. That reasoning was wrong: it left `def x:Int 5`
  ;; refused while `def x : Int 5` and `let x:Int 5` both worked, purely because
  ;; the four call sites gated the expander behind `(memq ':= …)`. The gate is
  ;; gone and this function now owns def-HEAD normalization for every `def`, so
  ;; the no-`:=` spelling reaches parse-def's name/:/type/body arm — which
  ;; already worked. See §E4.
  (check-equal? (expand-def-assign '(def x :Int 5)) '(def x : Int 5)))

(test-case "def-seam/A3 the no-annotation and multi-token spaced forms still work"
  ;; Non-regression around the arm being added.
  (check-equal? (expand-def-assign '(def x := 5)) '(def x 5))
  (check-equal? (expand-def-assign '(def x : List Int := 5))
                '(def x ($angle-type List Int) 5)))

;; ========================================
;; §B — Level 3 (file): the fused spelling works, and does not kill the file
;; ========================================

(test-case "def-seam/B1 a fused-annotation def does NOT abort the whole file"
  ;; THE HEADLINE PIN. Before the fix this did not merely report a bad result —
  ;; `process-file` RAISED out of preparse and produced NOTHING, so both flanking
  ;; defs vanished. That is the property under test: containment, not wording.
  (define rs (run-file-ws (sandwich "defseam-b1" "def x:Int := 5")))
  (check-equal? (length rs) 3
                (format "all three defs must produce a result; got: ~v" rs))
  (for ([r (in-list rs)] [i (in-naturals)])
    (check-false (prologos-error? r)
                 (format "result ~a should not be an error: ~v" i r))))

(test-case "def-seam/B2 fused and spaced spellings agree end-to-end"
  ;; Parity at Level 3 too: same program, only the annotation spelling differs.
  (define fused  (run-file-ws "ns defseam-b2f\ndef x:Int := 5\nx\n"))
  (define spaced (run-file-ws "ns defseam-b2s\ndef x : Int := 5\nx\n"))
  (check-equal? (length fused) 2 (format "fused: ~v" fused))
  (check-equal? (length spaced) 2 (format "spaced: ~v" spaced))
  (check-false (prologos-error? (first fused))
               (format "the fused def must succeed, got: ~v" (first fused)))
  (check-equal? (format "~a" (first fused)) (format "~a" (first spaced))
                "the def's own result must match the spaced spelling")
  (check-equal? (format "~a" (second fused)) (format "~a" (second spaced))
                "…and so must the value the name evaluates to"))

;; ========================================
;; §C — the CHANNEL: an unmakeable-sense `def` head is a per-command error
;; ========================================
;; These are the shapes fix (1) must REFUSE (they are not type annotations) and
;; fix (2) must refuse LOUDLY-BUT-LOCALLY. Each pins the same property: one
;; command is lost, the rest of the file survives.

(define (check-contained-error label body)
  (define rs (run-file-ws (sandwich (string-append "defseam-" label) body)))
  (check-equal? (length rs) 3
                (format "~a: the file must survive; got: ~v" label rs))
  (check-true (prologos-error? (second rs))
              (format "~a: the bad command must be a per-command error, got: ~v"
                      label (second rs)))
  (check-false (prologos-error? (first rs))
               (format "~a: the command BEFORE it must still run" label))
  (check-false (prologos-error? (third rs))
               (format "~a: the command AFTER it must still run" label)))

(test-case "def-seam/C1 chained annotation `x:A:B` is a contained, well-worded error"
  ;; Chained annotations are reserved for UCS and must stay refused
  ;; (split-glued-name-datum rejects the sexp spelling identically). Refused,
  ;; but not at the cost of the file.
  (check-contained-error "c1" "def x:A:B := 5")
  ;; ⚠ THE MESSAGE IS PINNED, and this is why: since the `:` mint (P4c-2) the
  ;; reader hands us `(:A ($bcast-step :B))`, NOT two colon-symbols — the first
  ;; colon fuses onto the binder and the REST become broadcast steps. The
  ;; original classifier tested `fused-type-annot?` on every token, so after
  ;; that mint landed it stopped recognizing chains: the message silently
  ;; degraded to the multi-token one AND printed the raw sentinel
  ;; `($bcast-step :B)` at a user who had written ordinary syntax. Containment
  ;; alone could not see it — `check-contained-error` only asks "is it an
  ;; error". Leaking an internal sentinel is the same defect P4c-2 condition
  ;; (c) fixed one seam over, so pin the wording, not just the outcome.
  (define rs (run-file-ws (sandwich "defseam-c1msg" "def x:A:B := 5")))
  (define msg (prologos-error-message (second rs)))
  (check-true (regexp-match? #rx"chained type annotation" msg)
              (format "must classify as chained, got: ~v" msg))
  (check-true (regexp-match? #rx":A:B" msg)
              (format "must echo what the user typed, got: ~v" msg))
  (check-false (regexp-match? #rx"bcast-step" msg)
               (format "must NOT leak the reader sentinel, got: ~v" msg)))

(test-case "def-seam/C2 multiplicity-shaped `x:0` is a contained error, not a type"
  ;; The Q_N4 discipline: no type name starts with a digit, so `:0` is a
  ;; MULTIPLICITY, never a type. Fix (1) must not swallow it as a type name —
  ;; `fused-type-annot?` is the one predicate that draws this line, which is why
  ;; the fix reuses it instead of re-testing the shape.
  (check-contained-error "c2" "def x:0 := 5"))

(test-case "def-seam/C3 multiplicity-shaped `x:w` is a contained error, not a type"
  ;; `:w`/`:m` stay multiplicities — the named cost recorded at fused-type-annot?
  ;; (a type literally named `w`/`m` cannot be fused; use the spaced form).
  (check-contained-error "c3" "def x:w := 5"))

(test-case "def-seam/C6 a MULTI-token fused annotation is refused with the rule, contained"
  ;; `def x:List Nat := 5`. The fused spelling is SINGLE-TOKEN by rule
  ;; (reader-forms.rkt § fused annotations; `defn` params and `let` bindings
  ;; carry the same restriction), so refusing is CORRECT — but the message must
  ;; name the rule and show the spaced form, not just say "unexpected tokens".
  (check-contained-error "c6" "def x:List Nat := 5")
  (define rs (run-file-ws (sandwich "defseam-c6msg" "def x:List Nat := 5")))
  (check-true (regexp-match? #rx"single-token" (prologos-error-message (second rs)))
              (format "message must name the rule, got: ~v" (second rs)))
  (check-true (regexp-match? #rx"def x : List Nat := value"
                             (prologos-error-message (second rs)))
              (format "message must show the spaced form, got: ~v" (second rs))))

(test-case "def-seam/C7 the PRIVATE `def-` fused spelling works — the two layers compose"
  ;; ⚠ THIS PIN WAS WRITTEN AS A TRIPWIRE AND FLIPPED, which is the point.
  ;;
  ;; When the fused arm first landed, `def- x:Int := 5` did NOT work, for a
  ;; reason one layer UP: the reader's binder-unwrap set `binder-region-heads`
  ;; was tested with a BARE `(memq hd …)`, so the suffixed `def-` was never
  ;; normalized and `before` arrived as `(($bcast-step :Int))` — a LIST. The
  ;; fused arm keys on the SYMBOL predicate `fused-type-annot?` and correctly
  ;; declined. Fix (2) meant it was at least CONTAINED rather than a whole-file
  ;; abort, and this pin asserted exactly that containment, with a note saying
  ;; it would flip to a success assertion if the reader was ever fixed.
  ;;
  ;; It was fixed, at the right layer: CIU T6 D4.P4c-2 (`cbd8d1a7`) added
  ;; `binder-head-base`, so `def-` now normalizes to `(def- x :Int := 5)` and
  ;; flows through the fused arm. NO production change in this seam was needed
  ;; — which is the argument for having refused to pattern-match the
  ;; `$bcast-step` artifact here in the first place. Two independent fixes at
  ;; their own layers compose; a workaround at the wrong layer would now be
  ;; dead code obscuring the real one.
  (define rs (run-file-ws (string-append "ns defseam-c7\n"
                                         "def- x:Int := 5\n"
                                         "x\n")))
  (check-equal? (length rs) 2 (format "got: ~v" rs))
  (check-false (prologos-error? (first rs))
               (format "fused `def-` must work, got: ~v" (first rs)))
  ;; …and it agrees with the spaced private spelling, the same parity §B pins
  ;; for the public form.
  (define spaced (run-file-ws "ns defseam-c7s\ndef- x : Int := 5\nx\n"))
  (check-equal? (format "~a" (first rs)) (format "~a" (first spaced)))
  (check-equal? (format "~a" (second rs)) (format "~a" (second spaced))))

(test-case "def-seam/C4 a bare `$def-error` marker with no args does not crash the parser"
  ;; The (pair? args) guard in the parser's marker arm is LOAD-BEARING — the
  ;; $retired-selection precedent records the failure mode: an unguarded
  ;; (car args) is ITSELF a whole-file abort, i.e. exactly what the seat exists
  ;; to eliminate. A user can type the marker head directly, so pin the guard.
  ;; This mirrors test-let-blocks.rkt's "let-p1/a bare $let-error marker" pin;
  ;; the arm now serves both heads, so both need the pin.
  (define rs (run-file-ws "ns defseam-c4\ndef x := ($def-error)\ndef y := 3\n"))
  (check-equal? (length rs) 2 (format "expected 2 results, got: ~v" rs))
  (check-true (prologos-error? (first rs)))
  (check-false (prologos-error? (second rs)) "the file must continue"))

(test-case "def-seam/C5 the marker arm honours the HEAD it was given"
  ;; One arm, two heads: the conversion is shared, but the no-args FALLBACK
  ;; wording is the one thing the heads are distinguished for. If a future edit
  ;; collapses the heads, this catches it — a def failure must not say "let".
  (define def-rs (run-file-ws "ns defseam-c5d\ndef x := ($def-error)\n"))
  (define let-rs (run-file-ws "ns defseam-c5l\ndef x := ($let-error)\n"))
  (check-true (regexp-match? #rx"def" (prologos-error-message (first def-rs)))
              (format "got: ~v" (first def-rs)))
  (check-true (regexp-match? #rx"let" (prologos-error-message (first let-rs)))
              (format "got: ~v" (first let-rs)))
  (check-not-equal? (prologos-error-message (first def-rs))
                    (prologos-error-message (first let-rs))))

;; ========================================
;; §E — the other two fused surfaces: the sexp GLUED name, and no-`:=`
;; ========================================
;; The `:=` fix left two siblings behind, both now closed by moving ALL def-head
;; normalization into `expand-def-assign` and calling it for EVERY def (the
;; `(memq ':= …)` gate at its four call sites is gone). One normalization point
;; serves three surfaces, so the fused recognition still has exactly one copy.

(test-case "def-seam/E1 all THREE annotation surfaces converge on one emission"
  ;; WS-split `(:Int)`, sexp-glued `x:Int`, and spaced `: Int` are three ways to
  ;; write one thing. Pinned as mutual equality rather than three separate
  ;; expectations, so they cannot drift apart one at a time.
  (define spaced (expand-def-assign '(def x : Int := 5)))
  (check-equal? (expand-def-assign '(def x :Int := 5)) spaced "WS-split fused")
  (check-equal? (expand-def-assign '(def x:Int := 5)) spaced "sexp glued name")
  (check-equal? spaced '(def x ($angle-type Int) 5)))

(test-case "def-seam/E2 the sexp glued name binds `x`, not a variable named `x:Int`"
  ;; THE SILENT WRONG ANSWER this closes. `(def x:Int := 5)` used to take the
  ;; null-`before` arm — the glued symbol was never split — and bind a variable
  ;; literally NAMED `x:Int`, untyped, with ZERO errors. Worse than the abort
  ;; fixed alongside it: loud beats silent. `let` closed exactly this at LET P4
  ;; (ruling 3) via `split-glued-name-datum`; `def` now calls the same helper.
  ;; This is a SEXP-mode pin by necessity: a .prologos file cannot produce the
  ;; glued shape at all (the WS reader splits it), so only process-string can
  ;; reach the surface under test.
  (define rs (run-sexp "(def x:Int := 5)(def y:Int 6)"))
  (check-equal? (length rs) 2 (format "got: ~v" rs))
  (check-true (regexp-match? #rx"^x : Int" (format "~a" (first rs)))
              (format "must bind `x` at type Int, got: ~v" (first rs)))
  (check-true (regexp-match? #rx"^y : Int" (format "~a" (second rs)))
              (format "…and the no-`:=` glued spelling too, got: ~v" (second rs))))

(test-case "def-seam/E3 a module path is NOT a fused annotation"
  ;; `str::length` produces EMPTY segments, which is exactly how
  ;; split-glued-name-datum tells a module path from an annotation. If this
  ;; regresses, every `::`-named def silently loses its name.
  (check-equal? (expand-def-assign '(def str::length := 5)) '(def str::length 5)))

(test-case "def-seam/E4 the fused spelling works WITHOUT `:=` too, matching spaced"
  ;; `def x : Int 5` (name/:/type/body) always worked; `def x:Int 5` did not,
  ;; because expand-def-assign was gated behind `(memq ':= …)` and so never saw
  ;; the no-`:=` spellings. `let x:Int 5` supported it, making `def` the outlier.
  (define fused  (run-file-ws "ns defseam-e4f\ndef x:Int 5\nx\n"))
  (define spaced (run-file-ws "ns defseam-e4s\ndef x : Int 5\nx\n"))
  (check-equal? (length fused) 2 (format "got: ~v" fused))
  (check-false (prologos-error? (first fused))
               (format "fused-without-`:=` must work, got: ~v" (first fused)))
  (check-equal? (format "~a" (first fused)) (format "~a" (first spaced)))
  (check-equal? (format "~a" (second fused)) (format "~a" (second spaced))))

(test-case "def-seam/E5 …and for the private `def-` form as well"
  (define rs (run-file-ws "ns defseam-e5\ndef- x:Int 5\nx\n"))
  (check-equal? (length rs) 2 (format "got: ~v" rs))
  (check-false (prologos-error? (first rs)) (format "got: ~v" (first rs))))

(test-case "def-seam/E6 two annotations for one binding is a contained error"
  ;; `def x:Int : Foo := 5` — the name carries one and another follows. Refusing
  ;; beats silently preferring either.
  (define r (expand-def-assign '(def x:Int : Foo := 5)))
  (check-equal? (car r) '$def-error (format "got: ~v" r))
  (check-true (regexp-match? #rx"just one" (cadr r)) (format "got: ~v" r))
  ;; …and a glued name followed by a stray multi-token type is refused too, so
  ;; sexp stays in step with WS (which refuses `x:List Nat` via §C6).
  (define m (expand-def-assign '(def x:List Nat := 5)))
  (check-equal? (car m) '$def-error (format "got: ~v" m))
  (check-true (regexp-match? #rx"just one type" (cadr m)) (format "got: ~v" m))
  ;; the glued chained form refuses with the UCS reason, like the WS one (C1)
  (define c (expand-def-assign '(def x:A:B := 5)))
  (check-equal? (car c) '$def-error (format "got: ~v" c))
  (check-true (regexp-match? #rx"UCS" (cadr c)) (format "got: ~v" c)))

(test-case "def-seam/E7 arity stubs pass through untouched (guard on the widened gate)"
  ;; ⚠ REGRESSION GUARD, and the reason the arity check exists. Removing the
  ;; `(memq ':= …)` gate means expand-def-assign now runs on EVERY def — so a
  ;; stub like `(def)` or `(def x)` reaches it, and an unguarded `(cadr datum)`
  ;; would raise at PREPARSE: a whole-file abort, i.e. this seam's own bug class
  ;; reintroduced by its own fix. Short forms must pass through to parse-def,
  ;; which reports them as per-command arity errors.
  (check-equal? (expand-def-assign '(def)) '(def))
  (check-equal? (expand-def-assign '(def x)) '(def x))
  ;; …and end-to-end: a bare `def` must not take the file down.
  (define rs (run-file-ws (sandwich "defseam-e7" "def")))
  (check-equal? (length rs) 3 (format "the file must survive a bare `def`; got: ~v" rs))
  (check-false (prologos-error? (first rs)))
  (check-false (prologos-error? (third rs))))

;; ========================================
;; §D — non-regression on the spellings that already worked
;; ========================================

(test-case "def-seam/D1 spaced and bare spellings still work at Level 3"
  (define rs (run-file-ws (string-append
                           "ns defseam-d1\n"
                           "def a := 1\n"
                           "def b : Int := 2\n"
                           "def c : List Int := '[1 2 3]\n")))
  (check-equal? (length rs) 3 (format "got: ~v" rs))
  (for ([r (in-list rs)] [i (in-naturals)])
    (check-false (prologos-error? r)
                 (format "result ~a should not be an error: ~v" i r))))
