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

;; ── SUB.1: substitution containment tripwire (POL.10 spin-out) ───────────────
;; docs/tracking/2026-07-24_SUBSTITUTION_CONTAINMENT_DEFECT.md — ruling (D).
;; The LIVE bug: nf-under-binder mints an open champ (a lambda whose body is a
;; map literal referencing the lambda's param); shift/subst treat containers
;; as closed leaves, so a later beta silently drops the argument — `?bvar0`
;; escaped to top level TYPED with 0 errors. Until SUB.3 (NbE open-the-binder)
;; makes the shape unconstructible, the tripwire at the three nf-persisting
;; boundaries (solve/solve-one is-goal answer rows + validate base-ok) refuses
;; to persist it: loud per-command exn:prologos-solve, the run continues.
;; ⚠ FLIP AT SUB.3: the poisoned cases below become correct-answer assertions
;; (6N — see the defect doc §5 E2E) when the fix lands.

(define SUBFIX
  (string-append
   "ns subtrip\n"
   "spec ctrl [Map Keyword <Nat -> Nat>] -> Nat\n"
   "defn ctrl [p]  [[get p :f] 5N]\n"
   "spec bug [Map Keyword <Nat -> [Map Keyword Nat]>] -> Nat\n"
   "defn bug [p]  [get [[get p :f] 5N] :a]\n"))

(test-case "SUB.1: the CONTROL still computes — closed lambda in an answer row"
  (define r (run-ns-ws-last
             (string-append SUBFIX
                            "[ctrl (solve-one (is ?f [fn [y : Nat] [add y 1N]]))]")))
  (check-true (string-contains? (result-msg r) "6N") (result-msg r)))

;; ⚠ FLIPPED AT SUB.3 (ruling D — NbE open-the-binder): the formerly-poisoned
;; shapes now compute the CORRECT answers (the defect doc §5 E2E). The SUB.1
;; tripwire remains installed as the standing invariant guard at the three
;; nf-persisting boundaries — these tests double as its no-false-positive
;; gates (any tripwire fire below would surface as a prologos-error).

(test-case "SUB.3: map-returning lambda through solve-one computes (was ?bvar0)"
  (define r (run-ns-ws-last
             (string-append SUBFIX
                            "[bug (solve-one (is ?f [fn [y : Nat] {:a y}]))]")))
  (define m (result-msg r))
  (check-false (prologos-error? r) m)
  (check-true (string-contains? m "5N") m)
  (check-false (string-contains? m "?bvar") "no open index escapes"))

(test-case "SUB.3: solve (list form) carries the safe lambda row"
  (define r (run-ns-ws-last
             (string-append SUBFIX
                            "solve (is ?f [fn [y : Nat] {:a y}])")))
  (define m (result-msg r))
  (check-false (prologos-error? r) m)
  (check-false (string-contains? m "?bvar") m)
  (check-true (string-contains? m ":f") "the answer row materializes"))

(test-case "SUB.3: both shapes in sequence — later commands see clean state"
  (define r (run-ns-ws-last
             (string-append SUBFIX
                            "solve (is ?f [fn [y : Nat] {:a y}])\n"
                            "[ctrl (solve-one (is ?f [fn [y : Nat] [add y 1N]]))]")))
  (check-true (string-contains? (result-msg r) "6N") (result-msg r)))

(test-case "SUB.3: validate accepts map-returning-lambda fields (was refused)"
  (define VS
    (string-append
     "ns subtripv\n"
     "schema FnBox\n"
     "  :f <Nat -> [Map Keyword Nat]>\n"
     "schema FnBox2\n"
     "  :f <Nat -> Nat>\n"))
  (define was-bad (run-ns-ws-last
                   (string-append VS "[validate FnBox {:f [fn [y : Nat] {:a y}]}]")))
  (check-false (prologos-error? was-bad) (result-msg was-bad))
  (check-true (string-contains? (result-msg was-bad) "ok") (result-msg was-bad))
  (define ok (run-ns-ws-last
              (string-append VS "[validate FnBox2 {:f [fn [y : Nat] [add y 1N]]}]")))
  (check-true (string-contains? (result-msg ok) "ok") (result-msg ok)))

;; ── SUB.3b: narrow-subst-bvars + narrow-match containment (the wider sibling) ─
;; The narrowing walker's [_ expr] catch-all silently DROPPED bindings for
;; every unlisted node (map/set/vec spines included), and narrow-match had no
;; map/vec decomposition — so `box ?y = {:a 5N}` on `defn box [x] {:a x}`
;; returned nil with 0 errors. Fixed: generic transparent-struct rebuild
;; fallback + explicit Pi/Sigma binder arms (+ the lam TYPE field) in
;; narrow-subst-bvars; entry-wise map + element-wise vec decomposition in
;; narrow-match (logic vars inside values bind).

(require (only-in "../narrowing.rkt" narrow-subst-bvars)
         (only-in "../syntax.rkt"
                  expr-map-assoc expr-map-empty expr-hole expr-bvar
                  expr-nat-val expr-fst expr-Pi expr-Nat expr-map-assoc-v))

(define NARFIX
  (string-append
   "ns subnarrow\n"
   "spec box Nat -> [Map Keyword Nat]\n"
   "defn box [x] {:a x}\n"
   "spec wrap Nat -> (PVec Nat)\n"
   "defn wrap [x] @[x 1N]\n"
   "spec nest Nat -> [Map Keyword [Map Keyword Nat]]\n"
   "defn nest [x] {:outer {:inner x}}\n"))

(test-case "SUB.3b: map-literal RHS narrows (was nil)"
  (define r (run-ns-ws-last (string-append NARFIX "box ?y = {:a 5N}")))
  (check-true (string-contains? (result-msg r) ":y 5N") (result-msg r)))

(test-case "SUB.3b: vec-literal RHS narrows"
  (define r (run-ns-ws-last (string-append NARFIX "wrap ?y = @[5N 1N]")))
  (check-true (string-contains? (result-msg r) ":y 5N") (result-msg r)))

(test-case "SUB.3b: nested map RHS narrows through both levels"
  (define r (run-ns-ws-last (string-append NARFIX "nest ?y = {:outer {:inner 7N}}")))
  (check-true (string-contains? (result-msg r) ":y 7N") (result-msg r)))

(test-case "SUB.3b: key-set mismatch does NOT match"
  (define r (run-ns-ws-last
             (string-append NARFIX
                            "spec boxm Nat -> [Map Keyword Nat]\n"
                            "defn boxm [x] {:a x :b 2N}\n"
                            "boxm ?z = {:a 9N}")))
  (check-true (string-contains? (result-msg r) "nil") (result-msg r)))

(test-case "SUB.3b unit: the walker substitutes through a map-assoc spine"
  (define spine (expr-map-assoc (expr-map-empty (expr-hole) (expr-hole))
                                (expr-keyword ':a) (expr-bvar 0)))
  (define out (narrow-subst-bvars spine (list (expr-nat-val 5)) 0))
  (check-equal? (expr-map-assoc-v out) (expr-nat-val 5)
                "the binding reaches the spine value"))

(test-case "SUB.3b unit: generic fallback covers formerly-skipped nodes"
  ;; expr-fst previously fell to [_ expr] — binding silently dropped
  (define out (narrow-subst-bvars (expr-fst (expr-bvar 0))
                                  (list (expr-nat-val 3)) 0))
  (check-equal? out (expr-fst (expr-nat-val 3))))

(test-case "SUB.3b unit: Pi codomain is a BINDER position (no capture)"
  ;; bvar0 under the Pi codomain refers to the Pi's own var — bindings at
  ;; depth 0 must NOT reach it; bvar1 there is the outer slot and must.
  (define pi (expr-Pi 'mw (expr-Nat) (expr-bvar 0)))
  (check-equal? (narrow-subst-bvars pi (list (expr-nat-val 9)) 0) pi
                "the codomain's own var stays bound")
  (define pi2 (expr-Pi 'mw (expr-Nat) (expr-bvar 1)))
  (check-equal? (narrow-subst-bvars pi2 (list (expr-nat-val 9)) 0)
                (expr-Pi 'mw (expr-Nat) (expr-nat-val 9))
                "the outer slot substitutes at depth+1"))

;; ── POL.3: declaration-order keys for solve echoes (design §8) ───────────────
;; Rows are champs (hash-ordered), so `solve (truths b1 b2 b3 _)` displayed
;; `{:b3 1, :_anon… 1, :b2 1, :b1 1}`. The declaration order lives in the goal's
;; positional query vars (B0's classify-goal-args, minus POL.2's anons) and is
;; applied at the eval echo seam, DISPLAY-ONLY: the row VALUE stays an unordered
;; champ, and a def-bound echo (no goal in hand) stays hash-ordered — the named
;; fallback, until an order-carrying row representation (Rel T2 territory).

(test-case "POL.3: solve keys display in declaration order"
  (define r (run-ns-ws-last (string-append FIXTURE "solve (truths b1 b2 b3 _)")))
  (check-true (string? r))
  (check-true (string-contains? r "{:b1 1, :b2 1, :b3 1}")
              "first row in declaration order (was hash order)"))

(test-case "POL.3: DECLARATION order, not alphabetical"
  (define r (run-ns-ws-last
             (string-append "ns p3\n"
                            "defr za [?z ?a]\n  || 1 2\n     3 4\n"
                            "solve (za z a)")))
  (check-true (string-contains? r "{:z 1, :a 2}")
              "z declared first displays first, though a < z alphabetically"))

(test-case "POL.3: solve-one bare row is ordered too"
  (define r (run-ns-ws-last (string-append FIXTURE "solve-one (truths b1 b2 b3 _)")))
  (check-true (string-contains? r "{:b1 1, :b2 1, :b3 1}")))

(test-case "POL.3: explain puts query keys first, metadata after"
  (define r (run-ns-ws-last
             (string-append "ns p3\n"
                            "defr za [?z ?a]\n  || 1 2\n     3 4\n"
                            "explain (za z a)")))
  (check-true (string-contains? r "{:z 1, :a 2, :provenance")
              "query keys lead; reserved metadata keys follow"))

(test-case "POL.3: anonymous rel uses its param declaration order"
  (define r (run-ns-ws-last
             (string-append "ns p3\n"
                            "defr za [?z ?a]\n  || 1 2\n     3 4\n"
                            "solve (rel [q p]\n  &> (za q p))")))
  (check-true (string-contains? r "{:q 1, :p 2}")))

(test-case "POL.3: def-bound echo is the NAMED fallback (displays, unordered)"
  (define r (run-ns-ws-last
             (string-append "ns p3\n"
                            "defr za [?z ?a]\n  || 1 2\n     3 4\n"
                            "def rr := solve (za z a)\n"
                            "rr")))
  ;; no goal in hand at the echo — hash order; assert it still displays both keys
  (check-true (string? r))
  (check-true (and (string-contains? r ":z 1") (string-contains? r ":a 2"))))
