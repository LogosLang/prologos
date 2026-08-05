#lang racket/base

;;;
;;; test-union-type-quiescence.rkt — the union-type HANG, pinned.
;;;
;;; Filed 2026-06-29 (DEMO Series, hunting a foray.prologos type-check hang) and
;;; open until 2026-08-05. The typing propagator network never quiesced: BSP
;;; fired forever, unbounded, and since the elaborator/typing network's fuel
;;; bound only trips on a contradiction it presented as a HANG rather than as a
;;; bounded diagnostic. Real-program-affecting — it took the LSP down too, which
;;; type-checks on open.
;;;
;;; The filed hypothesis was "the `:type`-facet union join not reaching a
;;; fixpoint". Profiling says the join is not the problem. `tagged-cell-merge`
;;; and `make-tagged-merge` unioned their entry lists with a bare
;;;
;;;     (append (entries new) (entries old))
;;;
;;; so `(merge x x)` returned twice x's entries: the merge was NOT IDEMPOTENT,
;;; which is the one property `structural-thinking.md` requires of every cell
;;; merge in this system. A cell whose lattice VALUE is stable but whose
;;; REPRESENTATION grows each round reads as changed to the scheduler, so its
;;; dependents re-fire, re-write the same entries, and round N+1 looks exactly
;;; like round N except longer. `tagged-cell-read` merges every matching entry
;;; on every read, so per-read cost grew with the list as well — 49% of total
;;; time under this repro, `attribute-map-merge-fn` alone at 30% SELF.
;;;
;;; Fix: `union-entries` (decision-cell.rkt) dedups by `equal?` on the whole
;;; `(bitmask . value)` pair, keeping the first occurrence — which is what the
;;; ordering contract already required ("NEW entries first — later writes win at
;;; same specificity"; `tagged-cell-read` takes the first match when no
;;; domain-merge is given).
;;;
;;; WHAT THESE TESTS ARE FOR: a timeout, not an answer. Each runs a known repro
;;; under a wall-clock bound and fails if it does not finish. The answers are
;;; asserted too, so that "terminates" cannot be satisfied by terminating
;;; WRONGLY — a cheaper bug to introduce here than the original one.
;;;
;;; Reference: DEFERRED.md § "BUG: Union-type checking hangs the type-checker".
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../relations.rkt"
         (only-in "../errors.rkt" prologos-error? prologos-error-message)
         (only-in "../macros.rkt" current-preparse-registry current-trait-registry
                  current-impl-registry current-param-impl-registry)
         (only-in "../metavar-store.rkt" current-persistent-registry-net-box
                  current-prop-net-box)
         (only-in "../propagator.rkt" with-forked-network)
         (only-in "../decision-cell.rkt"
                  tagged-cell-value tagged-cell-value-entries tagged-cell-merge
                  make-tagged-merge))

;; ~6x the ~4s these actually take.
;;
;; ⚠ If this file ever regresses, the BATCH runner will report
;; "ABORTED — 0 tests", not a failure. rackunit output arrives when the file
;; finishes, and a regressed file sits silent past the runner's 30s "dead
;; worker" heuristic. The run is correctly not-green either way, but the banner
;; will point at stale `.zo` (its standard guess) rather than at this. Re-run
;; the file DIRECTLY —
;;
;;     raco test racket/prologos/tests/test-union-type-quiescence.rkt
;;
;; — and the two lattice-contract cases below fail instantly with
;; `actual: 4 / expected: 2`, which names the defect exactly. That is why those
;; two come first and touch no compiler: they are the fast, precise signal, and
;; the repro cases are the belt.
(define TIMEOUT-SECONDS 25)

