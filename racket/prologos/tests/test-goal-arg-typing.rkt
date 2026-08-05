#lang racket/base

;;;
;;; DEFERRED 52 (chip `task_4c00d3f0`, filed 2026-08-05) — a type error in
;;; RELATIONAL GOAL-ARGUMENT position must be LOUD.
;;;
;;; The filed A/B ("a goal-position arity error becomes a silent empty bag")
;;; was a MIS-DIAGNOSIS, corrected by re-measurement 2026-08-05 against a
;;; pre-G2 baseline worktree (`ae26f540~1` = 0fd2098c):
;;;
;;;   - Pre-G2, `a:b` was SPLICED into two tokens, so a 2-argument call was
;;;     reported as `p2/4`. That "loud arity error" was itself a symptom of the
;;;     splicing bug — the diagnostic was a LIE. G2 made arity counting correct
;;;     (`(p2 1:Int)` → `p2/1`, `(p2 1:Int 2:Int 3:Int)` → `p2/3`, both right).
;;;   - The silent empty bag is NOT new and is unrelated to broadcast: pre-G2,
;;;     `(p2 1:Int)` already returned a silent `@[]`, and `[+ "str" 1]` /
;;;     `[undefined-fn 1]` in goal-arg position are silent on BOTH legs.
;;;
;;; THE ACTUAL DEFECT, verified by instrumenting `infer`: the goal arms of
;;; `infer` (typing-core.rkt, "Goals → Goal") call `infer` on each argument and
;;; DISCARD the result — including when that result is an `expr-error`. The same
;;; expression is loud in `def` position and as a bare expression command; only
;;; goal-argument position swallows it.
;;;
;;; Measured swallow shapes (all zero errors before the fix):
;;;   (q1 [+ "str" 1])   → @[]                — arg infers to expr-error, discarded
;;;   (q1 1:Int)         → @[]                — broadcast on a non-PVec subject
;;;   (is x [+ "str" 1]) → @[{:x unknown}]    — WORSE: a bogus BINDING, not an empty bag
;;;
;;; SCOPE BOUNDARY — which goal positions are EVALUATED (verified by probe):
;;;   `is`   evaluates its RHS      — (is x [+ 1 1]) → {:x 2}       ⇒ type errors are real
;;;   goal-app args are evaluated   — (q1 [+ 0 1])   → @[{}]        ⇒ type errors are real
;;;   `=`    does NOT evaluate      — (= x [+ 1 1])  → {:x unknown} ⇒ operands are TERMS
;;; So `expr-unify-goal` is deliberately NOT tightened: `=` renders ANY compound
;;; RHS as `unknown`, well-typed or not, so rejecting the ill-typed one would be
;;; inconsistent with accepting `[+ 1 1]`. (That `unknown` rendering is its own
;;; pre-existing defect — out of scope here, pinned below as status quo so a
;;; future change to it is deliberate.)
;;;
;;; ⚠ PIN SHAPE IS LOAD-BEARING. Every defect assertion below checks
;;; `prologos-error?` on the RESULT VALUE, never a substring of a rendered
;;; string. An empty bag renders as the STRING "@[] : _", so a substring-based
;;; pin would pass on exactly the failure mode this file exists to catch.
;;;

(require rackunit
         racket/string
         racket/set
         racket/port
         racket/runtime-path
         "test-support.rkt"
         (only-in "../errors.rkt" prologos-error? prologos-error-message))

(define (result-msg r) (if (prologos-error? r) (prologos-error-message r) r))

;; Resolved relative to THIS FILE, independent of the process cwd (see the DRIFT
;; GUARD test at the bottom for why that matters).
(define-runtime-path typing-propagators-path "../typing-propagators.rkt")
(define-runtime-path typing-core-path "../typing-core.rkt")

;; One fact, so a well-typed matching arg yields a solution and a well-typed
;; NON-matching arg yields a legitimately empty bag (the control that keeps the
;; fix from turning "no solutions" into an error).
(define FIX
  (string-append
   "ns goalargty\n"
   "defr q1 [?a]\n"
   "  || 1\n"))

(define (run body) (run-ns-ws-last (string-append FIX body)))

;; ── The defect: a type error in goal-argument position must be reported ──────

(test-case "DEFERRED 52: an ill-typed expression in goal-arg position is LOUD"
  (define r (run "(q1 [+ \"str\" 1])"))
  (check-true (prologos-error? r)
              (format "expected an error; got the silent-swallow result: ~a"
                      (result-msg r))))

