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
         (only-in "../champ.rkt" champ-empty champ-insert))

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