(define (run-prologos-string content)
  (define tmp (make-prologos-temp-file))
  (call-with-output-file tmp
    (lambda (out) (display content out))
    #:exists 'truncate)
  (define results
    (parameterize ([current-file-module-network-ref (make-module-network)]
                   [current-ns-context #f]
                   [current-module-registry prelude-module-registry]
                   [current-lib-paths (list prelude-lib-dir)]
                   [current-relation-store (make-relation-store)]
                   [current-preparse-registry prelude-preparse-registry]
                   [current-trait-registry prelude-trait-registry]
                   [current-impl-registry prelude-impl-registry]
                   [current-param-impl-registry prelude-param-impl-registry]
                   [current-persistent-registry-net-box
                    prelude-persistent-registry-net-box]
                   [current-module-registry-cell-id #f]
                   [current-ns-context-cell-id #f])
      (with-forked-network current-prop-net-box
        (install-module-loader!)
        (process-file (path->string tmp)))))
  (delete-file tmp)
  results)

;; Run under a wall-clock bound. Returns results, or 'TIMEOUT.
(define (run-bounded content)
  (define result-box (box 'TIMEOUT))
  (define worker
    (thread (lambda ()
              (with-handlers ([(lambda (_) #t)
                               (lambda (e) (set-box! result-box (list 'EXN e)))])
                (set-box! result-box (run-prologos-string content))))))
  (unless (sync/timeout TIMEOUT-SECONDS worker)
    (kill-thread worker))
  (unbox result-box))

(define (msg r) (if (prologos-error? r) (prologos-error-message r) (format "~a" r)))

(define (check-completes name content . expected-substrings)
  (define rs (run-bounded content))
  (check-false (eq? rs 'TIMEOUT)
               (format "~a: did not finish within ~as — the network is not quiescing"
                       name TIMEOUT-SECONDS))
  (when (list? rs)
    (check-equal? (filter prologos-error? rs) '()
                  (format "~a: expected 0 errors, got ~a"
                          name (map msg (filter prologos-error? rs))))
    (define all (string-join (map msg rs) " | "))
    (for ([sub (in-list expected-substrings)])
      (check-true (string-contains? all sub)
                  (format "~a: expected ~s in the output; got: ~a" name sub all)))))

;; ============================================================================
;; The lattice contract, directly
;; ============================================================================
;;
;; This is the test that would have caught it in 2026-06-29 without a repro at
;; all, and it is three lines. Every cell merge in this system must be
;; idempotent; nothing asserted it for this one.

(test-case "tagged-cell-merge is IDEMPOTENT — merge(x, x) = x"
  (define x (tagged-cell-value 'base (list (cons 1 'a) (cons 2 'b))))
  (define once (tagged-cell-merge x x))
  (check-equal? (length (tagged-cell-value-entries once)) 2
                "merging a value with itself must not grow its entry list")
  (define twice (tagged-cell-merge once once))
  (check-equal? (length (tagged-cell-value-entries twice)) 2
                "and must stay stable under repetition"))

(test-case "make-tagged-merge's wrapper is idempotent too — both had the bug"
  (define m (make-tagged-merge (lambda (a b) (if (eq? a b) a (list a b)))))
  (define x (tagged-cell-value 'base (list (cons 1 'a) (cons 2 'b))))
  (define once (m x x))
  (check-equal? (length (tagged-cell-value-entries once)) 2)
  (check-equal? (length (tagged-cell-value-entries (m once x))) 2
                "re-merging an already-merged value must be a no-op on entries"))

(test-case "distinct entries still UNION — dedup must not lose information"
  (define a (tagged-cell-value 'base (list (cons 1 'a))))
  (define b (tagged-cell-value 'base (list (cons 2 'b))))
  (define m (tagged-cell-merge a b))
  (check-equal? (length (tagged-cell-value-entries m)) 2
                "two different entries must both survive"))

(test-case "ordering is preserved — NEW entries stay first"
  ;; tagged-cell-read takes the FIRST match when no domain-merge is supplied,
  ;; so dedup keeping the first occurrence is what makes "later writes win at
  ;; same specificity" continue to hold.
  (define old (tagged-cell-value 'base (list (cons 1 'old))))
  (define new (tagged-cell-value 'base (list (cons 1 'new))))
  (define m (tagged-cell-merge old new))
  (check-equal? (car (tagged-cell-value-entries m)) (cons 1 'new)
                "the newer entry must remain first"))

;; ============================================================================
;; The repros
;; ============================================================================

(define UNION-DEF "def x : <Int | String> := 42\n")

(test-case "the three-command repro terminates (2026-08-02 triage form)"
  ;; A union-typed def, a command that USES it, and a later command containing
  ;; an APPLICATION. All three ingredients are required; each alone completes.
  ;; `[int+ …]` is MONOMORPHIC, which is what ruled out trait resolution.
  (check-completes "int+" (string-append "ns q1\n" UNION-DEF "x\n[int+ 1 2]\n")
                   "Int | String" "3"))

(test-case "the original ORDER-DEPENDENT repro terminates (2026-06-29 form)"
  (check-completes "the-form"
                   (string-append "ns q2\n" UNION-DEF "x\nthe <Int | String> \"0\"\n")
                   "Int | String"))

(test-case "the trait-application form terminates"
  (check-completes "plus" (string-append "ns q3\n" UNION-DEF "x\n[+ 1 2]\n")
                   "Int | String" "3"))

(test-case "the String-initialised union terminates too"
  ;; Initialising with a String rather than an Int also hung, which is how the
  ;; triage ruled out "the chosen branch" as the ingredient.
  (check-completes "string-init"
                   "ns q4\ndef x : <Int | String> := \"s\"\nx\n[+ 1.5 2.5]\n"
                   "Int | String"))

(test-case "the polymorphic-spec form terminates (the F1b.3 sighting)"
  ;; Recorded 2026-07-17 as a second, apparently different hang: a polymorphic
  ;; spec plus application over accumulated union state. Same defect.
  (check-completes "poly"
                   (string-append "ns q5\n" UNION-DEF
                                  "spec pick {A : Type} A A -> A\n"
                                  "defn pick [a b] a\n"
                                  "pick x x\n")
                   "Int | String"))

(test-case "the ingredients that ALWAYS completed still complete (control)"
  ;; If these ever hang, the fix has moved the problem rather than removed it.
  (check-completes "no-use" (string-append "ns q6\n" UNION-DEF "[int+ 1 2]\n") "3")
  (check-completes "not-union" "ns q7\ndef x : Int := 42\nx\n[int+ 1 2]\n" "3")
  (check-completes "literal-third" (string-append "ns q8\n" UNION-DEF "x\n42\n") "42"))
