#lang racket/base

;;;
;;; Rel/CIU seam spin-out — the SOLVE CARRIER: List → PVec.
;;; docs/tracking/2026-07-31_SOLVE_CARRIER_SPINOUT.md
;;;
;;; Discharges CIU T6 Path Selection's Q_U9: `:` broadcast REFUSES over `List`
;;; because `List` is a user-space inductive with no native carrier struct. Every
;;; other selection carrier is native (Map→champ, PVec→rrb, Set→hset,
;;; tuple→Record), so the fix is upstream — change what `solve` PRODUCES.
;;;
;;; These pin the FIVE surfaces the flip touches, three of which fail SILENTLY
;;; (they degrade, they do not error), plus the two RULINGS that bound its scope.
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt"
         (only-in "../typing-core.rkt" refine-solve-row-type-for-display)
         (only-in "../pnet-serialize.rkt" deep-struct->serializable deep-serializable->struct)
         (only-in "../syntax.rkt" expr-rrb expr-rrb-racket-rrb expr-champ expr-keyword expr-string)
         (only-in "../rrb.rkt" rrb-from-list rrb-to-list)
         (only-in "../champ.rkt" champ-empty champ-insert)
         ;; D4.P4d slice 7: the fusion gate + the head sets it now reads
         (only-in "../macros.rkt" access-sentinel?)
         (only-in "../reader-forms.rkt"
                  arity2-access-sentinel-heads brace-access-sentinel-heads
                  subject-preserving-access-heads subject-preserving-access-head?))

;; A small world: a 2-column relation, a duplicate-bearing one, and a
;; heterogeneous-column one (whose static column type is a UNION).
(define world
  (string-append
   "ns sc\n"
   "defr fc [?f ?c]\n"
   "  || \"apple\" \"red\"\n"
   "     \"banana\" \"yellow\"\n"
   "     \"cherry\" \"red\"\n"
   "defr twice [?n]\n"
   "  || 1\n"
   "     1\n"
   "     2\n"
   "defr val [?k ?v]\n"
   "  || :a 1\n"
   "     :b \"two\"\n"))

(define (ws expr) (run-ns-ws-last (string-append world expr "\n")))

;; An error's message text, whatever error struct it is (the family shares the
;; message field position via prologos-error-message).
(define (error-text r)
  (if (string? r) r (format "~a" r)))

