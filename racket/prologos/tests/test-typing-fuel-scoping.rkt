#lang racket/base
;;;
;;; test-typing-fuel-scoping.rkt — the bounded typing run must not leak its
;;; budget exhaustion as a network contradiction.
;;;
;;; `infer-on-network/full` (typing-propagators.rkt) runs the on-network
;;; typing pass to quiescence under a deliberately small budget
;;; (TYPING-FUEL-LIMIT = 200) so a pathological expression can't spin. When
;;; the budget runs out the fuel cell's on-write-check records a
;;; CONTRADICTION on the network — the structural realization of
;;; "cost-bounded exploration" (see `.claude/rules/stratification.md`).
;;;
;;; That marker means "this sub-run hit its budget", not "the information on
;;; the network is inconsistent". But `unify`'s top-level wrapper
;;; (unify.rkt) downgrades ANY successful unification to #f whenever the
;;; network carries a contradiction. So before the fix, one fuel-exhausted
;;; typing run made every LATER unification in the same command fail —
;;; including syntactically identical pairs (`unify Vat Vat` → #f) — which
;;; surfaced as a bare "Could not infer type" naming the whole expression,
;;; with no location and no mention of fuel.
;;;
;;; The budget is small enough that ORDINARY code crosses it: measured on a
;;; prelude-only let-chain of list operations, one binding costs ~74 fuel and
;;; four bindings cost ~211. So these tests are not exotic — they are the
;;; everyday shape that was silently mistyped.
;;;
;;; Origin: OCapN interop, 2026-07-27. Four test files
;;; (test-ocapn-{pipeline,e2e,bridge,vat}) failed with "Could not infer type";
;;; goblin-pitfalls #30 filed the same failure in 2026-05 with the wrong
;;; hypothesis ("`match` uses a different inference path").
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt"
         "../driver.rkt"
         "../errors.rkt"
         "../namespace.rkt"
         "../global-env.rkt"
         "../elaborator.rkt"
         "../metavar-store.rkt"
         "../macros.rkt"
         "../multi-dispatch.rkt"
         (only-in "../propagator.rkt"
                  make-prop-network
                  net-contradiction? net-contradiction-cell net-set-contradiction
                  fuel-cell-id cell-id))

;; ========================================
;; 1. The primitive: contradiction marker is settable + clearable
;; ========================================