(test-case "DEFERRED 52: a broadcast on a non-PVec subject in goal-arg position is LOUD"
  (define r (run "(q1 1:Int)"))
  (check-true (prologos-error? r)
              (format "expected an error; got: ~a" (result-msg r))))

(test-case "DEFERRED 52: `is` goal — an ill-typed RHS must not bind a bogus value"
  ;; `is` DOES evaluate its RHS, so this is a genuine evaluation failure. Pre-fix
  ;; it returned `@[{:x unknown}]` — a silent WRONG BINDING, strictly worse than
  ;; the empty bag the DEFERRED entry described.
  (define r (run "(is x [+ \"str\" 1])"))
  (check-true (prologos-error? r)
              (format "expected an error; got: ~a" (result-msg r))))

(test-case "DEFERRED 52: the swallow is not specific to implicit solve"
  (define r (run "solve (q1 [+ \"str\" 1])"))
  (check-true (prologos-error? r)
              (format "expected an error; got: ~a" (result-msg r))))

;; ── Controls: the fix must not over-reject ──────────────────────────────────
;;
;; These pin the BOUNDARY. Each one passed before the fix and must still pass
;; after it; together they say "only genuine type errors became loud".

(test-case "control: a ground matching arg still solves"
  (define r (run "(q1 1)"))
  (check-false (prologos-error? r) (result-msg r))
  (check-true (string-contains? r "@[{}]") r))

(test-case "control: a well-typed expression arg is evaluated and matches"
  (define r (run "(q1 [+ 0 1])"))
  (check-false (prologos-error? r) (result-msg r))
  (check-true (string-contains? r "@[{}]") r))

(test-case "control: a well-typed NON-matching arg is a legitimately empty bag, not an error"
  ;; The whole point of the pin shape above: "no solutions" is a real answer and
  ;; must stay silent. If this ever errors, the fix over-reached.
  (define r (run "(q1 2)"))
  (check-false (prologos-error? r) (result-msg r))
  (check-true (string-contains? r "@[]") r))

(test-case "control: a bare name in goal-arg position is a LOGIC VAR, not an error"
  (define r (run "(q1 nosuchvar)"))
  (check-false (prologos-error? r) (result-msg r))
  (check-true (string-contains? r ":nosuchvar") r))

(test-case "control: a compound term with an unknown functor stays a TERM (Prolog-correct)"
  ;; `[undefined-fn 1]` elaborates, under the relational fallback, to a nested
  ;; goal-app used as a TERM — `q1(undefined_fn(1))` is a legitimate query that
  ;; matches nothing. Its type is `expr-goal-type`, NOT `expr-error`, so the fix
  ;; must leave it alone. This is the arm that keeps the fix honest: it would be
  ;; easy to "fix" 52 by rejecting anything that fails to reduce to a value.
  (define r (run "(q1 [undefined-fn 1])"))
  (check-false (prologos-error? r) (result-msg r))
  (check-true (string-contains? r "@[]") r))

(test-case "control: `is` evaluates its RHS and binds the VALUE"
  (define r (run "(is x [+ 1 1])"))
  (check-false (prologos-error? r) (result-msg r))
  (check-true (string-contains? r ":x 2") r))

(test-case "control: `=` operands stay TERMS — not tightened, status quo pinned"
  ;; `=` does not evaluate: a well-typed compound RHS and an ill-typed one render
  ;; IDENTICALLY (`unknown`). That is why `expr-unify-goal` is out of scope for
  ;; the DEFERRED 52 fix. If a future change makes `=` evaluate, BOTH of these
  ;; move together — and this pin is what will say so.
  (define ok  (run "(= x [+ 1 1])"))
  (define bad (run "(= x [+ \"str\" 1])"))
  (check-false (prologos-error? ok) (result-msg ok))
  (check-false (prologos-error? bad) (result-msg bad))
  (check-true (string-contains? ok ":x unknown") ok)
  (check-true (string-contains? bad ":x unknown") bad))

(test-case "control: `=` on ground terms still unifies"
  (define r (run "(= 1 1)"))
  (check-false (prologos-error? r) (result-msg r))
  (check-true (string-contains? r "@[{}]") r))

;; ── Over-rejection controls found by the adversarial verify ──────────────────
;;
;; These three all PASSED before the DEFERRED 52 fix and broke under a first
;; version of it. They are the reason `goal-arg-excused?` excuses more than logic
;; variables: an `expr-error` out of the IMPERATIVE `infer` can also mean "this
;; inferencer has no arm for that node", which is not a user error.

