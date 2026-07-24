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
  ;; dedup is out of scope here). 16 rows = 16 `{`-opens after the list-open.
  (check-equal? (length (regexp-match* #rx"[{]" r)) 16
                "answer count unchanged by projection (duplicates preserved)"))

(test-case "POL.2: all-anon query projects to empty rows (membership-style)"
  (define r (run-ns-ws-last (string-append FIXTURE "solve (truths _ _ _ _)")))
  (check-true (string? r))
  (check-false (string-contains? r "_anon"))
  (check-false (string-contains? r ":b") "no named keys either")
  (check-equal? (length (regexp-match* #rx"[{][}]" r)) 16
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
