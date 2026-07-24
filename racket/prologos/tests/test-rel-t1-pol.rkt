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
         "test-support.rkt"
         (only-in "../errors.rkt" prologos-error? prologos-error-message)
         (only-in "../performance-counters.rkt"
                  with-perf-counters perf-counters-solver-row-scans)
         (only-in "../pnet-serialize.rkt"
                  deep-struct->serializable deep-serializable->struct)
         (only-in "../champ.rkt" champ-empty champ-insert champ-entries)
         (only-in "../syntax.rkt" expr-champ expr-champ? expr-champ-racket-champ
                  expr-keyword expr-keyword-name expr-int))

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

;; ── POL.10 (LANDED 2026-07-24, second pass — owner-ruled SNAPSHOT semantics):
;; `def` binds the WHNF-reduced value. Evaluation runs once at definition;
;; mentions read the value. WHNF (never nf): expr-lam is whnf-trivial, so
;; lambda-valued defs store unchanged — the first-pass collisions were all
;; nf-under-binder casualties and dissolve at whnf. Effects cannot reach a
;; def body (capability-gated, params-only ⇒ always under a binder).

(test-case "POL.10: a def-bound solve runs the solver ONCE — mentions add no scans"
  (define (scans-of program)
    (define-values (_ pc) (with-perf-counters (run-ns-ws-last program)))
    (perf-counters-solver-row-scans pc))
  (define base (string-append POL5-FIXTURE "def rows := solve (edge a b)\n"))
  (define with-uses (string-append base "rows\nrows\nrows"))
  (check-equal? (scans-of with-uses) (scans-of base)
                "three mentions of the def-bound rows must add ZERO row scans"))

(test-case "POL.10: def is a SNAPSHOT — a later defr does not change a bound solve"
  ;; Owner F1 ruling (2026-07-24): a binding denotes ONE value (the `random`
  ;; category-error principle). Recipe-style invalidation is Rel T2 IVM work.
  (define r (run-ns-ws-last
             (string-append POL5-FIXTURE
                            "def rows := solve (edge a b)\n"
                            "defr edge [?a ?b]\n"
                            "  || 7 8\n"
                            "rows")))
  (check-true (string? r))
  (check-false (string-contains? r ":a 7")
               "rows snapshot predates the second defr — must not see 7/8"))

(test-case "POL.10: lambda-valued defs are whnf-trivial — stored & applied unchanged"
  (define r (run-ns-ws-last
             (string-append "ns pol10fn\n"
                            "spec make-adder Int -> [Int -> Int]\n"
                            "defn make-adder [n]\n"
                            "  [fn [x : Int] [+ n x]]\n"
                            "def add5 := [make-adder 5]\n"
                            "[add5 37]")))
  (check-true (string-contains? r "42") "function-producing def constructs once and applies"))

(test-case "POL.10: expr-champ pnet round-trip (reconstructive champ-sentinel)"
  ;; def now binds reduced values, so champ rows can reach module env
  ;; snapshots — the sentinel serializes entries and rebuilds via champ-insert
  ;; (hashes recomputed at read; equal-hash-code is process-stable only).
  (define k1 (expr-keyword 'a))
  (define k2 (expr-keyword 'b))
  (define c (champ-insert (champ-insert champ-empty
                                        (equal-hash-code k1) k1 (expr-int 1))
                          (equal-hash-code k2) k2 (expr-int 2)))
  (define rt (deep-serializable->struct (deep-struct->serializable (expr-champ c))))
  (check-true (expr-champ? rt) "round-trips as an expr-champ, not a vector impostor")
  (define entries
    (sort (map (lambda (kv) (cons (car kv) (cdr kv)))
               (champ-entries (expr-champ-racket-champ rt)))
          (lambda (x y) (symbol<? (expr-keyword-name (car x)) (expr-keyword-name (car y))))))
  (check-equal? (length entries) 2)
  (check-equal? (cdr (car entries)) (expr-int 1))
  (check-equal? (cdr (cadr entries)) (expr-int 2)))

;; ── POL.4: arity mismatch is a HARD ERROR (owner-ruled: Prolog-style) ────────
;; Under- and over-application both errored silently before (nil / unbound-echo
;; rows — the D.2.c arity-lenient trap). Now: exn:prologos-solve raised at the
;; engine entries, converted at the command boundary to a per-command ERROR so
;; the file/REPL continues. The internal `goal-args='()` enumerate convention
;; (0-arg surface call) is preserved.

;; An arity error surfaces as a per-command prologos-error STRUCT — read its
;; message (the run-ns-ws-last raw result is not a string for error results).
(define (result-msg r) (if (prologos-error? r) (prologos-error-message r) r))

(test-case "POL.4: under-application errors with the available-arities diagnostic"
  (define m (result-msg (run-ns-ws-last (string-append FIXTURE "solve (truths b)"))))
  (check-true (string-contains? m "Unknown procedure: truths/1") m)
  (check-true (string-contains? m "definitions for: truths/4") m))

(test-case "POL.4: over-application errors likewise"
  (define m (result-msg (run-ns-ws-last (string-append FIXTURE "solve (truths b1 b2 b3 b4 b5)"))))
  (check-true (string-contains? m "Unknown procedure: truths/5") m))

(test-case "POL.4: correct arity + 0-arg enumerate both still work"
  (define ok (run-ns-ws-last (string-append FIXTURE "solve (bool x)")))
  (check-true (string-contains? ok ":x") "correct arity solves")
  (define enum (run-ns-ws-last (string-append FIXTURE "solve (bool)")))
  (check-false (string-contains? enum "Unknown procedure")
               "0-arg surface call keeps the enumerate convention"))

(test-case "POL.4: rule-BODY wrong-arity goals error too (solve-app-goal gate)"
  (define m (result-msg
             (run-ns-ws-last
              (string-append FIXTURE
                             "defr badrule [?x]\n  &> (truths x)\n"
                             "solve (badrule v)"))))
  (check-true (string-contains? m "Unknown procedure: truths/1") m))

(test-case "POL.4: unknown relation now presents as a per-command ERROR (file continues)"
  (define r (run-ns-ws-last (string-append FIXTURE "solve (nosuch x)\nsolve (bool y)")))
  ;; last result = the FOLLOWING command — proof the run continued past the error
  (check-true (string-contains? r ":y") "the command after the error still ran"))