(test-case "control: `[pair 1 2]` in goal-arg position must NOT error (inferencer gap != user error)"
  ;; Imperative `infer` has NO `expr-pair` arm — it types pairs only in `check`,
  ;; against an expected Sigma — so it falls to its catch-all `(expr-error)`. The
  ;; ON-NETWORK inferencer does have a rule, and the command boundary tries
  ;; on-network FIRST, which is why the identical `def` succeeds. Goal arguments
  ;; reach the imperative inferencer only.
  (define d (run "def zz := [pair 1 2]"))
  (check-false (prologos-error? d) (result-msg d))
  (check-true (string-contains? d "Sigma") d)
  (define r (run "(q1 [pair 1 2])"))
  (check-false (prologos-error? r)
               (format "a well-typed pair must not error in goal position; got: ~a"
                       (result-msg r)))
  (check-true (string-contains? r "@[]") r))

(test-case "control: a partial-application SECTION in an `is` RHS must NOT error"
  ;; `[int* _ 2]` is the idiom prologos-syntax.md explicitly recommends over an
  ;; inline `fn`. Sections type only in CHECK position, and an `is` RHS is
  ;; inferred with no expected type — so imperative `infer` yields `expr-error`.
  ;; It also escapes the logic-var guard by construction: the elaborator turns the
  ;; relational fallback OFF for an `is` RHS, so `_` stays a section hole
  ;; (`expr-hole`) instead of becoming a logic var. Excused via `expr-hole?`.
  (define r (run "(is g2 [int* _ 2])"))
  (check-false (prologos-error? r)
               (format "a section in an `is` RHS must not error; got: ~a" (result-msg r))))

(test-case "control: the 1-arg `(guard [pred])` form must NOT error"
  ;; elaborator.rkt builds `(expr-guard ec #f)` for the 1-arg form. The pre-fix arm
  ;; called `(infer ctx goal)` with goal=#f and DISCARDED the result; once the
  ;; result is consulted, the #f must be guarded — as every other walker over this
  ;; struct already does.
  (define r (run "solve (guard [lt 0 1])"))
  (check-false (prologos-error? r)
               (format "the 1-arg guard must not error; got: ~a" (result-msg r))))

