#lang racket/base

;;; test-batch-isolation.rkt — one `run-ns-*` call must not be visible to the
;;; next.
;;;
;;; The leak this pins was live for months and cost two wrong diagnoses.
;;;
;;; `spec-store-lookup` (macros.rkt:496) reads the CELL FIRST and falls back to
;;; the `current-spec-store` parameter. The batch worker snapshots and restores
;;; the PARAMETER per file — but the cell lives on the persistent-registry
;;; network, and `run-ns-*` handed every call the same prelude network box,
;;; unforked. So a `spec` registered by one test file was still in the cell for
;;; the next file in that worker, and the parameter restore the worker performs
;;; never touched it. The dual write to both parameter and cell is what hid it:
;;; the restore looked complete.
;;;
;;; Observed twice, both times as "passes alone, fails in batch, depends on
;;; which files share a worker":
;;;
;;;   - `test-defn-multiarg-patterns` registered `(spec c Handle2 -1> Nat)` and
;;;     `test-new-lattice-cell` then died on its own `def c : CellId` with
;;;     "def c has both a spec and inline type annotation" (2026-07-31). Worked
;;;     around by renaming the spec, which removed the collision, not the leak.
;;;   - The same file's `(spec ok2 Nat -> Nat)` reached `test-error-messages`,
;;;     whose own `defn ok2` has no spec and must INFER. It got the leaked spec
;;;     instead and failed with "cannot infer the type of an unannotated
;;;     parameter" — naming a subsystem that was working perfectly. Five
;;;     sightings before it was bisected to a two-file repro (2026-08-02).
;;;
;;; A leak of this shape is invisible to any single-file test, which is why it
;;; needs a file of its own: the assertion is about what does NOT survive.

(require rackunit
         racket/string
         "test-support.rkt"
         "../errors.rkt")

;; A name nothing else in the suite uses, so a failure here is this leak and
;; not somebody else's collision.
(define leaky-spec-name "zz-isolation-probe")

(test-case "isolation/a spec registered by one call is gone by the next"
  ;; Call 1 registers the spec and uses it.
  (define r1
    (run-ns-ws-all
     (format "ns t\nspec ~a Nat -> Nat\ndefn ~a\n  | zero -> 1N\n  | suc _ -> 2N\n"
             leaky-spec-name leaky-spec-name)))
  (check-true (list? r1))

  ;; Call 2 defines the SAME name with no spec, and an inline annotation that
  ;; would collide with a surviving one. If the spec leaked, this is the
  ;; "has both a spec and inline type annotation" error.
  (define r2
    (run-ns-ws-last
     (format "ns t\ndef ~a : Nat := 5N\n~a\n" leaky-spec-name leaky-spec-name)))
  (check-false (prologos-error? r2)
               (format "the spec leaked into the next call: ~v" r2)))

(test-case "isolation/inference still works on a name a previous call spec'd"
  ;; The exact shape that broke `test-error-messages`: a multi-clause defn with
  ;; no spec, whose parameter type comes from its Nat constructor patterns. A
  ;; leaked `Nat -> Nat` turns this from inference into checking, and the
  ;; failure names the inference engine rather than the leak.
  (run-ns-ws-all "ns t\nspec ok2-probe Nat -> Nat\ndefn ok2-probe\n  | zero -> 1N\n  | suc _ -> 2N\n")
  (define r (run-ns-ws-last "ns t\ndefn ok2-probe\n  | zero -> 1N\n  | suc _ -> 2N\n"))
  (check-false (prologos-error? r) (format "expected success, got: ~v" r)))

(test-case "isolation/the prelude is still there after the fork"
  ;; The fork is seeded FROM the prelude box, so everything the prelude
  ;; registered has to survive it. Without this, the fix would trade a leak for
  ;; an empty registry -- which is the failure mode of forking from scratch.
  (define r (run-ns-ws-last "ns t\n[+ 3N 2N]\n"))
  (check-false (prologos-error? r) (format "expected success, got: ~v" r))
  (check-true (string-contains? (format "~a" r) "5")
              (format "expected 5, got: ~v" r))
  ;; And a trait method, which is registry-backed rather than a plain binding --
  ;; the part of the prelude a bad fork would actually lose.
  (define r2 (run-ns-ws-last "ns t\n[eq? 3N 3N]\n"))
  (check-false (prologos-error? r2) (format "expected success, got: ~v" r2))
  (check-true (string-contains? (format "~a" r2) "true")
              (format "expected true, got: ~v" r2)))

;; ----------------------------------------------------------------
;; The advice a diagnostic gives has to be advice that parses
;; ----------------------------------------------------------------

(test-case "isolation/the unannotated-parameter hint suggests a spelling that works"
  ;; Not an isolation test, but it was found by one -- while checking that the
  ;; fork had not broken the prelude, `defn plus2 [n : Nat]` turned out to be a
  ;; PARSE ERROR, and the hint for the very failure it is meant to resolve was
  ;; recommending exactly that spelling.
  ;;
  ;; Spaced works for `fn`, fused works for both. The hint cannot tell them
  ;; apart -- by the time it fires, both are `expr-lam` -- so it must name the
  ;; spelling valid for both.
  (define r (run-ns-ws-last "ns t\ndefn zz-hint [n]\n  [+ n 2N]\n"))
  (check-true (prologos-error? r) (format "expected the infer failure, got: ~v" r))
  (define msg (format "~a" (prologos-error-message r)))
  (check-true (string-contains? msg "cannot infer the type of an unannotated parameter")
              (format "got: ~v" msg))
  (check-false (string-contains? msg "[x : T]")
               "the spaced form is a parse error for a defn parameter list")
  (check-true (string-contains? msg "[x:T]") (format "got: ~v" msg))
  (check-true (string-contains? msg "spec") (format "got: ~v" msg)))

(test-case "isolation/and the suggested spelling actually parses"
  ;; The pin that makes the one above mean something: run the advice.
  (define r (run-ns-ws-last "ns t\ndefn zz-fused [n:Nat]\n  [+ n 2N]\n[zz-fused 3N]\n"))
  (check-false (prologos-error? r) (format "the fused form did not parse: ~v" r))
  (check-true (string-contains? (format "~a" r) "5") (format "got: ~v" r))
  ;; …and the spaced form does NOT, which is why the message had to change.
  (define r2 (run-ns-ws-last "ns t\ndefn zz-spaced [n : Nat]\n  n\n"))
  (check-true (prologos-error? r2)
              (format "spaced defn params parse now? update the hint: ~v" r2)))
