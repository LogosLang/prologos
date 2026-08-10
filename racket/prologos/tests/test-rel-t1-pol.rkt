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
         racket/list
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

;; ── POL.7: single-line facts with `|` row separators (design §8) ─────────────
;; `|` tokenizes as the bare `$pipe` symbol and previously flowed into
;; parse-datum as a GARBAGE TERM (`|| 0 | 1 | 2` silently produced `unknown`
;; rows — probed, not inferred). Now: pipes = EXPLICIT rows (each segment must
;; match the arity exactly; empty segments error); without pipes the
;; pre-existing arity-chunking stands but a partial remainder is a LOUD error
;; instead of a silent dead row (the Watching-3 spurious-empty-results trap,
;; closed at the source). One shared splitter serves the flat and
;; continuation-line sites. Sexp mode untouched by construction (`|` is a
;; symbol-escape char in the Racket reader).

(test-case "POL.7: the owner's digits example — ten rows from one line"
  (define r (run-ns-ws-last
             (string-append "ns p7\n"
                            "defr digits [?d]\n"
                            "  || 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9\n"
                            "solve (digits d)")))
  (check-true (string? r))
  (check-true (string-contains? r "{:d 0}"))
  (check-true (string-contains? r "{:d 9}"))
  (check-false (string-contains? r "unknown") "no garbage `unknown` rows")
  (check-equal? (length (regexp-match* #rx"[{]" (car (regexp-split #rx" : " r)))) 10))

(test-case "POL.7: binary rows with pipes"
  (define r (run-ns-ws-last
             (string-append "ns p7\n"
                            "defr e2 [?a ?b]\n  || 1 2 | 3 4\n"
                            "solve (e2 a b)")))
  (check-true (string-contains? r "{:a 1, :b 2}"))
  (check-true (string-contains? r "{:a 3, :b 4}")))

(test-case "POL.7: pipes work on continuation lines too"
  (define r (run-ns-ws-last
             (string-append "ns p7\n"
                            "defr m [?x]\n  || 0 | 1\n     2 | 3\n"
                            "solve (m x)")))
  (check-equal? (length (regexp-match* #rx"[{]" (car (regexp-split #rx" : " r)))) 4))


;; ── DEFERRED 66: a COMPOUND TERM on the `||` line is a TERM, not a nested row ──
;;
;; The WS reader turns deeper-indented continuation rows into nested sublists
;; inside the `$facts-sep`, so the facts arm partitioned "pair => nested row",
;; whitelisting only the numeric-literal sentinels ($nat-literal, ...). Any OTHER
;; compound term — a constructor application, a list literal, a map — is also a
;; pair, so it was misclassified as a continuation row and SPLAYED into its
;; constituent tokens, fabricating rows the user never wrote, with ZERO errors:
;;     || [some 1]   ->  @[{:q unknown} {:q 1}]           TWO rows from one
;;     || '[1 2]     ->  @[{:q unknown} {:q 1} {:q 2}]    THREE rows from one
;;
;; Measured byte-identical at b429d038, so this is pre-existing, not G2/52 fallout.
;;
;; The discriminator is the SENTINEL'S LINE. A continuation row is BY DEFINITION
;; on a later line than the `||`; anything on the `||` line itself belongs to the
;; first row. Verified by instrumenting the reader: for `|| 1 2 / 3 4` the
;; sentinel is line 3 and the nested `(3 4)` is line 4, while for `|| [some 1]`
;; the sentinel and the compound are BOTH line 6.
;;
;; ⚠ Why not a positive bracket-origin marker (the cleaner inversion): parser.rkt
;; already records that a bracket group and a bare multi-token line are
;; "indistinguishable post-reader — same wrap-stx-list, no origin". Adding that
;; origin is a reader-wide change that also governs POL.8 clause grammar. Hence
;; the line rule, plus the RESIDUAL pinned below.

(test-case "DEFERRED 66: a constructor application on the `||` line is ONE term"
  (define r (run-ns-ws-last
             (string-append "ns d53\n"
                            "defr r2 [?a]\n  || [some 1]\n"
                            "solve (r2 q)")))
  (check-true (string? r) (result-msg r))
  ;; THE GUARANTEE IS THE ROW COUNT. Pre-fix this splayed into TWO rows
  ;; (`unknown`, `1`). Whether the compound VALUE then round-trips is a separate,
  ;; pre-existing gap — see the residual pin below — so do NOT assert on the
  ;; rendered value here or this test starts failing for an unrelated reason.
  (check-equal? (length (regexp-match* #rx"[{]" (car (regexp-split #rx" : " r)))) 1
                (format "exactly ONE row, not the splayed two; got: ~a" r)))

(test-case "DEFERRED 66: a list literal on the `||` line is ONE term"
  (define r (run-ns-ws-last
             (string-append "ns d53\n"
                            "defr r3 [?a]\n  || '[1 2]\n"
                            "solve (r3 q)")))
  (check-true (string? r) (result-msg r))
  ;; Pre-fix: THREE rows (`unknown`, `1`, `2`). Row count is the guarantee.
  (check-equal? (length (regexp-match* #rx"[{]" (car (regexp-split #rx" : " r)))) 1
                (format "exactly ONE row, not the splayed three; got: ~a" r)))

(test-case "DEFERRED 66: a map term beside a scalar fills a 2-arity row"
  ;; Pre-fix `{:k 1}` splayed into 2 terms, making 3 for arity 2 — the ONLY
  ;; shape that got caught, and only by accident.
  (define r (run-ns-ws-last
             (string-append "ns d53\n"
                            "defr r4 [?a ?b]\n  || {:k 1} 2\n"
                            "solve (r4 p q)")))
  (check-true (string? r) (result-msg r))
  (check-equal? (length (regexp-match* #rx"[{][:]p" (car (regexp-split #rx" : " r)))) 1
                (format "exactly ONE row; got: ~a" r)))

(test-case "control: multi-line continuation rows still split into rows"
  ;; The rule must not swallow the feature it is distinguishing against.
  (define r (run-ns-ws-last
             (string-append "ns d53\n"
                            "defr mr [?a ?b]\n  || 1 2\n     3 4\n"
                            "solve (mr p q)")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "{:p 1, :q 2}") r)
  (check-true (string-contains? r "{:p 3, :q 4}") r))

(test-case "control: a nat-literal term on the `||` line is still one term"
  (define r (run-ns-ws-last
             (string-append "ns d53\n"
                            "defr nr [?a]\n  || 1N | 2N\n"
                            "solve (nr q)")))
  (check-true (string? r) (result-msg r))
  (check-equal? (length (regexp-match* #rx"[{]" (car (regexp-split #rx" : " r)))) 2 r))

(test-case "DEFERRED 66: a STRUCTURAL sentinel heading a continuation line is a ROW, not a term"
  ;; ⚠ REGRESSION GUARD for the first version of the `$`-headed inversion, which
  ;; asserted "inside fact CONTENT a `$`-headed pair is always ONE VALUE". FALSE:
  ;; the reader wraps a continuation LINE by its FIRST TOKEN, so a line starting
  ;; with a structural sentinel arrives as `($pipe 3 4)` / `($clause-sep …)` /
  ;; `($facts-sep …)`. Treating those as terms turned this ordinary leading-pipe
  ;; table from a LOUD "empty row beside `|`" into TWO FABRICATED rows carrying
  ;; the raw sentinel — `@[{:d 0} {:d [?$pipe 1]} {:d [?$pipe 2]}]`, zero errors —
  ;; i.e. it moved a new shape INTO the very bug class being fixed. Caught by the
  ;; adversarial verify. If this test ever goes silent, the inversion has lost its
  ;; structural-sentinel exclusion again.
  (define m (result-msg (run-ns-ws-last
                         ;; NB: the `defr` must be the LAST command — run-ns-ws-last
                         ;; returns only the last result, and a trailing query would
                         ;; report the downstream "Unknown relation" instead of the
                         ;; row error this test is about.
                         (string-append "ns d53s\n"
                                        "defr digit [?d]\n  || 0\n   | 1\n   | 2\n"))))
  (check-true (string-contains? m "empty row beside")
              (format "must stay LOUD; got: ~a" m))
  (check-false (string-contains? m "$pipe")
               (format "and must never leak the raw sentinel; got: ~a" m)))

(test-case "DEFERRED 66 (residual CLOSED by 51c): a preparse rewrite no longer disables the line rule"
  ;; ⚠ INVERTED. This was DEFERRED 66's dominant residual: rule (B) needed
  ;; trustworthy srclocs, and any preparse rewrite in the defr destroyed them, so
  ;; an idiomatic `|>` or dot-access ANYWHERE silently restored the fabricated
  ;; rows — action at a distance. 51(c) preserves the srclocs, so the line rule
  ;; now applies and the compound stays ONE row.
  (define r (run-ns-ws-last
             (string-append "ns d53d\n"
                            "defr degr [?a ?b]\n"
                            "  || [some 1] 2\n"
                            "  &> (= a [|> 1 inc])\n"
                            "solve (degr p q)")))
  (check-true (string? r) (result-msg r))
  (define row1 (car (regexp-split #rx"[}]" (car (regexp-split #rx" : " r)))))
  (check-true (string-contains? row1 ":q 2")
              (format "the fact row must survive intact as ONE row; got: ~a" r)))

(test-case "DEFERRED 66: a $-headed compound on a CONTINUATION line IS fixed (and keeps row ORDER)"
  ;; Change (A) is not limited to the `||` line: it is srcloc-independent, so a
  ;; `$`-headed compound anywhere in the content is a term. This also fixes the
  ;; REORDERING the splay caused — nested rows are appended AFTER all flat rows
  ;; (`(append flat-rows other-rows)`), so pre-fix this produced 1, 4, then the
  ;; splayed 2, 3. The narrower residual pinned below is specifically about
  ;; NON-$-headed compounds on a continuation line.
  (define r (run-ns-ws-last
             (string-append "ns d53c\n"
                            "defr cont [?a]\n  || 1\n     '[2 3]\n     4\n"
                            "solve (cont q)")))
  (check-true (string? r) (result-msg r))
  (define vals (car (regexp-split #rx" : " r)))
  (check-equal? (length (regexp-match* #rx"[{]" vals)) 3
                (format "three rows, not four; got: ~a" r))
  ;; ⚠ UPDATED at the 2026-08-05 merge — this asserted `1.*unknown.*4`, and the
  ;; `unknown` was the representation gap the sibling test below pinned. This
  ;; branch CLOSED that gap (`10f5a080`, "a collection literal survives the
  ;; AST↔solver round trip"), so the middle row now renders its actual value.
  ;; The property under test was always SOURCE ORDER, not the gap; it is now
  ;; asserted against the real value instead of against a placeholder.
  (check-true (regexp-match? #rx"1.*2 3.*4" vals)
              (format "and in SOURCE order; got: ~a" r)))

(test-case "DEFERRED 66 RESIDUAL: a compound fact VALUE round-trips; its TYPE does not"
  ;; Removing the splay makes compound terms REACH the solver, where a
  ;; pre-existing representation gap shows: they render as `unknown`. This is NOT
  ;; caused by the splay fix and is not specific to fact rows — the same values in
  ;; plain relational term position do it with no `||` involved:
  ;;     (= y '[1 2])  → @[{:y unknown}]     (= z {:k 1}) → @[{:z unknown}]
  ;; (`(= x [some 1])` DOES render, so the gap is per-shape, not universal.)
  ;; Pinned so the row-count fix above is not misread as making compound facts
  ;; WORK, and so that closing the representation gap flags here.
  (define r (run-ns-ws-last
             (string-append "ns d53\n"
                            "defr rl [?a]\n  || '[1 2]\n"
                            "solve (rl q)")))
  (check-true (string? r) (result-msg r))
  ;; ⚠ INVERTED at the 2026-08-05 merge, exactly as this test asked ("Pinned …
  ;; so that closing the representation gap flags here"). It did flag. This
  ;; branch closed the VALUE half in `10f5a080`: the row now renders `{:q '[1 2]}`
  ;; where it rendered `{:q unknown}`.
  ;;
  ;; The TYPE half is still open — the result types as `[PVec {:q <error>}]`. So
  ;; the assertion is split rather than deleted: the value must round-trip, and
  ;; the type gap is pinned AS a gap, so closing it flags here too. Deleting the
  ;; test would have discarded a live signal for a still-open defect.
  (check-true (string-contains? r "'[1 2]")
              (format "the compound VALUE must round-trip now; got: ~a" r))
  (check-false (string-contains? r "{:q unknown}")
               (format "no placeholder should remain; got: ~a" r))
  (check-true (string-contains? r "<error>")
              (format "TYPE half still open — if this fails the gap closed, update it; got: ~a" r)))

(test-case "DEFERRED 66 RESIDUAL: a NON-$-headed compound on a CONTINUATION line is still splayed"
  ;; Pinned as a KNOWN LIMIT, not as desired behaviour. Narrow by design: only
  ;; NON-$-headed compounds (a bracket group like `[some 2]`); the $-headed case
  ;; is fixed by change (A) — see the test above. On a continuation line the
  ;; reader has already spliced the bracket group away, so `[some 2]` and a bare
  ;; two-token row `some 2` are the same datum — genuinely undecidable here.
  ;; Closing it needs the reader-side origin marker described above. If this test
  ;; ever FAILS because the row count dropped to 2, that is the fix landing, and
  ;; this pin should be inverted rather than deleted.
  (define r (run-ns-ws-last
             (string-append "ns d53\n"
                            "defr mx [?a]\n  || 1\n     [some 2]\n"
                            "solve (mx q)")))
  (check-true (string? r) (result-msg r))
  (check-equal? (length (regexp-match* #rx"[{]" (car (regexp-split #rx" : " r)))) 3
                (format "known limit: 1 + splayed(some,2) = 3 rows; got: ~a" r)))

(test-case "POL.7: wrong-length pipe segment is a loud error"
  (define m (result-msg (run-ns-ws-last
                         (string-append "ns p7\n"
                                        "defr e [?a ?b]\n  || 1 2 | 3 4 5\n"))))
  (check-true (string-contains? m "3 terms") m)
  (check-true (string-contains? m "arity is 2") m))

(test-case "POL.7: empty pipe segment is a loud error"
  (define m (result-msg (run-ns-ws-last
                         (string-append "ns p7\n"
                                        "defr e [?x]\n  || 1 | | 2\n"))))
  (check-true (string-contains? m "empty row") m))

(test-case "POL.7: a partial remainder WITHOUT pipes now errors (was a silent dead row)"
  (define m (result-msg (run-ns-ws-last
                         (string-append "ns p7\n"
                                        "defr e [?a ?b]\n  || 1 2 3 4 5\n"))))
  (check-true (string-contains? m "5 terms do not fill rows of arity 2") m))

(test-case "POL.7: legacy exact-multiple chunking still works (no pipes)"
  (define r (run-ns-ws-last
             (string-append "ns p7\n"
                            "defr leg [?x]\n  || 5 3\n"
                            "solve (leg x)")))
  (check-true (string-contains? r "{:x 5}"))
  (check-true (string-contains? r "{:x 3}")))

(test-case "POL.7: classic multi-line facts unchanged"
  (define r (run-ns-ws-last
             (string-append "ns p7\n"
                            "defr c [?k]\n  || 7\n     8\n"
                            "solve (c k)")))
  (check-true (string-contains? r "{:k 7}"))
  (check-true (string-contains? r "{:k 8}")))

;; ========================================================================
;; POL.8 — implicit rule-clause groups: layout-based parenless goals in
;; defr/rel `&>` bodies (owner co-design 2026-07-25; design §8 POL.8).
;; Grammar: goal-ness from defr-body context; the `&>` line's head token
;; decides (pair → paren-goal sequence, symbol → ONE bare goal); a grouped
;; continuation line is a sibling at any indent (Q5 lenient — paren groups
;; and bare ≥2-token lines are indistinguishable post-reader); single-token
;; lines are column-classified LOUDLY. Both spellings stay legal.
;; These run through process-string-ws (L2) — which also pins the tree-spine
;; duplicate parse (srcloc-stripped, surf discarded) staying harmless.
;; ========================================================================

(define P8FIX
  (string-append
   "ns p8\n"
   "defr fruit-color [?fruit ?color]\n"
   "  || \"blueberry\" \"blue\"\n"
   "  || \"banana\" \"yellow\"\n"
   "  || \"cherry\" \"red\"\n"))

(test-case "POL.8: bare single-goal clauses; two clauses stay a disjunction (owner form 1)"
  (define r (run-ns-ws-last
             (string-append P8FIX
                            "defr boy [?fruit]\n"
                            "  &> fruit-color fruit \"blue\"\n"
                            "  &> fruit-color fruit \"yellow\"\n"
                            "solve (boy f)")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "blueberry"))
  (check-true (string-contains? r "banana"))
  (check-false (string-contains? r "cherry")))

(test-case "POL.8: bare goal + sibling `not (…)` at the goal column (owner form 2)"
  (define r (run-ns-ws-last
             (string-append P8FIX
                            "defr fnoc [?fruit ?not-color]\n"
                            "  &> fruit-color fruit color\n"
                            "     not (= color not-color)\n"
                            "solve (fnoc f \"red\")")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "blueberry"))
  (check-true (string-contains? r "banana"))
  (check-false (string-contains? r "cherry")))

(test-case "POL.8: nested bare `not` — deeper line is its goal argument (owner form 3)"
  (define r (run-ns-ws-last
             (string-append P8FIX
                            "defr fnoc2 [?fruit ?not-color]\n"
                            "  &> fruit-color fruit color\n"
                            "     not\n"
                            "       = color not-color\n"
                            "solve (fnoc2 f \"red\")")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "blueberry"))
  (check-true (string-contains? r "banana"))
  (check-false (string-contains? r "cherry")))

(test-case "POL.8: bare and paren spellings are equivalent (same rows)"
  (define bare (run-ns-ws-last
                (string-append P8FIX
                               "defr b [?f]\n  &> fruit-color f \"blue\"\n"
                               "solve (b q)")))
  (define paren (run-ns-ws-last
                 (string-append P8FIX
                                "defr b [?f]\n  &> (fruit-color f \"blue\")\n"
                                "solve (b q)")))
  (check-equal? bare paren))

(test-case "POL.8/Q5: sloppy-indent paren continuation stays a SIBLING (lenient)"
  ;; conjunction semantics pinned: same fruit must have both colors -> empty
  (define r (run-ns-ws-last
             (string-append P8FIX
                            "defr both [?f]\n"
                            "  &> (fruit-color f \"blue\")\n"
                            "        (fruit-color f \"yellow\")\n"
                            "solve (both q)")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "@[]") "conjunction of two colors is unsatisfiable"))

(test-case "POL.8: single-token deeper line continues the `&>`-line bare goal"
  (define r (run-ns-ws-last
             (string-append P8FIX
                            "defr cont [?f]\n"
                            "  &> fruit-color f\n"
                            "       \"blue\"\n"
                            "solve (cont q)")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "blueberry")))

(test-case "POL.8: zero-arg sibling goal at the goal column"
  (define r (run-ns-ws-last
             (string-append P8FIX
                            "defr always []\n  ||\n"
                            "defr z [?f]\n"
                            "  &> fruit-color f \"blue\"\n"
                            "     always\n"
                            "solve (z q)")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "blueberry")))

(test-case "POL.8/Q6: single-line bare goal (flat arm)"
  (define r (run-ns-ws-last
             (string-append P8FIX
                            "defr one [?f] &> fruit-color f \"blue\"\n"
                            "solve (one q)")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "blueberry")))

(test-case "POL.8: mis-indent between `&>` and the goal column is LOUD"
  (define m (result-msg (run-ns-ws-last
                         (string-append P8FIX
                                        "defr m [?f]\n"
                                        "  &> fruit-color f\n"
                                        "    \"blue\"\n"))))
  (check-true (string-contains? m "indented between") m)
  (check-true (string-contains? m "align") m))

(test-case "POL.8/Q2a: paren goal followed by a bare token on one line is LOUD"
  (define m (result-msg (run-ns-ws-last
                         (string-append P8FIX
                                        "defr q2a [?f]\n"
                                        "  &> (fruit-color f c) not (= c \"red\")\n"))))
  (check-true (string-contains? m "parenthesized") m)
  (check-true (string-contains? m "not") m))

(test-case "POL.8: a single token cannot extend a parenthesized goal (LOUD)"
  (define m (result-msg (run-ns-ws-last
                         (string-append P8FIX
                                        "defr x [?f]\n"
                                        "  &> (fruit-color f \"blue\")\n"
                                        "       q\n"))))
  (check-true (string-contains? m "cannot extend a parenthesized goal") m))

(test-case "POL.8 (limit LIFTED by 51c): a preparse rewrite no longer refuses parenless goals"
  ;; ⚠ THIS TEST IS INVERTED FROM ITS ORIGINAL FORM, deliberately. It used to pin
  ;; POL.8's named limit: a preparse rewrite anywhere in the defr stripped the
  ;; inner srclocs, so `parse-clause-content` detected the loss (impossible
  ;; column 0) and refused parenless goals "with guidance rather than risking a
  ;; silent mis-grouping". DEFERRED 51(c) removed the stripping —
  ;; `rebuild-preserving-locs` (macros.rkt) re-attaches per-element srclocs after
  ;; preparse — so the guidance has nothing left to detect here and the clause
  ;; simply parses. The guard itself is KEPT as a safety net for shapes the
  ;; alignment cannot recover; it is just no longer reachable this way.
  (define r (run-ns-ws-last
             (string-append P8FIX
                            "def mm := {:k \"blue\"}\n"
                            "defr d [?f]\n  &> fruit-color f mm.k\n")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "d :") (format "the defr must now register; got: ~a" r)))

(test-case "POL.8: degraded srclocs with all-paren goals still parse (old path)"
  (define r (run-ns-ws-last
             (string-append P8FIX
                            "def mm := {:k \"blue\"}\n"
                            "defr d [?f]\n"
                            "  &> (fruit-color f mm.k)\n"
                            "solve (fruit-color f \"blue\")")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "blueberry") "the file continues; d registered"))

;; ── DEFERRED 51 (chip `task_4c00d3f0`, filed 2026-08-05) ───────────────────────
;; The guard above is triggered by DEGRADED SRCLOCS, and the degradation comes
;; from `macros.rkt`'s per-form `(syntax->datum stx)` strip + the defr arm's
;; 3-arg `datum->syntax` rebuild — i.e. from a preparse rewrite ANYWHERE in the
;; defr, NOT from dot-access specifically. Its message said "(e.g. dot-access)",
;; which CIU T6 D4.P4c-4c/G2 made misleading by turning broadcast into a live
;; second trigger (postfix-index was always a third).
;;
;; Owner ruling 2026-08-05: keep the POL.8 limit; make the MESSAGE name the real
;; condition. The relation-loss half is PRE-EXISTING — measured byte-identical
;; pre/post-G2 on the dot-access spelling against a baseline worktree at
;; `ae26f540~1` — and is pinned below as the RULED behaviour so that changing it
;; later is a deliberate decision rather than drift.

;; ⚠ Relation names here are UNIQUE ON PURPOSE. `run-ns-ws-last` does NOT reset
;; `current-relation-store` (it is absent from test-support.rkt's parameterize
;; block), so relations REGISTERED BY EARLIER TESTS IN THIS FILE remain visible.
;; A pin that reuses the popular name `d` silently queries the LEAKED relation
;; from the all-paren test at :619 and passes on an empty bag — which is exactly
;; the failure mode these pins exist to catch. Caught the first time round.
(define (p8-guard-msg body)
  (result-msg (run-ns-ws-last (string-append P8FIX "def mm := {:k \"blue\"}\n" body))))

(test-case "DEFERRED 51(c): NO rewrite family refuses a parenless clause any more"
  ;; Inverted from "every rewrite family triggers the guard". All four families
  ;; degraded the srclocs before 51(c); none does now.
  (for ([spelling (in-list '("mm.k" "mm:k" "mm[0]" "\'[1 2]"))]
        [what     (in-list '("dot-access" "broadcast" "postfix-index" "list-literal"))])
    (define r (run-ns-ws-last (string-append P8FIX "def mm := {:k \"blue\"}\n"
                                             "defr d51fam [?f]\n  &> fruit-color f " spelling "\n")))
    (check-true (string? r) (format "~a must no longer be refused; got: ~a" what (result-msg r)))
    (check-true (string-contains? r "d51fam :")
                (format "~a: the defr must register; got: ~a" what r))))

(test-case "DEFERRED 51(c): rewrite families on a CONTINUATION line — 3 of 4 work, `x[i]` does not"
  ;; The adversarial verify fairly objected that the family loop above only checks
  ;; that the defr REGISTERS, and only with the rewrite on the `&>` line — so it
  ;; passes over a family that parses into garbage on a CONTINUATION line. This
  ;; test closes that gap by comparing against a plain-literal control.
  ;;
  ;; `x.f`, `x:f` and `'[…]` all fold to `$`-HEADED forms, which `pol8-goal-pair?`
  ;; correctly declines to treat as a goal group. `x[i]` folds to `(get x i)` —
  ;; the ONE family whose output is not `$`-headed — so it is mistaken for a goal
  ;; group and a deeper continuation becomes a bogus sibling goal instead of
  ;; extending the previous goal. Root cause PRE-DATES 51(c) (an ordinary
  ;; `[inc z]` there behaves identically before and after); what 51(c) changed is
  ;; that the old actionable "parenthesize each goal" was replaced by an unrelated
  ;; type error. Filed as DEFERRED 69.
  (define (cont arg)
    (run-ns-ws-last (string-append P8FIX
                                   "def mm := {:k \"blue\"}\n"
                                   "def cols := '[\"red\" \"blue\"]\n"
                                   "defr d51cont [?f]\n"
                                   "  &> fruit-color f\n"
                                   "       " arg "\n")))
  (define control (cont "\"red\""))
  (check-true (string? control) (result-msg control))
  (for ([arg (in-list '("mm.k" "mm:k" "\'[1 2]"))]
        [what (in-list '("dot-access" "broadcast" "list-literal"))])
    (define r (cont arg))
    (check-true (string? r)
                (format "~a on a continuation line must parse; got: ~a" what (result-msg r))))
  ;; KNOWN LIMIT, pinned so it is visible rather than surprising. If this starts
  ;; passing, DEFERRED 69 is fixed — invert it rather than deleting it.
  (define idx (cont "cols[0]"))
  (check-true (prologos-error? idx)
              (format "known limit: postfix-index on a continuation line; got: ~a"
                      (result-msg idx))))

(test-case "DEFERRED 51(c) ⭐ THE POINT: a rewritten clause GROUPS CORRECTLY, not merely without error"
  ;; The load-bearing test of 51(c), and the one the old guard existed to make
  ;; unnecessary. POL.8 refused rather than "risk a silent mis-grouping" — so
  ;; lifting the refusal is only safe if the grouping is actually RIGHT.
  ;; Two sibling goals, one containing a dot-access, must parse as TWO arity-2
  ;; goals — identical to the rewrite-free control. An intermediate version of
  ;; `rebuild-preserving-locs` failed exactly here: it registered the defr but
  ;; parsed the two goals as ONE 3-argument goal (`fruit-color/3`), i.e. it turned
  ;; a loud refusal into the silent mis-grouping POL.8 warned about.
  (define (run2 arg)
    (run-ns-ws-last (string-append P8FIX "def mm := {:k \"blue\"}\n"
                                   "defr d51two [?f]\n"
                                   "  &> fruit-color f " arg "\n"
                                   "     fruit-color f \"blue\"\n"
                                   "solve (d51two z)")))
  (define rewritten (run2 "mm.k"))
  (define control   (run2 "\"yellow\""))
  (check-true (string? rewritten) (format "rewritten clause must parse; got: ~a" (result-msg rewritten)))
  (check-true (string? control) (result-msg control))
  (check-false (string-contains? (result-msg rewritten) "fruit-color/3")
               (format "must NOT collapse into one 3-arg goal; got: ~a" (result-msg rewritten)))
  (check-equal? rewritten control
                "a rewrite must not change how the clause GROUPS"))

(test-case "DEFERRED 51(c): a rewrite in EVERY goal still groups correctly (right-peel guard)"
  ;; The second mis-parse found while building 51(c), and the reason
  ;; `rebuild-preserving-locs` peels its middle FROM THE RIGHT. The strict suffix
  ;; is computed by datum equality, so when the CONTINUATION line also contains a
  ;; rewrite it is not in the suffix — it fell into the stamped middle, took the
  ;; first goal's position, and the two goals parsed as ONE 3-argument goal.
  ;; Silent, zero errors. Both goals here carry a dot-access on purpose.
  (define (run2 arg1 arg2)
    (run-ns-ws-last (string-append P8FIX "def mm := {:k \"blue\"}\n"
                                   "defr d51both [?f]\n"
                                   "  &> fruit-color f " arg1 "\n"
                                   "     fruit-color f " arg2 "\n"
                                   "solve (d51both z)")))
  (define both (run2 "mm.k" "mm.k"))
  (check-true (string? both) (format "must parse; got: ~a" (result-msg both)))
  (check-false (string-contains? (result-msg both) "fruit-color/3")
               (format "must NOT collapse into one 3-arg goal; got: ~a" (result-msg both)))
  ;; …and agree with a shape-identical rewrite-free control. The control literal
  ;; must be NON-MATCHING ("nope"), because `mm.k` does not evaluate in goal
  ;; position (pre-existing semantics) and so yields no rows; comparing against a
  ;; MATCHING literal would compare matching, not GROUPING, which is what this
  ;; test is about.
  (check-equal? both (run2 "\"nope\"" "\"nope\"")
                "two rewritten goals must group exactly like two plain ones")
  ;; a rewrite ONLY on the continuation line is the mirror case
  (define tail (run2 "\"blue\"" "mm.k"))
  (check-false (string-contains? (result-msg tail) "fruit-color/3")
               (format "continuation-only rewrite must not collapse either; got: ~a"
                       (result-msg tail))))

(test-case "DEFERRED 51(c) let leg: a top-level `let` rel RHS takes parenless goals"
  ;; The 4th family member, found by the def-arm verify (a 6-line reproducer with
  ;; ZERO rewrites). Mechanism, instrumented: the let desugar is
  ;;   (let r := V body) → ((fn (r : _) body) V)
  ;; — the `($goal-rhs (rel …))` subtree survives DATUM-IDENTICAL but MOVES from
  ;; element 3 to element 1, and prefix/suffix alignment cannot see moves, so the
  ;; whole form was stamped @let-position and the rel's clause layout died. The
  ;; helper's relocation step (unique datum-equal match, compound subtrees only)
  ;; pairs the moved subtree with its original, srclocs intact.
  ;; PIN SHAPE: equality with the PAREN-goal control — same semantics, parenless
  ;; vs paren spelling — so grouping AND solving are pinned at once.
  (define parenless (run-ns-ws-last
                     (string-append P8FIX
                                    "let d51lr := (rel [f]\n"
                                    "  &> fruit-color f \"blue\")\n"
                                    "  d51lr\n")))
  (define paren     (run-ns-ws-last
                     (string-append P8FIX
                                    "let d51lc := (rel [f]\n"
                                    "  &> (fruit-color f \"blue\"))\n"
                                    "  d51lc\n")))
  (check-true (string? paren) (result-msg paren))
  (check-false (string-contains? (result-msg parenless) "parenless goals cannot")
               (format "the guard must not fire; got: ~a" (result-msg parenless)))
  (check-equal? parenless paren
                "the parenless spelling must group and solve exactly like the paren control"))

(test-case "DEFERRED 51(c) let leg: two sibling parenless goals under a let GROUP correctly"
  (define parenless (run-ns-ws-last
                     (string-append P8FIX
                                    "let d51l2 := (rel [f]\n"
                                    "  &> fruit-color f \"blue\"\n"
                                    "     fruit-color f \"nope\")\n"
                                    "  d51l2\n")))
  (define paren     (run-ns-ws-last
                     (string-append P8FIX
                                    "let d51l3 := (rel [f]\n"
                                    "  &> (fruit-color f \"blue\") (fruit-color f \"nope\"))\n"
                                    "  d51l3\n")))
  (check-true (string? paren) (result-msg paren))
  (check-false (string-contains? (result-msg parenless) "fruit-color/3")
               (format "must not merge the sibling goals; got: ~a" (result-msg parenless)))
  (check-equal? parenless paren
                "two parenless sibling goals must conjoin exactly like the paren control"))

;; ── DEFERRED 70: the right-peel over-reach (the let leg was BODY-SHAPE-DEPENDENT) ──
;;
;; Every pin above uses an ATOM let-body (`d51lr`, `d51l2`). That is not a
;; neutral choice — it is the only body shape the let leg ever worked for.
;; `peelable?` accepts ANY two lists, so a COMPOUND body (`[some vr]`, the
;; idiomatic shape) pairs with the moved rel RHS and the RHS is rebuilt against
;; the BODY's syntax tree: nonzero column, so POL.8's column-0 marker goes blind
;; and the sibling goals collapse onto one line. Before the let leg landed this
;; same input got the LOUD guard — so the fix converted a correct refusal into a
;; mis-grouping, which is exactly the trade the arc's own commentary forbids.
;;
;; Found by probing the audit's inferred claim rather than by any gate: the suite
;; was green over this the whole time, because no pin used a compound body.
(define P8FIX2
  (string-append P8FIX
                 "defr fruit-size [?fruit ?size]\n"
                 "  || \"blueberry\" \"small\"\n"
                 "  || \"banana\" \"long\"\n"))

;; body shape × goal spelling, pinned by CONTROL EQUALITY in both directions.
(define (d57-run body goals)
  (run-ns-ws-last (string-append P8FIX2 "let d57r := (rel [f]\n" goals ")\n  " body "\n")))
(define D57-PARENLESS "  &> fruit-color f \"blue\"\n     fruit-size f \"small\"")
(define D57-PAREN     "  &> (fruit-color f \"blue\") (fruit-size f \"small\")")

(test-case "DEFERRED 70: a COMPOUND let-body must not steal the rel RHS's srclocs"
  ;; The regression proper. `[some d57r]` forces the rel, so a collapse is
  ;; observable; with the atom body the same clause parses correctly, which is
  ;; what makes this body-shape-dependent rather than a plain let-leg failure.
  (define parenless (d57-run "[some d57r]" D57-PARENLESS))
  (define paren     (d57-run "[some d57r]" D57-PAREN))
  (check-true (string? paren) (result-msg paren))
  (check-false (string-contains? (result-msg parenless) "fruit-color/5")
               (format "the compound body must not collapse the goals; got: ~a"
                       (result-msg parenless)))
  (check-equal? parenless paren
                "a compound let-body must group exactly like the paren control"))

(test-case "DEFERRED 70: the ATOM-body case keeps working (the shape the old pins used)"
  ;; Guards the fix from the other side — tightening the peel must not cost the
  ;; relocation path that already worked.
  (check-equal? (d57-run "d57r" D57-PARENLESS) (d57-run "d57r" D57-PAREN)
                "atom-body parenless goals must still match their paren control"))

(test-case "DEFERRED 70: a SINGLE goal under a compound body was never affected"
  ;; Pinned because it isolates the trigger: the collapse needs TWO OR MORE
  ;; sibling goals AND a compound body. A one-goal clause has no continuation
  ;; line for the peel to mis-pair, and passed before the fix as well.
  ;; ⚠ THIS PIN IS NARROWER THAN ITS NAME: it fixes the `let :=` SPELLING, and
  ;; the first cut of the fix regressed the ALIGNED-BLOCK and BRACKET spellings
  ;; of exactly this shape while this test stayed green. See the two below —
  ;; they exist because this one was not enough.
  (define one "  &> fruit-color f \"blue\"")
  (define one-p "  &> (fruit-color f \"blue\")")
  (check-equal? (d57-run "[some d57r]" one) (d57-run "[some d57r]" one-p)
                "a single parenless goal under a compound body must match its control"))

;; The two spellings the FIRST cut of the peel fix regressed. It gated the peel
;; on `pre > 0`; here relocation cannot reach the moved rel RHS at all (it sits
;; one level below the middle for the bracket form, two for `$let-block`), so the
;; peel was the ONLY thing carrying the srclocs and withdrawing it turned a
;; correct answer into a guard refusal. Both worked before that cut and must keep
;; working: they are the regression pins, not new capability.
(define (d57-aligned goals)
  (run-ns-ws-last (string-append P8FIX2 "let d57a (rel [f]\n" goals ")\n"
                                 "    d57n  5\n  [some d57a]\n")))
(define (d57-bracket goals)
  (run-ns-ws-last (string-append P8FIX2 "let [d57b (rel [f]\n" goals ")]\n"
                                 "  [some d57b]\n")))
(define D57-1GOAL   "          &> fruit-color f \"blue\"")
(define D57-1GOAL-P "          &> (fruit-color f \"blue\")")

(test-case "DEFERRED 70: ALIGNED-BLOCK let, one goal, compound body — must match its control"
  (check-equal? (d57-aligned D57-1GOAL) (d57-aligned D57-1GOAL-P)
                "aligned-block let must not lose the rel RHS's srclocs"))

(test-case "DEFERRED 70: BRACKET let, one goal, compound body — must match its control"
  (check-equal? (d57-bracket D57-1GOAL) (d57-bracket D57-1GOAL-P)
                "bracket let must not lose the rel RHS's srclocs"))

(define D57-2GOAL   (string-append "          &> fruit-color f \"blue\"\n"
                                   "             fruit-size f \"small\""))
(define D57-2GOAL-P "          &> (fruit-color f \"blue\") (fruit-size f \"small\")")

;; ── DEFERRED 71: the DEPTH WALL — the origin index ────────────────────────────
;;
;; ⚠ INVERTED (this was the DEFERRED 70 KNOWN LIMIT, and it said to invert rather
;; than delete when the fix landed). Both spellings used to MIS-GROUP into
;; `fruit-color/5` at two or more goals, because the moved rel RHS sits BELOW the
;; middle's top-level elements — one level down for the bracket form, two for
;; `$let-block` — where neither `peel-steals-a-move?` nor the relocation search
;; could see it.
;;
;; The fix is not a deeper search. `syntax->datum` allocates FRESH pairs and the
;; desugars splice sub-datums BY REFERENCE, so cons-cell identity is already an
;; exact origin marker for the thing this whole family is about — a subtree that
;; MOVED through a desugar unchanged. The strip now records it.
(test-case "DEFERRED 71: ALIGNED-BLOCK let at two or more goals — must match its control"
  (check-equal? (d57-aligned D57-2GOAL) (d57-aligned D57-2GOAL-P)
                "aligned-block let must group like its paren control at 2 goals"))

(test-case "DEFERRED 71: BRACKET let at two or more goals — must match its control"
  (check-equal? (d57-bracket D57-2GOAL) (d57-bracket D57-2GOAL-P)
                "bracket let must group like its paren control at 2 goals"))

(test-case "DEFERRED 71: the collapse is gone, not merely relabelled"
  ;; Belt-and-braces on the two above: control-equality would also pass if BOTH
  ;; sides broke identically, which is exactly how the `def := rel` member (a
  ;; separate slice) hides from its own pin. Name the old symptom explicitly.
  (check-false (string-contains? (result-msg (d57-aligned D57-2GOAL)) "fruit-color/5")
               (format "aligned block must not collapse; got: ~a"
                       (result-msg (d57-aligned D57-2GOAL))))
  (check-false (string-contains? (result-msg (d57-bracket D57-2GOAL)) "fruit-color/5")
               (format "bracket must not collapse; got: ~a"
                       (result-msg (d57-bracket D57-2GOAL))))
  ;; and the controls really do answer, so the equality above is not vacuous
  (check-true (string? (d57-aligned D57-2GOAL-P)) (result-msg (d57-aligned D57-2GOAL-P)))
  (check-true (string? (d57-bracket D57-2GOAL-P)) (result-msg (d57-bracket D57-2GOAL-P))))

;; ── DEFERRED 71: the index restores POSITIONS, not PROPERTIES ─────────────────
;;
;; Found by adversarial verify, MEASURED, and it had a SILENT mode. The origin
;; index hands back the ORIGINAL syntax object, which also carries its syntax
;; PROPERTIES — and `prologos-paren-origin` is POSITION-SENSITIVE: the reader
;; attaches it to every paren group and `paren-goal-stx?` reads it to decide that
;; a paren group AT COMMAND POSITION is a relational goal (POL.9). A `defmacro`
;; that lifts its argument to top level therefore turned an application into a
;; goal. `dbg (inc 10)` went `11 : Int` → a hard error; `dbg (= 1 1)` went
;; `true : Bool` → `@[{}] : _` with **zero errors on both legs**.
;;
;; The rule that fixed it: a hit whose original is the node we were ALREADY
;; aligned with has not moved and keeps its properties; any other hit MOVED and
;; takes srclocs ONLY. Nothing in the suite covered syntax properties before
;; this, which is why every gate was green over it.
(test-case "DEFERRED 71: a macro-spliced PAREN group at command position stays an application"
  (check-equal? (run-ns-ws-last (string-append
                                 "ns p8pp\n"
                                 "spec ppinc Int -> Int\n"
                                 "defn ppinc [n] [int+ n 1]\n"
                                 "defmacro ppdbg [$e]\n"
                                 "  $e\n"
                                 "ppdbg (ppinc 10)\n"))
                "11 : Int"
                "a macro must not turn its paren argument into a relational goal"))

(test-case "DEFERRED 71: …and the SILENT direction — a goal KEYWORD head keeps its bracket reading"
  ;; The sharp one: both legs report 0 errors, so only the VALUE and TYPE differ.
  ;; `(= 1 1)` at command position IS a unify goal when written by hand; spliced
  ;; out of a macro it must keep the reading it had before the index existed.
  (check-equal? (run-ns-ws-last (string-append
                                 "ns p8pq\n"
                                 "defmacro pqdbg [$e]\n"
                                 "  $e\n"
                                 "pqdbg (= 1 1)\n"))
                "true : Bool"
                "a macro-spliced goal-keyword group must not silently become a goal"))

(test-case "DEFERRED 71: the BRACKET spelling is the control — identical throughout"
  ;; Isolates the trigger to macro-spliced PARENS: this spelling never carried
  ;; `prologos-paren-origin` and was unaffected in either direction.
  (check-equal? (run-ns-ws-last (string-append
                                 "ns p8pr\n"
                                 "spec princ Int -> Int\n"
                                 "defn princ [n] [int+ n 1]\n"
                                 "defmacro prdbg [$e]\n"
                                 "  $e\n"
                                 "prdbg [princ 10]\n"))
                "11 : Int"
                "the bracket spelling must be unaffected"))

;; ── DEFERRED 71 slice 2: the SIBLING-LET chain ───────────────────────────────
;;
;; ⚠ INVERTED (the KNOWN LIMIT below said to invert rather than delete). This one
;; was NOT a depth problem at all — a distinction the earlier framing got wrong.
;; `merge-toplevel-sibling-lets` fused the run from a PURE DATUM and rebuilt with
;; a 4-arg `datum->syntax` against sibling 1, and `datum->syntax` stamps
;; RECURSIVELY, so every node of the merged form carried sibling 1's line and
;; column BEFORE `rebuild-preserving-locs` ever saw it. No search, at any depth,
;; can recover information that is no longer in the tree. The fix is that the
;; fusion now strips through the SAME origin index, so each sibling's own subtrees
;; stay recoverable by identity across the fusion.
;;
;; Its loudness was incidental: sibling 1 sits at column 0, which is exactly
;; POL.8's degradation marker. Had the chain been written indented (inside a
;; `defn`), the same defect would have been SILENT.
(test-case "DEFERRED 71 slice 2: a SIBLING-LET chain groups like its paren control"
  (define parenless (run-ns-ws-last
                     (string-append P8FIX2
                                    "let d58sx := 5\n"
                                    "let d58sr := (rel [f]\n"
                                    "  &> fruit-color f \"blue\"\n"
                                    "     fruit-size f \"small\")\n"
                                    "  [pair d58sx 1]\n")))
  (define paren     (run-ns-ws-last
                     (string-append P8FIX2
                                    "let d58tx := 5\n"
                                    "let d58tr := (rel [f]\n"
                                    "  &> (fruit-color f \"blue\") (fruit-size f \"small\"))\n"
                                    "  [pair d58tx 1]\n")))
  (check-false (string-contains? (result-msg parenless) "parenless goals cannot")
               (format "the guard must no longer fire; got: ~a" (result-msg parenless)))
  (check-equal? parenless paren
                "a sibling-let chain must group exactly like its paren control"))

(test-case "DEFERRED 71 slice 2: the chain still SOLVES, and the earlier siblings stay in scope"
  ;; Guards the half a grouping test cannot: the merge must still MERGE. If the
  ;; fusion stopped fusing, `d58ax` would fall out of scope and this errors.
  (define r (run-ns-ws-last
             (string-append P8FIX2
                            "let d58ax := 5\n"
                            "let d58ar := (rel [f]\n"
                            "  &> fruit-color f \"blue\"\n"
                            "     fruit-size f \"small\")\n"
                            "  [+ d58ax 1]\n")))
  (check-equal? r "6 : Int"
                (format "the merged chain must still evaluate its body; got: ~a"
                        (result-msg r))))

(test-case "SUPERSEDED by DEFERRED 71 slice 2 — was: a SIBLING-LET chain still degrades"
  ;; Found by self-probe minutes after the let-leg landing — the family-closure
  ;; lesson (Watching 4) applied: hunt the next member yourself, immediately.
  ;; `merge-toplevel-sibling-lets` FUSES the sibling lets' stxs into one datum
  ;; (`(map syntax->datum unit)` → merged nested let), so its rebuild has TWO
  ;; source trees — single-source alignment and the one-level relocation step
  ;; structurally cannot recover the second sibling's subtrees. Closing it needs
  ;; NEW machinery (an stx-carrying merge, or deep multi-source pool
  ;; relocation), not another application of the helper — deliberately NOT
  ;; improvised mid-arc; see DEFERRED 51(c). If this test starts failing because
  ;; the chain PARSES, that fix landed: invert it, do not delete it.
  ;;
  ;; ⚠ INVERTED at DEFERRED 71 slice 2, and the diagnosis above is now known to
  ;; be WRONG in its load-bearing half: this was never recoverable by a smarter
  ;; multi-source ALIGNMENT, because the fusion destroyed the srclocs before any
  ;; alignment ran. Kept verbatim, with its ORIGINAL fixture, as the historical
  ;; single-goal member — the two tests above carry the two-goal grouping and the
  ;; still-merges property.
  (define r (run-ns-ws-last
             (string-append P8FIX
                            "let d51sx := 5\n"
                            "let d51sr := (rel [f]\n"
                            "  &> fruit-color f \"blue\")\n"
                            "  [+ d51sx 1]\n")))
  (check-false (string-contains? (result-msg r) "parenless goals cannot")
               (format "the sibling-let guard must no longer fire; got: ~a"
                       (result-msg r)))
  (check-equal? r "6 : Int"
                (format "and the merged chain must evaluate; got: ~a" (result-msg r))))

(test-case "DEFERRED 51(c) def arm: unparenthesized `def r := rel …` takes parenless clauses"
  ;; The last spelling still degrading after the defr + [else] extensions. The
  ;; DEF arm's `rebuild-def-preserving-rhs` handles only a SINGLE element after
  ;; `:=` (`def-rhs-stx` is #f for a spliced multi-line `rel` RHS), so it fell to
  ;; the whole-form stamp — and the `:=` desugar itself changes the datum, so
  ;; this fired with NO rewrite anywhere in the source. Both fallback paths now
  ;; route through `rebuild-preserving-locs`.
  ;; MEASURED semantics after the fix: the clause parses (no guard), and the
  ;; spelling routes into the PRE-EXISTING POL.9b def-seam gap — a bare
  ;; multi-token RHS is application/value by Q_C, and a def-bound rel VALUE
  ;; infers a hole type, giving the same "Expression is not a valid type" that
  ;; `def bad := (dbl 3)` is already pinned to produce below ("Pinned so a
  ;; future diagnostic fix shows"). Consistency with the sibling spellings, not
  ;; a new failure: the misdirecting parse-layer refusal ("parenthesize each
  ;; GOAL" — when the actual fix is parenthesizing the REL) is gone.
  (define r (run-ns-ws-last
             (string-append P8FIX
                            "def d51r1 := rel [?f]\n"
                            "  &> fruit-color f \"blue\"\n"
                            "     fruit-color f \"nope\"\n")))
  (check-false (string-contains? (result-msg r) "parenless goals cannot")
               (format "the guard must not fire; got: ~a" (result-msg r)))
  ;; ⚠ INVERTED by DEFERRED 74 (the def-seam close). This used to route into the
  ;; POL.9b def-seam gap and report "Expression is not a valid type"; the
  ;; unannotated `def` path now skips `is-type` for hole-typed bodies exactly as
  ;; the ANNOTATED path always did, so a `rel` VALUE binds.
  ;; ⚠⚠ AND NOTE WHAT THIS TEST STILL DOES NOT SEE: member 4 (the clause
  ;; MIS-GROUPING in this spelling) remains latent underneath. `pp-expr`'s
  ;; expr-rel arm elides the clauses and a def-bound rel value cannot be queried,
  ;; so grouping is invisible from here. Do NOT read this passing as evidence
  ;; that the clause parsed correctly — see DEFERRED 72.
  (check-true (string-contains? (result-msg r) "d51r1")
              (format "the rel value must now bind; got: ~a" (result-msg r)))
  (check-false (string-contains? (result-msg r) "not a valid type")
               (format "the def-seam gap must be closed; got: ~a" (result-msg r))))

(test-case "DEFERRED 51(c) def arm: a rewrite inside the rel GROUPS like the control"
  (define (drel arg)
    (run-ns-ws-last (string-append P8FIX
                                   "def mm := {:k \"blue\"}\n"
                                   "def d51r2 := rel [?f]\n"
                                   "  &> fruit-color f " arg "\n"
                                   "     fruit-color f \"nope\"\n")))
  (define rewritten (drel "mm.k"))
  (define control   (drel "\"nada\""))
  (check-false (string-contains? (result-msg rewritten) "fruit-color/3")
               (format "must not collapse into one 3-arg goal; got: ~a" (result-msg rewritten)))
  (check-equal? (result-msg rewritten) (result-msg control)
                "a rewrite must not change how the def-RHS rel's clause GROUPS"))

(test-case "DEFERRED 51(c) def arm branch (b): a PAREN rel RHS with a rewrite keeps its clause layout"
  ;; The other changed path: a SINGLE-element `:=` RHS whose datum was rewritten
  ;; (heads match) used to be 4-arg re-stamped, flattening every inner srcloc —
  ;; so a paren `(rel …)` RHS containing a rewrite lost the layout its parenless
  ;; multi-goal clause needs. Now `rebuild-preserving-locs` keeps it, and the
  ;; Q_C mark is applied on top exactly as before: this spelling still SOLVES
  ;; (POL.9b/POL.10), so the pin is rows-based and strong — a mis-grouping would
  ;; surface as an arity error, not a row.
  (define (prel arg)
    (run-ns-ws-last (string-append P8FIX
                                   "def mm := {:k \"blue\"}\n"
                                   "def d51pr := (rel [f]\n"
                                   "  &> fruit-color f " arg "\n"
                                   "     fruit-color f \"blue\")\n"
                                   "d51pr")))
  (define rewritten (prel "mm.k"))
  (define control   (prel "\"nada\""))
  (check-true (string? rewritten) (result-msg rewritten))
  (check-false (string-contains? (result-msg rewritten) "fruit-color/3")
               (result-msg rewritten))
  ;; Neither arg matches (mm.k is an unevaluated term; "nada" matches nothing),
  ;; so both conjunctions yield the same empty row set — comparable outputs whose
  ;; equality pins the GROUPING while the solve pins the Q_C property survival.
  (check-equal? rewritten control
                "the rewritten paren-RHS rel must group and solve like the control"))

(test-case "def arm Q_C parity: the := contracts are UNCHANGED by the srcloc extension"
  ;; The def arm is where `prologos-defrhs-command` (Q_C) is stamped — a SINGLE
  ;; element after `:=` gets command-position goal-ness; a bare multi-token RHS
  ;; stays application/value BY CONSTRUCTION. Pin both sides so the helper swap
  ;; cannot silently shift the boundary.
  (define solves (run-ns-ws-last
                  (string-append P8FIX "def blues := (fruit-color f \"blue\")\n")))
  (check-true (string? solves) (result-msg solves))
  (check-true (string-contains? solves "PVec")
              (format "paren RHS keeps its implicit solve; got: ~a" solves))
  (define app (run-ns-ws-last "ns qcp\ndef app1 := [+ 1 2]\n"))
  (check-true (string-contains? app "app1 : Int") (result-msg app))
  (define appr (run-ns-ws-last "ns qcp\ndef mmn := {:n 1}\ndef app2 := [+ mmn.n 2]\n"))
  (check-true (string-contains? appr "app2 : Int")
              (format "a rewritten application RHS stays an application; got: ~a"
                      (result-msg appr))))

(test-case "DEFERRED 51(c) [else] arm: a bare top-level `rel` with a rewrite takes parenless goals"
  ;; The scope gap named at 51(c)'s landing: a bare top-level `rel` does NOT go
  ;; through the `defr` preparse arm — it is a "regular form" handled by the
  ;; fold's `[else]` arm, which still rebuilt with the whole-form stamp. So after
  ;; 51(c), `rel` and `defr` DISAGREED on the same POL.8 grammar: the identical
  ;; parenless clause registered under `defr` and refused under `rel`. This pins
  ;; the [else] extension that closes the disagreement.
  (define r (run-ns-ws-last
             (string-append P8FIX
                            "def mm := {:k \"blue\"}\n"
                            "rel [q]\n"
                            "  &> fruit-color q mm.k\n")))
  (check-true (string? r)
              (format "a bare rel with a rewrite must not be refused; got: ~a" (result-msg r)))
  (check-false (string-contains? (result-msg r) "parenless goals cannot")
               (result-msg r)))

(test-case "DEFERRED 51(c) [else] arm: a two-goal bare `rel` with a rewrite GROUPS like the control"
  ;; Same discipline as the defr ⭐ test: registering is not the bar — grouping
  ;; identically to a shape-identical rewrite-free control is. Control literal is
  ;; NON-matching so the comparison is about grouping, not matching.
  (define (brel arg)
    (run-ns-ws-last (string-append P8FIX
                                   "def mm := {:k \"blue\"}\n"
                                   "rel [q]\n"
                                   "  &> fruit-color q " arg "\n"
                                   "     fruit-color q \"nope\"\n")))
  (define rewritten (brel "mm.k"))
  (define control   (brel "\"nada\""))
  (check-true (string? rewritten) (result-msg rewritten))
  (check-false (string-contains? (result-msg rewritten) "fruit-color/3")
               (format "must not collapse into one 3-arg goal; got: ~a" (result-msg rewritten)))
  (check-equal? rewritten control
                "a rewrite must not change how a bare rel's clause GROUPS"))

(test-case "DEFERRED 51(c): the relation now registers AND answers"
  ;; Inverted from "the refusal takes the relation with it — pinned". That pin
  ;; recorded owner ruling (a) (keep the limit); 51(c) supersedes it.
  (define r (run-ns-ws-last (string-append P8FIX
                                           "def mm := {:k \"blue\"}\n"
                                           "defr d51ruled [?f]\n  &> fruit-color f mm:k\n"
                                           "solve (d51ruled q)")))
  (check-false (prologos-error? r)
               (format "no longer an error; got: ~a" (result-msg r)))
  (check-false (string-contains? (result-msg r) "Unknown relation") (result-msg r)))

(test-case "DEFERRED 51: the all-paren spelling handles broadcast correctly (and loudly)"
  ;; The counterpart to the guard: with parens the clause parses, the relation
  ;; registers, and the arity error is REPORTED. G2 improved this path — pre-G2
  ;; the same input returned a silent `@[]` because `x:y` was spliced into two
  ;; tokens, inflating the goal's arity to a value that happened to match.
  (define r (run-ns-ws-last (string-append P8FIX
                                           "def mm := {:k \"blue\"}\n"
                                           "defr d51paren [?f]\n  &> (fruit-color mm:k)\n"
                                           "solve (d51paren q)")))
  (check-true (prologos-error? r) (format "expected an arity error; got: ~a" (result-msg r)))
  (check-true (string-contains? (result-msg r) "fruit-color/1") (result-msg r)))

(test-case "POL.8: a literal cannot head a goal line (LOUD)"
  (define m (result-msg (run-ns-ws-last
                         (string-append P8FIX
                                        "defr h [?f]\n"
                                        "  &> \"blue\" f\n"))))
  (check-true (string-contains? m "must start with a relation name") m))

(test-case "POL.8: top-level bare `rel` body takes parenless goals (shared grammar)"
  (define r (run-ns-ws-last
             (string-append P8FIX
                            "rel [q]\n"
                            "  &> fruit-color q \"blue\"\n")))
  (check-true (string? r) (result-msg r))
  (check-false (string-contains? r "rule clause")))

(test-case "POL.8/Q6 sexp: flat bare goal run is ONE goal; flat $clause-sep splits clauses"
  (define r (run-ns-last
             (string-append "(ns p8s)\n"
                            "(defr gg (?x ?y) || 1 2)\n"
                            "(defr bare (?x) &> gg x 2)\n"
                            "(defr two (?x) &> gg x 2 &> gg x 4)\n"
                            "(solve (bare q))")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "{:q 1}")))

;; ========================================================================
;; POL.9a — implicit solve: parens make goals at command position
;; (owner co-design 2026-07-25; design §8 POL.9 — the paren-goal design).
;; `(foo x)` at top level = solve (foo x); `foo x` / `[foo x]` = application;
;; keyword heads keep their forms; `rel` is the one keyword that queries.
;; The WS reader marks paren origin ('prologos-paren-origin); sexp mode is
;; untouched by construction (the named WS-vs-sexp divergence, pinned below).
;; Head classification happens at solve time: relation → rows; value-bound →
;; a guiding diagnostic; unknown → the POL.4 unknown-relation error.
;; ========================================================================

(define P9FIX
  (string-append
   "ns p9\n"
   "defr fruit-color [?fruit ?color]\n"
   "  || \"blueberry\" \"blue\"\n"
   "  || \"banana\" \"yellow\"\n"
   "  || \"cherry\" \"red\"\n"
   "  || \"plum\" \"purple\"\n"
   "defr red-or-green [?f]\n"
   "  &> fruit-color f \"red\"\n"
   "defr blue-or-yellow [?f]\n"
   "  &> fruit-color f \"blue\"\n"
   "  &> fruit-color f \"yellow\"\n"
   "defn dbl [x:Int] : Int\n"
   "  * x 2\n"))

(test-case "POL.9: a paren goal at top level carries an implicit solve (typed rows)"
  (define r (run-ns-ws-last (string-append P9FIX "(blue-or-yellow q)")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "blueberry"))
  (check-true (string-contains? r "banana"))
  (check-true (string-contains? r "PVec {:q String}")
              "the B-machinery types the implicit solve identically"))

(test-case "POL.9: the composed owner example — paren rel + POL.8 parenless clauses"
  (define r (run-ns-ws-last
             (string-append P9FIX
                            "(rel [fruit]\n"
                            "  &> fruit-color fruit _\n"
                            "     not (red-or-green fruit)\n"
                            "     not (blue-or-yellow fruit))")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "plum"))
  (check-false (string-contains? r "cherry")))

(test-case "POL.9: nested deeper-indent `not` works INSIDE parens (flat regrouping)"
  (define r (run-ns-ws-last
             (string-append P9FIX
                            "(rel [f]\n"
                            "  &> fruit-color f c\n"
                            "     not\n"
                            "       = c \"red\")")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "plum"))
  (check-false (string-contains? r "cherry")))

(test-case "POL.9: multi-clause anonymous rel inside parens is a DISJUNCTION"
  (define r (run-ns-ws-last
             (string-append P9FIX
                            "solve (rel [f]\n"
                            "       &> fruit-color f \"red\"\n"
                            "       &> fruit-color f \"purple\")")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "cherry"))
  (check-true (string-contains? r "plum")))

(test-case "POL.9: defn head in parens → the guiding function diagnostic"
  (define m (result-msg (run-ns-ws-last (string-append P9FIX "(dbl 3)"))))
  (check-true (string-contains? m "dbl is a function") m)
  (check-true (string-contains? m "[dbl") m))

(test-case "POL.9: explicit solve over a defn head gets the SAME diagnostic"
  (define m (result-msg (run-ns-ws-last (string-append P9FIX "solve (dbl 3)"))))
  (check-true (string-contains? m "dbl is a function") m))

(test-case "POL.9: zero-arg paren of a function → diagnostic (was a value echo)"
  (define m (result-msg (run-ns-ws-last (string-append P9FIX "(dbl)"))))
  (check-true (string-contains? m "dbl is a function") m))

(test-case "POL.9: unknown head → unknown-relation; the file CONTINUES past it"
  (define r (run-ns-ws-last (string-append P9FIX "(mystery q)\n[dbl 21]")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "42") "the command after the error still ran"))

(test-case "POL.9: keyword heads keep their forms; brackets stay application"
  (check-true (string-contains? (run-ns-ws-last (string-append P9FIX "(+ 1 2)")) "3"))
  (check-true (string-contains? (run-ns-ws-last (string-append P9FIX "[dbl 3]")) "6")))

(test-case "POL.9: sexp mode — (dbl 3) stays APPLICATION (the named divergence, pinned)"
  (define r (run-ns-last
             (string-append "(ns p9s)\n"
                            "(spec sdbl Int -> Int)\n"
                            "(defn sdbl [x] (int* x 2))\n"
                            "(sdbl 3)")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "6")))

(test-case "POL.9: a preparse rewrite inside a paren goal keeps goal-ness (4-arg preserve)"
  (define r (run-ns-ws-last
             (string-append P9FIX
                            "def mm := {:c \"blue\"}\n"
                            "(fruit-color f mm.c)")))
  ;; computed goal args don't evaluate (pre-existing semantics) → empty, but the
  ;; command IS a solve — pinned via the row-container TYPE on the echo.
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "PVec {:f String}") r))

(test-case "POL.9: a gate-rejected defr's solve points at the earlier error"
  (define m (result-msg (run-ns-ws-last
                         (string-append P9FIX
                                        "defr unsafe-r [?x]\n"
                                        "  &> not (fruit-color y x)\n"
                                        "(unsafe-r q)"))))
  (check-true (string-contains? m "failed to register") m))

;; ========================================================================
;; POL.9b — the def-RHS leg (Q_C): `def r := (reach a b)` ≡ `:= solve (…)`.
;; Realization: the preparse def arm carries the := RHS element's stx
;; (srclocs + paren-origin) through the rewrite; parse-def dispatches at all
;; three body sites; the merge prefers the preparse surf exactly when the
;; two spines DISAGREE in category (preparse=solve vs tree=app) — explicit
;; `def := solve (…)` parses as solve on both spines and merges as before.
;; ========================================================================

(test-case "POL.9b: def RHS paren goal binds the solve's rows"
  (define r (run-ns-ws-last
             (string-append P9FIX
                            "def blues := (fruit-color f \"blue\")\n"
                            "blues")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "blueberry"))
  (check-true (string-contains? r "PVec {:f String}")))

(test-case "POL.9b: def RHS paren rel with POL.8 parenless clauses (inner layout survives)"
  (define r (run-ns-ws-last
             (string-append P9FIX
                            "def nonred := (rel [f]\n"
                            "                &> fruit-color f c\n"
                            "                   not (= c \"red\"))\n"
                            "nonred")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "blueberry"))
  (check-true (string-contains? r "plum"))
  (check-false (string-contains? r "cherry")))

(test-case "POL.9b: explicit `def := solve (…)` unchanged"
  (define r (run-ns-ws-last
             (string-append P9FIX
                            "def ys := solve (fruit-color f \"yellow\")\n"
                            "ys")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "banana")))

(test-case "POL.9b: paren and explicit spellings are byte-equivalent at the def seam"
  (define paren (run-ns-ws-last
                 (string-append P9FIX "def r := (fruit-color f \"blue\")\nr")))
  (define expl  (run-ns-ws-last
                 (string-append P9FIX "def r := solve (fruit-color f \"blue\")\nr")))
  (check-equal? paren expl))

(test-case "POL.9b: def-seam PARITY on bad heads — now the GUIDING diagnostic"
  ;; ⚠ INVERTED by DEFERRED 74, exactly as this test's own comment asked ("Pinned
  ;; so a future diagnostic fix shows"). Both spellings used to hit the def-seam
  ;; type error because typing PRECEDES evaluation on the def path, so the
  ;; guiding message — which is raised at EVALUATION time — could never be
  ;; reached. Closing the seam lets it through.
  (define paren (result-msg (run-ns-ws-last
                             (string-append P9FIX "def bad := (dbl 3)"))))
  (define expl  (result-msg (run-ns-ws-last
                             (string-append P9FIX "def bad := solve (dbl 3)"))))
  (check-equal? paren expl "paren spelling ≡ explicit solve spelling")
  (check-true (string-contains? paren "is a function") paren)
  (check-false (string-contains? paren "not a valid type") paren))

(test-case "DEFERRED 74: closing the seam un-preempts the OTHER guiding diagnostics too"
  ;; The seam was not hiding one message, it was hiding a class: any diagnostic
  ;; raised at EVALUATION time on a def RHS was preempted by the type check.
  (define unknown (result-msg (run-ns-ws-last
                               (string-append P9FIX "def bad := solve (nosuchrel a b)"))))
  (check-true (string-contains? unknown "nosuchrel")
              (format "an unknown relation must name itself; got: ~a" unknown))
  (check-false (string-contains? unknown "not a valid type") unknown))

(test-case "DEFERRED 74 rider: `expr-narrow` on a def RHS no longer LIES about multiplicity"
  ;; `inferQ` had no `expr-narrow` arm, so it fell to its catch-all and reported
  ;; "Multiplicity violation" — naming QTT, which was working perfectly. The
  ;; def-seam gap had MASKED it (narrow infers to a hole, so `is-type` rejected
  ;; the body first), which is why closing the seam had to bring the twin arm
  ;; with it: otherwise one honest error is traded for one misleading one.
  ;; See `.claude/rules/pipeline.md` § "infer / inferQ Are Twins".
  (define r (run-ns-ws-last (string-append
                             "ns dn\n"
                             "spec add2 Int Int -> Int\n"
                             "defn add2 [a b] [int+ a b]\n"
                             "def n1 := [#= [add2 ?x 3] 5]\n")))
  (check-false (string-contains? (result-msg r) "Multiplicity violation")
               (format "the lying diagnostic must be gone; got: ~a" (result-msg r)))
  (check-false (string-contains? (result-msg r) "not a valid type")
               (format "and it must not fall back to the seam error; got: ~a" (result-msg r))))

(test-case "DEFERRED 74: a NON-GROUND def type reports the inference failure, not multiplicity"
  ;; The seam close let hole-typed bodies through to QTT — correct, since holes
  ;; are legitimate for rel/defr/narrow/solve. But a non-ground type ALSO arises
  ;; when inference simply failed, and QTT then has nothing to check against and
  ;; reports its generic `tu-error` as "Multiplicity violation" — naming a
  ;; subsystem that is working perfectly.
  ;; ⚠ The trigger is NOT "has a hole": `flip const false 2` infers a type
  ;; carrying an unsolved META, and a hole-only test misses it. The condition is
  ;; the GATE's own (`def-type-not-ground?`), because if the type is not ground
  ;; QTT cannot do its job at all and its failure is downstream of inference.
  (define r (run-ns-ws-last "ns t6x\ndef d6x := flip const false 2\n"))
  (check-false (string-contains? (result-msg r) "Multiplicity violation")
               (format "must not blame multiplicity; got: ~a" (result-msg r)))
  (check-true (string-contains? (result-msg r) "Could not infer type")
              (format "must report the inference failure; got: ~a" (result-msg r))))

(test-case "DEFERRED 74: the ANNOTATED def path is unchanged (it always had the guard)"
  ;; The whole defect was that the two def paths disagreed. Pin the one that was
  ;; already right, so a future edit cannot fix them apart again.
  (check-equal? (run-ns-ws-last (string-append P9FIX "def okk : Int := [dbl 3]"))
                "okk : Int defined."
                "an annotated def must be unaffected"))

;; MERGE 2026-08-05: kept from this branch alongside main's cases above. They
;; assert PROPERTIES main's version does not: that the two seams agree, and that
;; a working relation on a def RHS still works. The second is the one that
;; matters — without it, "every def errors" would satisfy the parity assertion.
(test-case "POL.9b: the def seam agrees with TOP LEVEL on a bad head"
  ;; The property rather than the string: the same program at top level and on a
  ;; `def` RHS must classify the same way. The top-level message was always
  ;; right; the def seam is what moved.
  (define top (result-msg (run-ns-ws-last (string-append P9FIX "(dbl 3)"))))
  (define deffed (result-msg (run-ns-ws-last
                              (string-append P9FIX "def bad := (dbl 3)"))))
  (check-equal? top deffed "top level and def seam must classify a bad head alike"))

(test-case "POL.9b: a REAL relation on a def RHS is untouched (control)"
  (define r (run-ns-ws-last
             (string-append P9FIX "def good := (fruit-color f \"blue\")\ngood")))
  (check-true (string? r) (result-msg r)))

(test-case "POL.9b: bare/bracket def RHS stays application-value"
  (define r (run-ns-ws-last
             (string-append P9FIX
                            "def six := [dbl 3]\n"
                            "six")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "6")))

(test-case "POL.9b: sexp def RHS paren application unchanged (divergence pinned)"
  (define r (run-ns-last
             (string-append "(ns p9bs)\n"
                            "(def six (int* 2 3))\n"
                            "(eval six)")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "6")))

;; ========================================================================
;; POL.9c — Q_B: defn/defr namespaces are DISJOINT at registration.
;; LOCAL-only (refer-imported names stay shadowable — the prelude
;; xor/singleton precedent); same-kind redefinition stays legal. The kind
;; discriminator is the local env entry's value (a defr name's env value IS
;; its expr-defr body). Named gap: multi-arity defn base names live only in
;; the ambient multi-defn registry (no module provenance) — that collision
;; is ungated by design.
;; ========================================================================

(test-case "POL.9c/Q_B: defr over a local defn errors, pointing at the value kind"
  (define m (result-msg (run-ns-ws-last
                         (string-append "ns qb1\n"
                                        "defn area [x:Int] : Int\n  * x x\n"
                                        "defr area [?a]\n  || 1\n"))))
  (check-true (string-contains? m "already defined as a function/value") m))

(test-case "POL.9c/Q_B: def over a local defr errors, pointing at the relation kind"
  (define m (result-msg (run-ns-ws-last
                         (string-append "ns qb2\n"
                                        "defr speed [?s]\n  || 3\n"
                                        "def speed := 42"))))
  (check-true (string-contains? m "already defined as a relation") m))

(test-case "POL.9c/Q_B: defn over a local defr errors too (process-def route)"
  (define m (result-msg (run-ns-ws-last
                         (string-append "ns qb3\n"
                                        "defr color [?c]\n  || \"red\"\n"
                                        "defn color [x:Int] : Int\n  * x 2\n"))))
  (check-true (string-contains? m "already defined as a relation") m))

(test-case "POL.9c/Q_B: same-kind redefinition stays LEGAL (re-defr + def-over-def)"
  (define r (run-ns-ws-last
             (string-append "ns qb4\n"
                            "defr edge [?a]\n  || 1\n"
                            "defr edge [?a]\n  || 2\n"
                            "def n := 1\n"
                            "def n := 2\n"
                            "solve (edge x)")))
  (check-true (string? r) (result-msg r)))

(test-case "POL.9c/Q_B CANARY: defr shadowing a refer-imported prelude name stays LEGAL"
  ;; xor is refer-imported from the prelude's bool module — imports live in
  ;; the cascade, not this module's own cell-id-map, so the LOCAL-only gate
  ;; must not fire (the lib/examples/foray.prologos precedent).
  (define r (run-ns-ws-last
             (string-append "ns qb5\n"
                            "defr xor [?p]\n  || 7\n"
                            "solve (xor q)")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "{:q 7}")))

(test-case "POL.9c/Q_B: the run CONTINUES past a gate error"
  (define r (run-ns-ws-last
             (string-append "ns qb6\n"
                            "defn area [x:Int] : Int\n  * x x\n"
                            "defr area [?a]\n  || 1\n"
                            "[+ 20 22]")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "42")))

(test-case "POL.9c/Q_B: the FOURTH direction — defr over a prior multi-arity defn — IS gated"
  ;; DEFERRED.md said this direction was deliberately UNGATED and routed the
  ;; fix to PM 12/12B, on the premise that "multi-arity base names live only in
  ;; the ambient current-multi-defn-registry, which carries no module
  ;; provenance". Probed 2026-08-04: false at HEAD. A multi-arity `defn` ALSO
  ;; takes a local global-env binding, so `global-env-lookup-local` sees it and
  ;; the existing Q_B gate covers this direction like the other three.
  ;;
  ;; Pinned in BOTH spellings, because the entry's premise was specifically
  ;; about the registry rather than the spec: with a `spec` and without one.
  (define with-spec
    (result-msg (run-ns-ws-last
                 (string-append "ns qb8\n"
                                "spec zzz Nat -> Bool\n"
                                "defn zzz\n  | zero -> true\n  | suc _ -> false\n"
                                "defr zzz [?x]\n  || 1\n"))))
  (check-true (string-contains? with-spec "already defined as a function/value") with-spec)
  (define no-spec
    (result-msg (run-ns-ws-last
                 (string-append "ns qb9\n"
                                "defn www\n  | zero -> true\n  | suc _ -> false\n"
                                "defr www [?x]\n  || 1\n"))))
  (check-true (string-contains? no-spec "already defined as a function/value") no-spec))

(test-case "POL.9c/Q_B CANARY: defr over an IMPORTED multi-defn stays legal"
  ;; The entry's stated reason for leaving the direction ungated was that
  ;; gating "would fire on prelude multi-defns (`nth` and friends)". It does
  ;; not — the gate is local-only, and `nth` arrives through the cascade. This
  ;; is the canary for that specific fear, alongside the `xor` one above.
  (define r (run-ns-ws-last
             (string-append "ns qb10\n"
                            "defr nth [?a ?b]\n  || 1 2 | 3 4\n"
                            "solve (nth x y)")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "{:x 1, :y 2}") r))

(test-case "POL.9c/Q_B: multi-arity defn BASE name gated against a prior defr"
  (define m (result-msg (run-ns-ws-last
                         (string-append "ns qb7\n"
                                        "defr nsize [?s]\n  || 3\n"
                                        "defn nsize\n"
                                        "  | [x] -> x\n"
                                        "  | [x y] -> [+ x y]\n"))))
  (check-true (string-contains? m "already defined as a relation") m))

;; ========================================================================
;; X.close Batch A — gap-closing tests (2026-07-25).
;; The PIR's adversarial audit found these surfaces shipped without pins.
;; ========================================================================

;; ── SC: the REPL/editor preparse-macro fix (`19d9f8ae`) ─────────────────
;; SC fixed an owner-reported blocker — `process-string-ws` (the path the
;; REPL/LSP use) had been made cell-pipeline-only, silently dropping
;; preparse-macro support, so `solver` reached the tree parser unexpanded
;; ("solver should have been expanded before parsing"). It shipped with ZERO
;; tests; the commit cited "130 REPL/LSP/WS tests pass", which is
;; pre-existing regression evidence, not a pin on the fixed behavior.
;; These three run through run-ns-ws-last == process-string-ws == the exact
;; path that was broken.

(define SC-FIX
  (string-append
   "ns sctest\n"
   "defr edge [?a ?b]\n"
   "  || \"x\" \"y\"\n"
   "     \"y\" \"z\"\n"
   "solver cfg\n"
   "  :tabling by-default\n"))

(test-case "SC: a NAMED solver config expands and `solve-with` dispatches (the owner's blocker)"
  (define r (run-ns-ws-last (string-append SC-FIX "solve-with cfg (edge a b)")))
  (check-true (string? r) (result-msg r))
  (check-false (string-contains? (format "~a" r) "should have been expanded")
               "the `solver` preparse macro must expand on the WS-string path")
  (check-true (string-contains? r "{:a \"x\", :b \"y\"}")))

(test-case "SC: inline `solve-with {overrides}` works on the WS-string path"
  (define r (run-ns-ws-last
             (string-append SC-FIX "solve-with {:tabling by-default} (edge a b)")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "{:a \"y\", :b \"z\"}")))

(test-case "SC: the `:semantics` key expands too (WFLE-era solver form)"
  (define r (run-ns-ws-last
             (string-append "ns sctest2\n"
                            "defr e [?a]\n  || 1\n"
                            "solver wf\n  :semantics well-founded\n"
                            "solve-with wf (e a)")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "{:a 1}")))

;; ── POL.8: the merge FUTURE-TRAP, test-pinned ───────────────────────────
;; Design §8 names it in prose only: adding a `defr` arm to driver.rkt's
;; `surf-source-line` / `same-form-type?` would silently flip the L2 merge
;; winner to the srcloc-STRIPPED tree-spine surf — and POL.8's grammar is
;; column-based, so it would break with no failure at the point of change.
;; run-ns-ws-last IS the L2 path, so layout parsing here is exactly the
;; canary: if the winner flips, the stripped surf cannot see columns and
;; the sibling/continuation distinction collapses.

(test-case "POL.8 FUTURE-TRAP canary: layout still parses on the L2 (merge) path"
  (define r (run-ns-ws-last
             (string-append P8FIX
                            "defr canary [?fruit ?not-color]\n"
                            "  &> fruit-color fruit color\n"
                            "     not\n"
                            "       = color not-color\n"
                            "solve (canary f \"red\")")))
  (check-true (string? r) (result-msg r))
  ;; If the merge winner flipped to the stripped surf, the deeper line could
  ;; not be distinguished from a sibling goal and this would not be `not`-filtered.
  (check-true (string-contains? r "blueberry"))
  (check-false (string-contains? r "cherry")
               "a flipped merge winner loses column info and breaks the nesting"))

;; ── POL.8/POL.9 error branches that had no coverage ─────────────────────

(test-case "POL.8: an empty `&>` clause is accepted (no goals)"
  (define r (run-ns-ws-last (string-append P8FIX "defr empt [?x]\n  &>\n")))
  (check-false (prologos-error? r) (result-msg r)))

(test-case "POL.8: a multi-token bare line at the goal column is a SIBLING goal"
  ;; The Q5 residual: paren-origin and indent-origin groups are
  ;; indistinguishable post-reader, so a multi-token bare line reads as the
  ;; sibling it was meant to be. Pinned so the behavior is deliberate.
  (define r (run-ns-ws-last
             (string-append P8FIX
                            "defr sib [?f]\n"
                            "  &> fruit-color f \"blue\"\n"
                            "     fruit-color f \"blue\"\n"
                            "solve (sib q)")))
  (check-true (string? r) (result-msg r))
  (check-true (string-contains? r "blueberry")))

(test-case "POL.9: `raise-unknown-relation-error` branch 3 — a NON-function value head"
  ;; branch 1 = defr-failed-to-register, branch 2 = Pi-typed (function),
  ;; branch 3 = bound as a non-function value. Only 1 and 2 were covered.
  (define m (result-msg (run-ns-ws-last
                         (string-append P9FIX
                                        "def notafn := 42\n"
                                        "(notafn q)"))))
  (check-true (string-contains? m "bound as a value") m)
  (check-true (string-contains? m "defr")
              (format "the message should point at how to define a relation: ~a" m)))

(test-case "POL.4: a MULTI-ARITY relation accepts any variant arity (arity=#f path)"
  ;; Named as a watchout when POL.4 landed (multi-arity relations are
  ;; first-class, relation-info-arity = #f) but never pinned.
  (define r (run-ns-ws-last
             (string-append "ns polma\n"
                            "defr ma\n"
                            "  | [?x]    || 1\n"
                            "  | [?x ?y] || 2 3\n"
                            "solve (ma a)")))
  (check-true (string? r) (result-msg r))
  (check-false (string-contains? (format "~a" r) "Unknown procedure")
               "a valid variant arity must not trip the POL.4 gate"))

;; ── Q_N1 (X.close ruling, 2026-07-25): the GOAL KEYWORDS take the implicit
;; solve. `paren-goal-stx?`'s keyword exclusion protects EXPRESSION forms; it
;; had nothing to say about goals, so `not`/`=`/`is` rode it incidentally.
;; The set {rel, not, =, is} is DERIVED from run-solve-goal's dispatch — these
;; tests pin that equality, so a goal kind added there without being added to
;; `goal-keywords` shows up as a failure here.

(define QN1FIX
  (string-append
   "ns qn1\n"
   "defr blocked [?c]\n"
   "  || \"c\"\n"))

(test-case "Q_N1: `(not (goal))` at command position ≡ `solve (not (goal))`"
  ;; WAS: a stuck `reduce` term typed Bool, with ZERO errors — the
  ;; silent-useless-answer shape. Now it evaluates as NAF.
  (define implicit (run-ns-ws-last (string-append QN1FIX "(not (blocked \"c\"))")))
  (define explicit (run-ns-ws-last (string-append QN1FIX "solve (not (blocked \"c\"))")))
  (check-true (string? implicit) (result-msg implicit))
  (check-equal? implicit explicit "implicit and explicit spellings must agree")
  (check-false (string-contains? implicit "reduce")
               "must not leave a stuck reduce term"))

(test-case "Q_N1: NAF that SUCCEEDS also agrees with the explicit spelling"
  (define implicit (run-ns-ws-last (string-append QN1FIX "(not (blocked \"zzz\"))")))
  (define explicit (run-ns-ws-last (string-append QN1FIX "solve (not (blocked \"zzz\"))")))
  (check-equal? implicit explicit)
  (check-true (string-contains? implicit "{}") "an unblocked term satisfies the negation"))

(test-case "Q_N1: `(= a b)` is a unify GOAL at command position"
  (define implicit (run-ns-ws-last (string-append QN1FIX "(= 1 1)")))
  (define explicit (run-ns-ws-last (string-append QN1FIX "solve (= 1 1)")))
  (check-equal? implicit explicit))

(test-case "Q_N1: `(is q 5)` is an is-GOAL at command position (was an ERROR)"
  (define implicit (run-ns-ws-last (string-append QN1FIX "(is q 5)")))
  (define explicit (run-ns-ws-last (string-append QN1FIX "solve (is q 5)")))
  (check-true (string? implicit) (result-msg implicit))
  (check-equal? implicit explicit)
  (check-true (string-contains? implicit "{:q 5}")))

(test-case "Q_N1: the FUNCTIONAL spellings are untouched — brackets stay application"
  ;; The delimiter convention's own spelling. This is what keeps Bool
  ;; negation/equality reachable after the goal keywords were whitelisted.
  (check-true (string-contains? (run-ns-ws-last (string-append QN1FIX "[not true]")) "false"))
  (check-true (string-contains? (run-ns-ws-last (string-append QN1FIX "[not false]")) "true"))
  (check-true (string-contains? (run-ns-ws-last (string-append QN1FIX "[= 1 1]")) "true")))

(test-case "Q_N1: EXPRESSION keywords still keep their forms (the exclusion still works)"
  (check-true (string-contains? (run-ns-ws-last (string-append QN1FIX "(+ 1 2)")) "3"))
  (check-true (string-contains? (run-ns-ws-last (string-append QN1FIX "(the Int 4)")) "4")))

(test-case "Q_N1: guard/cut are NOT goal keywords (run-solve-goal does not dispatch them)"
  ;; They are clause-body-only (the A.1 mini-audit finding). Pinned so that
  ;; widening `goal-keywords` past the dispatch set is a deliberate act.
  (check-false (memq 'guard '(rel not = is)) "guard must stay out of goal-keywords")
  (check-false (memq 'cut '(rel not = is)) "cut must stay out of goal-keywords"))

(test-case "Q_N1: goal keywords reach the def RHS too — PARITY with the explicit spelling"
  ;; The def RHS is command position (Q_C), so the goal keywords dispatch there
  ;; as well. Both spellings currently hit the PRE-EXISTING POL.9b def-seam gap
  ;; ("Expression is not a valid type" — the def arm type-checks the body before
  ;; evaluation, so the solve row-type path errors ahead of any runtime answer).
  ;; That gap is filed in DEFERRED.md; what Q_N1 must guarantee is that the two
  ;; spellings behave IDENTICALLY. When the def-seam gap is fixed, both flip
  ;; together and this test keeps holding.
  (define implicit (result-msg (run-ns-ws-last
                                (string-append QN1FIX "def u := (not (blocked \"zzz\"))"))))
  (define explicit (result-msg (run-ns-ws-last
                                (string-append QN1FIX "def u := solve (not (blocked \"zzz\"))"))))
  (check-equal? implicit explicit
                "the implicit goal-keyword RHS must behave exactly like the explicit solve"))

;; ========================================================================
;; X.close Batch C — the un-arm'd-node → spurious "Multiplicity violation"
;; class, 3rd instance. `inferQ` had a lam arm ONLY inside the beta-redex
;; case, so a lambda reached in INFER position (a map VALUE) fell to the
;; catch-all → tu-error → checkQ-top's generic "Multiplicity violation".
;; typing-core's `infer` has the mirror arm; the twins had diverged.
;;
;; NOTE the recorded repro was `def := [validate …]` — probing showed
;; `validate` is a RED HERRING: it delegates to its subject, and the subject
;; was the map-with-a-lambda. The defect is both narrower (any map value that
;; is a lambda) and broader (nothing to do with schemas) than recorded.
;; ========================================================================

(test-case "Batch C: a map value that is a LAMBDA no longer dies as a multiplicity violation"
  ;; THE ROOT, minimal — no validate, no schema.
  (define r (run-ns-ws-last "ns bcroot\ndef m := {:f [fn [y : Nat] [add y 1N]]}\nm"))
  (check-false (prologos-error? r) (result-msg r))
  (check-true (string-contains? (result-msg r) ":f") (result-msg r)))

(test-case "Batch C: the map's TYPE is right, not merely error-free"
  (define r (run-ns-ws-last "ns bcty\ndef m := {:f [fn [y : Nat] {:a y}]}\nm"))
  (check-false (prologos-error? r) (result-msg r))
  (check-true (string-contains? (result-msg r) "Nat -> {:a Nat}")
              (format "expected the field to carry a function type, got: ~a" (result-msg r))))

(test-case "Batch C: the RECORDED instance-3 repro (def := [validate …]) now types"
  ;; The shape as first seen (SUB.1 probe, `f19d6f56`): validate over a schema
  ;; whose field is FUNCTION-typed. Simpler validate spellings never reproduced
  ;; it — the lambda is what mattered.
  (define VS (string-append "ns bcval\n"
                            "schema FnBox\n"
                            "  :f <Nat -> [Map Keyword Nat]>\n"))
  (define r (run-ns-ws-last
             (string-append VS "def vr := [validate FnBox {:f [fn [y : Nat] {:a y}]}]\nvr")))
  (check-false (prologos-error? r) (result-msg r))
  (check-true (string-contains? (result-msg r) "ok") (result-msg r)))

(test-case "Batch C: infer-position and check-position AGREE on a legal linear lambda"
  ;; The fix must not make infer position more permissive OR stricter than the
  ;; canonical check-mode path. A linear binder used exactly once is legal.
  (define bare (run-ns-ws-last "ns bcm1\ndef a := [fn [x :1 Nat] x]\na"))
  (define inmap (run-ns-ws-last "ns bcm2\ndef a := {:f [fn [x :1 Nat] x]}\na"))
  (check-false (prologos-error? bare) (result-msg bare))
  (check-false (prologos-error? inmap) (result-msg inmap))
  (check-true (string-contains? (result-msg inmap) ":1")
              "the linear multiplicity must survive into the map's field type"))

(test-case "Batch C: a GENUINE multiplicity violation in a map value still FAILS CLOSED"
  ;; The fix removes the FALSE positive, not the check. Named limitation: in
  ;; infer position this surfaces as "Could not infer type" rather than
  ;; "Multiplicity violation" — inferQ's protocol has only tu / tu-error, no
  ;; distinct multiplicity channel. Loud and sound, just less precise; pinned
  ;; here so that if the channel is ever added, this test says so.
  (define r (run-ns-ws-last "ns bcbad\ndef b := {:f [fn [x :1 Nat] [pair x x]]}\nb"))
  (check-true (prologos-error? r)
              "using a linear binder twice must still be rejected inside a map value"))

(test-case "Batch C: the untouched neighbours still behave (regression guard)"
  (define scalar (run-ns-ws-last "ns bcn1\ndef m := {:a 1}\nm"))
  (define barefn (run-ns-ws-last "ns bcn2\ndef f := [fn [y : Nat] {:a y}]\nf"))
  (check-false (prologos-error? scalar) (result-msg scalar))
  (check-false (prologos-error? barefn) (result-msg barefn)))

;; ============================================================================
;; LEVEL 3 — the POL cluster through `process-file`
;; ============================================================================
;;
;; Everything above this line is Level 2 (`run-ns-ws-last`, a WS string in a
;; preloaded env). `testing.md` mandates three-level validation for syntax
;; features, and POL.7/8/9 ARE syntax features: `||` fact blocks, paren-dropped
;; `&>` goal groups, and the implicit `solve` at command position.
;;
;; Until now the cluster's L3 coverage rode entirely on
;; `examples/2026-07-19-rel-t1-acceptance.prologos` via
;; `tests/test-rel-t1-acceptance.rkt` — one file, asserted only at the
;; whole-file level (0 errors + marker positions). That is a gate, but it is not
;; per-construct coverage: a POL.8 continuation rule could break and the
;; acceptance file would still pass if its own shapes happened not to use it.
;;
;; What L3 actually adds over L2 here is real, not ceremonial. Top-level
;; scoping, file-level preparse, and multi-form interaction differ from
;; string-mode processing, and the implicit-solve rule is defined BY command
;; position — so "is this a goal?" is precisely a question L2 cannot ask the
;; same way.

;; Run a .prologos string through the full pipeline (Level 3); return results.
;; Seeded from the prelude snapshot (as the sibling -naf / -typed-rows files do)
;; so each case costs milliseconds instead of a 39-module prelude reload; the
;; relation store stays FRESH, which is the isolation that matters here.
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

(define (l3-errors results)
  (filter prologos-error? results))

(define (l3-msg r)
  (if (prologos-error? r) (prologos-error-message r) (format "~a" r)))

;; ----------------------------------------------------------------------------
;; POL.7 — `||` fact blocks
;; ----------------------------------------------------------------------------

(test-case "L3/POL.7: a `||` block chunks by arity, one row per line"
  (define rs (run-prologos-string
              (string-append
               "ns l3pol7 :no-prelude\n\n"
               "defr fruit-color [?fruit ?color]\n"
               "  || \"apple\" \"red\"\n"
               "     \"banana\" \"yellow\"\n"
               "     \"grape\" \"purple\"\n\n"
               "(fruit-color f \"yellow\")\n")))
  (check-equal? (map l3-msg (l3-errors rs)) '() "expected 0 errors")
  (check-true (string-contains? (l3-msg (last rs)) "banana")
              (l3-msg (last rs))))

(test-case "L3/POL.7: `|` separates EXPLICIT rows on one line"
  (define rs (run-prologos-string
              (string-append
               "ns l3pol7b :no-prelude\n\n"
               "defr fruit-color [?fruit ?color]\n"
               "  || \"apple\" \"red\" | \"banana\" \"yellow\" | \"grape\" \"purple\"\n\n"
               "(fruit-color f \"purple\")\n")))
  (check-equal? (map l3-msg (l3-errors rs)) '() "expected 0 errors")
  (check-true (string-contains? (l3-msg (last rs)) "grape") (l3-msg (last rs))))

(test-case "L3/POL.7: a `|` segment that does not match the arity is a LOUD error"
  ;; It used to register a silent dead row that no query could ever match.
  ;; The message must name both the segment's size and the relation's arity —
  ;; without both numbers the author cannot tell which side is wrong.
  (define rs (run-prologos-string
              (string-append
               "ns l3pol7c :no-prelude\n\n"
               "defr fruit-color [?fruit ?color]\n"
               "  || \"apple\" | \"red\"\n")))
  (define errs (l3-errors rs))
  (check-equal? (length errs) 1 "the malformed row must be reported, not skipped")
  (define m (l3-msg (car errs)))
  (check-true (string-contains? m "1 term") m)
  (check-true (string-contains? m "arity is 2") m))

;; ----------------------------------------------------------------------------
;; POL.8 — `&>` groups may drop the goal parens; LAYOUT decides
;; ----------------------------------------------------------------------------

(define L3-FRUIT
  (string-append
   "defr fruit-color [?fruit ?color]\n"
   "  || \"apple\" \"red\"\n"
   "     \"banana\" \"yellow\"\n"
   "     \"grape\" \"purple\"\n\n"))

(test-case "L3/POL.8: a bare head is ONE goal; a line at the goal column is a SIBLING goal"
  (define rs (run-prologos-string
              (string-append
               "ns l3pol8 :no-prelude\n\n" L3-FRUIT
               "defr fruit-not-of-color [?fruit ?not-color]\n"
               "  &> fruit-color fruit color\n"
               "     not (= color not-color)\n\n"
               "(fruit-not-of-color f \"red\")\n")))
  (check-equal? (map l3-msg (l3-errors rs)) '() "expected 0 errors")
  ;; parens inside a bare-head line are ARGUMENT terms, so `not (= c n)` is one
  ;; goal with one argument — not two goals.
  (define m (l3-msg (last rs)))
  (check-true (string-contains? m "banana") m)
  (check-true (string-contains? m "grape") m)
  (check-false (string-contains? m "apple") "the red fruit must be excluded"))

(test-case "L3/POL.8: a line indented DEEPER continues the previous goal as its argument"
  ;; Same relation as above, written with `not` and its argument on separate
  ;; lines. The two spellings must agree — that agreement IS the layout rule.
  (define flat (run-prologos-string
                (string-append
                 "ns l3pol8a :no-prelude\n\n" L3-FRUIT
                 "defr r [?fruit ?not-color]\n"
                 "  &> fruit-color fruit color\n"
                 "     not (= color not-color)\n\n"
                 "(r f \"red\")\n")))
  (define deep (run-prologos-string
                (string-append
                 "ns l3pol8b :no-prelude\n\n" L3-FRUIT
                 "defr r [?fruit ?not-color]\n"
                 "  &> fruit-color fruit color\n"
                 "     not\n"
                 "       = color not-color\n\n"
                 "(r f \"red\")\n")))
  (check-equal? (map l3-msg (l3-errors flat)) '() "flat spelling: expected 0 errors")
  (check-equal? (map l3-msg (l3-errors deep)) '() "deep spelling: expected 0 errors")
  (check-equal? (l3-msg (last deep)) (l3-msg (last flat))
                "the deeper-continuation spelling must mean the same thing"))

;; ----------------------------------------------------------------------------
;; POL.9 — goals carry an implicit `solve` at COMMAND position
;; ----------------------------------------------------------------------------

(test-case "L3/POL.9: a paren group at top level IS a goal"
  (define rs (run-prologos-string
              (string-append
               "ns l3pol9 :no-prelude\n\n" L3-FRUIT
               "(fruit-color f \"red\")\n"
               "solve (fruit-color f \"red\")\n")))
  (check-equal? (map l3-msg (l3-errors rs)) '() "expected 0 errors")
  (define n (length rs))
  (check-equal? (l3-msg (list-ref rs (- n 2))) (l3-msg (list-ref rs (- n 1)))
                "the implicit form must equal the explicit `solve`"))

(test-case "L3/POL.9: a paren group on a `def` RHS is a goal (POL.10 snapshot)"
  (define rs (run-prologos-string
              (string-append
               "ns l3pol9b :no-prelude\n\n" L3-FRUIT
               "def yellows := (fruit-color f \"yellow\")\n"
               "yellows\n")))
  (check-equal? (map l3-msg (l3-errors rs)) '() "expected 0 errors")
  (define m (l3-msg (last rs)))
  (check-true (string-contains? m "banana") m)
  ;; The snapshot is a real value, not a stuck goal term.
  (check-false (string-contains? m "solve") m))

(test-case "L3/POL.9: `foo x` and `[foo x]` stay APPLICATION — scope is parens only"
  (define rs (run-prologos-string
              (string-append
               "ns l3pol9c :no-prelude\n\n"
               "spec inc Int -> Int\n"
               "defn inc [n] [int+ n 1]\n\n"
               "inc 1\n"
               "[inc 1]\n")))
  (check-equal? (map l3-msg (l3-errors rs)) '() "expected 0 errors")
  (define n (length rs))
  (check-true (string-contains? (l3-msg (list-ref rs (- n 1))) "2")
              "[inc 1] must apply, not query")
  (check-equal? (l3-msg (list-ref rs (- n 2))) (l3-msg (list-ref rs (- n 1)))
                "the bracket and bare spellings are the same application"))

;; ----------------------------------------------------------------------------
;; POL.9 diagnostics — the three that guide rather than merely reject
;; ----------------------------------------------------------------------------

(test-case "L3/POL.9: a paren goal over a FUNCTION says how application is written"
  (define rs (run-prologos-string
              (string-append
               "ns l3pol9d :no-prelude\n\n"
               "spec inc Int -> Int\n"
               "defn inc [n] [int+ n 1]\n\n"
               "(inc 1)\n")))
  (define errs (l3-errors rs))
  (check-equal? (length errs) 1)
  (define m (l3-msg (car errs)))
  (check-true (string-contains? m "is a function") m)
  (check-true (string-contains? m "[inc")
              (format "must show the working spelling; got: ~a" m)))

(test-case "L3/POL.9: a wrong arity gets the SWI-style 'however, there are definitions for'"
  (define rs (run-prologos-string
              (string-append
               "ns l3pol9e :no-prelude\n\n"
               "defr edge [?a ?b]\n  || \"x\" \"y\"\n     \"y\" \"z\"\n\n"
               "(edge a)\n")))
  (define errs (l3-errors rs))
  (check-equal? (length errs) 1)
  (define m (l3-msg (car errs)))
  (check-true (string-contains? m "edge/1") m)
  (check-true (string-contains? m "edge/2")
              (format "must name the arity that DOES exist; got: ~a" m)))

(test-case "L3: `defn` and `defr` namespaces are DISJOINT within a module"
  (define rs (run-prologos-string
              (string-append
               "ns l3xk :no-prelude\n\n"
               "spec twice Int -> Int\n"
               "defn twice [n] [int* n 2]\n\n"
               "defr twice [?x]\n  || 1\n")))
  (define errs (l3-errors rs))
  (check-equal? (length errs) 1 "the second registration must be refused")
  (define m (l3-msg (car errs)))
  (check-true (string-contains? m "already defined") m)
  (check-true (string-contains? m "cannot be both") m))
