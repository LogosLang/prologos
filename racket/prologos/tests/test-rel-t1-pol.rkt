#lang racket/base

;;;
;;; Rel T1 POL — polish-cluster gates (design §8 roster).
;;; POL.2 / B3.0 (2026-07-24): anonymous `_` query vars are solver-visible free
;;; vars (answer COUNT unchanged — duplicates preserved; POL.1 dedup is a
;;; separate aspect) but are NOT projected into solution rows. The filter is
;;; kernel-level (reduction.rkt anon-query-var? / row-query-vars) so runtime
;;; champ rows and B3's static row labels stay key-agreed.
;;; Owner repro source: standup-2026-07-19.org § "Polish points for REL".
;;;

(require rackunit
         racket/string
         "test-support.rkt")

(define FIXTURE
  (string-append
   "ns poltest\n"
   "defr bool [?b]\n"
   "  || 1\n"
   "     0\n"
   "defr truths [?b1 ?b2 ?b3 ?b4]\n"
   "  &> (bool b1) (bool b2) (bool b3) (bool b4)\n"))

(test-case "POL.2: anon `_` keys are dropped from solve rows; duplicates preserved"
  (define r (run-ns-ws-last (string-append FIXTURE "solve (truths b1 b2 b3 _)")))
  (check-true (string? r))
  (check-true (string-contains? r ":b1") "named query vars keep their keys")
  (check-true (string-contains? r ":b3"))
  (check-false (string-contains? r "_anon") "anon gensym keys must not appear")
  ;; 2^4 = 16 solutions; the two `_` values yield DUPLICATE rows (kept — POL.1
  ;; dedup is out of scope here). Count braces in the VALUE part only — since
  ;; B3.1 the printed TYPE of a rule solve is itself a row (`List {:b1 Int …}`)
  ;; and would inflate a whole-string count.
  (define val-part (car (regexp-split #rx" : " r)))
  (check-equal? (length (regexp-match* #rx"[{]" val-part)) 16
                "answer count unchanged by projection (duplicates preserved)"))

(test-case "POL.2: all-anon query projects to empty rows (membership-style)"
  (define r (run-ns-ws-last (string-append FIXTURE "solve (truths _ _ _ _)")))
  (check-true (string? r))
  (check-false (string-contains? r "_anon"))
  (check-false (string-contains? (car (regexp-split #rx" : " r)) ":b")
               "no named keys in the value rows")
  (check-equal? (length (regexp-match* #rx"[{][}]" (car (regexp-split #rx" : " r)))) 16
                "16 empty rows — one per solution"))

(test-case "POL.2: solve-one drops anon keys too (same kernel filter)"
  (define r (run-ns-ws-last (string-append FIXTURE "solve-one (truths b1 _ _ _)")))
  (check-true (string? r))
  (check-true (string-contains? r ":b1"))
  (check-false (string-contains? r "_anon")))

(test-case "POL.2: explain rows drop anon keys (answer-result path)"
  (define r (run-ns-ws-last (string-append FIXTURE "explain (truths b1 b2 b3 _)")))
  (check-true (string? r))
  (check-false (string-contains? r "_anon")))

;; ── POL.5: def := solve(…) — the spurious multiplicity violation ─────────────
;; The qtt expr-goal-app arm propagated the goal HEAD's inferQ failure (the
;; head is a raw relational symbol — no inferQ arm) as tu-error, poisoning
;; every def-bound solve into checkQ-top's generic "Multiplicity violation".
;; Fixed 2026-07-24: the head contributes zero usage when un-inferQ-able
;; (mirroring typing-core's discard). Owner repro: def := solve (movies …).

(define POL5-FIXTURE
  (string-append
   "ns pol5test\n"
   "defr edge [?a ?b]\n"
   "  || 1 2\n"
   "     2 3\n"
   "defr reach [?x ?z]\n"
   "  &> (edge x z)\n"
   "  &> (edge x y) (reach y z)\n"))

(test-case "POL.5: def binds a solve over a FACTS relation (no multiplicity violation)"
  (define r (run-ns-ws-last (string-append POL5-FIXTURE "def frows := solve (edge a b)\nfrows")))
  (check-true (string? r))
  (check-false (string-contains? r "Multiplicity") r)
  (check-true (string-contains? r ":a") "bound value holds the rows"))

(test-case "POL.5: def binds a solve over a RULE relation; solve-one row projects"
  (define r (run-ns-ws-last
             (string-append POL5-FIXTURE
                            "def one := solve-one (reach x z)\n"
                            "one.z")))
  (check-true (string? r))
  (check-false (string-contains? r "Multiplicity") r)
  (check-true (string-contains? r ": Int")
              "def-bound solve-one row projects a typed field — the motivating composition"))

(test-case "POL.2: STATIC row labels drop anon keys too (CbC key agreement)"
  ;; goal-app-row (typing-core) filters via the SAME kernel predicate, so on a
  ;; facts-only relation (where static rows exist since B2) the static type and
  ;; the runtime row agree: no :_anon field on either side.
  (define r (run-ns-ws-last
             (string-append "ns poltest2\n"
                            "defr data [?k ?s]\n"
                            "  || 1 \"a\"\n"
                            "     2 \"b\"\n"
                            "solve (data _ s)")))
  (check-true (string? r))
  (check-true (string-contains? r ":s String") "static row keeps the named field")
  (check-false (string-contains? r "_anon") "no anon field in the static type either"))
