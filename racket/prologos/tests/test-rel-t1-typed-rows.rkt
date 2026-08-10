#lang racket/base

;;;
;;; Rel Track 1 — Aspect B (typed solution rows), B1.
;;;
;;; solve/solve-with/solve-one/explain/explain-with over a SCHEMA'D goal-app now
;;; carry a typed per-solution ROW instead of a bare hole:
;;;   - keys  = query-var names Κ′ (Prolog-parity; from B0's classify-goal-args)
;;;   - types = the relation schema's field types α (positional bridge)
;;;   - wrap  = PVec<row> (solve/solve-with/explain*), bare row (solve-one)
;;;           (was List<row> until the SolveCarrier spin-out, 2026-07-31)
;;;   - explain rows carry a 'dyn tail for conditional reserved metadata keys
;;; Un-schema'd relations stay loose (expr-hole) — B2 refines the codata case.
;;;
;;; Exercises BOTH checkers (process-file runs infer + inferQ). The shared
;;; solve-row-type twin (typing-core + qtt) makes the row derivation single-source.
;;;

(require rackunit
         racket/list
         racket/string
         racket/path
         racket/file
         "../driver.rkt"
         "../errors.rkt"
         "../namespace.rkt"
         "../relations.rkt"
         "test-support.rkt"
         (only-in "../macros.rkt" current-preparse-registry current-trait-registry
                  current-impl-registry current-param-impl-registry)
         (only-in "../metavar-store.rkt" current-persistent-registry-net-box current-prop-net-box)
         (only-in "../propagator.rkt" with-forked-network))

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Run a .prologos string through the full pipeline (Level 3); return result strings.
(define (run-prologos-string content)
  (define tmp (make-temporary-file "rel-t1-rows-~a.prologos"))
  (call-with-output-file tmp
    (lambda (out) (display content out))
    #:exists 'truncate)
  (define results
    ;; Seed from the once-per-subprocess prelude snapshot instead of reloading
    ;; all 39 prelude modules per test case (~3.5s each, and none of it the thing
    ;; under test). The registry family is seeded TOGETHER — a preloaded module
    ;; registry means modules are not re-loaded, so seeding the module registry
    ;; alone would leave trait/impl empty. Mirrors test-support.rkt's run-ns-*.
    ;; The relation store stays FRESH: per-test fact isolation is the point here.
    (parameterize ([current-file-module-network-ref (make-module-network)]
                   [current-ns-context #f]
                   [current-module-registry prelude-module-registry]
                   [current-lib-paths (list lib-dir)]
                   [current-relation-store (make-relation-store)]
                   [current-preparse-registry prelude-preparse-registry]
                   [current-trait-registry prelude-trait-registry]
                   [current-impl-registry prelude-impl-registry]
                   [current-param-impl-registry prelude-param-impl-registry]
                   [current-persistent-registry-net-box prelude-persistent-registry-net-box]
                   [current-module-registry-cell-id #f]
                   [current-ns-context-cell-id #f])
      (with-forked-network current-prop-net-box
        (install-module-loader!)
        (process-file (path->string tmp)))))
  (delete-file tmp)
  results)

(define (last-result results) (last results))

;; A schema'd edge world (from/to : String, weight : Int) with multi-line facts.
(define edge-world
  (string-append
   "ns t\n\n"
   "schema Edge\n  :from String\n  :to String\n  :weight Int\n\n"
   "defr edge : Edge\n  || \"a\" \"b\" 3\n  || \"c\" \"d\" 5\n\n"))

;; ========================================
;; B1 — solve over a schema'd relation → PVec<row> (query-var keys, schema types)
;; ========================================

(test-case "B1: solve → PVec of a row keyed by query-vars, typed by the schema"
  (define r (last-result
             (run-prologos-string
              (string-append edge-world "solve (edge f t w)\n"))))
  (check-true (string-contains? r "PVec") "solve result is PVec-wrapped (SolveCarrier)")
  (check-false (string-contains? r "List") "…and no longer List-wrapped")
  ;; query-var keys (f/t/w), NOT schema field names (from/to/weight)
  (check-true (string-contains? r ":f String") "free arg f typed String (schema :from)")
  (check-true (string-contains? r ":t String") "free arg t typed String (schema :to)")
  (check-true (string-contains? r ":w Int")    "free arg w typed Int (schema :weight)")
  (check-false (string-contains? r ":from") "keys are query-var names, not schema field names")
  (check-false (string-contains? r ": _")   "solve over a schema'd relation is no longer an untyped hole"))

(test-case "B1: solve-one → BARE row (not List, not Option — D25.4 unwrapped)"
  (define r (last-result
             (run-prologos-string
              (string-append edge-world "solve-one (edge f t w)\n"))))
  (check-true (string-contains? r ":w Int") "solve-one row typed by the schema")
  (check-true (string-contains? r ":f String"))
  (check-false (string-contains? r "List")   "solve-one is a bare row, not List-wrapped")
  (check-false (string-contains? r "PVec")   "…and the SolveCarrier flip did NOT reach it (R2)")
  (check-false (string-contains? r "Option") "solve-one is unwrapped (D25.4), not Option"))

(test-case "B1: partially-ground goal → only the FREE positions become typed fields"
  (define r (last-result
             (run-prologos-string
              (string-append edge-world "solve (edge \"a\" t w)\n"))))
  (check-true (string-contains? r ":t String"))
  (check-true (string-contains? r ":w Int"))
  ;; :f is ground ("a"), so it is NOT a solution key
  (check-false (string-contains? r ":f") "ground position f is not a solution field"))

(test-case "B1: explain → PVec row with a 'dyn tail (open) for reserved metadata keys"
  (define r (last-result
             (run-prologos-string
              (string-append edge-world "explain (edge f t w)\n"))))
  (check-true (string-contains? r "PVec"))
  (check-true (string-contains? r ":w Int") "explain row typed by the schema")
  (check-true (string-contains? r "| _") "explain rows are open (dyn tail) for :provenance et al."))

;; ========================================
;; B1 — the composition (first-green): field projection off a solution row is TYPED
;; ========================================

(test-case "B1 first-green: (solve-one q).w projects to the schema field type Int"
  (define r (last-result
             (run-prologos-string
              (string-append edge-world "(solve-one (edge f t w)).w\n"))))
  (check-true (string-contains? r ": Int") "projected weight field is typed Int")
  (check-true (string-contains? r "3") "and evaluates to the first solution's weight"))

(test-case "B1 first-green: (solve-one q).f projects to the schema field type String"
  (define r (last-result
             (run-prologos-string
              (string-append edge-world "(solve-one (edge f t w)).f\n"))))
  (check-true (string-contains? r ": String") "projected from field is typed String"))

;; ========================================
;; B2 — codata: un-schema'd relation typing (the F1 `Map` side, one layer up)
;; ========================================

;; An un-schema'd FACTS-ONLY relation (a small standalone world per case).
(define plain-facts-world
  (string-append
   "ns t\n\n"
   "defr edge [?from ?to ?weight]\n  || \"a\" \"b\" 3\n  || \"c\" \"d\" 5\n\n"))

(test-case "B2: un-schema'd facts-only relation → row typed by OBSERVED literal types"
  (define r (last-result
             (run-prologos-string
              (string-append plain-facts-world "solve (edge f t w)\n"))))
  (check-true (string-contains? r "PVec"))
  (check-true (string-contains? r ":f String") "f observed String from the facts")
  (check-true (string-contains? r ":t String"))
  (check-true (string-contains? r ":w Int")    "w observed Int from the facts")
  (check-false (string-contains? r ": _") "an un-schema'd FACTS relation is no longer loose (B2)"))

(test-case "B2: heterogeneous column → a UNION of the observed types"
  (define r (last-result
             (run-prologos-string
              (string-append
               "ns t\n\n"
               "defr mixed [?x ?y]\n  || \"a\" 1\n  || 2 \"b\"\n\n"
               "solve (mixed x y)\n"))))
  ;; :x observed from "a" (String) and 2 (Int) → a union of the two
  (check-true (or (string-contains? r "String | Int") (string-contains? r "Int | String"))
              "heterogeneous column is a union of String and Int"))

(test-case "B2: field projection off an OBSERVED (un-schema'd) row is typed"
  (define r (last-result
             (run-prologos-string
              (string-append plain-facts-world "(solve-one (edge f t w)).w\n"))))
  (check-true (string-contains? r ": Int") "projected weight is Int (observed from facts)"))

;; FLIPPED at B3.1 (was: "rule-bearing stays loose : _"). The B3 walker now
;; derives rule rows statically — body-goal dataflow, an UPPER BOUND through the
;; generators (NOT output observation, which stays banned per §6.2).
(test-case "B3.1: RULE-bearing relation gets a derived static row (body-goal dataflow)"
  (define r (last-result
             (run-prologos-string
              (string-append
               plain-facts-world
               "defr ruler [?a ?b]\n  &> (edge a b _)\n\n"
               "solve (ruler s d)\n"))))
  (check-false (string-contains? r ": _")
               "rule-bearing no longer falls to the loose hole")
  (check-true (string-contains? r ":s") "row keyed by query vars")
  (check-true (string-contains? r ":d")))

(test-case "B3.1: recursive rule (transitive closure) types via the fixpoint"
  (define r (last-result
             (run-prologos-string
              (string-append
               plain-facts-world
               "defr reach [?x ?z]\n"
               "  &> (edge x z _)\n"
               "  &> (edge x y _) (reach y z)\n\n"
               "solve (reach x z)\n"))))
  (check-false (string-contains? r ": _") "TC must not stay loose")
  (check-true (string-contains? r ":x") "typed row keyed by query vars"))

(test-case "B3.1: `=`-unify literal + `is` contributions type the bound var"
  (define r (last-result
             (run-prologos-string
              (string-append
               plain-facts-world
               "defr tagged [?n ?tag]\n  &> (edge n _ _) (= tag \"seen\")\n\n"
               "solve (tagged n tag)\n"))))
  (check-true (string-contains? r ":tag String") "unify-with-literal types the var")
  (check-true (string-contains? r ":n") "app-position var typed from callee column"))

(test-case "B3.1 (D-B3.3): anonymous `rel` solves type via the same walker"
  (define r (last-result
             (run-prologos-string
              (string-append
               plain-facts-world
               "solve (rel [?v]\n       &> (edge v _ _))\n"))))
  (check-false (string-contains? r ": _") "anon rel no longer loose")
  (check-true (string-contains? r ":v") "row keyed by the rel's params"))

(test-case "B3.1: MIXED facts+clauses relation joins the fact contribution"
  ;; Pre-B3.1 the relation-global has-clauses? gate discarded the fact half.
  (define r (last-result
             (run-prologos-string
              (string-append
               plain-facts-world
               "defr mixed [?v]\n"
               "  || 9\n"
               "  &> (edge v _ _)\n\n"
               "solve (mixed v)\n"))))
  (check-false (string-contains? r ": _") "mixed relation no longer loose")
  (check-true (string-contains? r ":v") "typed row present"))

;; ========================================
;; B3.2 — display-time COINDUCTIVE refinement (design §6.10 D-B3.1(ii))
;; ========================================
;; The coinductive half of B3, and DISPLAY-ONLY by construction: the type echoed
;; beside an eval result is refined from the ACTUAL rows, while the type that is
;; STORED (and that governs composition) stays the static one. The division is
;; phase-forced — the checker runs before reduction — so this can never feed
;; static typing. Two moves: FILL a statically-underivable (hole) field from the
;; values actually present, and SHARPEN a static union to the branches actually
;; observed ("exact for the result set").

(define het-world
  (string-append
   "ns t\n\n"
   "defr mixed [?k ?v]\n"
   "  || 1 \"a\"\n"
   "     2 7\n\n"))

(test-case "B3.2 SHARPEN: a union field displays only the branches actually observed"
  (define r (format "~a" (last-result
                          (run-prologos-string
                           (string-append het-world "solve (mixed 1 v)\n")))))
  (check-true (string-contains? r "{:v String}")
              "the all-String result set narrows `String | Int` to `String`")
  (check-false (string-contains? r "String | Int")))

(test-case "B3.2 SHARPEN does NOT over-narrow: both branches observed → union kept"
  (define r (format "~a" (last-result
                          (run-prologos-string
                           (string-append het-world "solve (mixed k v)\n")))))
  (check-true (string-contains? r "String | Int")
              "when the result set really is heterogeneous the union stays"))

(test-case "B3.2 is DISPLAY-ONLY: a def announces the STORED (static) type"
  ;; the def-binding arm is deliberately un-refined — a def's announced type is
  ;; the type it stores, and that is what composition sees.
  (define results (run-prologos-string
                   (string-append het-world
                                  "def r := solve (mixed 1 v)\n"
                                  "r\n")))
  (define def-line (format "~a" (list-ref results (- (length results) 2))))
  (define echo-line (format "~a" (last-result results)))
  (check-true (string-contains? def-line "String | Int")
              "the STORED type keeps the static union")
  (check-true (string-contains? echo-line "{:v String}")
              "echoing the bound value refines the DISPLAY only"))

(test-case "B3.2: an unobservable field keeps its hole (never invents a type)"
  ;; `?w` is bound by nothing in the body → statically a hole (D-B3.6 never lie),
  ;; and its runtime value is an unbound logic-var echo → nothing to observe.
  (define r (format "~a" (last-result
                          (run-prologos-string
                           (string-append
                            "ns t\n\n"
                            "defr edge [?a ?b]\n  || 1 2\n     2 3\n\n"
                            "defr looseparam [?x ?w]\n  &> (edge x z)\n\n"
                            "solve (looseparam x w)\n")))))
  (check-true (string-contains? r ":w _") "hole stays a hole when unobservable"))

(test-case "B3.2: a fully-concrete row type is untouched (the zero-cost gate)"
  (define r (format "~a" (last-result
                          (run-prologos-string
                           (string-append
                            "ns t\n\n"
                            "defr edge [?a ?b]\n  || 1 2\n     2 3\n\n"
                            "defr twohop [?x ?z]\n  &> (edge x y) (edge y z)\n\n"
                            "solve (twohop x z)\n")))))
  (check-true (string-contains? r "{:x Int :z Int}")))

;; Unit-level: the refiner's paths that no surface program reaches today.
;; FILL is currently unreachable end-to-end — B3.1's walker is thorough enough
;; that a hole field almost always means "nothing binds this var", whose runtime
;; value is an unbound echo. The one shape that would reach it (a var unified
;; with a pvec/map literal) is blocked by an ADJACENT pre-existing defect: such
;; unifications yield the runtime value `unknown` (see the B3.2 close note).
;; These pin the paths so they are correct when that defect is fixed.

(require (only-in "../typing-core.rkt" refine-solve-row-type-for-display)
         (only-in "../syntax.rkt"
                  expr-champ expr-keyword expr-Record record-field expr-hole
                  expr-Int expr-String expr-Bool expr-union expr-int expr-string
                  expr-app expr-fvar expr-nil expr-PVec expr-rrb)
         (only-in "../pretty-print.rkt" pp-expr)
         (only-in "../champ.rkt" champ-empty champ-insert)
         (only-in "../rrb.rkt" rrb-from-list))

(define (b32-row . kvs)
  (expr-champ (for/fold ([c champ-empty]) ([kv (in-list kvs)])
                (define k (expr-keyword (car kv)))
                (champ-insert c (equal-hash-code k) k (cdr kv)))))
(define (b32-list . rows)
  (for/foldr ([acc (expr-nil)]) ([r (in-list rows)])
    (expr-app (expr-app (expr-fvar 'cons) r) acc)))
(define (b32-rec . fs)
  (expr-Record 'keyword
               (for/list ([f (in-list fs)])
                 (cons (car f) (record-field (cdr f) 'present)))
               'closed))
(define (b32-List r) (expr-app (expr-fvar 'prologos::data::list::List) r))
;; SolveCarrier (2026-07-31): PVec is the PRODUCTION carrier since the flip; the
;; List builders above now pin the RETAINED arm (narrowing, R3). Each shape-level
;; case below therefore runs against BOTH carriers — a differential pair, so a
;; future edit to one arm of display-row-type-parts / display-result-rows cannot
;; silently diverge from the other.
(define (b32-PVec r) (expr-PVec r))
(define (b32-pvec . rows) (expr-rrb (rrb-from-list rows)))

(test-case "B3.2 unit FILL: a hole field takes the observed type of the rows"
  (check-equal? (pp-expr (refine-solve-row-type-for-display
                          (b32-List (b32-rec (cons 'a (expr-Int)) (cons 'b (expr-hole))))
                          (b32-list (b32-row (cons 'a (expr-int 1)) (cons 'b (expr-string "s")))
                                    (b32-row (cons 'a (expr-int 2)) (cons 'b (expr-string "t"))))))
                "[prologos::data::list::List {:a Int :b String}]"))

;; ⚠ A union field carries its `<…>` (2026-08-04, with the D4.P3a item 18 fix).
;; Bare, these snapshots were ambiguous: `{:b String | Int}` reads as a row whose
;; TAIL is `| Int`, which is the same shape the dyn-tail marker `| _` uses. The
;; brackets are the union's only source spelling, so this is what a user writes.
;; Do not "simplify" them back out.

(test-case "B3.2 unit FILL: heterogeneous observations join into a union"
  (check-equal? (pp-expr (refine-solve-row-type-for-display
                          (b32-List (b32-rec (cons 'b (expr-hole))))
                          (b32-list (b32-row (cons 'b (expr-string "s")))
                                    (b32-row (cons 'b (expr-int 3))))))
                "[prologos::data::list::List {:b <String | Int>}]"))

(test-case "B3.2 unit: observation DISAGREEING with the static union is discarded"
  ;; a branch outside the static union would signal a defect elsewhere; the echo
  ;; must not paper over it by displaying a claim the static side never made.
  (check-equal? (pp-expr (refine-solve-row-type-for-display
                          (b32-List (b32-rec (cons 'b (expr-union (expr-Int) (expr-Bool)))))
                          (b32-list (b32-row (cons 'b (expr-string "s"))))))
                "[prologos::data::list::List {:b <Int | Bool>}]"))

(test-case "B3.2 unit: solve-one's BARE row refines too"
  (check-equal? (pp-expr (refine-solve-row-type-for-display
                          (b32-rec (cons 'b (expr-union (expr-String) (expr-Int))))
                          (b32-row (cons 'b (expr-string "s")))))
                "{:b String}"))

(test-case "B3.2 unit: an empty result set observes nothing (type unchanged)"
  (check-equal? (pp-expr (refine-solve-row-type-for-display
                          (b32-List (b32-rec (cons 'b (expr-hole)))) (expr-nil)))
                "[prologos::data::list::List {:b _}]"))

;; ── SolveCarrier: the PVec twins of the four shape-level cases above ─────────
;; These are the LOAD-BEARING half since the flip — every production solve echo
;; now arrives as `(expr-rrb …)` typed `(expr-PVec row)`. Both display walkers
;; had to grow an arm; miss either and the refinement degrades SILENTLY (holes
;; stay `_`, unions stay unsharpened) with zero errors. Hence the pins.

(test-case "SolveCarrier unit FILL: a hole field takes the observed type (PVec carrier)"
  (check-equal? (pp-expr (refine-solve-row-type-for-display
                          (b32-PVec (b32-rec (cons 'a (expr-Int)) (cons 'b (expr-hole))))
                          (b32-pvec (b32-row (cons 'a (expr-int 1)) (cons 'b (expr-string "s")))
                                    (b32-row (cons 'a (expr-int 2)) (cons 'b (expr-string "t"))))))
                "[PVec {:a Int :b String}]"))

(test-case "SolveCarrier unit FILL: heterogeneous observations join into a union (PVec carrier)"
  (check-equal? (pp-expr (refine-solve-row-type-for-display
                          (b32-PVec (b32-rec (cons 'b (expr-hole))))
                          (b32-pvec (b32-row (cons 'b (expr-string "s")))
                                    (b32-row (cons 'b (expr-int 3))))))
                "[PVec {:b <String | Int>}]"))

(test-case "SolveCarrier unit: observation DISAGREEING with the static union is discarded (PVec carrier)"
  (check-equal? (pp-expr (refine-solve-row-type-for-display
                          (b32-PVec (b32-rec (cons 'b (expr-union (expr-Int) (expr-Bool)))))
                          (b32-pvec (b32-row (cons 'b (expr-string "s"))))))
                "[PVec {:b <Int | Bool>}]"))

(test-case "SolveCarrier unit: an EMPTY PVec observes nothing (type unchanged)"
  ;; the empty result is `@[]` now, not `nil` — the walker must return no rows
  ;; rather than treating the empty rrb as an unrecognized shape.
  (check-equal? (pp-expr (refine-solve-row-type-for-display
                          (b32-PVec (b32-rec (cons 'b (expr-hole)))) (b32-pvec)))
                "[PVec {:b _}]"))

(test-case "SolveCarrier unit: a PVec with a NON-row member is skipped, not aborted"
  ;; mirrors the cons arm's filter — an unrecognized member must not poison the
  ;; observations drawn from its well-formed siblings.
  (check-equal? (pp-expr (refine-solve-row-type-for-display
                          (b32-PVec (b32-rec (cons 'b (expr-hole))))
                          (expr-rrb (rrb-from-list
                                     (list (b32-row (cons 'b (expr-string "s")))
                                           (expr-int 99))))))
                "[PVec {:b String}]"))