(test-case "net-set-contradiction round-trips the marker"
  (define net (make-prop-network))
  (check-false (net-contradiction? net)
               "a fresh network carries no contradiction")
  (define marked (net-set-contradiction net fuel-cell-id))
  (check-true (net-contradiction? marked))
  (check-equal? (net-contradiction-cell marked) fuel-cell-id
                "the marker records WHICH cell contradicted")
  (define cleared (net-set-contradiction marked #f))
  (check-false (net-contradiction? cleared)
               "restoring #f clears the marker")
  (check-false (net-contradiction? net)
               "the original network is untouched (persistent structure)"))

(test-case "net-set-contradiction preserves a NON-fuel marker under the save/restore idiom"
  ;; The scoping at the bounded run's boundary restores the marker only when
  ;; the run's own budget was what tripped it. A contradiction already present
  ;; on entry survives; so does one raised by a different cell.
  (define other-cell (cell-id 9999))
  (define entered (net-set-contradiction (make-prop-network) other-cell))
  (define saved (net-contradiction-cell entered))
  ;; sub-run exhausts fuel on top of the pre-existing contradiction
  (define after-run (net-set-contradiction entered fuel-cell-id))
  (define restored
    (if (eq? (net-contradiction-cell after-run) fuel-cell-id)
        (net-set-contradiction after-run saved)
        after-run))
  (check-equal? (net-contradiction-cell restored) other-cell
                "the pre-existing contradiction is restored, not clobbered"))

;; ========================================
;; 2. The behaviour: over-budget expressions still type-check
;; ========================================

(define preamble "(ns test-typing-fuel-scoping)\n")

(define-values (shared-global-env shared-ns-context shared-module-reg
                shared-trait-reg shared-impl-reg shared-param-impl-reg
                shared-ctor-reg shared-type-meta)
  (parameterize ([current-file-module-network-ref (make-module-network)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string preamble)
    (values (current-file-module-network-ref) (current-ns-context)
            (current-module-registry) (current-trait-registry)
            (current-impl-registry) (current-param-impl-registry)
            (current-ctor-registry) (current-type-meta))))

(define (run-last s)
  (last
   (parameterize ([current-file-module-network-ref shared-global-env]
                  [current-ns-context shared-ns-context]
                  [current-module-registry shared-module-reg]
                  [current-lib-paths (list prelude-lib-dir)]
                  [current-preparse-registry (current-preparse-registry)]
                  [current-trait-registry shared-trait-reg]
                  [current-impl-registry shared-impl-reg]
                  [current-param-impl-registry shared-param-impl-reg]
                  [current-ctor-registry shared-ctor-reg]
                  [current-type-meta shared-type-meta])
     (process-string s))))

;; ~211 fuel measured (budget is 200) — this is the smallest everyday shape
;; that crosses the line. Pre-fix this returned an inference-failed-error.
(test-case "a let-chain that exhausts the typing budget still type-checks"
  (define r
    (run-last
     (string-append
      "(eval (let (a0 (cons 1 (cons 2 (cons 3 nil)))\n"
      "            a1 (reverse a0)\n"
      "            a2 (append a1 a1)\n"
      "            a3 (reverse a2))\n"
      "        (length a3)))")))
  (check-false (prologos-error? r)
               (format "over-budget let-chain must not report a type error; got ~a" r))
  (check-true (string-contains? (format "~a" r) "Nat")
              (format "expected a Nat-typed result, got ~a" r)))

;; ~384 fuel measured — nearly 2x over budget, to pin that the fix is not a
;; threshold nudge.
(test-case "a much larger let-chain still type-checks"
  (define r
    (run-last
     (string-append
      "(eval (let (a0 (cons 1 (cons 2 (cons 3 nil)))\n"
      "            a1 (reverse a0)   a2 (append a1 a1)\n"
      "            a3 (reverse a2)   a4 (append a3 a3)\n"
      "            a5 (reverse a4)   a6 (append a5 a5)\n"
      "            a7 (reverse a6)   a8 (append a7 a7))\n"
      "        (length a8)))")))
  (check-false (prologos-error? r)
               (format "deep let-chain must not report a type error; got ~a" r)))

;; goblin-pitfalls #30 blamed this failure on "`match` inside a 7+ binding
;; let-chain". Both halves of that framing are wrong, and they are two
;; INDEPENDENT defects:
;;
;;   (a) let-DEPTH is irrelevant. A bare `(match (cons 1 nil) | nil -> 0 |
;;       cons hd _ -> hd)` with no let at all, consuming 34 of 200 fuel,
;;       fails identically. `match` in INFER position has no motive to
;;       synthesize; it needs a checking context. That is a separate,
;;       pre-existing, still-open limitation — NOT what this file fixes.
;;   (b) What #30's `length` / `nth` workarounds actually bought was staying
;;       under the fuel budget. In CHECK position `match` type-checks fine,
;;       and then the budget is the only thing left to trip over.
;;
;; The guard here is (b). The second test pins (a) so the two are never
;; conflated again.
(test-case "a CHECKED `match` at the end of an over-budget let-chain type-checks"
  (define r
    (run-last
     (string-append
      "(eval (let (a0 (cons 1 (cons 2 (cons 3 nil)))\n"
      "            a1 (reverse a0)\n"
      "            a2 (append a1 a1)\n"
      "            a3 (reverse a2))\n"
      "        (the Int (match a3 | nil -> 0 | cons hd _ -> hd))))")))
  (check-false (prologos-error? r)
               (format "checked match in an over-budget let-chain must not error; got ~a" r)))

(test-case "an UNCHECKED inline `match` fails regardless of fuel (pitfall #30, corrected)"
  ;; No let, well under budget. If this ever starts passing, `match` gained
  ;; infer-mode support and this test should flip to a positive assertion.
  (define r (run-last "(eval (match (cons 1 nil) | nil -> 0 | cons hd _ -> hd))"))
  (check-true (prologos-error? r)
              "bare inline match in infer position has no motive — still unsupported")
  (define annotated
    (run-last "(eval (the Int (match (cons 1 nil) | nil -> 0 | cons hd _ -> hd)))"))
  (check-false (prologos-error? annotated)
               "the annotation supplies the motive — this is the workaround"))

;; The two spellings must AGREE — the point is not just "no error" but that
;; the over-budget path yields the same answer as the under-budget one.
(test-case "over-budget and under-budget spellings agree"
  (define short-form
    (run-last "(eval (let (a0 (cons 7 nil)) (length a0)))"))
  (define long-form
    (run-last
     (string-append
      "(eval (let (a0 (cons 7 nil)\n"
      "            a1 (reverse a0)   a2 (reverse a1)\n"
      "            a3 (reverse a2)   a4 (reverse a3))\n"
      "        (length a4)))")))
  (check-false (prologos-error? long-form))
  (check-equal? (format "~a" long-form) (format "~a" short-form)
                "reversing an odd number of times is identity for length"))