(test-case "DRIFT GUARD: the infer-unsynthesizable? exempt set still matches the sources"
  ;; `infer-unsynthesizable?` (typing-core.rkt) is DERIVED, not guessed:
  ;;   {nodes with register-typing-rule!} MINUS {nodes with an imperative `infer`
  ;;   arm}, minus `expr-error` (an error IS an error and must never be excused).
  ;; Recompute it from source so a future `register-typing-rule!` for a node that
  ;; `infer` also lacks cannot silently widen the class — which would reintroduce
  ;; the `expr-pair` over-rejection under a different node name.
  ;; ⚠ define-runtime-path, NOT a relative string. A relative path resolves
  ;; against the PROCESS cwd, which differs between `raco test tests/foo.rkt`
  ;; (cwd = tests/) and the batch-worker suite runner (cwd = racket/prologos) —
  ;; so a string path here passes individually and ERRORS in the full suite. That
  ;; is exactly what happened the first time this test ran under `--all`.
  (define (slurp p) (call-with-input-file p port->string))
  (define tp (slurp typing-propagators-path))
  (define tc (slurp typing-core-path))
  (define rules
    (list->set (regexp-match* #rx"register-typing-rule![ \t]+[(]?(expr-[a-z0-9-]+)[?]"
                              tp #:match-select cadr)))
  (define ip (car (regexp-match-positions #rx"[(]define [(]infer ctx e[)]" tc)))
  (define after (substring tc (cdr ip)))
  (define nxt (regexp-match-positions #rx"\n[(]define [(]" after))
  (define body (if nxt (substring after 0 (caar nxt)) after))
  (define arms
    (list->set (regexp-match* #rx"[[][(](expr-[a-z0-9-]+)[ )]" body #:match-select cadr)))
  (define derived (set-remove (set-subtract rules arms) "expr-error"))
  (check-equal? derived (set "expr-pair" "expr-hole" "expr-reduce" "expr-refl")
                (format "derived exempt set moved — update infer-unsynthesizable? and read its comment; derived: ~a"
                        (sort (set->list derived) string<?))))

;; ── Clause bodies (owner-requested follow-up, 2026-08-05) ───────────────────
;;
;; The first DEFERRED 52 fix reached only TOP-LEVEL goals. `expr-clause` (and its
;; parents `expr-defr-variant` / `expr-rel` / `expr-defr`, and `expr-fact-block`)
;; still called `infer` for effect and discarded the result — so an ill-typed goal
;; inside a `defr` BODY, which is where nearly all real goal code lives, stayed
;; silent at registration and then quietly matched nothing at query time.
;;
;; Consequence of fixing it, stated plainly: an ill-typed clause body now makes
;; the `defr` FAIL TO REGISTER, so a later query reports the relation as unknown.
;; That matches how a parse-level clause error already behaves (DEFERRED 51's
;; ruled status quo) and how `def` behaves. It is a real behaviour change, not
;; just a new diagnostic.

(define CFIX
  (string-append
   "ns clausebody\n"
   "defr fc [?f ?c]\n"
   "  || \"blueberry\" \"blue\"\n"))

(define (crun body) (run-ns-ws-last (string-append CFIX body)))

(test-case "clause body: an ill-typed goal argument is LOUD at defr registration"
  (define r (crun "defr badclause [?x]\n  &> (fc x [+ \"str\" 1])\n"))
  (check-true (prologos-error? r)
              (format "expected the defr to fail; got: ~a" (result-msg r))))

(test-case "clause body: the relation is then reported unknown, not silently empty"
  ;; The failure mode being closed: pre-fix this returned `@[] : [PVec {:z String}]`
  ;; with ZERO errors — indistinguishable from "no solutions".
  (define r (crun (string-append "defr badclause2 [?x]\n  &> (fc x [+ \"str\" 1])\n"
                                 "solve (badclause2 z)")))
  (check-true (prologos-error? r)
              (format "expected an error at the query; got: ~a" (result-msg r))))

(test-case "control: a well-typed clause body still registers and answers"
  (define r (crun (string-append "defr okclause [?x]\n  &> (fc x \"blue\")\n"
                                 "solve (okclause z)")))
  (check-false (prologos-error? r) (result-msg r))
  (check-true (string-contains? r "blueberry") r))

(test-case "control: a clause body full of LOGIC VARS is not an error"
  ;; The excuse gate must still apply inside clause bodies — this is the shape
  ;; virtually every real rule has, and it must not become an error.
  (define r (crun (string-append "defr passthru [?f ?c]\n  &> (fc f c)\n"
                                 "solve (passthru a b)")))
  (check-false (prologos-error? r) (result-msg r))
  (check-true (string-contains? r "blueberry") r))

(test-case "control: a multi-goal clause with `not` and a guard still registers"
  (define r (crun (string-append "defr multi [?f]\n"
                                 "  &> (fc f c) (guard [lt 0 1])\n"
                                 "solve (multi q)")))
  (check-false (prologos-error? r) (result-msg r))
  (check-true (string-contains? r "blueberry") r))

(test-case "clause body: an UNPLUMBED goal form is now a per-command error, not a whole-file abort"
  ;; `all-different` / `element` / `cumulative` / `minimize` are parser-reachable
  ;; ONLY inside clause bodies (parser.rkt gates them on
  ;; `current-parsing-relational-goal?`), but they are not plumbed through the
  ;; pipeline — `zonk` has no arm, so at b429d038 this input died with
  ;;     match: no matching clause for (expr-all-different '(a b))   [zonk.rkt:75]
  ;; producing NO output at all: a WHOLE-FILE ABORT, the class
  ;; .claude/rules/pipeline.md tells us to hunt ("output is EMPTY, not partial").
  ;;
  ;; The clause-body propagation makes `infer` reject the clause BEFORE zonk runs,
  ;; so the defr fails as a per-command error and the file continues. Deliberately
  ;; NOT excused: excusing it would let the term reach zonk and restore the crash.
  ;; An adversarial verify called this a blocking regression on the belief that it
  ;; "registered" pre-change; measurement showed it aborted the file instead.
  (define r (run-ns-ws-last
             (string-append "ns gcpin\n"
                            "defr digits [?d]\n  || 1 | 2 | 3\n"
                            "defr c1 [?a ?b]\n  &> (digits a) (digits b) (all-different a b)\n"
                            "def marker := 99")))
  ;; The LAST command must have RUN — that is what proves the file continued.
  (check-false (prologos-error? r)
               (format "the file must continue past the bad defr; got: ~a" (result-msg r)))
  (check-true (string-contains? r "marker") r))