;; The P2 guided diagnostic for a relation used in APPLICATION position.
(define (relation-diagnostic? r)
  (and (not (string? r))
       (regexp-match? #rx"is a relation, not a function" (error-text r))))

;; ========================================
;; The carrier
;; ========================================

(test-case "solve returns a PVec of rows, not a List"
  (define r (ws "solve (fc f \"red\")"))
  (check-true (string? r) (format "~a" r))
  (check-true (string-contains? r "@[") "the VALUE is a PVec literal")
  (check-true (string-contains? r "[PVec {:f String}]") "…and the TYPE is [PVec row]")
  (check-false (string-contains? r "List") "no List anywhere in value or type"))

(test-case "an implicit solve (POL.10 def RHS) carries the same carrier"
  (define r (ws "def rows := (fc f \"red\")\nrows"))
  (check-true (string? r) (format "~a" r))
  (check-true (string-contains? r "[PVec {:f String}]")))

(test-case "explain flips WITH solve (ruling R1) — same carrier, 'dyn-tailed row"
  (define r (ws "explain (fc f \"red\")"))
  (check-true (string? r) (format "~a" r))
  (check-true (string-contains? r "@[") "explain's value is a PVec too")
  (check-true (string-contains? r "PVec") "…and so is its type")
  (check-true (string-contains? r "| _") "explain rows keep the 'dyn tail for :provenance et al.")
  (check-true (string-contains? r ":provenance") "…and still carry the metadata"))

(test-case "solve-one is UNCHANGED (ruling R2) — a bare row, not any container"
  (define r (ws "solve-one (fc f \"red\")"))
  (check-true (string? r) (format "~a" r))
  (check-false (string-contains? r "@[")   "not a PVec")
  (check-false (string-contains? r "PVec") "not PVec-typed")
  (check-false (string-contains? r "List") "and not List-typed either")
  (check-true (string-contains? r "{:f String}") "just the bare row (D25.4 unwrapped)"))

;; ========================================
;; Invariants the flip must not break
;; ========================================

(test-case "BAG semantics survive: duplicate rows are PRESERVED, not deduped"
  ;; Rel T1 POL.1: one row per derivation path; the multiplicity IS the
  ;; derivation count (ℕ-semiring provenance). PVec is ordered and
  ;; duplicate-bearing, so this is carried exactly — pinned, not assumed.
  (define r (ws "solve (twice n)"))
  (check-true (string? r) (format "~a" r))
  (check-equal? (length (regexp-match* #rx"\\{:n 1\\}" r)) 2
                "the two derivations of n=1 both appear")
  (check-true (string-contains? r "{:n 2}")))

(test-case "the empty result is @[] — an empty PVec that still announces its row type"
  ;; the one deliberate user-visible shape change: `nil` was a nullary List
  ;; constructor carrying no container identity at the value level.
  (define r (ws "solve (fc f \"blue\")"))
  (check-true (string? r) (format "~a" r))
  (check-true (string-contains? r "@[]"))
  (check-false (string-contains? r "nil"))
  (check-true (string-contains? r "[PVec {:f String}]") "the row type is still announced"))

(test-case "POL.3 declaration-order echo survives the carrier change"
  ;; the driver's ordered-echo walker had to grow an rrb arm; without it the echo
  ;; falls back to pp-expr and keys silently revert to champ-hash order.
  (define r (ws "solve (fc f c)"))
  (check-true (string? r) (format "~a" r))
  (check-true (regexp-match? #rx"\\{:f [^}]*:c " r)
              "keys read f then c — the goal's positional query-var order"))

(test-case "B3.2 display refinement still fires through the PVec carrier"
  ;; THE CAPTURE-GAP PIN. `:v` is statically a union (the fact rows disagree); a
  ;; query returning only Int rows must SHARPEN the echoed type while the stored
  ;; type keeps the union. Both display walkers must handle the carrier or this
  ;; degrades silently — no error, just a less precise echo.
  (define stored (ws "def only-a := solve (val :a v)\nonly-a"))
  (check-true (string? stored) (format "~a" stored))
  (check-true (string-contains? stored "[PVec {:v Int}]")
              "the ECHO of the def-bound value is sharpened to Int by observation")
  (define union-r (ws "solve (val k v)"))
  (check-true (string-contains? union-r "Int | String")
              "…while a query spanning both rows keeps the union"))

;; ========================================
;; Scope rulings, made executable
;; ========================================

(test-case "R3: functional-logic NARROWING stays on the List carrier"
  ;; narrowing shares the row-building helper but is a different feature, typed
  ;; expr-hole. Flipping it would move a runtime shape with no type to match.
  ;; sexp mode: `(= (f ?x) target)` elaborates to expr-narrow (in WS the same
  ;; text is a unify GOAL — the institutionalized WS/sexp divergence).
  (define r (run-ns-last "(ns t)\n(= (not ?b) true)\n"))
  (check-true (string? r) (format "~a" r))
  (check-true (string-contains? r "'[") "narrowing still yields a List literal")
  (check-false (string-contains? r "@[") "…and specifically NOT the PVec carrier"))

;; ========================================
;; The .pnet carrier round-trip
;; ========================================

(define (row s)
  (define k (expr-keyword 'f))
  (expr-champ (champ-insert champ-empty (equal-hash-code k) k (expr-string s))))

(test-case "a PVec of rows survives .pnet serialization with hashes RECOMPUTED"
  ;; POL.10 lets a `def` bind a whnf-reduced solve result into a module
  ;; env-snapshot, so the carrier reaches the cache. rrb-root's `tail` is a RAW
  ;; RACKET VECTOR and deep-s->v has no vector? arm, so before the rrb-sentinel
  ;; arm the champ rows inside leaked through `[else v]` VERBATIM — persisting
  ;; equal-hash-code values, which are process-stable ONLY.
  (define v (expr-rrb (rrb-from-list (list (row "apple") (row "cherry")))))
  (define ser (deep-struct->serializable v))
  (check-true (and (list? ser) (eq? (car ser) 'rrb-sentinel))
              "serialized reconstructively, not as a raw struct walk")
  (check-false (regexp-match? #rx"[0-9]{10,}" (format "~s" ser))
               "no equal-hash-code is persisted (the champ-sentinel invariant)")
  (define back (deep-serializable->struct ser))
  (check-equal? (length (rrb-to-list (expr-rrb-racket-rrb back))) 2)
  (check-equal? (map (lambda (r) (format "~s" r)) (rrb-to-list (expr-rrb-racket-rrb back)))
                (map (lambda (r) (format "~s" r)) (rrb-to-list (expr-rrb-racket-rrb v)))
                "contents round-trip identically"))

(test-case "an EMPTY PVec round-trips through .pnet"
  (define e (expr-rrb (rrb-from-list '())))
  (define back (deep-serializable->struct (deep-struct->serializable e)))
  (check-equal? (rrb-to-list (expr-rrb-racket-rrb back)) '()))

;; ========================================
;; P2 — the `let` binding-RHS implicit solve (ruling R6)
;; ========================================
;; `def x := (goal …)` carried an implicit solve (POL.9b) but `let x := (goal …)`
;; did not — the LET track landed a new binding form and the scope never grew.
;; The reader mints a `$goal-rhs` sentinel around a paren value in binding
;; position (the paren-origin SYNTAX PROPERTY cannot survive: `expand-let` is a
;; preparse macro and receives fully stripped datums); the parser, which owns the
;; keyword table, decides goal-ness. Neither side duplicates the other's table.

(test-case "let x := (goal …) carries the implicit solve — nested shorthand"
  (define r (ws "let xs := (fc f \"red\")\n  xs"))
  (check-true (string? r) (format "~a" r))
  (check-true (string-contains? r "[PVec {:f String}]"))
  (check-true (string-contains? r "apple")))

(test-case "…the ALIGNED block, alongside an ordinary binding"
  (define r (ws "let xs (fc f \"red\")\n    n 7\n  xs"))
  (check-true (string? r) (format "~a" r))
  (check-true (string-contains? r "[PVec {:f String}]")))

(test-case "…and the BRACKET form"
  (define r (ws "let [xs := (fc f \"red\")] xs"))
  (check-true (string? r) (format "~a" r))
  (check-true (string-contains? r "[PVec {:f String}]")))

(test-case "the EXPLICIT spelling still works — no DOUBLE solve"
  ;; REGRESSION PIN. The first position rule wrapped every non-body paren child,
  ;; so in `let ls := solve (goal …)` it wrapped `solve`'s ARGUMENT and produced
  ;; `solve (solve …)` — which echoed as a stuck `(solve @[…]) : _`. The rule now
  ;; mirrors POL.9b: only a SINGLE-element value after `:=` qualifies, so a
  ;; multi-token RHS stays the auto-wrapped application it always was.
  (define r (ws "let ls := solve (fc f \"red\")\n  ls"))
  (check-true (string? r) (format "~a" r))
  (check-false (string-contains? r "(solve") "the goal is solved ONCE, not wrapped again")
  (check-true (string-contains? r "[PVec {:f String}]")))

(test-case "a NON-goal keyword head in a let RHS keeps its expression reading"
  ;; the parser's keyword table is what makes this work; the reader only reports
  ;; \"this was in parens, in binding position\".
  (check-true (string-contains? (ws "let n := (+ 1 2)\n  n") "3 : Int"))
  (check-true (string-contains? (ws "let n := (the Int 4)\n  n") "4 : Int")))

(test-case "SCOPE BOUND: a paren goal in ARGUMENT position is NOT an implicit solve"
  ;; R6 scopes the rule to a BINDING RHS. General expression position keeps the
  ;; old reading — a goal there would make ordinary calls re-query the ambient
  ;; fact store, which is the standing purity concern.
  (define r (ws "let n := [pvec-length-int (fc f \"red\")]\n  n"))
  (check-false (string? r) "argument position is still an error")
  (check-true (relation-diagnostic? r) "…but a GUIDED one that names the fix"))

(test-case "a let BODY is not a binding RHS — no implicit solve there either"
  (define r (ws "let n := 1\n  (fc f \"red\")"))
  (check-false (string? r) "the body keeps its pre-existing reading")
  (check-true (relation-diagnostic? r)))

(test-case "flat-pair bracket bindings mark the VALUE slots, not the names"
  (define r (ws "let [xs (fc f \"red\") n 7] xs"))
  (check-true (string? r) (format "~a" r))
  (check-true (string-contains? r "[PVec {:f String}]")))

;; ========================================
;; P2 — the guided diagnostic (the INVERSE of POL.9's)
;; ========================================
;; relations.rkt already guided the goal-over-a-function case (`(dbl 3)` → "dbl
;; is a function — application is written [dbl …]"). The mirror image had no
;; diagnostic: APPLYING a relation surfaced whatever its ARGUMENTS did — for the
;; common `[fc f "red"]` shape a bare "Unbound variable f", naming the query
;; variable rather than the mistake. `f` is unbound precisely BECAUSE this should
;; have been a goal.

(test-case "applying a relation with a FREE var: guided, not `Unbound variable f`"
  (define r (ws "[fc f \"red\"]"))
  (check-true (relation-diagnostic? r) (format "~a" r))
  (check-false (regexp-match? #rx"Unbound variable" (error-text r))
               "the old message named the query var, not the mistake"))

(test-case "applying a relation with GROUND args: same message, not `Could not infer type`"
  ;; the all-ground shape took a different route (it reached typing), so it used
  ;; to produce a different unhelpful error. One message now covers both.
  (define r (ws "[fc \"apple\" \"red\"]"))
  (check-true (relation-diagnostic? r) (format "~a" r))
  (check-false (regexp-match? #rx"Could not infer type" (error-text r))))

(test-case "the diagnostic does NOT fire for a function — `[dbl 3]` still evaluates"
  (define r (ws "defn dbl [x:Int] : Int\n  * x 2\n[dbl 3]"))
  (check-true (string? r) (format "~a" r))
  (check-true (string-contains? r "6 : Int")))

(test-case "a LOCAL BINDING shadowing a relation name is not diagnosed"
  ;; the env check is load-bearing: inside `[fn [fc] …]` the name is an ordinary
  ;; parameter, not a goal head. Without the guard this became the relation
  ;; diagnostic — a wrong error on correct code.
  (define r (ws "[fn [fc] [fc 1]]"))
  (check-false (relation-diagnostic? r)
               "shadowed name elaborates as a local, whatever it then infers to"))

(test-case "the diagnostic is NAMESPACE-scoped — a same-named relation elsewhere is not it"
  ;; REGRESSION PIN. The first cut consulted the relation STORE and matched any
  ;; key ending `::m`. The store is not namespace-scoped, so a relation `m` in
  ;; one namespace mis-diagnosed an unrelated `def m := {…}` in another — it
  ;; broke four Batch-C tests that have nothing to do with relations. Going
  ;; through the GLOBAL ENV (where a defr name is bound to an expr-defr value)
  ;; makes namespace- and rebinding-correctness structural rather than checked.
  (void (run-ns-ws-last (string-append world "solve (fc f \"red\")")))
  (define r (run-ns-ws-last "ns other\ndef fc := {:a 1}\nfc"))
  (check-false (relation-diagnostic? r) (format "~a" r))
  (check-true (string? r) (format "~a" r)))

(test-case "…and REBINDING-scoped — `def` over a defr name stops the diagnostic"
  (define r (run-ns-ws-last (string-append world "def fc := 5\n[int+ fc 1]")))
  (check-false (relation-diagnostic? r) (format "~a" r)))

(test-case "the let walk does NOT descend into a `racket{…}` foreign block"
  ;; REGRESSION PIN, found by the FULL SUITE and by nothing else. At reader stage
  ;; a foreign block is still ORDINARY SYNTAX (combine-foreign-blocks runs later,
  ;; at preparse), so a blind walk reaches the HOST language's code. A Racket
  ;; `(let loop ([n 10] [acc 0]) …)` is `let`-headed, so mark-let-goal-rhs wrapped
  ;; `([n 10] [acc 0])` in a `$goal-rhs` sentinel and corrupted the block.
  ;; The SINGLE-LINE racket{…} shape passes either way — only the multi-line one
  ;; carries an embedded `let`, which is why targeted runs stayed green.
  (define r (run-ns-ws-last
             (string-append
              "ns fb\n"
              "def fy : Nat racket{\n"
              "  (let loop ([n 10] [acc 0])\n"
              "    (if (zero? n) acc\n"
              "        (loop (sub1 n) (add1 acc))))\n"
              "}\n"
              "fy\n")))
  (check-true (string? r) (format "~a" r))
  (check-true (string-contains? r "10") "the host-language let still evaluates"))

;; ========================================
;; CIU T6 D4.P4d slice 7 — a paren goal that is the SUBJECT of a postfix access
;; ========================================
;; `(fc f "red")` carries its implicit solve; `(fc f "red"):f` did not. By
;; REFERENTIAL TRANSPARENCY it must — it is the same value with the same
;; selection applied. Owner-requested 2026-08-08.
;;
;; WHY THE OBVIOUS FIX IS WRONG, and why these pins are shaped as they are.
;; The reader mints a postfix sentinel as a SIBLING of its subject, never a
;; wrapper: `(G):f` reads as `((G) ($bcast-step :f))`. So `parse-command-datum`
;; tests goal-ness on the OUTER list and the solve is skipped. The tempting
;; repair — descend to the subject and re-test `paren-goal-stx?` there — is
;; REFUTED by measurement: `(G).0` and the bracket APPLICATION `[get (G) 0]`
;; produce a BYTE-IDENTICAL datum with IDENTICAL syntax properties
;; (top paren-origin=#f, subject paren-origin=#t). A property-keyed subject fix
;; cannot tell them apart and would widen Q_C into argument position — the
;; exact thing "SCOPE BOUND" above pins as out of scope.
;;
;; So the witness is the DATUM sentinel `$goal-rhs`, on the argument the reader
;; already records for the analogous problem one level in ("preserve that bit in
;; the DATUM, where stripping cannot reach it" — parse-reader.rkt). A syntax
;; PROPERTY cannot serve: it is attached to every lparen group with no position
;; test, so it SURVIVES in two positions that must refuse (a `defn` body, a
;; nested bracket) and is STRIPPED in three that must solve (def RHS, aligned
;; let RHS, every chain) — i.e. it is anti-correlated with the answer.
;;
;; EXISTENCE PROOF that the sentinel reaches the subject seat and works there:
;; `let [zb := (fc f "red"):f] zb` ALREADY evaluates correctly at HEAD, because
;; the bracket-`let` arm of `mark-binding-values` is the one arm with no
;; element-count gate. Slice 7 makes the other command positions reach the same
;; mechanism; it does not invent one.

;; Level 3 (process-file) — testing.md's three-level rule. The defect was
;; reported against a .prologos file, and Level 3 is the level that catches
;; top-level scoping. Returns ALL results so a whole-file abort is visible as
;; MISSING output rather than as a changed error.
(define (s7-file src)
  (run-ns-ws-file-all
   (string-append world "def s7-before := 1\n" src "\ndef s7-after := 42\n")))

(define (s7-survived? rs)
  (and (ormap (lambda (r) (and (string? r) (string-contains? r "s7-before"))) rs)
       (ormap (lambda (r) (and (string? r) (string-contains? r "s7-after"))) rs)))

;; THE DIFFERENTIAL ORACLE. Referential transparency is the whole proposition,
;; so assert it directly: the one-step form must produce what the two-step form
;; produces — whatever that is. This is deliberately NOT "assert the rows":
;; three of the spellings (`.f`, `{f}`, and the chains) are legitimately REFUSED
;; even for an ordinary value, and pinning their refusal TEXT would pin the
;; wrong proposition. What must never differ is one-step vs two-step.
;; ⚠ These deliberately do NOT go through `s7-file`: its `def s7-after := 42`
;; trailer would be the `last` result on BOTH sides, so the comparison would be
;; vacuously true and `relation-diagnostic?` would inspect that trailer instead
;; of the answer. (Observed: the first draft of this oracle passed at RED.)
;; Whole-file survival is asserted by the SEAM pins below, which do use s7-file.
;; The oracle compares the IMPLICIT spelling against the EXPLICIT one —
;; `(fc f "red"):f` vs `[solve (fc f "red")]:f` — which is the equivalence
;; POL.9b already pins at the def seam ("paren and explicit spellings are
;; byte-equivalent", test-rel-t1-pol.rkt). It is tighter than comparing against
;; a NAMED two-step binding: three of these selectors are legitimately REFUSED
;; even for an ordinary value, and a refusal message embeds the rendered
;; subject term — so a named binding differs cosmetically (`sc::s7b.f` vs
;; `(solve (fc ?f "red")).f`) while meaning the same thing. Against the
;; explicit spelling the subject term is identical, so the comparison can be
;; exact without pinning any particular diagnostic's wording.
(define (s7-eval src) (last (run-ns-ws-file-all (string-append world src "\n"))))
(define (s7-two-step sel)
  (s7-eval (string-append "[solve (fc f \"red\")]" sel)))
(define (s7-one-step sel)
  (s7-eval (string-append "(fc f \"red\")" sel)))

(define S7-SELECTORS
  ;; every postfix surface the reader supports over a paren subject.
  ;; `.f` is the PLAIN DOT — the commonest selection surface, and absent from
  ;; the original defect report. `[0]` is byte-identical to `.0` (Q_R1's "two
  ;; surfaces over ONE mechanism"), so pinning only one leaves a live hole.
  (list ":f" ".0" "[0]" ".f" "{f}" ":{f}" ":f:g" ".0:f"))

(test-case "P4d-s7: a paren goal under a postfix access equals its two-step spelling"
  ;; RED at b6f773a8: every selector returns the relation diagnostic instead.
  (for ([sel (in-list S7-SELECTORS)])
    (define one (s7-one-step sel))
    (define two (s7-two-step sel))
    (check-false (relation-diagnostic? one)
                 (format "~s must not be read as APPLICATION of the relation: ~a" sel one))
    (check-equal? (format "~a" one) (format "~a" two)
                  (format "~s: one-step must equal two-step (referential transparency)" sel))))

(test-case "P4d-s7: the value spellings actually produce the rows"
  ;; the oracle above would be satisfied by two matching ERRORS, so pin the
  ;; three selectors that have a real answer.
  (define r (s7-one-step ":f"))
  (check-true (string? r) (format "~a" r))
  (check-true (string-contains? r "apple"))
  (check-true (string-contains? r "cherry"))
  (check-true (string-contains? r "[PVec String]")))

(test-case "P4d-s7: the def RHS seam"
  ;; RED for a DIFFERENT reason than the top-level cases: `def-rhs-stx` requires
  ;; exactly ONE element after `:=`, and a postfix access is TWO reader
  ;; elements, so the Q_C stamp is never applied at all.
  (define rs (s7-file "def okA := (fc f \"red\"):f\nokA"))
  (check-true (s7-survived? rs) (format "per-command errors only: ~a" rs))
  (check-false (ormap relation-diagnostic? rs) (format "~a" rs))
  (check-true (ormap (lambda (r) (and (string? r) (string-contains? r "apple"))) rs)
              (format "~a" rs)))

(test-case "P4d-s7: the let binding-RHS seam — the `:=` spelling"
  ;; SCOPED DELIBERATELY TO ONE SPELLING, and the scoping is a measurement, not
  ;; a convenience. Of the four `let` binding spellings, only `let x := V`
  ;; accepts a postfix access on an ORDINARY value at HEAD; the other three
  ;; refuse `let … xs:name` with no goal anywhere in sight:
  ;;   let [p1 xs:name] p1     → "each binding must be (name value) …"
  ;;   let [p2 := xs:name] p2  → "Could not infer type"
  ;;   let p3 xs:name          → the guided fused-annotation/broadcast-step error
  ;; Those are PRE-EXISTING and independent of slice 7 — a goal cannot be made
  ;; to work there without first fixing the ordinary-value case. Filed as
  ;; DEFERRED 97 rather than silently pinned here, because a pin over someone
  ;; else's defect is how a slice acquires unrelated failures.
  ;; [owner ruling 2026-08-08] "the `let`s shouldn't disagree on their behavior
  ;; whether they use a `:=` or not" — so the `:=` and ALIGNED-BLOCK spellings
  ;; are pinned together. The bracket form has its own regression pin below.
  (for ([src (in-list (list "let lz := (fc f \"red\"):f\n  lz"
                            "let p 1\n    lz (fc f \"red\"):f\n  lz"))])
    (define rs (s7-file src))
    (check-true (s7-survived? rs) (format "~s: ~a" src rs))
    (check-false (ormap relation-diagnostic? rs) (format "~s: ~a" src rs))
    (check-true (ormap (lambda (r) (and (string? r) (string-contains? r "apple"))) rs)
                (format "~s must bind the solved rows: ~a" src rs))))

(test-case "P4d-s7: a multi-line `def` RHS keeps its solve"
  ;; [owner ruling 2026-08-08] "the multi-line `def` shouldn't lose it's solve".
  ;; A continuation-line value is nested ONE level deeper than the one-line
  ;; spelling — `(def D := ((g …) ($bcast-step :c)))` — so the one-line form
  ;; worked and this did not.
  (define rs (s7-file "def D :=\n  (fc f \"red\"):f\nD"))
  (check-true (s7-survived? rs) (format "~a" rs))
  (check-false (ormap relation-diagnostic? rs) (format "~a" rs))
  (check-true (ormap (lambda (r) (and (string? r) (string-contains? r "apple"))) rs)
              (format "~a" rs)))

(test-case "P4d-s7 GUARD: a user BRACKET in that same position still does NOT solve"
  ;; ⚠ THE PIN THAT PAYS FOR THE BRACKET MARK. `def B := [(g …):c]` produces an
  ;; element BYTE-IDENTICAL to the multi-line layout group above — same datum,
  ;; same span, no properties (measured). Seeing through the layout group
  ;; without a way to tell the two apart would mint a goal in ARGUMENT position.
  ;; `prologos-bracket-origin` is what makes "unmarked ⇒ layout" structural.
  (define rs (s7-file "def B := [(fc f \"red\"):f]"))
  (check-true (s7-survived? rs) (format "~a" rs))
  (check-true (ormap relation-diagnostic? rs)
              (format "a bracket argument must keep its application reading: ~a" rs)))

(test-case "P4d-s7: the bracket-`let` REGRESSION pin — it already worked"
  ;; `let [zb := (goal …):f] zb` evaluates correctly at HEAD, because the
  ;; bracket-`:=` arm of `mark-binding-values` is the one arm with no
  ;; element-count gate — it minted `$goal-rhs`, which landed in SUBJECT
  ;; position and was consumed there by `parse-datum`'s existing sentinel arm.
  ;; That is the EXISTENCE PROOF slice 7's design rests on: the mechanism works
  ;; in subject position, it was simply unreachable from the other spellings.
  ;; This pin exists so that proof cannot silently rot.
  (define rs (s7-file "let [zb := (fc f \"red\"):f] zb"))
  (check-false (ormap relation-diagnostic? rs) (format "~a" rs))
  (check-true (ormap (lambda (r) (and (string? r) (string-contains? r "apple"))) rs)
              (format "~a" rs)))

;; ---------------------------------------------------------------------------
;; THE SCOPE GUARD. These are the pins slice 7 exists to keep GREEN, not to
;; flip. Each is a position that must CONTINUE to refuse. The first is the
;; load-bearing one: its datum is byte-identical to `(G).0`'s, so it is the
;; canary for a property-keyed or shape-keyed fix widening Q_C.
;; ---------------------------------------------------------------------------

(test-case "P4d-s7 GUARD: `[get (goal …) 0]` is APPLICATION, not a selection"
  ;; ⚠ THE DISCRIMINATOR. `[get (fc f "red") 0]` and `(fc f "red").0` produce
  ;; the SAME datum with the SAME syntax properties. Only the reader can tell
  ;; them apart — brackets never carry paren-origin — which is precisely why
  ;; the witness has to be minted there and not recovered in the parser.
  (define r (ws "[get (fc f \"red\") 0]"))
  (check-false (string? r) "argument position stays an error")
  (check-true (relation-diagnostic? r) (format "…and a guided one: ~a" r)))

(test-case "P4d-s7 GUARD: a `defn` body does NOT solve, with or without access"
  ;; The standing purity question (.claude/rules/prologos-syntax.md): a goal in
  ;; a defn body would make ordinary CALLS re-query the ambient fact store.
  ;; ⚠ This position CARRIES paren-origin on the subject today, so it is the
  ;; sharpest test of a property-keyed fix — and a widening here reads as an
  ;; IMPROVEMENT to an error-count gate (1 error → 0), i.e. it is silent.
  (for ([body (in-list '("(fc f \"red\"):f" "(fc f \"red\")" "(fc f \"red\").0"))])
    (define rs (s7-file (string-append "defn s7hz [x]\n  " body)))
    (check-true (s7-survived? rs) (format "~s: ~a" body rs))
    (check-true (ormap relation-diagnostic? rs)
                (format "a defn body must still refuse ~s: ~a" body rs))))

(test-case "P4d-s7 GUARD: nested brackets, match arms and fn bodies do NOT solve"
  (for ([src (in-list (list "def s7n := [[(fc f \"red\"):f]]"
                            "def s7m := match 1\n  | 1 -> (fc f \"red\"):f"
                            "def s7f := [fn [y : Int] (fc f \"red\"):f]"
                            "def s7a := [pvec-length-int (fc f \"red\"):f]"))])
    (define rs (s7-file src))
    (check-true (s7-survived? rs) (format "~s: ~a" src rs))
    (check-true (ormap relation-diagnostic? rs)
                (format "~s must stay application: ~a" src rs))))

(test-case "P4d-s7 GUARD: a let BODY is still not a binding RHS, under access too"
  (define r (ws "let n := 1\n  (fc f \"red\"):f"))
  (check-false (string? r) "the body keeps its pre-existing reading")
  (check-true (relation-diagnostic? r) (format "~a" r)))

(test-case "P4d-s7 GUARD: the EXPLICIT spelling still solves ONCE under access"
  ;; the double-solve regression, re-run through the new subject seat.
  (define r (ws "def s7e := solve (fc f \"red\")\ns7e:f"))
  (check-true (string? r) (format "~a" r))
  (check-false (string-contains? r "(solve") "solved once, not wrapped again")
  (check-true (string-contains? r "apple")))

(test-case "P4d-s7 GUARD: sexp mode is untouched — `(get …)` stays application"
  ;; The WS/sexp divergence is institutionalized for BARE paren goals only. The
  ;; sexp reader never attaches paren-origin and never mints `$goal-rhs`, so a
  ;; shape-keyed fix keying on the head `get` (a USER-WRITABLE keyword, unlike
  ;; the `$`-prefixed internal sentinels) would leak a SECOND divergence.
  (define r (run-ns-last (string-append
                          "(ns s7x)\n"
                          "(def mm : (Map Keyword Int) {:a 1})\n"
                          "(get mm :a)\n")))
  (check-true (string-contains? (format "~a" r) "1") (format "~a" r)))

;; ---------------------------------------------------------------------------
;; The re-homing of the access-sentinel head sets (slice 7 support change).
;; `access-sentinel?` — preparse's FUSION GATE — used to be a nine-way
;; disjunction of per-sentinel predicates; it now reads the head sets in
;; reader-forms.rkt so the READER can consume the same list (it cannot require
;; macros.rkt). These pin that the re-expression is FAITHFUL, and that the
;; subject-preserving subset really is a subset.
;; ---------------------------------------------------------------------------

(test-case "P4d-s7: the fusion gate agrees with the shared head sets"
  ;; every arity-2 head is a sentinel at arity 2, and NOT at other arities
  (for ([h (in-list arity2-access-sentinel-heads)])
    (check-true  (access-sentinel? (list h 'x)) (format "~a at arity 2" h))
    (check-false (access-sentinel? (list h))    (format "~a at arity 1" h))
    (check-false (access-sentinel? (list h 'x 'y)) (format "~a at arity 3" h)))
  ;; the brace family takes an arbitrary-length body — head alone is enough
  (for ([h (in-list brace-access-sentinel-heads)])
    (check-true (access-sentinel? (list h))       (format "~a head-only" h))
    (check-true (access-sentinel? (list h 'a 'b)) (format "~a with a body" h)))
  ;; and nothing else is
  (check-false (access-sentinel? '($select-path x y)) "the FOLD's own output is not a sentinel")
  (check-false (access-sentinel? '($goal-rhs x))      "the goal marker is not a sentinel")
  (check-false (access-sentinel? 'foo))
  (check-false (access-sentinel? '(foo x))))

(test-case "P4d-s7: every subject-preserving head is a real access sentinel"
  ;; the subset relation is the invariant: a head that preserves its subject
  ;; must first BE a sentinel, or the reader would mark a subject the fold
  ;; never consumes.
  (for ([h (in-list subject-preserving-access-heads)])
    (check-true (subject-preserving-access-head? h))
    (check-not-false (or (memq h arity2-access-sentinel-heads)
                         (memq h brace-access-sentinel-heads))
                     (format "~a must be in one of the head sets" h)))
  ;; the EXCLUDED heads are excluded on purpose — their fold arms discard the
  ;; base (the retired family → ($retired-selection …), $dot-brace likewise),
  ;; so there is no subject left to carry a goal.
  (for ([h (in-list '($dot-key $nil-dot-key $broadcast-access $dot-brace))])
    (check-false (subject-preserving-access-head? h)
                 (format "~a DESTROYS its base — it must not be marked" h))))

(test-case "P4d-s7: the reader's mark and the fold's gate agree on ARITY, not just heads"
  ;; ⚠ FOUND BY THE ADVERSARIAL VERIFY, and it is the drift the head-set
  ;; re-homing was supposed to prevent — committed in the very change that
  ;; claimed to unify the two predicates. `access-sentinel-elem?` (reader) tested
  ;; only the HEAD while `access-sentinel?` (preparse fold) tests head AND arity,
  ;; so a mis-arity sentinel was MARKED but never FOLDED and leaked to
  ;; elaboration as `Unbound variable $dot-access` — where HEAD reported the
  ;; relation diagnostic. Sharing a list does not make two predicates agree.
  (define rs (s7-file "(fc f \"red\") ($dot-access a b c)"))
  (check-true (s7-survived? rs) (format "~a" rs))
  (check-false (ormap (lambda (r) (regexp-match? #rx"Unbound variable [$]dot-access"
                                                 (error-text r)))
                      rs)
               (format "a mis-arity sentinel must not leak past the fold: ~a" rs)))

;; ---------------------------------------------------------------------------
;; The widening, and the diagnostic that makes it acceptable.
;; [owner ruling 2026-08-08] "If `(...)` is our relational delimiters, with an
;; implicit `solve` on it, then wrapping other values in them does seem like it
;; should be a properly-guided error."
;; Base was INCONSISTENT here: bare `(mm)` already refused, while `(mm).a`
;; quietly treated the parens as grouping and returned the field. Slice 7 makes
;; the access agree with the bare form — and hoists the guided diagnostic to
;; ELABORATION so it survives the selection seat, where type-checking used to
;; fail first and report "the subject is not a record" instead.
;; ---------------------------------------------------------------------------

(define (s7-guided? r)
  (regexp-match? #rx"parens make a relational goal" (error-text r)))

(test-case "P4d-s7: a VALUE in parens is refused the same way bare or under an access"
  (define rs (s7-file (string-append "def mm := {:a 1 :b 2}\n" "(mm)\n" "(mm).a\n" "(mm):a")))
  (check-true (s7-survived? rs) (format "~a" rs))
  (define guided (filter s7-guided? rs))
  (check-equal? (length guided) 3
                (format "all three spellings must give the GUIDED diagnostic: ~a" rs))
  ;; …and specifically NOT the unguided type error the select used to report
  (check-false (ormap (lambda (r) (regexp-match? #rx"subject is not a record" (error-text r))) rs)
               (format "the guided message must survive the selection seat: ~a" rs)))

(test-case "P4d-s7: the guided refusal names a real source location"
  ;; the runtime diagnostic arrived with `<unknown>`; deciding at elaboration
  ;; gives it the goal's own srcloc, which is strictly better than base.
  (define rs (s7-file "def mm := {:a 1}\n(mm).a"))
  (define g (findf s7-guided? rs))
  (check-not-false g (format "~a" rs))
  (check-false (regexp-match? #rx"<unknown>" (format "~a" g))
               (format "the refusal must carry a real srcloc: ~a" g)))

(test-case "P4d-s7: an UNKNOWN head is left alone — forward references still work"
  ;; the elaboration-time check refuses only a head that is env-bound and NOT a
  ;; relation. An unknown name must stay the runtime "Unknown relation" path,
  ;; because a relation may be registered by a LATER command in the same file.
  (define rs (s7-file "(nosuchrel x y)"))
  (check-true (s7-survived? rs) (format "~a" rs))
  (check-true (ormap (lambda (r) (regexp-match? #rx"Unknown relation" (error-text r))) rs)
              (format "~a" rs)))

(test-case "P4d-s7: the WHOLE solve family refuses a non-relation the same way"
  ;; ⚠ POST-VERIFY FIX. The first cut hoisted the diagnostic for `surf-solve`
  ;; only, leaving `solve-one` / `explain` / the `-with` pair on the RUNTIME
  ;; path — same message, two production sites, and an `<unknown>` srcloc on one
  ;; of them. That is the drift class, self-inflicted, in the change whose own
  ;; commit message complains about drift. Found by A/B against base, not by a
  ;; test — which is why this one exists.
  (define rs (s7-file (string-append "def mm := {:a 1}\n"
                                     "solve (mm)\n" "solve-one (mm)\n"
                                     "explain (mm)\n" "(mm)")))
  (check-true (s7-survived? rs) (format "~a" rs))
  (define guided (filter s7-guided? rs))
  (check-equal? (length guided) 4
                (format "every member of the family must refuse: ~a" rs))
  (check-false (ormap (lambda (r) (regexp-match? #rx"<unknown>" (format "~a" r))) guided)
               (format "…and each with a REAL srcloc, not <unknown>: ~a" guided))
  ;; the `who` prefix matches the runtime site's own label, so the text is
  ;; unchanged from base — only WHERE it is produced moved.
  (check-true (ormap (lambda (r) (regexp-match? #rx"explain: mm is bound" (error-text r))) guided)
              (format "explain keeps its own label: ~a" guided))
  (check-true (ormap (lambda (r) (regexp-match? #rx"solve: mm is bound" (error-text r))) guided)
              (format "solve keeps its own label: ~a" guided)))

(test-case "P4d-s7 GUARD: a solve UNDER A BINDER is never pre-judged"
  ;; ⚠ POST-RE-VERIFY FIX, and the sharpest of the three. Relation-hood is
  ;; resolved at SOLVE time, not elaboration time. `defn hops [x]` ⏎
  ;; `solve (link a b)` elaborates NOW but runs when `hops` is CALLED — by which
  ;; point `link` may be a relation that did not exist yet, or `hops` may never
  ;; be called. The first cut pre-judged it and REFUSED a program base compiles
  ;; and runs, so the function never defined at all. The elaboration-time check
  ;; is now depth-0 only; under any binder we say nothing and leave it to the
  ;; existing runtime diagnostic. False negatives (missed guidance) are fine
  ;; here; false positives are not.
  (define rs (s7-file (string-append "def link := \"cross-dock\"\n"
                                     "defn hops [x]\n  solve (link a b)")))
  (check-true (s7-survived? rs) (format "~a" rs))
  (check-true (ormap (lambda (r) (and (string? r) (string-contains? r "hops"))) rs)
              (format "the function must still DEFINE: ~a" rs))
  (check-false (ormap s7-guided? rs)
               (format "no elaboration-time refusal under a binder: ~a" rs)))

(test-case "P4d-s7 GUARD: `-with` keeps base's diagnostic ORDER and aim"
  ;; When BOTH the solver and the goal head are wrong, base points at the
  ;; offending SOLVER TOKEN. Checking the goal first replaced that with a
  ;; whole-form srcloc — same information, worse aim. The goal check therefore
  ;; sits AFTER the solver/overrides checks in the two `-with` arms.
  (define rs (s7-file "def mm := {:a 1}\nsolve-with nosuchcfg (mm 1)"))
  (check-true (s7-survived? rs) (format "~a" rs))
  (check-true (ormap (lambda (r) (regexp-match? #rx"Unbound variable nosuchcfg" (error-text r))) rs)
              (format "the SOLVER error must win, as at base: ~a" rs))
  (check-false (ormap s7-guided? rs)
               (format "…and the goal-head message must not pre-empt it: ~a" rs)))

(test-case "P4d-s7: a MISSPELLED relation is named, not drowned in a broadcast error"
  ;; ⚠ POST-RE-VERIFY FIX. Once the access spelling solves, `(fcc f "red"):f`
  ;; becomes `solve (fcc …)`, whose row is a hole — and the SELECTION then
  ;; reported "broadcast `:f` needs a PVec … this one is `_`" at `<unknown>`,
  ;; naming the wrong thing at no location, where base said `Unbound variable
  ;; fcc` at the token. The unknown arm restores the BARE form's own message.
  (define rs (s7-file "(fcc f \"red\"):f"))
  (check-true (s7-survived? rs) (format "~a" rs))
  (check-true (ormap (lambda (r) (regexp-match? #rx"Unknown relation: fcc" (error-text r))) rs)
              (format "the misspelling must be NAMED: ~a" rs))
  (check-false (ormap (lambda (r) (regexp-match? #rx"needs a PVec" (error-text r))) rs)
               (format "…not reported as a broadcast-carrier problem: ~a" rs))
  (check-false (ormap (lambda (r) (regexp-match? #rx"<unknown>" (format "~a" r))) rs)
               (format "…and at a real srcloc: ~a" rs)))

(test-case "P4d-s7: `def-` agrees with ITSELF, access or no access"
  ;; ⚠ POST-RE-VERIFY FIX. The mint normalized `def-` → `def` while the
  ;; pre-existing Q_C def leg (macros.rkt `def-rhs-stx`) matches `def`
  ;; literally — so adding an access to a REFUSING `def-` made it succeed. The
  ;; private spelling must not disagree with itself; whether `def-` should carry
  ;; Q_C at all is pre-existing (DEFERRED 97).
  (define rs (s7-file "def- pv := (fc f \"red\")\ndef- pa := (fc f \"red\"):f"))
  (check-true (s7-survived? rs) (format "~a" rs))
  (check-equal? (length (filter relation-diagnostic? rs)) 2
                (format "both `def-` spellings must behave the SAME: ~a" rs)))
