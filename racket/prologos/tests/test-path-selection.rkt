#lang racket/base

;;;
;;; CIU T6 Path Selection — the track's test file (created P2.a, grown per phase).
;;; P2.a: prerequisite repairs — the record-project Int gate, the pvec-nth
;;; discipline guard, the ground-expr? twin fallbacks (the broadcast-get
;;; walker-safety arms retired WITH the node at D4.P1a).
;;; P2.b: the two-tier principle. D4.P1a: the retirement batch + marker seat.
;;; Design: docs/tracking/2026-07-28_CIU_T6_PATH_SELECTION_D4.md §5 (P2 record
;;; in the 2026-07-26 predecessor §5.10).
;;;

(require rackunit
         racket/list
         racket/set
         racket/string
         racket/file
         racket/runtime-path
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../reduction.rkt"
         "../namespace.rkt"
         (prefix-in tc: "../typing-core.rkt")   ;; D4.P4a: select-project, for the totality pins
         ;; D4.P4e-1b 1b-iii-A: the FAIL-KIND totality pin. Relative path, per
         ;; testing.md — a collection-path require loads a SECOND compiler instance.
         (prefix-in te: "../typing-errors.rkt")
         (prefix-in tr: "../trait-resolution.rkt")
         (prefix-in u: "../unify.rkt")
         (prefix-in gc: "../global-constraints.rkt")
         "../errors.rkt"
         "../champ.rkt"
         (only-in "../rrb.rkt" rrb-from-list rrb-to-list)   ;; D4.P4a: twin-regression fixture; to-list: P4e-0 token probes
         "test-support.rkt"
         "../parse-reader.rkt"
         ;; D4.P4e-1a slice 1a-i: the star arrival matrix — the ONE enumeration
         ;; the leak gate reads instead of copying (see the gate's own note).
         "../tools/star-arrival-matrix.rkt"
         ;; D4.P4b-ii-2b: the surf-* layer, for the $select-path sentinel pins
         (only-in "../surface-syntax.rkt"
                  surf-select? surf-select-sort surf-select-branches))

(define-runtime-path lib-dir "../lib")

;; ---- Shared fixture (loaded once; :no-prelude — @[…]/pvec-* are parser keywords) ----
(define-values (shared-global-env shared-ns-context shared-module-reg
                shared-trait-reg shared-impl-reg shared-param-impl-reg
                shared-bundle-reg)
  (parameterize ([current-file-module-network-ref (make-module-network)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string "(ns path-selection-test :no-prelude)")
    (values (global-env-snapshot) (current-ns-context) (current-module-registry)
            (current-trait-registry) (current-impl-registry)
            (current-param-impl-registry) (current-bundle-registry))))

(define (run-ws s)
  (define tmp (make-temporary-file "prologos-pathsel-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display s out)))
  (define result
    (parameterize ([current-file-module-network-ref
                    (module-network-add-import (make-module-network)
                                               (module-network-from-snapshot shared-global-env))]
                   [current-ns-context shared-ns-context]
                   [current-module-registry shared-module-reg]
                   [current-trait-registry shared-trait-reg]
                   [current-impl-registry shared-impl-reg]
                   [current-param-impl-registry shared-param-impl-reg]
                   [current-bundle-registry shared-bundle-reg])
      (process-file (path->string tmp))))
  (delete-file tmp)
  (map (lambda (r) (format "~a" r)) result))

(define (run-ws-last s) (last (run-ws s)))

;; RAW results (NOT formatted). Required by P2.b: the silent miss DISPLAYS as
;; "<error> : Int", so a #rx"error" assertion matches the silent form too and
;; would pass for the wrong reason. `prologos-error?` is the only honest
;; discriminator between "counted error" and "well-typed-looking wrong value".
(define (run-ws-raw s)
  (define tmp (make-temporary-file "prologos-pathsel-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display s out)))
  (define result
    (parameterize ([current-file-module-network-ref
                    (module-network-add-import (make-module-network)
                                               (module-network-from-snapshot shared-global-env))]
                   [current-ns-context shared-ns-context]
                   [current-module-registry shared-module-reg]
                   [current-trait-registry shared-trait-reg]
                   [current-impl-registry shared-impl-reg]
                   [current-param-impl-registry shared-param-impl-reg]
                   [current-bundle-registry shared-bundle-reg])
      (process-file (path->string tmp))))
  (delete-file tmp)
  result)

(define (run-ws-raw-last s) (last (run-ws-raw s)))

;; ---- Second fixture: WITH prelude (cached via test-support) ----
;; Needed by the slice-3 List tests: under :no-prelude the `List` TYPE does not
;; exist, so `def xs := [pvec-to-list …]` dies with not-a-type-error and every
;; later line is `Unbound variable` — which a prologos-error? assertion
;; CANNOT tell from the loud miss it means to pin (observed: a false green).
(define-values (pre-global-env pre-ns-context pre-module-reg
                pre-trait-reg pre-impl-reg pre-param-impl-reg
                pre-bundle-reg)
  (parameterize ([current-file-module-network-ref (make-module-network)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string "(ns path-selection-pre)")
    (values (global-env-snapshot) (current-ns-context) (current-module-registry)
            (current-trait-registry) (current-impl-registry)
            (current-param-impl-registry) (current-bundle-registry))))

(define (run-ws-pre-raw s)
  (define tmp (make-temporary-file "prologos-pathselpre-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display s out)))
  ;; ⚠ `dynamic-wind`, not a trailing `delete-file`: `process-file` RAISES for any
  ;; source that hits the parse/expansion abort path, and the plain form skipped
  ;; the delete on exactly those calls. Measured while landing D4.P4e-1a slice
  ;; 1a-i, whose gate deliberately exercises 21 raising cells per run
  ;; (DEFERRED 108): **192 stale `prologos-pathselpre-*` files** had accumulated
  ;; in $TMPDIR. Pre-existing, and every caller of this fixture paid it.
  (define result
    (dynamic-wind
      void
      (lambda ()
        (parameterize ([current-file-module-network-ref
                        (module-network-add-import (make-module-network)
                                                   (module-network-from-snapshot pre-global-env))]
                       [current-ns-context pre-ns-context]
                       [current-module-registry pre-module-reg]
                       [current-lib-paths (list prelude-lib-dir)]
                       [current-preparse-registry prelude-preparse-registry]
                       [current-trait-registry pre-trait-reg]
                       [current-impl-registry pre-impl-reg]
                       [current-param-impl-registry pre-param-impl-reg]
                       [current-bundle-registry pre-bundle-reg])
          (process-file (path->string tmp))))
      (lambda () (when (file-exists? tmp) (delete-file tmp)))))
  result)

(define (run-ws-pre s) (map (lambda (r) (format "~a" r)) (run-ws-pre-raw s)))
(define (run-ws-pre-last s) (last (run-ws-pre s)))

;; Guard against the false-green class above: the PRELUDE fixture must actually
;; give us a typed List def, or every downstream assertion is meaningless.
(test-case "fixture sanity: the prelude fixture stores a typed List def"
  (define r (run-ws-pre "def xs0 := [pvec-to-list @[10 20 30]]\nxs0\n"))
  (check-false (ormap (lambda (x) (regexp-match? #rx"not-a-type|Unbound" x)) r)
               "prelude fixture broken — List type unavailable")
  (check-regexp-match #rx"List" (last r)))

;; ============================================================
;; P2.a — record-project dynamic Int gate (D3-S1 prerequisite for PS10)
;; ============================================================

(test-case "tuple dynamic index: Int VARIABLE degrades to ⋃positions (was: ERROR)"
  ;; `def i := 1` is Int by the language's own convention (prologos-syntax.md
  ;; § Nat vs Int); the literal leg's comment claims to mirror expr-get's
  ;; Nat-or-Int gate — the dynamic leg now actually does.
  (define r (run-ws-last "(ns path-selection-test :no-prelude)\ndef tr := @[1 \"a\" true]\ndef i := 1\ntr[i]"))
  (check-regexp-match #rx"Bool \\| Int \\| String" r))

(test-case "tuple dynamic index: Nat variable still degrades to ⋃positions (pin)"
  (define r (run-ws-last "(ns path-selection-test :no-prelude)\ndef tr := @[1 \"a\" true]\ndef n : Nat := 1N\ntr[n]"))
  (check-regexp-match #rx"Bool \\| Int \\| String" r))

(test-case "pvec-nth on a tuple: Int VARIABLE stays REJECTED (the census-hazard pin)"
  ;; The pvec-* runtime is Nat-value-only (F1a-col discipline). Before P2.a this
  ;; rejection rode record-project's Nat-only dynamic leg; widening that leg
  ;; alone would silently flip this to accepted-then-runtime-stall — so
  ;; pvec-nth's Record leg carries its OWN gate, pinned here.
  (define r (run-ws-last "(ns path-selection-test :no-prelude)\ndef tr := @[1 \"a\" true]\ndef j := 1\n[pvec-nth tr j]"))
  (check-regexp-match #rx"error|Error|ERROR" r))

(test-case "pvec-nth on a tuple: Nat variable union-degrade still works (pin)"
  (define r (run-ws-last "(ns path-selection-test :no-prelude)\ndef tr := @[1 \"a\" true]\ndef n : Nat := 1N\n[pvec-nth tr n]"))
  (check-regexp-match #rx"Bool \\| Int \\| String" r))

;; ============================================================
;; P2.a — ground-expr? twins: the generic transparent-struct fallback
;; (pipeline.md § Exhaustive Walkers; the D3-S9 re-homed CIU T2 item)
;; ============================================================

(define ?m1 (expr-meta 990001 #f))
(define ?m2 (expr-meta 990002 #f))

(test-case "twin B (trait-resolution): a union of unsolved metas is NOT ground"
  (check-false (tr:ground-expr? (expr-union ?m1 ?m2))))

(test-case "twin B: a union nested under an armed arm is NOT ground"
  (check-false (tr:ground-expr? (expr-app (expr-fvar 'List) (expr-union ?m1 ?m2)))))

(test-case "twin B: unarmed compound nodes carrying a meta are NOT ground"
  ;; expr-Vec / expr-fst / expr-ann all fell to [_ #t] before the fallback.
  (check-false (tr:ground-expr? (expr-Vec ?m1 (expr-nat-val 3))))
  (check-false (tr:ground-expr? (expr-fst ?m1)))
  (check-false (tr:ground-expr? (expr-ann ?m1 (expr-Nat)))))

(test-case "twin B: ground atoms + armed nodes stay ground (must-not-change pins)"
  (check-true (tr:ground-expr? (expr-fvar 'Int)))
  (check-true (tr:ground-expr? (expr-union (expr-Nat) (expr-String))))
  (check-true (tr:ground-expr? (expr-app (expr-fvar 'List) (expr-Nat)))))

(test-case "twin B: mult/level metas do NOT gate type-groundness (ruled + pinned)"
  ;; Dict params use mw; mult/level metas commonly stay unsolved until final
  ;; zonk — making them gate would starve trait resolution. The generic descent
  ;; bottoms out in their numeric id fields, so they report ground.
  (check-true (tr:ground-expr? (expr-Type (level-meta 990003))))
  (check-true (tr:ground-expr? (expr-Pi (mult-meta 990004) (expr-Nat) (expr-Nat)))))

(test-case "twin A (global-constraints): a logic var inside an unarmed compound is NOT ground"
  (define lv (expr-logic-var 'x 'free))
  (check-false (gc:narrow-ground-expr? (expr-union lv (expr-Nat))))
  (check-false (gc:narrow-ground-expr? (expr-fst lv))))

(test-case "twin A: a logic var inside a CHAMP container is NOT ground (element descent)"
  (define lv (expr-logic-var 'x 'free))
  (define champ-lv
    (whnf (expr-map-assoc (expr-map-empty (expr-Keyword) (expr-Nat))
                          (expr-keyword 'a) lv)))
  (define champ-ok
    (whnf (expr-map-assoc (expr-map-empty (expr-Keyword) (expr-Nat))
                          (expr-keyword 'a) (expr-nat-val 1))))
  (check-true (expr-champ? champ-lv))
  (check-false (gc:narrow-ground-expr? champ-lv))
  (check-true (gc:narrow-ground-expr? champ-ok)))

;; ============================================================
;; P2.a — normalize-for-resolution: unions now descend (the audit's capture gap)
;; ============================================================

(test-case "normalize-for-resolution descends into unions (PVec shorthand pin)"
  (check-equal? (u:normalize-for-resolution
                 (expr-union (expr-PVec (expr-Nat)) (expr-Nat)))
                (expr-union (expr-app (expr-tycon 'PVec) (expr-Nat))
                            (expr-Nat))))

;; ============================================================
;; P2.a — expr-broadcast-get walker safety: RETIRED WITH THE NODE (D4.P1a).
;; The two whnf/definitely-not-map? pins that lived here died with
;; expr-broadcast-get (ruling Q_L3). The conservative-default coverage they
;; incidentally carried is now pinned DIRECTLY by "P1a B4" below (critic C3).
;; ============================================================

;; ============================================================
;; P2.b — THE TWO-TIER PRINCIPLE  (design §5.10 round 7, realization round 8)
;;
;;   ASSERTIVE tier (map-get / .field / v[k]) — a FAILED runtime lookup is a
;;   LOUD, COUNTED error.  HONEST tier (nil-safe-get / nth / kv-get) — unchanged.
;;
;; Written FAILING-FIRST. Group A fails at P2.b's opening and is the phase gate;
;; Group B passes today and must KEEP passing (the change's blast-radius pins).
;;
;; Why this battery is mandatory rather than "flip 2 assertions" (round-8 audit):
;; FIVE of the six target sites have ZERO coverage in either direction — every
;; in-tree OOB pin is a CLOSED TUPLE that errors at ELABORATION and never reaches
;; reduction — so the flip is suite-invisible both ways without these.
;; ============================================================

;; ---------- SITE 7 — the fabricated-`none` class (slice 1) ----------
;;
;; The remaining assertive-tier legs (Map-miss loud · List OOB) arrive with the
;; A1 decision round, each with its own tests — per `workflow.md`, a phase
;; brings its OWN coverage.

;; ---------- SLICE 2 — PVec OOB loud + BOTH def seams (round 8b) ----------
;;
;; No strictness slot needed here (audit `wf_af8d65c5-a6e`): both rrb arms
;; isolate the genuine range error AFTER a successful literal-index extraction,
;; and `expr-PVec` carries no arity/tail — no permissive counterpart exists.

(test-case "P2.b A3: PVec runtime OOB via expr-get is LOUD (reduction.rkt:2731)"
  (define r (run-ws-raw-last "def v := @[10 20 30]\nv[5]\n"))
  (check-true (prologos-error? r)))

(test-case "P2.b A3b: the loud OOB names index and length (the quality bar)"
  (define r (run-ws-last "def v := @[10 20 30]\nv[5]\n"))
  (check-regexp-match #rx"out of bounds" r)
  (check-regexp-match #rx"5" r)
  (check-regexp-match #rx"3" r))

(test-case "P2.b A4: pvec-nth runtime OOB is LOUD (reduction.rkt:2798 — was the stuck leg)"
  (define r (run-ws-raw-last "def v := @[10 20 30]\n[pvec-nth v 5N]\n"))
  (check-true (prologos-error? r)))

(test-case "P2.b A9 (deliberate flip, round 8b): DYNAMIC-index tuple OOB becomes loud"
  ;; Types to ⋃positions (the P2.a union-degrade) and reaches reduction with a
  ;; runtime-computed index. The STATIC literal-index tuple pins are untouched —
  ;; they error at elaboration and never reach these arms.
  (define r (run-ws-raw-last
             (string-append
              "def tr := @[1 \"a\" true]\n"
              "[pvec-nth tr [pvec-length @[1N 2N 3N 4N 5N]]]\n")))
  (check-true (prologos-error? r)))

;; ---------- SLICE 3 — the List-leg split (round 8b) ----------
;;
;; expr-get's List arm CONFLATED "index is not a literal" with OOB — both fell
;; to one `(expr-error)`. Consequence: a lambda body indexing a ground list was
;; DESTROYED to `<error>` at definition time (a live silent-wrong-value bug).
;; The split: non-literal index → STUCK (mirrors the rrb arm); true OOB → LOUD.

(test-case "P2.b A10: List runtime OOB via expr-get is LOUD"
  (define r (run-ws-pre-raw
             (string-append
              "def xs := [pvec-to-list @[10 20 30]]\n"
              "[get xs 5]\n")))
  (check-false (prologos-error? (first r)) "the def itself must succeed")
  (check-true (prologos-error? (last r))))

(test-case "P2.b A10b: the loud List OOB names index and length"
  (define r (run-ws-pre-last
             (string-append
              "def xs := [pvec-to-list @[10 20 30]]\n"
              "[get xs 5]\n")))
  (check-regexp-match #rx"out of bounds" r))

(test-case "P2.b A11 (the live bug): nf no longer destroys a get-on-List under a binder"
  ;; The conflation's observable: POL.10 STORES the whnf value, so the stored
  ;; lambda body is intact and application works — but the nf DISPLAY descends
  ;; under the binder, hits `[get xs i]` with i a bvar (non-literal index), and
  ;; collapses it to `<error>`. The displayed body is a silent lie about the
  ;; stored value. After the split: non-literal stays a STUCK get, so the
  ;; display shows the real body. The application pin must hold BOTH before
  ;; and after (it is the must-not-break half).
  (define r (run-ws-pre
             (string-append
              "def xs := [pvec-to-list @[10 20 30]]\n"
              "def f := [fn [i : Nat] [get xs i]]\n"
              "f\n"
              "[f 1N]\n")))
  (check-false (regexp-match? #rx"<error>" (third r))
               "the DISPLAYED lambda body must not be nf-destroyed")
  (check-regexp-match #rx"20 : Int" (last r)))

;; ---------- SLICE 4 — the Map-miss fork via CARRIED-ALPHA (round 8b) ----------
;;
;; Elaboration mints a strictness SLOT (a fresh meta, type-blind) on the USER's
;; direct projection only; typing solves it to assertive when the subject is
;; (Map K V); zonk materializes; the champ-miss arm reads it. The permissive
;; default means: raw-constructed nodes, the reduction-lowered get-in/update-in
;; family (= the PS12/M3 DYNAMIC TIER), and dyn-row subjects all keep D19.

(test-case "P2.b A1: a (Map K V) runtime miss is LOUD and COUNTED (was: `<error> : Int`, 0 errors)"
  (define r (run-ws-raw-last
             (string-append
              "def d : [Map Keyword Int] := [map-assoc [map-assoc {} :a 1] :b 2]\n"
              "[map-get d :zzz]\n")))
  (check-true (prologos-error? r)
              "a dict miss must be a COUNTED error, not a displayed <error> value"))

(test-case "P2.b A1b: the loud Map miss names the key and the available keys (the quality bar)"
  (define r (run-ws-last
             (string-append
              "def d : [Map Keyword Int] := [map-assoc [map-assoc {} :a 1] :b 2]\n"
              "[map-get d :zzz]\n")))
  (check-regexp-match #rx"zzz" r)
  (check-regexp-match #rx"available" r))

(test-case "P2.b A2: a (Map K V) miss must not COMMIT silently into a def"
  (define rs (run-ws-raw
              (string-append
               "def d : [Map Keyword Int] := [map-assoc [map-assoc {} :a 1] :b 2]\n"
               "def dmiss := [map-get d :zzz]\n")))
  (check-true (ormap prologos-error? rs)
              "def-committing a miss is the stored silent-wrong-answer class"))

(test-case "P2.b B9 (the tier boundary): a get-in path miss on a Map stays PERMISSIVE"
  ;; get-in/update-in are the PS12/M3 DYNAMIC tier — their inlined map-get
  ;; chains carry NO slot (permissive #f), by design not by accident. If this
  ;; pin breaks, the tier boundary moved.
  (define r (run-ws-raw-last
             (string-append
              "def d : [Map Keyword Int] := [map-assoc [map-assoc {} :a 1] :b 2]\n"
              "[get-in d :zzz]\n")))
  (check-false (prologos-error? r)))

(test-case "P2.b B10: a Map HIT is unaffected, direct and def-committed"
  (define r (run-ws
             (string-append
              "def d : [Map Keyword Int] := [map-assoc [map-assoc {} :a 1] :b 2]\n"
              "[map-get d :a]\n"
              "def hit := [map-get d :b]\nhit\n")))
  (check-regexp-match #rx"1 : Int" (second r))
  (check-regexp-match #rx"2 : Int" (last r)))

;; THE DEF SEAMS (Q_N5, both — driver.rkt:1907 inferred, :2112 annotated).
(test-case "P2.b A7: a panic-valued def is COUNTED at the inferred def seam (was: silent)"
  (define rs (run-ws-raw
              (string-append
               "spec boom Int -> Int\n"
               "defn boom [x]\n"
               "  [panic \"BOOM\"]\n"
               "def d := [boom 2]\n")))
  (check-true (ormap prologos-error? rs)
              "def d := [boom 2] yielded `d : Int defined.` with ZERO errors"))

(test-case "P2.b A8: the ANNOTATED def seam is checked too (driver.rkt:2112)"
  ;; The round-8 design named only :1907; the audit found the annotated twin.
  (define rs (run-ws-raw
              (string-append
               "spec boom2 Int -> Int\n"
               "defn boom2 [x]\n"
               "  [panic \"BOOM\"]\n"
               "def d : Int := [boom2 2]\n")))
  (check-true (ormap prologos-error? rs)))

;; SITE 7 (round-8 Q_N6) — the design's claim was inverted in BOTH halves:
;; the PRESENT position fabricates `none`; the OOB position is ALREADY loud.
(test-case "P2.b A5 (site 7): [map-get tup <nat>] on a PRESENT position PROJECTS the value"
  (define r (run-ws-last "def tp := @[1 \"a\" true]\n[map-get tp 1N]\n"))
  (check-regexp-match #rx"\"a\"" r
                      "position 1 is present with type String — must be \"a\", not `none`")
  (check-false (regexp-match? #rx"none" r)
               "`none` here is a FABRICATED library value at the projected type"))

(test-case "P2.b A6 (site 7): the fabricated `none` must not be def-committed"
  (define r (run-ws-last "def tp := @[1 \"a\" true]\ndef m1 := [map-get tp 1N]\nm1\n"))
  (check-regexp-match #rx"\"a\"" r)
  (check-false (regexp-match? #rx"none" r)))

;; ---------- Group B — MUST-NOT-BREAK (the blast-radius pins) ----------

(test-case "P2.b B1 (D19): a dyn-ROW miss stays PERMISSIVE — the mark keys on the SUBJECT"
  (define r (run-ws-raw-last
             (string-append
              "def m := [map-assoc [map-assoc {} :a 1] :b \"s\"]\n"
              "[map-get m :c]\n")))
  (check-false (prologos-error? r)
               "exploration on a dyn row is exempt (route-soundness:200, records ;;77)"))

(test-case "P2.b B2 (D19): the third pin — an ANNOTATED def of a dyn-row miss stays permissive"
  (define rs (run-ws-raw
              (string-append
               "def m := [map-assoc [map-assoc {} :a 1] :b \"s\"]\n"
               "def x : String := [map-get m :c]\n")))
  (check-false (ormap prologos-error? rs)
               "keying on the DEF's annotated type instead of the subject breaks this"))

(test-case "P2.b B3: a CLOSED-row miss keeps its rich static diagnostic (the quality bar)"
  (define r (run-ws-last "def r := {:a 1}\n[map-get r :zzz]\n"))
  (check-regexp-match #rx"not present in the record" r)
  (check-regexp-match #rx"available fields" r))

(test-case "P2.b B4: an OOB read in an UNTAKEN branch must not be made loud"
  ;; The guard-awareness pin. `lt?` is prelude-only, so the property is pinned
  ;; with a literal guard instead: the OOB node is elaborated and typed but
  ;; never REDUCED (boolrec selects only the taken branch, reduction.rkt:1869).
  ;; This is what insulates the bounds-guarded honest tier (pvec-idx-nth), and
  ;; it is why the strictness decision may only bite at REDUCTION of the marked
  ;; node — an elaboration-time firing would break every guarded read.
  (define r (run-ws-raw-last
             (string-append
              "def v := @[10 20 30]\n"
              "[if false [pvec-nth v 99N] 0]\n")))
  (check-false (prologos-error? r)
               "the strictness decision may only bite when the node REDUCES"))

(test-case "P2.b B5: the HONEST tier is untouched — nil-safe-get champ miss → nil"
  (define empty (expr-champ champ-empty))
  (check-equal? (whnf (expr-nil-safe-get empty (expr-keyword 'missing)))
                (expr-nil)
                "nil-safe-get has its own champ arm and must not inherit loudness"))

(test-case "P2.b B6: in-bounds reads are unaffected (the three correct spellings)"
  (define r (run-ws "def tp := @[1 \"a\" true]\ntp[1]\n[pvec-nth tp 1N]\n[get tp 1N]\n"))
  (for ([x (in-list (take-right r 3))])
    (check-regexp-match #rx"\"a\"" x)))

(test-case "P2.b B7: a runtime-COMPUTED in-bounds index still projects (no false OOB)"
  (define r (run-ws-last
             (string-append
              "def v := @[10 20 30]\n"
              "[pvec-nth v [pvec-length @[1N 2N]]]\n")))
  (check-regexp-match #rx"30" r))

(test-case "P2.b B8 (the named bound, D22 precedent): a NESTED panic prints, counts 0"
  ;; Top-node-bounded at both seams — accepted + NAMED in round 7/8. This pin
  ;; makes the boundary deliberate: if it ever flips, it flips in a test.
  ;; (Nested under a MAP literal — core syntax; cons/nil are prelude-only and
  ;; would make this fail with `Unbound variable`, i.e. for the wrong reason.)
  (define rs (run-ws-raw
              (string-append
               "spec boom3 Int -> Int\n"
               "defn boom3 [x]\n"
               "  [panic \"NESTED\"]\n"
               "def q := {:x [boom3 1]}\n")))
  (check-false (ormap prologos-error? rs)
               "a panic nested inside a constructed value is uncounted (top-node bound)"))

;; ============================================================
;; D4.P1a — THE RETIREMENT BATCH  (D4 §5.P1a; audit wf_789e4f0f-f02)
;;
;; Written FAILING-FIRST. Group A pins the GUIDED retirement diagnostics
;; (marker-form seat: tokens stay, preparse rewrites die, the PARSER converts
;; sentinels to per-command parse-error VALUES). Group B pins the survivors.
;;
;; Fixture discipline (Watching #4): map-literal subjects use the :no-prelude
;; fixture; List subjects ('[…] lowers to cons/nil = prelude names) use the
;; PRELUDE fixture — else a broadcast test errors for the WRONG reason and
;; false-greens an is-error assertion.
;; ============================================================

;; ---------- Group A — the retirements (RED until P1a lands) ----------

(test-case "P1a A1: dot-key POSTFIX `user.:name` → guided retirement error; file CONTINUES"
  (define rs (run-ws
              (string-append
               "def user := {:name \"Alice\" :age 30}\n"
               "user.:name\n"
               "def zz := 7\n"
               "zz\n")))
  (check-regexp-match #rx"retired" (second rs))
  (check-regexp-match #rx"\\.name" (second rs))
  (check-regexp-match #rx"7 : Int" (last rs)
                      "the seat must be per-command — later commands still evaluate"))

(test-case "P1a A2: dot-key PREFIX `.:name user` → the same guided error (Pattern-2a shape)"
  (define rs (run-ws
              (string-append
               "def user := {:name \"Alice\"}\n"
               ".:name user\n")))
  (check-regexp-match #rx"retired" (last rs)))

(test-case "P1a A3: the nil-dot-key twins `#:name` / `#.:name` → guided error naming the survivor `#.name`"
  ;; These are ALREADY broken on the WS path today (probe: `Unbound variable`)
  ;; — the pin asserts the MESSAGE upgrade, not a behavior flip.
  (define rs (run-ws
              (string-append
               "def user := {:name \"Alice\"}\n"
               "user#:name\n"
               "user#.:name\n")))
  (check-regexp-match #rx"retired" (second rs))
  (check-regexp-match #rx"#\\.name" (second rs))
  (check-regexp-match #rx"retired" (third rs))
  (check-regexp-match #rx"#\\.name" (third rs)))

(test-case "P1a A4: broadcast `.*name` → guided error naming `:name` (the accepted P1→P4 gap's noise)"
  ;; PRELUDE fixture: the subject must be a REAL List so that today the form
  ;; SUCCEEDS — an undefined subject would error today too and false-red this.
  (define rs (run-ws-pre
              (string-append
               "def ladmins := '[{:name \"Alice\"} {:name \"Bob\"}]\n"
               "ladmins.*name\n"
               "ladmins.*nope\n"
               "def after := 1\nafter\n")))
  (check-regexp-match #rx"retired" (second rs))
  (check-regexp-match #rx":name" (second rs))
  ;; the once-SILENT wrong answer ('[<error> <error>] at 0 errors) dies with
  ;; the surface — same guided error, no fabricated value:
  (check-regexp-match #rx"retired" (third rs))
  (check-false (regexp-match? #rx"<error>" (third rs)))
  (check-regexp-match #rx"1 : Int" (last rs)))

(test-case "P1a A5: the `broadcast-get` parser KEYWORD is retired — both spellings error"
  ;; Zero live users (census). Bracket spelling → unbound variable;
  ;; paren spelling at command position → a POL.9 goal → solver diagnostic.
  (define rs1 (run-ws-pre-raw
               (string-append
                "def xs := '[{:name \"A\"}]\n"
                "[broadcast-get xs :name]\n")))
  (check-true (prologos-error? (last rs1))
              "[broadcast-get …] must no longer be a live application")
  (define rs2 (run-ws-pre-raw
               (string-append
                "def xs := '[{:name \"A\"}]\n"
                "(broadcast-get xs :name)\n")))
  (check-true (prologos-error? (last rs2))
              "(broadcast-get …) at command position must no longer parse as the keyword"))

(test-case "P1a A6: keyword-literal postfix `m[:a]` → guided error naming `m.a` / `[get m :a]`"
  (define rs (run-ws
              (string-append
               "def m := {:a 1 :b 2}\n"
               "m[:a]\n")))
  (check-regexp-match #rx"retired" (last rs))
  (check-regexp-match #rx"get" (last rs)))

(test-case "P1a A7: negative literal postfix `v[-1]` is a COUNTED error (was: silent wrong answer, 0 errors)"
  (define r (run-ws-raw-last "def v := @[10 20 30]\nv[-1]\n"))
  (check-true (prologos-error? r)
              "v[-1] type-checked Int and printed a stuck term at ZERO errors"))

(test-case "P1a A7b: the negative-index error names the negativity"
  (define r (run-ws-last "def v := @[10 20 30]\nv[-1]\n"))
  (check-regexp-match #rx"negative" r))

(test-case "P1a A8: empty postfix `v[]` → guided message (was: generic `Unexpected datum: ()`)"
  (define r (run-ws-last "def v := @[10 20 30]\nv[]\n"))
  (check-regexp-match #rx"empty" r))

(test-case "P1a A9: `_[k]` hole subject → guided message (was: generic `Could not infer type`)"
  (define r (run-ws-last "def k := :a\n_[k]\n"))
  (check-regexp-match #rx"subject" r))

;; ---------- Group B — survivors (GREEN today, must STAY green) ----------

(test-case "P1a B1: `#.name` nil-safe access SURVIVES the twin retirement"
  (define r (run-ws-last "def user := {:name \"Alice\"}\nuser#.name\n"))
  (check-regexp-match #rx"\"Alice\"" r))

(test-case "P1a B2: `m[k]` with a COMPUTED Keyword key survives (the discriminator is literal-only)"
  (define r (run-ws-last "def m := {:x 42}\ndef k : Keyword := :x\nm[k]\n"))
  (check-regexp-match #rx"42" r))

(test-case "P1a B3: numeric postfix `v[0]` keeps extraction (PS2 flip CANCELED, owner)"
  (define r (run-ws-last "def v := @[10 20 30]\nv[0]\n"))
  (check-regexp-match #rx"10 : Int" r))

(test-case "P1a B5: a ZERO-ARG marker head must NOT abort the file (the seat's own contract)"
  ;; Found by the P1a adversarial verify: the marker arm called (car args)
  ;; unguarded, so `[$retired-selection]` raised at the parse seam and killed
  ;; the WHOLE FILE — the exact failure mode this seat exists to eliminate.
  ;; Its three raw-sentinel siblings carried the guard from the start.
  (define rs (run-ws "[$retired-selection]\ndef okz := 1\nokz\n"))
  (check-regexp-match #rx"retired" (first rs))
  (check-regexp-match #rx"1 : Int" (last rs)
                      "a raise here aborts the file — later commands must still evaluate"))

(test-case "P1a B6: a RETIRED sentinel inside a defmacro template must not abort the file"
  ;; pattern-var? excluded the live sentinels but not the retired $dot-key /
  ;; $nil-dot-key, so a retired shape in a template read as an unbound pattern
  ;; variable and raised out of preparse — again whole-file. (Pre-existing;
  ;; the asymmetry was flagged by the mini-audit and closed here.)
  (define rs (run-ws
              (string-append
               "defmacro getname [$u] [$u.:name]\n"
               "def okm := 1\n"
               "okm\n")))
  (check-regexp-match #rx"1 : Int" (last rs)
                      "registering the macro must not abort the file"))

(test-case "P1a B7: a negative NON-integer index is guided too (not just exact integers)"
  (define r (run-ws-last "def v := @[10 20 30]\nv[-1.5]\n"))
  (check-regexp-match #rx"negative" r))

;; ============================================================
;; D4.P1b-i — repairs (D4 §5.P1b-i; audit wf_d0862784-5e5)
;; ============================================================

(test-case "P1b-i C1 (Q_M4): the top-level `<` swallow is gone E2E — intervening commands survive"
  ;; Before the fix these THREE lines collapsed into ONE form (the `<` on
  ;; line 1 matched the `>` on line 3), so `ok` was never defined and the
  ;; whole thing reported ZERO errors. `<`/`>` are themselves unbound as
  ;; functions here (they are spelled lt/gt) — irrelevant: the property
  ;; under test is that each line is its OWN top-level form.
  (define rs (run-ws "def p := 1 < 2\ndef ok := 7\ndef q := 3 > 4\nok\n"))
  (check-true (ormap (lambda (r) (regexp-match? #rx"ok : Int defined" r)) rs)
              "the intervening def must be its OWN form and succeed")
  (check-false (regexp-match? #rx"Unbound" (last rs))
               "a command BETWEEN a `<` and a later `>` must survive as its own form"))

(test-case "P1b-i C2 (Q_M3): `def ?x` is a guided error — `?` is the logic-var modality"
  ;; Namespace RESERVATION [owner]: `?` marks a logic variable (narrowing,
  ;; defr params), so a def binding was never meant to be one. Legal at HEAD
  ;; (`def ?cfg := {:a 1}` → `?cfg : {:a Int} defined.`), reserved here.
  (define rs (run-ws "def ?cfg := {:a 1}\ndef okr := 1\nokr\n"))
  (check-regexp-match #rx"logic variable|\\?-prefixed|reserved" (first rs))
  (check-regexp-match #rx"1 : Int" (last rs)
                      "the reservation must be per-command — the file continues"))

(test-case "P1a B4: definitely-not-map? conservative default pinned DIRECTLY (replaces the broadcast-get pin)"
  ;; The retiring walker pin at :258-266 incidentally carried the track file's
  ;; only direct pin on P2.b's positive-list default (critic C3). This pins it
  ;; on a plainly-unarmed node so the coverage survives the node deletion.
  (check-false (definitely-not-map? (expr-fvar 'some-unknown-node))
               "an unrecognized node must default to #f — unknown is not not-a-map"))

;; ============================================================
;; D4.P1b-ii — the `.{` opener (dot-lbrace re-mint)
;;
;; The reader/grouping pins live in test-parse-reader.rkt (incl. the FLAGSHIP
;; nesting pin and the Q_N3 two-grouper agreement guard). These are the
;; Level-3 WS pins: the construct LEXES and GROUPS, and until P3 gives it
;; semantics it must fail GUIDINGLY and PER-COMMAND — never a whole-file abort
;; and never the misleading "Unbound variable" the generic path produced.
;; ============================================================

(test-case "P1b-ii: `.{ }` gives a GUIDED per-command error and the file CONTINUES"
  (define rs (run-ws-raw
              (string-append
               "def cfg := {:host \"localhost\" :port 8080}\n"
               "cfg.{host port}\n"
               "def after := 42\n"
               "after\n")))
  ;; the offending command errors...
  (check-true (ormap prologos-error? rs))
  ;; ...and the commands AFTER it still run (this is the whole point of the
  ;; P1a marker-seat discipline: a parse-error VALUE, never a raise).
  (check-regexp-match #rx"42" (last rs)))

(test-case "P1b-ii: the guided error names the construct, not a missing variable"
  (define r (run-ws-last
             (string-append
              "def cfg := {:host \"localhost\" :port 8080}\n"
              "cfg.{host port}\n")))
  (check-regexp-match #rx"select block" r)
  (check-false (regexp-match? #rx"Unbound variable" r)
               "a valid new form reported as a missing variable is the misleading shape"))

(test-case "P1b-ii: plain field access is UNAFFECTED (must-not-break)"
  (define r (run-ws-last
             (string-append
              "def cfg := {:host \"localhost\" :port 8080}\n"
              "cfg.host\n")))
  (check-regexp-match #rx"localhost" r))

(test-case "P1b-ii BLOCKING regression pin: `.{ }` in a defmacro TEMPLATE must not abort the file"
  ;; Found by adversarial verify BEFORE the commit; it was a real regression.
  ;; `$dot-brace` was missing from `pattern-var?`'s exclusion list (macros.rkt),
  ;; so the sentinel read as a macro PATTERN VARIABLE and `datum-subst` raised
  ;; "Unbound pattern variable in template: $dot-brace" — an uncaught raise at
  ;; preparse, i.e. a WHOLE-FILE ABORT with zero results, where the same source
  ;; gave a per-command error before the token existed.
  ;;
  ;; ⚠ This pin must exercise macro USE, not just registration: P1a's own
  ;; sibling pin only registers a macro, and registration is harmless — the
  ;; abort needs the template to be SUBSTITUTED. A registration-shaped pin
  ;; would have stayed green through the whole defect.
  (define rs (run-ws-raw
              (string-append
               "defmacro getsel [$u] [$u.{a b}]\n"
               "def cfg := {:host \"h\"}\n"
               "[getsel cfg]\n"
               "def after := 42\n"
               "after\n")))
  ;; the file must RUN TO COMPLETION — the trailing command is the real assertion
  (check-regexp-match #rx"42" (last rs)
                      "whole-file abort: nothing after the macro use evaluated")
  (check-true (ormap prologos-error? rs))
  (check-true (ormap (lambda (r) (regexp-match? #rx"select block" (format "~a" r))) rs)
              "the guided error must survive macro expansion"))

;; ============================================================
;; D4.P1b-iii / Q_M8 — the SILENT-WRONG-ANSWER repair (audit wf_18992d66-b81)
;;
;; Q_M8's original safety premise was FALSE: `:10` would have moved LOUD →
;; SILENT WRONG. Probed at 88b3019a, the 2-element `defn [x :N]` shape:
;;   `defn g [x :7]  x` → SILENTLY ACCEPTED, `:7` consumed as a TYPE NAME,
;;                        yielding `g : [Pi [x :0 <[Type 0]>] x -> x]`
;;   `defn g [x :0/:1/:10] x` → all LOUD
;; i.e. the VALID multiplicities are loud here and `:7` is the anomaly. Root
;; cause: `fused-type-annot?` (parser.rkt) excluded FOUR lexemes against a
;; recognizer minting TWELVE, so everything else fell through and was consumed
;; as a type. Owner ruling Q_N4 widened the scope: fix it STRUCTURALLY — no
;; type name starts with a digit — which repairs the PRE-EXISTING `:7` bug too.
;; ============================================================

(test-case "Q_N4: `defn g [x :7] x` is LOUD (was: silently a DIFFERENT function)"
  (define rs (run-ws-raw "defn g7 [x :7] x\n"))
  (check-true (ormap prologos-error? rs)
              ":7 was consumed as a TYPE NAME and silently defined [Pi [x :0 <[Type 0]>] …]"))

(test-case "Q_N4: multi-digit `:10` in binder position stays LOUD (no LOUD→SILENT slide)"
  (define rs (run-ws-raw "defn g10 [x :10] x\n"))
  (check-true (ormap prologos-error? rs)))

(test-case "Q_N4: the VALID multiplicities are unchanged in the 3-element shape"
  ;; The multiplicity surface must not move: these are the working spellings.
  (check-regexp-match #rx"Int -> Int" (car (run-ws "def fw := [fn [x :w Int] x]\n")))
  (check-regexp-match #rx":1" (car (run-ws "def f1 := [fn [x :1 Int] x]\n"))))

(test-case "Q_N4: a SPACED implicit type binder is unaffected (the 419-site population)"
  (define r (run-ws-last "spec hq {A : Type} A -> A\ndefn hq [x] x\n[hq 5]\n"))
  (check-regexp-match #rx"5" r))

;; ============================================================
;; D4.P1b-iii — the P1b-ii RESIDUAL, CLOSED
;;
;; P1b-ii's guided error was unreachable wherever arity is checked first,
;; because `$dot-brace` never FUSED onto its base — it stayed a separate sibling
;; item, so a map literal saw an odd element count, `fn` saw a non-binder, and
;; `validate` saw an extra argument, each reporting its own confusing thing.
;; The cause was `access-sentinel?` (macros.rkt), a fusion gate named by NO
;; enumeration. Both brace-family sentinels are now in it.
;; ============================================================

(test-case "P1b-iii: the guided error IS reachable inside a map literal (was: odd-element-count)"
  (define r (run-ws-last "def cfg := {:host \"h\"}\ndef m := {:k cfg.{host}}\n"))
  (check-regexp-match #rx"select block" r)
  (check-false (regexp-match? #rx"even number of elements" r)
               "the enclosing arity check fired first — the sentinel did not fuse"))

(test-case "P1b-iii: reachable inside an fn BODY (was: 'all parameters must be bare symbols')"
  ;; ⚠ RENAMED + CORRECTED at P1b-iii; FLIPPED at D4.P3a: a body-position
  ;; select block now has SEMANTICS, so the property upgrades from "the guided
  ;; error is reachable" to "the body select WORKS under an annotated binder"
  ;; (the hole-domain `[fn [x] …]` shape stays a pre-existing PX-family
  ;; failure, identical for map-get — not selection's).
  (define r (run-ws-last "def cfg := {:host \"h\"}\ndef y := [fn [x : Int] cfg{host}]\n"))
  (check-regexp-match #rx"Int -> \\{:host String\\}" r)
  (check-false (regexp-match? #rx"bare symbols" r)))

(test-case "P1b-iii: an fn PARAM-LIST select block is LOUD (the honest behaviour)"
  ;; The real param-list case, now actually exercised. It is LOUD and the file
  ;; continues — the correctness property holds — but the message is the binder
  ;; walker's generic one, NOT the guided select-block error, and it dumps raw
  ;; syntax objects. Same for the `spec f{A}` spelling. Pinned as-is and the
  ;; diagnostic-quality gap is filed (DEFERRED); pinning the honest behaviour
  ;; is what stops a future change silencing it.
  (define rs (run-ws-raw "def bs := {:a 1}\ndef f := [fn [x bs{a}] x]\ndef after := 7\nafter\n"))
  (check-true (ormap prologos-error? rs) "must be LOUD")
  (check-regexp-match #rx"7" (last rs) "and the file must continue"))

(test-case "P1b-iii: adjacent select block in a defmacro TEMPLATE does not abort the file"
  ;; The P1b-ii regression class, re-pinned for the NEW sentinel: `$select-brace`
  ;; must be excluded from `pattern-var?` or macro use is a whole-file abort.
  (define rs (run-ws-raw
              (string-append
               "defmacro sel3 [$u] [$u{a b}]\n"
               "def cfg := {:host \"h\"}\n"
               "[sel3 cfg]\n"
               "def after3 := 42\n"
               "after3\n")))
  (check-regexp-match #rx"42" (last rs) "whole-file abort — nothing after the macro use ran")
  (check-true (ormap prologos-error? rs)))

(test-case "P1b-iii: WS `racket{…}` foreign blocks still work — NET-NEW coverage"
  ;; The audit found WS racket{…} has ZERO regression coverage: all 13
  ;; test-foreign-block cases are SEXP (they never reach group-items), and
  ;; lib/examples/foreign.prologos is 'skip'ed by the runner. These are the
  ;; first pins that actually exercise HEAD PRECEDENCE at the grouping layer.
  ;; Shape copied from the live sites (`def x : Nat racket{42}`) — my first
  ;; draft invented a `foreign racket "…"` preamble that is not the form, and
  ;; failed for that reason rather than for the property under test.
  (define r (run-ws-last "def fx : Nat racket{42}\nfx\n"))
  (check-false (regexp-match? #rx"select block" r)
               "head precedence failed — racket{…} was read as a select block")
  (check-regexp-match #rx"42" r))

(test-case "P1b-iii: MULTI-LINE WS `racket{…}` — the shape a single-line pin misses"
  ;; 2 of the 10 live WS sites are multi-line, and the audit named that as the
  ;; most exposed shape.
  (define r (run-ws-last
             (string-append
              "def fy : Nat racket{\n"
              "  (let loop ([n 10] [acc 0])\n"
              "    (if (zero? n) acc\n"
              "        (loop (sub1 n) (add1 acc))))\n"
              "}\n"
              "fy\n")))
  (check-false (regexp-match? #rx"select block" r))
  (check-regexp-match #rx"10" r))

;; ============================================================
;; D4.P1b-iii — THE FOLD MUST BE A FIXPOINT (adversarial verify, pre-commit)
;;
;; The first draft of the brace-family fusion arm rewrote
;;   (x base ($select-brace a))  ->  (x ($select-brace base a))
;; which is STILL sentinel-headed, therefore NOT a fixpoint. Because
;; `preparse-expand-subforms` re-enters while the datum keeps changing, each
;; pass swallowed one more sibling to the LEFT. Three BLOCKING consequences,
;; all silent, all under a green suite and a clean corpus A/B:
;;   1. a multi-arity `defn` clause lost its `$pipe` head and was SILENTLY
;;      DROPPED — the function evaluated with the wrong arms at 0 errors;
;;   2. `defn g [x base{a}] x` silently defined a 4-parameter function;
;;   3. the application HEAD itself was swallowed.
;; Every other access-sentinel arm rewrites the sentinel AWAY (to `get` /
;; `map-get`) and is a fixpoint; this one now does too, emitting the NOT-YET
;; marker instead.
;; ============================================================

(test-case "P1b-iii: the brace fusion fold is IDEMPOTENT (the fixpoint property)"
  (define once (rewrite-dot-access '(x base ($select-brace a))))
  (define twice (rewrite-dot-access once))
  (check-equal? once twice "non-idempotent fold — it will swallow siblings on re-entry")
  ;; and it must NOT be sentinel-headed, which is WHY it is a fixpoint
  (check-false (and (pair? once) (memq (car once) '($select-brace $dot-brace)))
               "the result is still sentinel-headed — re-entry will match it again"))

(test-case "P1b-iii: fusion consumes the BASE only — the application head survives"
  ;; D4.P3a UPDATE: the select-brace half now fuses to the REAL `$select` head
  ;; (semantics landed); the top-level dot-brace half keeps the guided marker
  ;; (a bare `x.{…}` at top level stays refused — its meaning is P3b/P4
  ;; territory). The property pinned is unchanged: ONE item out, head intact.
  (check-equal? (preparse-expand-form '(h base ($select-brace a)))
                '(h ($select base a)))
  (check-equal? (preparse-expand-form '(h base ($dot-brace a)))
                '(h ($retired-selection select-block #f))))

(test-case "P1b-iii BLOCKING pin: a multi-arity defn clause is NOT silently dropped"
  ;; Was: `bad : Int -> Int defined.` with 0 errors and `[bad 0]` returning the
  ;; WRONG arm, because the `| 0 -> …` clause head had been eaten.
  ;; D4.P3a UPDATE: `mm{a}` now has SEMANTICS, so the property upgrades from
  ;; "errors rather than silently dropping" to "the clause FIRES with the
  ;; right arm" — a strictly stronger pin of the same fixpoint defect.
  ;; ⚠ The arms deliberately share ONE result type: multi-arity clauses with
  ;; HETEROGENEOUS result types fail at HEAD with a lying unannotated-param
  ;; diagnostic — PRE-EXISTING and select-free (probe: `| 0 -> {:a 1} |
  ;; n -> 5` fails identically; filed 2026-07-30). Distinct VALUES still
  ;; discriminate the arms.
  (define rs (run-ws-raw
              (string-append
               "def mm := {:a 1 :b 2}\n"
               "defn bad\n"
               "  | 0 -> mm{a}\n"
               "  | n -> {:a 999}\n"
               "[bad 0]\n"
               "[bad 5]\n")))
  (check-false (ormap prologos-error? rs))
  (check-regexp-match #rx":a 1" (format "~a" (list-ref rs (- (length rs) 2)))
                      "the `| 0` clause was dropped or answered wrong")
  (check-regexp-match #rx":a 999" (format "~a" (last rs))))

(test-case "P1b-iii BLOCKING pin: an adjacent brace in a defn PARAM LIST is not silent"
  ;; Was: `g : _ _ _ _ -> _ defined.` with 0 errors (params $select-brace/x/base/a).
  (define rs (run-ws-raw "def bs := {:a 1}\ndefn g [x bs{a}] x\n"))
  (check-true (ormap prologos-error? rs)))

;; ============================================================
;; CIU T6 D4.P2 — grade-1 core: `.N` ordinal access  (Q_M8 dot half, Q_R1–Q_R5)
;;
;; Reader/datum pins live in test-parse-reader.rkt. THIS is the other half of
;; the TWO-LAYER pin the §Q8.1 correction forces.
;;
;; ⚠ The design said the rational mis-lex sat "at 0 errors" and demanded
;; failing-test-first on that. It was a LAYER ERROR: the 6/5 reading is
;; reader-layer, and END TO END the stranded bare `|.|` is UNBOUND, so every
;; rational-class form is LOUD today. Framing a pin as "was silently 6/5"
;; would make it pass/fail for a reason it does not claim — this arc's hazard
;; 4. So these are framed: WAS A MISLEADING ERROR, NOW COMPUTES THE VALUE.
;; ============================================================

(test-case "P2 fixpoint pin: the $postfix-index fold is IDEMPOTENT (Q_R1 inherits this)"
  ;; Q_R1's second, independent justification. P1b-iii's BLOCKING defect was a
  ;; non-fixpoint fold that swallowed one more LEFT sibling per preparse pass.
  ;; The existing arm emits `(get target key)` — NOT sentinel-headed — so pass 2
  ;; short-circuits at the ormap gate. `.N` reusing it inherits the property.
  (define once (rewrite-dot-access '(x ($postfix-index 0))))
  (define twice (rewrite-dot-access once))
  (check-equal? once twice "non-idempotent fold — it will swallow siblings on re-entry")
  (check-false (and (pair? once) (memq (car once) '($postfix-index)))
               "result is still sentinel-headed — re-entry will match it again"))

(test-case "P2 ⭐ .N computes a value where it was a MISLEADING error (PVec)"
  (define r (run-ws "def v := @[10 20 30]\nv.0\nv.2\n"))
  (check-regexp-match #rx"10 : Int" (second r))
  (check-regexp-match #rx"30 : Int" (last r)))

(test-case "P2 ⭐ the RATIONAL class, end-to-end: was `Unbound variable`, now a value"
  ;; `m.1.2` read as ($decimal-literal 6/5) at the reader, leaving a bare `|.|`
  ;; that is UNBOUND — so this was 2 counted errors, not a silent 6/5.
  (define rs (run-ws-raw "def m := @[@[1 2 3] @[4 5 6]]\nm.1.2\nm.0.0\n"))
  (check-false (ormap prologos-error? rs)
               "the rational mis-lex is gone; both forms must now type and reduce")
  (define r (map (lambda (x) (format "~a" x)) rs))
  (check-regexp-match #rx"6 : Int" (second r))
  (check-regexp-match #rx"1 : Int" (last r)))

(test-case "P2: multi-digit ordinals (Q_M8 — the ruling's own motivating case)"
  (define r (run-ws
             (string-append
              "def big := @[0 1 2 3 4 5 6 7 8 9 10 11 12]\n"
              "big.10\nbig.12\n")))
  (check-regexp-match #rx"10 : Int" (second r))
  (check-regexp-match #rx"12 : Int" (last r)))

(test-case "P2: chains in BOTH directions (field→nat was mis-lexed, nat→field mis-folded)"
  (define r (run-ws
             (string-append
              "def cfg := {:admins @[{:name \"Alice\"} {:name \"Bob\"}]}\n"
              "cfg.admins.0.name\ncfg.admins.1.name\n")))
  (check-regexp-match #rx"\"Alice\"" (second r))
  (check-regexp-match #rx"\"Bob\"" (last r)))

(test-case "P2 ⭐ Q_R1 end-to-end: `v[0]` and `v.0` agree, being one mechanism"
  (define r (run-ws "def v := @[10 20 30]\nv[1]\nv.1\n"))
  (check-equal? (second r) (last r)
                "two surfaces over ONE mechanism — if these differ, Q_R1 broke"))

(test-case "P2: het tuple .N keeps EXACT per-position types (record-project)"
  (define r (run-ws "def t := @[7 \"seven\" :seven]\nt.0\nt.1\nt.2\n"))
  (check-regexp-match #rx"7 : Int" (list-ref r 1))
  (check-regexp-match #rx"\"seven\" : String" (list-ref r 2))
  (check-regexp-match #rx":seven : Keyword" (list-ref r 3)))

(test-case "P2: a PVec runtime OOB stays LOUD (the P2 two-tier substrate)"
  (define r (run-ws-raw-last "def v := @[10 20 30]\nv.5\n"))
  (check-true (prologos-error? r)))

(test-case "P2 Q_R5: a het-tuple OOB NAMES the index and the arity (was bare 'Could not infer type')"
  ;; `closed-row-miss-hint` was KEYWORD-GATED, so a nat-domain closed row got no
  ;; hint at all — and het tuples are exactly what the acceptance corpus pins.
  ;; ⚠ THIS PIN WAS VACUOUS IN ITS FIRST DRAFT — AND THE DRAFT PASSED. Asserting
  ;; bare #rx"9" / #rx"3" matched DIGITS IN THE TEMP-FILE PATH inside the printed
  ;; error struct, the identical trap this arc already hit. Assert on DISTINCTIVE
  ;; PHRASING, never on bare digits.
  (define r (run-ws-last "def t := @[7 \"seven\" :seven]\nt.9\n"))
  (check-regexp-match #rx"index 9" r "must name the offending INDEX")
  (check-regexp-match #rx"valid indices" r "must name the valid RANGE")
  (check-false (regexp-match? #rx"Unbound variable" r)
               "the pre-P2 lie: the stranded bare `|.|` was reported instead"))

;; ---------- the LYING DIAGNOSTICS this phase actually repairs ----------
;; P2's real headline, unclaimed by §5.P2: because `x.0` was THREE datum items,
;; every arity-checking context blamed something else entirely.

(test-case "P2 ⭐ lying diagnostic 1: `.N` inside a MAP LITERAL blamed the map key"
  ;; was: "Bare symbol '.' not allowed as map key; use :. for keyword"
  (define r (run-ws-raw "def v := @[10 20 30]\ndef q := {:a v.0}\nq\n"))
  (check-false (ormap prologos-error? r))
  (check-regexp-match #rx"10" (format "~a" (last r))))

(test-case "P2 ⭐ lying diagnostic 2: `.N` in an fn BODY blamed the PARAMETER LIST"
  ;; was: "fn: all parameters except body must be bare symbols or a binder (x : T)"
  (define r (run-ws-raw "def v := @[10 20 30]\ndef f := [fn [w : [PVec Int]] w.0]\n[f v]\n"))
  (check-false (ormap prologos-error? r))
  (check-regexp-match #rx"10 : Int" (format "~a" (last r))))

(test-case "P2 ⭐ lying diagnostic 3: a bare `.N` at top level said `Unbound variable`"
  (define r (run-ws-raw-last "def v := @[10 20 30]\nv.0\n"))
  (check-false (prologos-error? r)))

(test-case "P2: `.N` folds in ALL FOUR rewrite-dot-access callers"
  ;; ⚠ CORRECTED at D4.P4b-ii-2b: this said THREE and named three. There are
  ;; FOUR — `expand-pipe-block` (macros.rkt:6294) landed at P3a, AFTER this
  ;; test was written, and it is the DANGEROUS one: `apply-pipe-step` appends
  ;; the accumulator into any hole-free step, which is how a surplus arg gets
  ;; into a fold's output. The title over-claimed coverage it never had, and
  ;; the b-ii-2 mini-audit's critic caught it. The `$select-path` arity gate
  ;; now refuses that shape loudly (see the b-ii-2b pins).
  ;; The four: preparse-expand-subforms (the re-entry),
  ;; preparse-map-literal-contents (map-literal VALUES), expand-mixfix-form
  ;; (the `.( … )` token stream, folded BEFORE pratt-parse).
  ;; ⚠ The first draft of this pin used `.( v.0 )` — a SINGLE-operand mixfix,
  ;; which errors identically on the baseline with a plain `.name`
  ;; (`.( c.a )` → "mixfix: Unexpected token after expression"). It would have
  ;; failed for a reason unrelated to `.N`. Use a real infix expression.
  (define r (run-ws-raw "def v := @[10 20 30]\n.( v.0 + v.1 )\ndef q := {:a v.2}\nq\n"))
  (check-false (ormap prologos-error? r))
  (define f (map (lambda (x) (format "~a" x)) r))
  (check-regexp-match #rx"30 : Int" (second f))     ;; mixfix caller
  (check-regexp-match #rx"30" (last f)))            ;; map-literal-value caller

(test-case "P2 NEW-INSTANCE GUARD: `ns foo.2` must NOT silently drop the segment"
  ;; namespace.rkt's guard raised only for $dot-access. With `.N` minting
  ;; $postfix-index, `ns foo.2` would reintroduce exactly the silent-drop bug
  ;; that b0db8f3e fixed.
  ;; ✅ THE NAMED FOLLOW-UP LANDED AT G2/B (2026-08-05). This comment used to
  ;; record that the guard RAISES — "a whole-file abort … Left as-is
  ;; deliberately … a future change to the seat is visible". The preparse seam
  ;; guard is that change: the refusal is still LOUD, but it is now a
  ;; per-command error VALUE, so the pin reads the RESULT LIST, not an exn.
  (check-true (ormap (lambda (r) (regexp-match? #rx"namespace name cannot contain"
                                                (format "~a" r)))
                     (run-ws-raw "ns foo.2\n"))
              "a numeric ns segment must be REJECTED, not silently dropped"))

(test-case "P2 MUST-NOT-BREAK: `.k` nominal access and the `v[…]` surface are untouched"
  (define r (run-ws
             (string-append
              "def cfg := {:host \"localhost\" :port 8080}\n"
              "cfg.host\ncfg.port\n"
              "def v := @[10 20 30]\nv[2]\n")))
  (check-regexp-match #rx"\"localhost\"" (list-ref r 1))
  (check-regexp-match #rx"8080 : Int" (list-ref r 2))
  (check-regexp-match #rx"30 : Int" (last r)))

;; ============================================================
;; D4.P2 — pins added from the pre-commit ADVERSARIAL VERIFY.
;;
;; Four perspective-diverse skeptics + an adjudicator, on the uncommitted diff.
;; The adjudicator worktree-pinned a baseline and A/B'd, which is what turned
;; the first item below from "a gap" into "a REGRESSION" — the distinction that
;; made it commit-blocking.
;; ============================================================

(test-case "P2 REGRESSION PIN (adversarial verify): a NEGATIVE literal index must not hijack the hint"
  ;; The ordinal branch sits FIRST in `closed-row-miss-hint`'s `or`, and its
  ;; first draft accepted ANY `expr-int` — dropping the `exact-nonnegative-integer?`
  ;; half of the guard it mirrors (`record-project`'s literal-nat leg). Effect:
  ;;   (a) it asserted the index was out of range for an expression that
  ;;       TYPE-CHECKS FINE (record-project routes a negative literal to the
  ;;       DYNAMIC path, which succeeds as the union of positions), and
  ;;   (b) it SUPPRESSED the correct keyword closed-row-miss hint on the same
  ;;       expression — strictly worse than the message it replaced.
  ;; Not reachable from `.N` (which cannot lex a sign) nor from `het[-1]` (the
  ;; postfix-neg marker intercepts), which is exactly why no `.N` test caught it.
  ;; The reachable surface is the paren-keyword form.
  (define r (run-ws
             (string-append
              "def mp := {:a 1 :b 2}\n"
              "def het := @[7 \"seven\" :seven]\n"
              "[+ (get het -1) mp.nope]\n")))
  ;; the KEYWORD miss is what is actually wrong here, and must be what is named
  (check-regexp-match #rx"not present in the record" (last r))
  (check-regexp-match #rx"nope" (last r))
  (check-false (regexp-match? #rx"out of range" (last r))
               "the ordinal branch hijacked a sound subexpression's diagnostic"))

(test-case "P2: a negative literal index still TYPE-CHECKS (the union-of-positions path)"
  ;; The premise of the pin above: `(get het -1)` is not an error at all, so
  ;; claiming it is out of range is a false statement, not a stricter one.
  (define r (run-ws-raw-last
             (string-append
              "def het := @[7 \"seven\" :seven]\n"
              "(get het -1)\n")))
  (check-false (prologos-error? r)))

(test-case "P2: the TRUE ordinal OOB hint survives the negative-literal fix"
  ;; Guard the fix against over-correction — the whole point of Q_R5 must remain.
  (define r (run-ws-last
             (string-append
              "def het := @[7 \"seven\" :seven]\n"
              "het[9]\n")))
  (check-regexp-match #rx"index 9" r)
  (check-regexp-match #rx"valid indices" r))

(test-case "P2 (adversarial verify): the ASCII-digit gate is SUITE-defended, not comment-defended"
  ;; `char-numeric?` accepts U+0663 etc. while `string->number` rejects them, so
  ;; a `char-numeric?` gate would mint a `#f` payload. The adjudicator PROVED
  ;; the swap is invisible to all 241 targeted tests by actually making it —
  ;; i.e. the decision was defended only by a comment. It is now pinned.
  ;; A non-ASCII digit must be DECLINED by the ordinal recognizer (it then falls
  ;; to pre-existing machinery, byte-identical to baseline).
  ;; A non-ASCII digit is DECLINED by the ordinal recognizer AND by
  ;; `recognize-dot-access` (whose exclusion is the wider `char-numeric?`), so it
  ;; falls through to pre-existing machinery, which RAISES. A/B-verified
  ;; byte-identical to baseline, so this pins "declined, unchanged" — not a new
  ;; surface. If a future cleanup swaps in `char-numeric?`, the recognizer would
  ;; instead ACCEPT it and mint a `#f` payload, and this check-exn goes red.
  (define arabic-3 (string (integer->char #x0663)))
  (check-exn #rx"exact\\?: contract violation"
             (lambda () (compat-read-all-forms-string (string-append "x." arabic-3)))
             "a non-ASCII digit must be DECLINED by the ordinal recognizer")
  ;; and the positive direction: an ASCII ordinal payload is an exact non-negative
  ;; integer, which is what `string->number` can actually produce.
  (define payload (cadr (cadr (car (compat-read-all-forms-string "x.10")))))
  (check-true (exact-nonnegative-integer? payload)
              "the $postfix-index payload must be an exact non-negative integer"))

(test-case "P2 (adversarial verify): the fixpoint pin now carries LEFT SIBLINGS"
  ;; The original pin tested `(x ($postfix-index 0))` — a shape with no left
  ;; siblings, while P1b-iii's defect was precisely that re-entry swallowed one
  ;; more LEFT sibling per pass. A sibling-free shape cannot observe that.
  (define once (rewrite-dot-access '(h base ($postfix-index 0) ($dot-access name))))
  (define twice (rewrite-dot-access once))
  (check-equal? once twice "non-idempotent fold — it will swallow siblings on re-entry")
  ;; the application head must SURVIVE; only the immediate base is consumed
  (check-equal? (car once) 'h "the application head was swallowed")
  ;; and a base-less ordinal must not consume anything to its left
  (check-equal? (rewrite-dot-access '(($postfix-index 0)))
                (rewrite-dot-access (rewrite-dot-access '(($postfix-index 0))))))

;; ============================================================
;; CIU T6 D4.P3a — the node + KEYED blocks, no `^`  (Q_T1/Q_T2/Q_T5, Q_U1)
;;
;; Failing-test-first: every E2E pin below was written RED — at pin time each
;; select form produced the P1a NOT-YET marker error ("select blocks … are not
;; supported yet"), which is the documented fails-for-the-right-reason state.
;; The battery pins the Q_T rulings: Route A node (Q_T1), Horn-D LENIENT
;; presence (Q_T2), strict duplicate check BEFORE make-record can last-win,
;; the malformed-payload seat, the type-position refusal, branch-aware miss
;; errors, and §9's learnability pair. Corpus list per Q_U1 (owner,
;; 2026-07-30): P3a owns EVERY no-`^` block line.
;; ============================================================

;; Fixture strings (per-call, against the shared env). The FIRST test-case is
;; the fixture-sanity guard (the Watching-4 lesson: a broken fixture makes
;; every pin fail for the WRONG reason — guard the premise).
(define P3A-CFG
  (string-append
   "def cfg := {:name \"GuildHall\" :version \"1.0.0\" "
   ":server {:host \"localhost\" :port 8080 :ssl {:enabled true :cert-path \"/etc\"}} "
   ":database {:url \"db-url\" :pool-size 10}}\n"))

(define P3A-REGIONS
  (string-append
   "def regions := {:eu {:host \"eu.x\" :port 443} "
   ":us {:host \"us.x\" :port 443} :ap {:host \"ap.x\" :port 8443}}\n"))

(test-case "P3a fixture-sanity guard: the fixture defs load and P2 access works (GREEN before P3a)"
  (define rs (run-ws-raw (string-append P3A-CFG P3A-REGIONS "cfg.server.host\n")))
  (check-false (ormap prologos-error? rs) "the P3a fixture itself is broken — every pin below is void")
  (check-regexp-match #rx"localhost" (format "~a" (last rs))))

;; ---- the preparse seam: fold, fixpoint, registration sites ----

(test-case "P3a: the fold fuses [base $select-brace] into the $select head"
  (check-equal? (preparse-expand-form '(h base ($select-brace a)))
                '(h ($select base a))))

(test-case "P3a: the fold is a FIXPOINT with LEFT siblings and an opaque payload"
  ;; The P1b-iii BLOCKING class: a non-fixpoint fold swallows one more LEFT
  ;; sibling per preparse re-entry. AND the payload must stay RAW — if re-entry
  ;; descended into `($select …)`, the payload's `($dot-access b)` would fuse
  ;; against its neighbour into `(map-get a :b)`, silently destroying the
  ;; branch structure before the parser can segment it.
  (define once (preparse-expand-form '(f w ($select-brace a ($dot-access b)))))
  (define twice (preparse-expand-form once))
  (check-equal? once '(f ($select w a ($dot-access b))))
  (check-equal? once twice "non-idempotent fold or non-opaque payload — re-entry changed the datum")
  (check-equal? (car once) 'f "the application head was swallowed"))

(test-case "P3a: $select is NOT an access sentinel and NOT a pattern variable"
  ;; access-sentinel? membership is what would make the fold non-fixpoint (the
  ;; head would re-match on re-entry); pattern-var? membership is the
  ;; whole-file-abort site (the P1b-ii regression class).
  (check-false (access-sentinel? '($select x a)))
  (check-false (pattern-var? '$select)))

(test-case "P3a: the baseless $select-brace stays as the needs-a-subject backstop"
  ;; The audit's C23: the baseless leg REMAINS — the fold must not touch a
  ;; sentinel with no base; the parser's own arm answers it.
  ;; (the single-element unwrap at the fold exit is the established norm —
  ;; the P2 `(($postfix-index 0))` pin unwraps identically)
  (check-equal? (preparse-expand-form '(($select-brace a)))
                '($select-brace a)))

(test-case "P3a: a select block in a defmacro TEMPLATE works through macro USE"
  ;; The pin is via USE, not registration (the P1b-ii lesson: a
  ;; registration-shaped pin stays green through the defect). RED today: the
  ;; NOT-YET marker error.
  (define rs (run-ws-raw
              (string-append
               "def bm := {:host \"h\" :port 1}\n"
               "defmacro sel4 [$u] [$u{host}]\n"
               "[sel4 bm]\n")))
  (check-false (ormap prologos-error? rs)
               "macro-expanded select must fold + parse + evaluate")
  (check-regexp-match #rx":host \"h\"" (format "~a" (last rs))))

;; ---- E2E keyed corpus (Q_U1: every no-`^` block line) ----

(test-case "P3a ⭐ single-branch projection keeps the key: cfg{database}"
  (define rs (run-ws (string-append P3A-CFG "cfg{database}\n")))
  (define r (last rs))
  (check-regexp-match #rx":pool-size 10" r)
  (check-regexp-match #rx":url \"db-url\"" r)
  ;; type rows are canonically sorted, so the TYPE string is exact
  (check-regexp-match #rx"\\{:database \\{:pool-size Int :url String\\}\\}" r))

(test-case "P3a ⭐ sub-block narrows under kept ancestry: cfg{server.{host port}}"
  (define rs (run-ws (string-append P3A-CFG "cfg{server.{host port}}\n")))
  (define r (last rs))
  (check-regexp-match #rx":host \"localhost\"" r)
  (check-regexp-match #rx":port 8080" r)
  (check-regexp-match #rx"\\{:server \\{:host String :port Int\\}\\}" r)
  ;; narrowed: ssl must NOT survive into the result
  (check-false (regexp-match #rx"ssl" r)))

(test-case "P3a: doubly nested sub-block: cfg{server.{ssl.{enabled}}}"
  (define rs (run-ws (string-append P3A-CFG "cfg{server.{ssl.{enabled}}}\n")))
  (define r (last rs))
  (check-regexp-match #rx":enabled true" r)
  (check-regexp-match #rx"\\{:server \\{:ssl \\{:enabled Bool\\}\\}\\}" r))

(test-case "P3a: plain dot-descent projects with ancestry: cfg{database.pool-size}"
  ;; The dot-access ATTACH rule (no sub-block involved): projection keeps the
  ;; traversed nominal keys — {:database {:pool-size 10}}, NOT bare 10.
  (define rs (run-ws (string-append P3A-CFG "cfg{database.pool-size}\n")))
  (define r (last rs))
  (check-regexp-match #rx":pool-size 10" r)
  (check-regexp-match #rx"\\{:database \\{:pool-size Int\\}\\}" r))

(test-case "P3a: multi-branch block: cfg{name version}"
  (define rs (run-ws (string-append P3A-CFG "cfg{name version}\n")))
  (define r (last rs))
  (check-regexp-match #rx":name \"GuildHall\"" r)
  (check-regexp-match #rx":version \"1.0.0\"" r)
  (check-regexp-match #rx"\\{:name String :version String\\}" r))

(test-case "P3a: nominal n-ary selection over a map-of-rows: regions{eu us}"
  (define rs (run-ws (string-append P3A-REGIONS "regions{eu us}\n")))
  (define r (last rs))
  (check-regexp-match #rx":eu" r)
  (check-regexp-match #rx":us" r)
  (check-false (regexp-match #rx":ap" r) "unselected key :ap must be pruned")
  (check-regexp-match
   #rx"\\{:eu \\{:host String :port Int\\} :us \\{:host String :port Int\\}\\}" r))

(test-case "P3a ⭐ selection results are ordinary closed rows: def + re-projection"
  (define rs (run-ws (string-append
                      P3A-CFG
                      "def sub := cfg{server.{host}}\n"
                      "sub.server.host\n")))
  (check-regexp-match #rx"sub : \\{:server \\{:host String\\}\\} defined" (second rs))
  (check-regexp-match #rx"\"localhost\" : String" (last rs)))

(test-case "P3a: a select composes with dot-access: cfg{server}.server.host"
  (define rs (run-ws (string-append P3A-CFG "cfg{server}.server.host\n")))
  (check-regexp-match #rx"\"localhost\" : String" (last rs)))

;; ---- Q_T2: Horn D, LENIENT ----

(test-case "P3a ⭐ Q_T2 LENIENT: listed-'present fields on a DYN row select; result row is CLOSED"
  ;; dyn2's fields are listed 'present ({:host String :port Int | _}) — their
  ;; presence IS sourced, so the block may select them. The RESULT row is
  ;; closed all-'present (no `| _` in the result type) — PS15's "sealable,
  ;; validatable" claim made true.
  (define rs (run-ws-raw (string-append
                          "def base := {:host \"h\" :port 1}\n"
                          "def kk := :port\n"
                          "def d2 := [map-assoc base kk 2]\n"
                          "d2{host}\n")))
  (check-false (ormap prologos-error? rs) "the LENIENT select must succeed")
  (define r (format "~a" (last rs)))
  (check-regexp-match #rx":host \"h\"" r)
  (check-regexp-match #rx"\\{:host String\\}" r)
  ;; verify-corrected: an open row prints `{… | _}` — the pipe is INSIDE the
  ;; braces, so the original `} |` regexp could never fire; `[|]` can.
  (check-false (regexp-match #rx"[|]" r) "the result row must be CLOSED (no dyn tail)"))

(test-case "P3a Q_T2: an 'unknown-marked field REFUSES with the remedy list"
  ;; dyn1 = dissoc-with-dynamic-key → every field 'unknown ({:host? … | _}).
  (define rs (run-ws-raw (string-append
                          "def base := {:host \"h\" :port 1}\n"
                          "def kk := :port\n"
                          "def d1 := [map-dissoc base kk]\n"
                          "d1{host}\n")))
  (check-true (prologos-error? (last rs)))
  (define r (format "~a" (last rs)))
  ;; the remedy list names ONLY remedies that work at HEAD (adversarial
  ;; verify dropped "annotate its row type" — no working spelling exists)
  (check-regexp-match #rx"seal" r)
  (check-regexp-match #rx"validate" r)
  (check-false (regexp-match #rx"annotate" r) "an unimplementable remedy re-appeared"))

(test-case "P3a Q_T2: an UNLISTED field on a dyn row REFUSES with the remedy list"
  (define rs (run-ws-raw (string-append
                          "def base := {:host \"h\" :port 1}\n"
                          "def kk := :port\n"
                          "def d2 := [map-assoc base kk 2]\n"
                          "d2{zzz}\n")))
  (check-true (prologos-error? (last rs)))
  (define r (format "~a" (last rs)))
  ;; the remedy list names ONLY remedies that work at HEAD (adversarial
  ;; verify dropped "annotate its row type" — no working spelling exists)
  (check-regexp-match #rx"seal" r)
  (check-regexp-match #rx"validate" r)
  (check-false (regexp-match #rx"annotate" r) "an unimplementable remedy re-appeared"))

(test-case "P3a Q_T2: a (Map K V) subject REFUSES with the remedy list"
  (define rs (run-ws-raw (string-append
                          "def m1 := [map-assoc [map-empty Keyword Int] :a 1]\n"
                          "m1{a}\n")))
  (check-true (prologos-error? (last rs)))
  (define r (format "~a" (last rs)))
  ;; the remedy list names ONLY remedies that work at HEAD (adversarial
  ;; verify dropped "annotate its row type" — no working spelling exists)
  (check-regexp-match #rx"seal" r)
  (check-regexp-match #rx"validate" r)
  (check-false (regexp-match #rx"annotate" r) "an unimplementable remedy re-appeared"))

(test-case "P3a: a keyed block on a TUPLE (nat row) is a loud refusal"
  (define rs (run-ws-raw (string-append
                          "def het := @[7 \"seven\" :seven]\n"
                          "het{name}\n")))
  (check-true (prologos-error? (last rs)))
  (check-regexp-match #rx"tuple" (format "~a" (last rs))))

;; ---- the error battery: miss, duplicate, malformed payload ----

(test-case "P3a ⭐ closed-row miss names the fields, the branch, and the extraction spelling"
  (define rs (run-ws-raw (string-append P3A-CFG "cfg{zzz}\n")))
  (check-true (prologos-error? (last rs)))
  (define r (format "~a" (last rs)))
  (check-regexp-match #rx":zzz" r)
  (check-regexp-match #rx"available fields" r)
  (check-regexp-match #rx"branch" r)
  ;; §9's learnability half: the block-side miss names the extraction spelling
  (check-regexp-match #rx"\\.zzz" r))

(test-case "P3a: a miss INSIDE a sub-block names the full branch path"
  (define rs (run-ws-raw (string-append P3A-CFG "cfg{server.{zzz}}\n")))
  (check-true (prologos-error? (last rs)))
  (define r (format "~a" (last rs)))
  (check-regexp-match #rx":zzz" r)
  (check-regexp-match #rx"server" r))

(test-case "P3a ⭐ duplicate output keys error BEFORE make-record can last-win"
  ;; make-record dedups right-priority SILENTLY ({:a 1 :a 2} → {:a 2} at 0
  ;; errors, probe-verified at HEAD) — so the strict check must run before
  ;; minting, at both the top level and nested sub-block levels.
  (define raw1 (run-ws-raw-last (string-append P3A-CFG "cfg{database database}\n")))
  (check-true (prologos-error? raw1))
  (define r1 (format "~a" raw1))
  (check-regexp-match #rx"duplicate" r1)
  (check-regexp-match #rx":database" r1)
  (check-regexp-match #rx"\\^" r1)  ;; remedies ^k' / ^_ named
  (define raw2 (run-ws-raw-last (string-append P3A-CFG "cfg{server.{host host}}\n")))
  (check-true (prologos-error? raw2))
  (define r2 (format "~a" raw2))
  (check-regexp-match #rx"duplicate" r2)
  (check-regexp-match #rx":host" r2))

(test-case "P3a: the empty block has its OWN arm ahead of L4"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{}\n")))
  (check-true (prologos-error? raw))
  (define r (format "~a" raw))
  (check-regexp-match #rx"empty selection" r)
  (check-regexp-match #rx"empty map" r))

(test-case "P3a→P3c: an ordinal STEP over a KEYWORD row is the honest cross-domain error"
  ;; P3c-flipped (verify rank 5): this pin carried the "unruled" refusal;
  ;; ordinal steps are LIVE now (Q_U2) — `.0` over a keyword row gets the
  ;; not-indexable teaching, not a phase pointer.
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{server.0}\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"tuple or vector subject" (format "~a" raw)))

(test-case "P3a→P3c: ordinal BRANCHES over a KEYWORD row refuse cross-domain"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{0 1}\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"tuple or vector subject" (format "~a" raw)))

(test-case "P3a malformed seat: keyword items are written bare"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{:name}\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"bare" (format "~a" raw)))

(test-case "P3a malformed seat: stray `.` / $rest / list items / atoms are refused"
  (check-true (prologos-error? (run-ws-raw-last (string-append P3A-CFG "cfg{server . host}\n"))))
  (check-true (prologos-error? (run-ws-raw-last (string-append P3A-CFG "cfg{name...}\n"))))
  (check-true (prologos-error? (run-ws-raw-last (string-append P3A-CFG "cfg{[name version]}\n"))))
  (check-true (prologos-error? (run-ws-raw-last (string-append P3A-CFG "cfg{\"s\"}\n")))))

(test-case "P3a malformed seat: a nested ADJACENT brace names the `.{…}` spelling"
  ;; `cfg{server{host}}` — the sub-block spelling inside a block is `.{…}`.
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{server{host}}\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"narrow with" (format "~a" raw)))

(test-case "P3a malformed seat: a segment cannot follow a sub-block"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{server.{host}.port}\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"cannot follow" (format "~a" raw)))

(test-case "P3a: type position refuses loudly"
  (define rs (run-ws-raw (string-append P3A-CFG "def bad : cfg{version} := \"x\"\n")))
  (check-true (ormap prologos-error? rs) "a select block must not be accepted as a type"))

(test-case "P3a: top-level `x.{…}` gets a guided error that does not lie about x{…}"
  ;; After P3a, `x{…}` WORKS — the old shared message ("select blocks … are
  ;; not supported yet") would be false. The dot-brace form at top level stays
  ;; refused, with guidance naming the block spelling.
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg.{version}\n")))
  (check-true (prologos-error? raw))
  (define r (format "~a" raw))
  (check-regexp-match #rx"belongs inside a select block" r)
  (check-false (regexp-match #rx"not supported yet" r)
               "the P1a NOT-YET wording survived past its truth"))

;; ---- the twins (inferQ/checkQ) + §9's learnability pair ----

(test-case "P3a twins: a select as a MAP VALUE (infer position) types under QTT"
  ;; The cdb535ac shape: map values are INFER position — an un-arm'd inferQ
  ;; falls to the catch-all and lies "Multiplicity violation".
  (define rs (run-ws-raw (string-append P3A-CFG "def m2 := {:f cfg{database}}\n")))
  (check-false (ormap prologos-error? rs)
               "an inferQ miss surfaces as a lying 'Multiplicity violation'"))

(test-case "P3a twins: a select in a defn body + call"
  (define rs (run-ws (string-append
                      P3A-CFG
                      "defn getdb [] cfg{database}\n"
                      "[getdb]\n")))
  (check-regexp-match #rx":pool-size 10" (last rs)))

(test-case "P3a §9 learnability pair: x.a.b extracts, x{a.b} projects — side by side"
  (define rs (run-ws (string-append
                      P3A-CFG
                      "cfg.database.pool-size\n"
                      "cfg{database.pool-size}\n")))
  (check-regexp-match #rx"^10 : Int" (second rs))
  (check-regexp-match #rx"\\{:database \\{:pool-size Int\\}\\}" (last rs)))

;; ============================================================
;; D4.P3a — ADVERSARIAL VERIFY pins (6th consecutive slice with a catch)
;;
;; Four skeptics + main-thread adjudication on the uncommitted diff.
;; BLOCKING: block-form `|>` with a select init silently evaluated the WRONG
;; select at 0 errors (head-macro dispatch precedes the fold; the pipe's step
;; builder spliced its accumulator INTO the raw sentinel payload, and the
;; later fold fused the corrupted select onto the FUNCTION). SIGNIFICANT:
;; the `$select` subject was never preparse-expanded (the fold-arm comment's
;; premise was FALSE — the fold runs before subform recursion), freezing raw
;; sentinels inside compound subjects; schema-sealed subjects refused with a
;; wrong-kinded message while the remedy text said "seal the subject" (found
;; by TWO skeptics independently); `^`-bearing items produced FABRICATED
;; field-miss diagnostics on exactly the P3b spellings the duplicate message
;; recommends.
;; ============================================================

(test-case "P3a verify ⭐ BLOCKING: block-form pipe with a select init pipes the RIGHT value"
  ;; Was: `|> cfg{server} f` = `($select f server cfg-as-branch)` — a select
  ;; over the FUNCTION, silently wrong when f's row happened to offer the keys.
  (check-equal? (preparse-expand-form '($pipe-gt cfg ($select-brace server) f2))
                '(f2 ($select cfg server)))
  ;; E2E at TOP LEVEL — a block-form pipe on a def RHS is PRE-EXISTING broken
  ;; (worktree-pinned baseline: `def r3 := |> cfg.server map-keys` fails with
  ;; 2 errors at clean HEAD, select-free), so the def shape cannot pin THIS
  ;; defect. Top level works and discriminates: the corrupted fold selected
  ;; off the FUNCTION, so :server-vs-:name tells the subjects apart.
  (define rs (run-ws-raw (string-append P3A-CFG "|> cfg{server} map-keys\n")))
  (check-false (ormap prologos-error? rs))
  (define r (format "~a" (last rs)))
  (check-regexp-match #rx":server" r)
  (check-false (regexp-match #rx":name" r) "the pipe selected off the wrong subject"))

;; ⚠ UPDATED at b-ii-2b (the RED set): the subject's inner `m.x` now folds to
;; `($select-path m x)` instead of `(map-get m :x)`. The CLAIM is unchanged —
;; the subject IS expanded while the payload stays raw — only the folded shape
;; moved, which is the migration itself.
(test-case "P3a verify: compound select SUBJECTS are preparse-expanded (partial opacity)"
  ;; The fold runs BEFORE subform recursion, so the subject arrives raw; the
  ;; $select arm now expands the SUBJECT while the payload stays protected.
  ;; F2a shape — bracket-group subject with an inner dot-access:
  (check-equal? (preparse-expand-form '((f m ($dot-access x)) ($select-brace a)))
                '($select (f ($select-path m x)) a))
  ;; F2b shape — subject containing its OWN select:
  (check-equal? (preparse-expand-form '((g cfg ($select-brace server)) ($select-brace server)))
                '($select (g ($select cfg server)) server))
  ;; F2c E2E — map-literal subject whose VALUE uses dot-access:
  (define rs (run-ws-raw "def p := {:x 5}\ndef s4 := {:a p.x}{a}\ns4\n"))
  (check-false (ormap prologos-error? rs))
  (check-regexp-match #rx":a 5" (format "~a" (last rs))))

(test-case "P3a verify ⭐ schema-sealed subjects project THROUGH the seal (the remedy loop closes)"
  ;; Two skeptics convergent: `sealed{name}` refused as 'subject-other while
  ;; the refusal messages named "seal the subject" as remedy #1.
  (define rs (run-ws-raw
              (string-append
               "schema Person\n  :name String\n  :age Int\n"
               "def sealed := the Person {:name \"ann\" :age 3}\n"
               "sealed{name}\n"
               "def picker := [fn [p : Person] p{name}]\n"
               "[picker sealed]\n")))
  (check-false (ormap prologos-error? rs))
  (check-regexp-match #rx":name \"ann\"" (format "~a" (list-ref rs (- (length rs) 3))))
  (check-regexp-match #rx":name \"ann\"" (format "~a" (last rs))))

(test-case "P3a verify (P3c-updated): `^`-bearing items never fabricate a field miss"
  ;; P3a refused both spellings with a pointer; P3b landed `^_`; P3c landed
  ;; the keyless sort — BOTH are live semantics now. The pin's surviving
  ;; intent: no `^` spelling may produce a fabricated "not present" miss.
  (define raw1 (run-ws-raw-last (string-append P3A-CFG "cfg{version^}\n")))
  (check-false (prologos-error? raw1) "the keyless 1-tuple is live at P3c")
  (check-false (regexp-match #rx"not present" (format "~a" raw1)) "fabricated miss")
  (define raw2 (run-ws-raw-last (string-append P3A-CFG "cfg{server.host^_}\n")))
  (check-false (prologos-error? raw2) "Reading N is live since P3b")
  (check-regexp-match #rx":server-host" (format "~a" raw2)))

(test-case "P3a verify: ground non-map subjects PANIC at the top level too (tier symmetry)"
  ;; Was: `(whnf (expr-select (expr-int 5) …))` returned the node unchanged —
  ;; silent stick where the nested descent one level down panics loudly.
  (define r (whnf (expr-select (expr-int 5) (expr-path '((a)) 'block) #f)))
  (check-true (expr-panic? r) "a ground non-map subject must panic, not stick")
  ;; and a stuck NEUTRAL still sticks (fvar subject — no panic, no loop):
  (define stuck (whnf (expr-select (expr-fvar 'nosuch) (expr-path '((a)) 'block) #f)))
  (check-true (expr-select? stuck)))

(test-case "P3a verify: trailing steps after a terminal sub-block panic (constructed IR)"
  ;; The parser grammar forbids the shape; the reducer now enforces it rather
  ;; than silently discarding the trailing steps.
  (define subj (whnf (expr-select (expr-fvar 'x) (expr-path '((a)) 'block) #f)))
  (check-true (expr-select? subj)) ;; sanity: stuck neutral stays stuck
  (define bad-branches '((a (@sub (b)) c)))
  ;; construct the champ directly — no fixture dependency
  (define inner
    (champ-insert champ-empty (equal-hash-code (expr-keyword 'b)) (expr-keyword 'b) (expr-int 1)))
  (define champ-subj
    (expr-champ (champ-insert champ-empty (equal-hash-code (expr-keyword 'a)) (expr-keyword 'a)
                              (expr-champ inner))))
  (define r (whnf (expr-select champ-subj (expr-path bad-branches 'block) #f)))
  (check-true (expr-panic? r) "trailing steps after @sub must panic, not vanish"))

(test-case "P3a verify: the sub-block empty message does not claim `{}` is a map literal"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{server.{}}\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"empty sub-block" (format "~a" raw)))

(test-case "P3a verify: the duplicate message also names the WORKING remedy (sub-block grouping)"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{database.url database.pool-size}\n")))
  (check-true (prologos-error? raw))
  (define r (format "~a" raw))
  (check-regexp-match #rx"duplicate" r)
  (check-regexp-match #rx"sub-block" r))

;; ============================================================
;; CIU T6 D4.P3b — the `^` family  (Q_T3/T4a/T4b/T4b′/T7/T8, Q_U1)
;;
;; Failing-test-first: every pin below was written RED — at pin time each `^`
;; spelling produced P3a's re-key-family pointer error ("… lands at Path
;; Selection P3b"), the stray-`.` text (the ordinal-`^` shatter shapes), or an
;; unbound-variable error (the top-level spellings) — the documented
;; fails-for-the-right-reason state. The battery pins: the ONE splitter's
;; continuation grammar (`-`?·{ε | label | `_`}), in-place rename (Q_T4b),
;; `^_` Reading N (Q_T4b′), mid-path dissolve/splice, the `^-` collapse
;; family (Q_T7), `^..` parent-key collapse (Q_T8), the OUTPUT-level-local
;; duplicate check (Q_T3, the monotonicity pin), the Q_T4a ordinal-`^` guided
;; error across ALL THREE datum shapes, and the malformed-`^` battery.
;; Leaf-position bare `^` (keyless) REFUSES with a P3c pointer — the boundary
;; note: the tuple carrier does not exist until P3c.
;; ============================================================

;; ---- the splitter, one E2E pin per continuation (Q_T4b base rules) ----

(test-case "P3b ⭐ in-place rename: cfg{server.host^h} keeps the level, renames the leaf"
  ;; Q_T4b: rename is IN PLACE — {:server {:h …}}, NOT {:h …}.
  (define r (run-ws-last (string-append P3A-CFG "cfg{server.host^h}\n")))
  (check-regexp-match #rx":h \"localhost\"" r)
  (check-regexp-match #rx"\\{:server \\{:h String\\}\\}" r)
  (check-false (regexp-match #rx":host" r) "the source key must not survive a rename"))

(test-case "P3b: head-leaf rename: cfg{database^db}"
  (define r (run-ws-last (string-append P3A-CFG "cfg{database^db}\n")))
  (check-regexp-match #rx":db" r)
  (check-regexp-match #rx"\\{:db \\{:pool-size Int :url String\\}\\}" r))

(test-case "P3b ⭐ mid-path dissolve splices: cfg{server^.host}"
  ;; only dissolve removes a level (Q_T4b).
  (define r (run-ws-last (string-append P3A-CFG "cfg{server^.host}\n")))
  (check-regexp-match #rx":host \"localhost\"" r)
  (check-regexp-match #rx"\\{:host String\\}" r)
  (check-false (regexp-match #rx":server" r) "the dissolved level must not survive"))

(test-case "P3b: mid-path rename: cfg{server^srv.host}"
  ;; `k'` is legal mid-path (spec §3.4) — the level is kept under the new key.
  (define r (run-ws-last (string-append P3A-CFG "cfg{server^srv.host}\n")))
  (check-regexp-match #rx"\\{:srv \\{:host String\\}\\}" r))

(test-case "P3b: dissolve then multi-descent: cfg{server^.ssl.enabled}"
  (define r (run-ws-last (string-append P3A-CFG "cfg{server^.ssl.enabled}\n")))
  (check-regexp-match #rx":enabled true" r)
  (check-regexp-match #rx"\\{:ssl \\{:enabled Bool\\}\\}" r))

(test-case "P3b: dissolve + sub-block: cfg{database^.{url pool-size}}"
  (define r (run-ws-last (string-append P3A-CFG "cfg{database^.{url pool-size}}\n")))
  (check-regexp-match #rx":url \"db-url\"" r)
  (check-regexp-match #rx":pool-size 10" r)
  (check-regexp-match #rx"\\{:pool-size Int :url String\\}" r))

(test-case "P3b ⭐ `^_` Reading N: rename the leaf IN PLACE to the path-synthesized key"
  ;; Q_T4b′: cfg{server.host^_} → {:server {:server-host …}} — the flat
  ;; result was the SUPERSEDED surface's reading (that spelling is `^-_`).
  (define r (run-ws-last (string-append P3A-CFG "cfg{server.host^_ database.url^_}\n")))
  (check-regexp-match #rx":server-host \"localhost\"" r)
  (check-regexp-match #rx":database-url \"db-url\"" r)
  (check-regexp-match
   #rx"\\{:database \\{:database-url String\\} :server \\{:server-host String\\}\\}" r))

(test-case "P3b ⭐ `^-` collapse keeps the leaf key, drops the ancestry (Q_T7)"
  (define r (run-ws-last (string-append P3A-CFG "cfg{server.host^-}\n")))
  (check-regexp-match #rx":host \"localhost\"" r)
  (check-regexp-match #rx"\\{:host String\\}" r)
  (check-false (regexp-match #rx":server" r)))

(test-case "P3b: `^-k'` collapse-rename (Q_T7)"
  (define r (run-ws-last (string-append P3A-CFG "cfg{server.host^-hst}\n")))
  (check-regexp-match #rx":hst \"localhost\"" r)
  (check-regexp-match #rx"\\{:hst String\\}" r))

(test-case "P3b ⭐ `^-_` collapse-synth: FLAT provenance (Q_T7 — where the old `^_` semantics live)"
  (define r (run-ws-last (string-append P3A-CFG "cfg{server.host^-_ database.url^-_}\n")))
  (check-regexp-match #rx":server-host \"localhost\"" r)
  (check-regexp-match #rx":database-url \"db-url\"" r)
  (check-regexp-match #rx"\\{:database-url String :server-host String\\}" r))

(test-case "P3b ⭐ `^..` parent-key collapse: ancestors above the parent are KEPT (Q_T8)"
  ;; server.ssl.enabled^.. ≡ server.ssl^.enabled^ssl → {:server {:ssl true}}
  (define r (run-ws-last (string-append P3A-CFG "cfg{server.ssl.enabled^..}\n")))
  (check-regexp-match #rx":ssl true" r)
  (check-regexp-match #rx"\\{:server \\{:ssl Bool\\}\\}" r)
  (check-false (regexp-match #rx":enabled" r) "the leaf key must not survive `^..`"))

(test-case "P3b: 2-segment `^..` lands the leaf under the parent key at top level"
  (define r (run-ws-last (string-append P3A-CFG "cfg{database.url^..}\n")))
  (check-regexp-match #rx":database \"db-url\"" r)
  (check-regexp-match #rx"\\{:database String\\}" r))

;; ---- the flagship (spec §10.1) ----

(test-case "P3b ⭐⭐ the FLAGSHIP: cfg{server^.{ssl^.enabled^ssl port} version database^.pool-size}"
  (define r (run-ws-last
             (string-append P3A-CFG
                            "cfg{server^.{ssl^.enabled^ssl port} version database^.pool-size}\n")))
  (check-regexp-match #rx":ssl true" r)
  (check-regexp-match #rx":port 8080" r)
  (check-regexp-match #rx":version \"1.0.0\"" r)
  (check-regexp-match #rx":pool-size 10" r)
  (check-regexp-match #rx"\\{:pool-size Int :port Int :ssl Bool :version String\\}" r))

;; ---- Q_T3: the OUTPUT-level-local duplicate check ----

(test-case "P3b ⭐⭐ the MONOTONICITY pin: cfg{server^.{port} database^.port} ERRORS (Q_T3)"
  ;; The named pin: the syntactic-block reading ACCEPTS this (two branch heads
  ;; server ≠ database); Ruling B B4 REJECTS it (two dissolving branches land
  ;; :port at the same OUTPUT level). Accepting it today would be the ONE
  ;; monotonicity break — an error that later became a different meaning.
  ;; The naive lowering silently last-wins (probe-verified at the audit).
  (define raw (run-ws-raw-last
               (string-append P3A-CFG "cfg{server^.{port} database^.port}\n")))
  (check-true (prologos-error? raw) "Q_T3: this must ERROR at the strict waypoint")
  (define r (format "~a" raw))
  (check-regexp-match #rx"duplicate" r)
  (check-regexp-match #rx":port" r))

(test-case "P3b: duplicate LEAF after rename errors, naming the remedies (spec §10.1 negative)"
  ;; app-config{server^.host database^.url^host} — the rename CREATES the collision.
  (define raw (run-ws-raw-last
               (string-append P3A-CFG "cfg{server^.host database^.url^host}\n")))
  (check-true (prologos-error? raw))
  (define r (format "~a" raw))
  (check-regexp-match #rx"duplicate" r)
  (check-regexp-match #rx":host" r)
  (check-regexp-match #rx"\\^" r "the message names the ^k'/^_ remedies"))

(test-case "P3b: distinct spliced keys COEXIST (no false duplicate): cfg{server^.{host} version}"
  (define rs (run-ws-raw (string-append P3A-CFG "cfg{server^.{host} version}\n")))
  (check-false (ormap prologos-error? rs))
  (define r (format "~a" (last rs)))
  (check-regexp-match #rx":host \"localhost\"" r)
  (check-regexp-match #rx":version \"1.0.0\"" r))

;; ---- Horn D through `^` (presence checks run on SOURCE fields) ----

(test-case "P3b: a dissolved head still projects the SOURCE field — miss is branch-aware"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{nope^.host}\n")))
  (check-true (prologos-error? raw))
  (define r (format "~a" raw))
  (check-regexp-match #rx":nope" r)
  (check-regexp-match #rx":database|:server" r "the miss names the available fields"))

;; ---- Q_T4a: the ordinal-`^` guided error, ALL THREE datum shapes ----

(test-case "P3b ⭐ Q_T4a in-block: cfg{admins.0^first} — the |.| shatter shape"
  ;; datum: admins |.| 0 ^ first — must NOT hit the stray-`.` arm.
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{admins.0^first}\n")))
  (check-true (prologos-error? raw))
  (define r (format "~a" raw))
  (check-regexp-match #rx"ordinal has no key" r)
  (check-regexp-match #rx"admins\\^first\\.0" r "the message names the valid spelling")
  (check-false (regexp-match #rx"stray" r) "must not fall to the stray-`.` arm"))

(test-case "P3b Q_T4a top level: x[0]^ — the $postfix-index shape"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg[0]^\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"ordinal has no key" (format "~a" raw)))

(test-case "P3b Q_T4a top level: x.0^ — the stranded-dot shape"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg.0^\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"ordinal has no key" (format "~a" raw)))

;; ---- the P3b/P3c boundary: keyless leaf `^` refuses with a P3c pointer ----

(test-case "P3b boundary (P3c-flipped): the keyless spellings are LIVE"
  ;; These two pins carried the P3b→P3c boundary refusals; P3c demolished
  ;; them as planned. The semantic pins live in the P3c battery below —
  ;; here we keep the flip itself pinned: no refusal survives.
  (check-false (prologos-error?
                (run-ws-raw-last (string-append P3A-CFG "cfg{version^}\n"))))
  (check-false (prologos-error?
                (run-ws-raw-last
                 (string-append P3A-CFG "cfg{server.host^ database.url^}\n")))))

;; ---- the malformed-`^` battery ----

(test-case "P3b malformed: a^b^c — one `^` per segment"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{a^b^c}\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"one `\\^`" (format "~a" raw)))

(test-case "P3b malformed: lone `^` and spaced `^ b` — a `^` needs a segment to its left"
  (define raw1 (run-ws-raw-last (string-append P3A-CFG "cfg{^}\n")))
  (check-true (prologos-error? raw1))
  (check-regexp-match #rx"segment" (format "~a" raw1))
  (define raw2 (run-ws-raw-last (string-append P3A-CFG "cfg{^ b}\n")))
  (check-true (prologos-error? raw2))
  (check-regexp-match #rx"segment" (format "~a" raw2)))

(test-case "P3b malformed: `^...` absorbs into $rest and the seat rejects it (Q_T8 edge)"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{a.b^...}\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"\\.\\.\\." (format "~a" raw)))

(test-case "P3b malformed: `^..` with no parent segment refuses"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{version^..}\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"parent" (format "~a" raw)))

(test-case "P3b malformed: mid-path `^_` refuses (synth attaches to the last segment)"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{server^_.host}\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"LAST segment" (format "~a" raw)))

(test-case "P3b malformed: mid-path collapse `^-` refuses (collapse is a leaf continuation)"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{server^-.host}\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"LEAF continuation" (format "~a" raw)))

(test-case "P3b malformed: a rename target may not begin with `-` (Q_T7 eyes-open)"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{server.host^--x}\n")))
  (check-true (prologos-error? raw))
  ;; verify finding 9: the original `#rx"-"` pin was VACUOUS — the transparent
  ;; error struct prints the temp-file path, which always contains a dash.
  (check-regexp-match #rx"collapse marker" (format "~a" raw)))

;; ---- §G: a `^`-shaped selection seals + validates (Q_U1 reassigned here) ----

(test-case "P3b ⭐ §G: the selection result seals and validates (schema + `the` + validate)"
  ;; validate needs the result + reason modules in scope (:no-prelude fixture)
  (define rs (run-ws-raw
              (string-append
               "require [prologos::data::result :refer [Result ok err ok? err?]]\n"
               "require [prologos::data::reason :refer [Reason missing-required check-failed type-mismatch unexpected-field errors-to-list]]\n"
               P3A-CFG
               "schema SrvC\n  :host String\n  :port Int\n"
               "def sc := the SrvC cfg{server^.{host port}}\n"
               "sc.host\n"
               "[validate SrvC cfg{server^.{host port}}]\n")))
  (check-false (ormap prologos-error? rs))
  (check-regexp-match #rx"\"localhost\"" (format "~a" (list-ref rs (- (length rs) 2))))
  (check-regexp-match #rx"ok|valid" (format "~a" (last rs))))

;; ---- twins: a `^`-bearing select under QTT ----

(test-case "P3b twins: a collapse-synth select on a def RHS + re-projection"
  (define rs (run-ws-raw (string-append
                          P3A-CFG
                          "def flat := cfg{server.host^-_}\n"
                          "flat.server-host\n")))
  (check-false (ormap prologos-error? rs))
  (check-regexp-match #rx"\"localhost\"" (format "~a" (last rs))))

;; ============================================================
;; D4.P3b — ADVERSARIAL VERIFY pins (7th consecutive slice with a catch)
;;
;; 4 skeptics + adjudication on the uncommitted diff. BLOCKING: the first
;; ordinal-rekey seat replaced the WHOLE datum with the guided marker, so a
;; match arm containing `v[0]^` lost its `->` and raw-crashed the READER —
;; a whole-file abort where HEAD recovered per-command. Same root cause
;; swallowed a defn clause, broke map-literal arity, and shredded pipe
;; inits. Fixed by ELEMENT-WISE marker replacement (the P1a dot-key
;; precedent). Plus: the fused `^..enabled` continuation missed the Q_T8
;; lookahead (INVERTED stray-dot advice); `k^...label` leaked the internal
;; `($rest-param …)` sentinel; the dup message's `^_` remedy reproduced the
;; collision in both canonical classes (dropped); digit-leading rename
;; targets minted dot-unreachable fields (refused); `{0^first}` escaped the
;; ONE Q_T4a message; a vacuous `#rx"-"` pin matched the temp-file path.
;; ============================================================

(test-case "P3b verify ⭐ BLOCKING: ordinal-^ inside a match arm recovers PER-COMMAND"
  ;; Was: the whole ($pipe 0 -> body) arm became the bare marker; the arm
  ;; parser found no `->` and raw-crashed — ZERO commands output.
  (define rs (run-ws-raw (string-append
                          P3A-CFG
                          "def w := match 5\n  | 0 -> cfg[0]^\n  | _ -> 111\n"
                          "cfg.version\n")))
  (check-regexp-match #rx"ordinal has no key|1.0.0"
                      (format "~a" rs)
                      "the file must survive to later commands")
  (check-regexp-match #rx"\"1.0.0\"" (format "~a" (last rs))
                      "the command AFTER the bad arm must still run"))

(test-case "P3b verify: ordinal-^ in a defn clause body keeps the clause structure"
  (define rs (run-ws-raw (string-append
                          P3A-CFG
                          "defn k2 [x] cfg[0]^\n"
                          "cfg.version\n")))
  (check-regexp-match #rx"\"1.0.0\"" (format "~a" (last rs))))

(test-case "P3b verify: ordinal-^ as a map-literal VALUE errors per-command, not arity"
  (define raw (run-ws-raw (string-append P3A-CFG "def g2 := {:a cfg[0]^}\ncfg.version\n")))
  (check-false (regexp-match #rx"even number" (format "~a" raw))
               "the marker must not splice element-wise into the literal")
  (check-regexp-match #rx"\"1.0.0\"" (format "~a" (last raw))))

(test-case "P3b verify: siblings SURVIVE the element-wise ordinal-^ marker"
  ;; the whole-datum replacement lost `f` and `b`; element-wise keeps them
  (check-equal? (car (preparse-expand-form '(f w ($postfix-index 0) ^ b)))
                'f))

(test-case "P3b verify ⭐ fused `^..` continuation agrees with the spaced spelling"
  ;; Was: `ssl^..enabled` → the second dot FUSED into ($dot-access enabled),
  ;; the Q_T8 lookahead missed, and the stray-`.` arm gave INVERTED advice
  ;; ("write the path with no spaces" — it had none).
  (define r (run-ws-last (string-append P3A-CFG "cfg{server.ssl^..enabled}\n")))
  (check-regexp-match #rx"\\{:server \\{:enabled Bool\\}\\}" r)
  ;; and the sub-block continuation:
  (define r2 (run-ws-last (string-append P3A-CFG "cfg{server.ssl^..{enabled}}\n")))
  (check-regexp-match #rx":enabled true" r2))

(test-case "P3b verify: `^.`-near-miss names `^..`, not the stray-dot advice"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{server.ssl^ .}\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"\\^\\.\\." (format "~a" raw)))

(test-case "P3b verify: `k^...label` gets the Q_T8 message, never the raw sentinel"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{server.ssl^...enabled}\n")))
  (check-true (prologos-error? raw))
  (check-false (regexp-match #rx"rest-param" (format "~a" raw)) "internal sentinel leaked")
  (check-regexp-match #rx"k\\^\\.\\." (format "~a" raw)))

(test-case "P3b verify: head-position `{0^first}` takes the ONE Q_T4a message"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{0^first}\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"ordinal has no key" (format "~a" raw)))

(test-case "P3b verify: digit-leading rename targets refuse (dot-unreachable field)"
  (define raw1 (run-ws-raw-last (string-append P3A-CFG "cfg{server.host^0}\n")))
  (check-true (prologos-error? raw1))
  (check-regexp-match #rx"digit" (format "~a" raw1))
  (define raw2 (run-ws-raw-last (string-append P3A-CFG "cfg{server.host^-0}\n")))
  (check-true (prologos-error? raw2))
  (check-regexp-match #rx"digit" (format "~a" raw2)))

(test-case "P3b verify: the `server^{x}` misspelling names the SEGMENT, not 'field'"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{server^srv{host}}\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"server" (format "~a" raw)))

(test-case "P3b verify (P3c-closed): the Q_T4a advice EXECUTES — admins^first.0 works"
  ;; At P3b this spelling hit the P3c ordinal-step pointer; P3c lifted it.
  ;; The Q_T4a advice loop is now fully closed: rename the nominal segment,
  ;; then descend the ordinal — end to end.
  ;; self-contained fixture (P3C-DATA is defined later in the file)
  (define rs (run-ws-raw (string-append
                          "def adm2 := @[{:name \"Alice\" :role :super} {:name \"Bob\" :role :regular}]\n"
                          "def mq := {:admins adm2}\n"
                          "mq{admins^first.0}\n")))
  (check-false (ormap prologos-error? rs))
  (check-regexp-match #rx"\\{:first \\{:name String :role Keyword\\}\\}" (format "~a" (last rs)))
  ;; and over a NON-indexable value the error is the honest cross-domain one:
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{server^first.0}\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"ordinal" (format "~a" raw)))

;; ============================================================
;; CIU T6 D4.P3c — keyless + L4 + honest nesting  (Q_U2, ruling 2a, L4/B5)
;;
;; Failing-test-first: every pin below was written RED — at pin time each
;; spelling produced one of the three P3c pointers landed by P3a/P3b (the
;; keyless-leaf refusal, the ordinal-STEP refusal, the ordinal-BRANCH
;; refusal), the documented fails-for-the-right-reason state. The battery
;; pins: `^`-terminated keyless branches (tuple components in written order,
;; ordinally re-keyed — the nat-row mint at EVERY n incl. 1-tuples, which is
;; WHY selection routes around the collapsing `@[…]` literal arm, ruling
;; 2a); ordinal branches `{N M}` (fresh indices, selection order); ordinal
;; STEPS per Q_U2 Reading A (descend, NO output level — `.0` ≠ `.{0}`); the
;; L4 sort-homogeneity error at the OUTPUT level; and the G11 one-space pair
;; AS AMENDED by P3b's digit-target refusal (both halves now refuse loudly —
;; the one-space flip crosses a loud wall instead of two silent meanings).
;; ============================================================

(define P3C-DATA
  (string-append
   "def admins := @[{:name \"Alice\" :role :super} {:name \"Bob\" :role :regular}]\n"
   "def het3 := @[7 \"seven\" :seven]\n"))

(test-case "P3c fixture-sanity guard: PVec + het tuple mint as expected (GREEN before P3c)"
  (define rs (run-ws-raw (string-append P3C-DATA "admins.0.name\nhet3[1]\n")))
  (check-false (ormap prologos-error? rs) "the P3c fixture itself is broken")
  (check-regexp-match #rx"\"seven\"" (format "~a" (last rs))))

;; ---- keyless: `^`-terminated branches assemble tuples ----

(test-case "P3c ⭐ the keyless 2-tuple: cfg{server.host^ database.url^} → ⟨String String⟩"
  (define r (run-ws-last (string-append P3A-CFG "cfg{server.host^ database.url^}\n")))
  (check-regexp-match #rx"\"localhost\"" r)
  (check-regexp-match #rx"\"db-url\"" r)
  (check-regexp-match #rx"⟨String String⟩" r)
  (check-false (regexp-match #rx":host|:server" r) "keyless drops ALL keys"))

(test-case "P3c ⭐ the HONEST 1-TUPLE (ruling 2a): cfg{version^} → ⟨String⟩"
  ;; the entire reason selection mints rows directly: the @[…] literal arm
  ;; collapses to PVec at EVERY homogeneous n, so this value is unreachable
  ;; via literals.
  (define r (run-ws-last (string-append P3A-CFG "cfg{version^}\n")))
  (check-regexp-match #rx"\"1.0.0\"" r)
  (check-regexp-match #rx"⟨String⟩" r)
  (check-false (regexp-match #rx"PVec" r) "must be the 1-tuple, not a collapsed PVec"))

(test-case "P3c: keyless nested under kept ancestry: cfg{server.{host^ port^}}"
  (define r (run-ws-last (string-append P3A-CFG "cfg{server.{host^ port^}}\n")))
  (check-regexp-match #rx"\"localhost\"" r)
  (check-regexp-match #rx"8080" r)
  (check-regexp-match #rx"\\{:server ⟨String Int⟩\\}" r))

(test-case "P3c: a dissolved head SPLICES keyless components to its level"
  (define r (run-ws-last (string-append P3A-CFG "cfg{server^.{host^ port^}}\n")))
  (check-regexp-match #rx"⟨String Int⟩" r)
  (check-false (regexp-match #rx":server" r)))

(test-case "P3c: keyless leaf under a mid-path dissolve: cfg{server^.host^} → ⟨String⟩"
  (define r (run-ws-last (string-append P3A-CFG "cfg{server^.host^}\n")))
  (check-regexp-match #rx"\"localhost\"" r)
  (check-regexp-match #rx"⟨String⟩" r))

;; ---- ordinal branches: fresh indices, selection order ----

(test-case "P3c ⭐ ordinal branches re-derive indices in WRITTEN order: het3{2 0}"
  (define r (run-ws-last (string-append P3C-DATA "het3{2 0}\n")))
  (check-regexp-match #rx"⟨Keyword Int⟩" r "written order: element 2 then element 0")
  (check-regexp-match #rx":seven" r)
  (check-regexp-match #rx"7" r))

(test-case "P3c: ordinal 1-tuple over a PVec: admins{1}"
  (define r (run-ws-last (string-append P3C-DATA "admins{1}\n")))
  (check-regexp-match #rx"\"Bob\"" r)
  (check-regexp-match #rx"⟨\\{:name String :role Keyword\\}⟩" r))

(test-case "P3c: ordinal branches over a KEYWORD row refuse loudly (cross-domain)"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{0 1}\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"ordinal" (format "~a" raw)))

;; ---- Q_U2 Reading A: ordinal STEPS descend with NO output level ----

(test-case "P3c ⭐⭐ the Q_U2 DISCRIMINATING PAIR: admins.0 (descent) ≠ admins.{0} (1-tuple)"
  (define rs (run-ws-raw (string-append
                          P3C-DATA
                          "def m5 := {:admins admins}\n"
                          "m5{admins.0}\n"
                          "m5{admins.{0}}\n")))
  (check-false (ormap prologos-error? rs))
  (define step-r (format "~a" (list-ref rs (- (length rs) 2))))
  (define block-r (format "~a" (last rs)))
  ;; the STEP descends — element 0's row lands BARE under :admins
  (check-regexp-match #rx"\\{:admins \\{:name String :role Keyword\\}\\}" step-r)
  ;; the BLOCK re-derives — a 1-tuple under :admins
  (check-regexp-match #rx"\\{:admins ⟨\\{:name String :role Keyword\\}⟩\\}" block-r))

(test-case "P3c Q_U2: nominal ancestry survives BELOW an ordinal step: {admins.0.name}"
  (define rs (run-ws-raw (string-append
                          P3C-DATA
                          "def m6 := {:admins admins}\n"
                          "m6{admins.0.name}\n")))
  (check-false (ormap prologos-error? rs))
  (define r (format "~a" (last rs)))
  (check-regexp-match #rx"\"Alice\"" r)
  (check-regexp-match #rx"\\{:admins \\{:name String\\}\\}" r))

(test-case "P3c Q_U2: an ordinal step then a sub-block: {admins.0.{name}}"
  (define rs (run-ws-raw (string-append
                          P3C-DATA
                          "def m7 := {:admins admins}\n"
                          "m7{admins.0.{name}}\n")))
  (check-false (ormap prologos-error? rs))
  (check-regexp-match #rx"\\{:admins \\{:name String\\}\\}" (format "~a" (last rs))))

(test-case "P3c: het-tuple ordinal steps type EXACTLY per position"
  (define rs (run-ws-raw (string-append
                          P3C-DATA
                          "def m8 := {:t het3}\n"
                          "m8{t.1}\n")))
  (check-false (ormap prologos-error? rs))
  (check-regexp-match #rx"\\{:t String\\}" (format "~a" (last rs))))

(test-case "P3c: het-tuple ordinal step OOB is a LOUD typing error naming the position"
  (define rs (run-ws-raw (string-append
                          P3C-DATA
                          "def m9 := {:t het3}\n"
                          "m9{t.9}\n")))
  (check-true (prologos-error? (last rs)))
  (check-regexp-match #rx"9" (format "~a" (last rs))))

;; ---- L4: sort homogeneity, checked at the OUTPUT level ----

(test-case "P3c ⭐ L4: mixed keyed/keyless sorts error level-locally"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{version^ server.port}\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"mix" (format "~a" raw)))

(test-case "P3c L4: a SPLICED keyless component mixes at the OUTPUT level (the Q_T3 frame)"
  ;; version is keyed; the dissolved branch splices a keyless component into
  ;; the same level — the syntactic-branch reading would miss this.
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{version server^.{host^}}\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"mix" (format "~a" raw)))

(test-case "P3c L4: keyless sub-level under a keyed level is LEGAL (level-local, not global)"
  (define rs (run-ws-raw (string-append P3A-CFG "cfg{version server.{host^}}\n")))
  (check-false (ormap prologos-error? rs)
               "the sub-block is its OWN level — keyed outer + keyless inner must pass"))

;; ---- the G11 one-space pair, AS AMENDED (both halves loud) ----

(test-case "P3c ⭐ G11 as amended: {a^0} and {a^ 0} are DIFFERENT loud errors"
  ;; original G11: `{a^0}` keyed-rename-to-:0 vs `{a^ 0}` keyless 2-tuple.
  ;; P3b's verify refused digit-leading rename targets (`:0` would be
  ;; dot-unreachable), so the pair's one-space flip now crosses a LOUD wall:
  ;; `{a^0}` = the digit-target refusal; `{a^ 0}` = keyless leaf + ordinal
  ;; branch over a KEYWORD row — a cross-domain refusal.
  (define raw1 (run-ws-raw-last (string-append P3A-CFG "cfg{name^0}\n")))
  (check-true (prologos-error? raw1))
  (check-regexp-match #rx"digit" (format "~a" raw1))
  (define raw2 (run-ws-raw-last (string-append P3A-CFG "cfg{name^ 0}\n")))
  (check-true (prologos-error? raw2))
  (check-false (regexp-match #rx"digit" (format "~a" raw2)) "the spaced half is a DIFFERENT error")
  (check-regexp-match #rx"ordinal" (format "~a" raw2)))

;; ---- composition: selection results are ordinary tuples ----

(test-case "P3c: a keyless selection result is def-storable and re-indexable"
  (define rs (run-ws-raw (string-append
                          P3C-DATA
                          "def pair := admins{0 1}\n"
                          "pair.0.name\n")))
  (check-false (ormap prologos-error? rs))
  (check-regexp-match #rx"\"Alice\"" (format "~a" (last rs))))

(test-case "P3c twins: a keyless select on a def RHS under QTT"
  (define rs (run-ws-raw (string-append
                          P3A-CFG
                          "def kv := cfg{version^}\n"
                          "kv.0\n")))
  (check-false (ormap prologos-error? rs))
  (check-regexp-match #rx"\"1.0.0\"" (format "~a" (last rs))))

;; ============================================================
;; D4.P3c — ADVERSARIAL VERIFY pins (no BLOCKING — first slice in eight;
;; 2 SIGNIFICANT + 3 MINOR, all fixed pre-commit)
;;
;; Rank 1 (SIGNIFICANT, twin-drift): ordinal-headed branches with
;; keyless/collapse LEAVES pre-classify into walk-to-leaf, whose dispatch
;; missed the (@ord N) pair — the label leaked into select-project-field
;; and produced LYING subject diagnostics ("not a record" on a PVec that
;; works for the keyed twin; a BLANK generic on records via the hint's
;; swallow-all). Fixed with the @ord arm in BOTH walks atomically (fixing
;; typing alone would have converted the lie into a runtime champ-of panic
;; — the Exhaustive-Walkers twin-drift class). Rank 2: {N.M} fused
;; decimals leaked ($decimal-literal q) at a stale message. Rank 3: `.-1`
;; was invisible + the PVec wording predated live ordinals. Rank 4:
;; in-block v[0] aliasing pinned as the Q_R1 identity; {[0]} guided.
;; Rank 5: the two stale P3a-era pin titles flipped above.
;; ============================================================

(test-case "P3c verify ⭐ rank 1: ordinal head + keyless leaf works (was a lying non-record error)"
  (define rs (run-ws-raw (string-append P3C-DATA "admins{0.name^}\n")))
  (check-false (ormap prologos-error? rs))
  (define r (format "~a" (last rs)))
  (check-regexp-match #rx"\"Alice\"" r)
  (check-regexp-match #rx"⟨String⟩" r "one keyless branch — the honest 1-tuple"))

(test-case "P3c verify rank 1: ordinal head + collapse leaf re-keys (coherent with the component walk)"
  (define rs (run-ws-raw (string-append P3C-DATA "admins{0.name^-}\n")))
  (check-false (ormap prologos-error? rs))
  (check-regexp-match #rx"\\{:name String\\}" (format "~a" (last rs))))

(test-case "P3c verify rank 1: ordinal head over a RECORD subject refuses honestly (was a BLANK generic)"
  (define raw (run-ws-raw-last (string-append P3A-CFG "cfg{0.name^}\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"tuple or vector subject" (format "~a" raw)))

(test-case "P3c verify rank 2: {N.M} decimal fusion gets the guided collision message"
  (define raw (run-ws-raw-last (string-append P3C-DATA "admins{1.2}\n")))
  (check-true (prologos-error? raw))
  (define r (format "~a" raw))
  (check-regexp-match #rx"decimal literal" r)
  (check-false (regexp-match #rx"decimal-literal" r) "the sentinel must not leak")
  ;; and the recommended spaced spelling EXECUTES:
  (define rs (run-ws-raw (string-append
                          "def nv := @[@[1 2] @[3 4]]\n"
                          "nv{0 .1}\n")))
  (check-false (ormap prologos-error? rs)))

(test-case "P3c verify rank 3: `.-1` surfaces in the vector-subject message"
  (define rs (run-ws-raw (string-append
                          P3C-DATA
                          "def mv := {:admins admins}\n"
                          "mv{admins.-1}\n")))
  (check-true (prologos-error? (last rs)))
  (define r (format "~a" (last rs)))
  (check-regexp-match #rx"-1" r)
  (check-regexp-match #rx"ordinal" r))

(test-case "P3c verify rank 4: in-block `v[0]` aliases `.0` (the Q_R1 identity holds in blocks)"
  (define rs (run-ws-raw (string-append
                          P3C-DATA
                          "def mw := {:admins admins}\n"
                          "mw{admins[0]}\n"
                          "mw{admins.0}\n")))
  (check-false (ormap prologos-error? rs))
  (check-equal? (format "~a" (list-ref rs (- (length rs) 2)))
                (format "~a" (last rs))
                "two surfaces, ONE mechanism — byte-identical results"))

(test-case "P3c verify rank 4: head-position `{[0]}` is guided to the bare spelling"
  (define raw (run-ws-raw-last (string-append P3C-DATA "admins{[0]}\n")))
  (check-true (prologos-error? raw))
  (check-regexp-match #rx"written bare" (format "~a" raw)))

;; ============================================================
;; D4.P4a — STEP-KIND TOTALITY (the Exhaustive Walkers rule, applied
;; BEFORE the sixth step kind lands rather than after a silent miss)
;; ============================================================
;;
;; The step vocabulary is a CLOSED union (syntax.rkt § "the ONE shared branch
;; walk"):  symbol | number | (@key name cont) | (@sub . branches) | (@ord N).
;; Q_U7 adds a sixth kind at P4c — the `(@bcast step)` ω wrapper.
;;
;; Censused at `cab30b9a`, EIGHT cond arms dispatch on step kind and SILENTLY
;; absorb an unknown one (the design said four — the 8th enumeration
;; under-count of this arc, landing on the phase built to end that class):
;;
;;   1 syntax.rkt:849       select-step-output-name   -> #f   (no name)
;;   2 syntax.rkt:907       select-branch-top-keys    -> '()  (no component)
;;   3 typing-core.rkt:776  walk-to-leaf              -> treated as a nominal key
;;   4 typing-core.rkt:824  select-branch-entries     -> treated as a nominal key
;;   5 typing-core.rkt:882  select-below-field        -> treated as a nominal key
;;   6 reduction.rkt:1675   walk-to-leaf              -> project (champ-of v name)
;;   7 reduction.rkt:1703   branch-entries            -> treated as a nominal key
;;   8 reduction.rkt:1752   below-value               -> treated as a nominal key
;;
;; A sixth kind reaching ANY of them is a silent wrong answer, not an error.
;; Owner ruling 2026-07-31: route ALL EIGHT through one named classifier
;; (`select-step-kind`) whose else RAISES, and give each consumer a `case`
;; over the closed kind set whose own else re-raises.
;;
;; WHY THESE ARE DIRECT-CALL UNIT PINS: there is no sixth step kind yet, so
;; the untotal case is UNCONSTRUCTIBLE from surface syntax. A pin written
;; through `process-string` cannot reach these arms. (And a pin that merely
;; called a not-yet-existing `select-step-kind` would fail with "unbound
;; identifier" — NOT the reason it claims, this arc's hazard 4, which has
;; already produced one vacuous pin and two mis-premised fixtures.) Each pin
;; below hands a walk a synthetic unknown step and asserts it RAISES; today
;; every one of them returns a VALUE instead, so the RED is
;; "expected exception, got value" — which IS the claimed reason.

(define BOGUS-STEP '(@bogus-step-kind zzz))

;; The pins assert the TOTALITY failure specifically, not merely "something
;; raised". `check-exn exn:fail?` is far too broad: the adversarial verify
;; showed it passes on an ARITY error or a malformed fixture, so a future
;; change to `make-record`/`champ-insert` could turn all eight green while the
;; totality arms were entirely reverted. The fixtures are also hoisted OUT of
;; the guarded lambda for the same reason — a fixture that throws must fail
;; the test, not satisfy it.
(define (totality-exn? e)
  (and (exn:fail? e)
       (regexp-match? #rx"unknown select step kind|no arm for select step kind"
                      (exn-message e))))

;; ---- sites 1 + 2: the shared syntax.rkt walks (directly exported) ----

(test-case "P4a totality site 1: select-step-output-name RAISES on an unknown step kind"
  (check-exn totality-exn?
             (lambda () (select-step-output-name BOGUS-STEP))
             "an unknown step kind must not silently contribute NO output name"))

(test-case "P4a totality site 2: select-branch-top-keys RAISES on an unknown step kind"
  (check-exn totality-exn?
             (lambda () (select-branch-top-keys (list BOGUS-STEP)))
             "an unknown step kind must not silently contribute NO component"))

;; ---- sites 3-5: the typing walk, via the exported `select-project` ----
;; ctx is unused by select-row-of / select-project-field, so '() is faithful.

(define (bogus-typing-subject)
  ;; a closed keyword row offering :a — so the walk gets PAST the subject
  ;; check and reaches the step dispatch proper
  (make-record 'keyword
               (list (cons 'a (record-field (expr-Int) 'present)))
               'closed))

;; hoisted: built ONCE, outside every guarded lambda
(define BOGUS-TYPING-SUBJ (bogus-typing-subject))

(test-case "P4a totality site 4: select-project's branch walk RAISES on an unknown step kind"
  ;; the branch head is the bogus step -> select-branch-entries' guard
  (check-exn totality-exn?
             (lambda () (tc:select-project '() BOGUS-TYPING-SUBJ (list (list BOGUS-STEP)) 'block))
             "an unknown step kind must not be silently projected as a nominal key"))

(test-case "P4a totality site 5: select-below-field RAISES on an unknown step kind below a kept head"
  ;; `a` descends, then the bogus step is BELOW it -> select-below-field's guard
  (check-exn totality-exn?
             (lambda () (tc:select-project '() BOGUS-TYPING-SUBJ (list (list 'a BOGUS-STEP)) 'block))
             "an unknown step kind below a kept head must not be silently projected"))

(test-case "P4a totality site 3: walk-to-leaf RAISES on an unknown step kind (collapse branch)"
  ;; a `^-` collapse leaf pre-classifies into walk-to-leaf -> its guard
  (check-exn totality-exn?
             (lambda () (tc:select-project '() BOGUS-TYPING-SUBJ
                                           (list (list BOGUS-STEP '(@key a collapse))) 'block))
             "walk-to-leaf must not silently treat an unknown step kind as a nominal key"))

;; ---- sites 6-8: the reduction walk, via the newly-exported `select-reduce` ----

(define (bogus-runtime-subject)
  (let ([kw (expr-keyword 'a)])
    (expr-champ (champ-insert champ-empty (equal-hash-code kw) kw (expr-int 1)))))

;; hoisted, as above
(define BOGUS-RUNTIME-SUBJ (bogus-runtime-subject))

(test-case "P4a totality site 7: select-reduce's branch-entries RAISES on an unknown step kind"
  (check-exn totality-exn?
             (lambda () (nf (select-reduce BOGUS-RUNTIME-SUBJ (list (list BOGUS-STEP)) 'block #f)))
             "an unknown step kind must not be silently projected at runtime"))

(test-case "P4a totality site 8: select-reduce's below-value RAISES on an unknown step kind"
  (check-exn totality-exn?
             (lambda () (nf (select-reduce BOGUS-RUNTIME-SUBJ (list (list 'a BOGUS-STEP)) 'block #f)))
             "an unknown step kind below a kept head must not be silently projected at runtime"))

(test-case "P4a totality site 6: select-reduce's walk-to-leaf RAISES on an unknown step kind"
  (check-exn totality-exn?
             (lambda () (nf (select-reduce BOGUS-RUNTIME-SUBJ
                                           (list (list BOGUS-STEP '(@key a collapse)))
                                           'block #f)))
             "walk-to-leaf must not silently treat an unknown step kind as a nominal key"))

;; ============================================================
;; D4.P4a — THE WHOLE-NODE ABORT (owner ratification 2026-07-31)
;; ============================================================
;;
;; RULED: a runtime miss anywhere inside a selection aborts the WHOLE
;; selection — no partial results, no `expr-panic` buried in an output slot.
;; Mechanism: `select-reduce` opens ONE `let/ec` (reduction.rkt:1600) and the
;; miss paths `return` through it.
;;
;; WHY THIS IS PINNED NOW, BEFORE BROADCAST EXISTS: §5.P4's original LOWERING
;; clause said reduction would lower per-step onto `pvec-map`/`map-map-vals`.
;; Four agents converged that this is contradicted by shipped code — a
;; per-element lowering would evaluate each element independently and BURY the
;; panic value in an output slot, which is the P2.b fabrication class. The
;; ruling is WALK-under-one-`let/ec`; this fixture is what makes it a fact
;; rather than a claim, so P4c's per-element broadcast cannot drift it back
;; under a "map semantics" intuition.
;;
;; The discriminator is deliberate: TWO branches, the FIRST of which succeeds.
;; Under WALK the whole node is the panic. Under a per-element LOWERING the
;; result would be a 2-field record whose `:a` slot holds 1 and whose `:nope`
;; slot holds the panic — i.e. a fabricated partial answer at zero errors.

(test-case "P4a whole-node abort: a runtime miss aborts the NODE, not one slot"
  (define result
    (nf (select-reduce (bogus-runtime-subject)
                       (list (list 'a)        ;; succeeds — :a is present
                             (list 'nope))    ;; misses at runtime
                       'block #f))) ;; misses at runtime
  (check-true (expr-panic? result)
              "the WHOLE selection must be the panic (single let/ec), not a record with a panic inside")
  (check-false (expr-champ? result)
               "a record result here would be a fabricated partial answer — the P2.b class"))

(test-case "P4a whole-node abort: the panic names the missing field, not the surviving one"
  ;; ⚠ The adversarial verify showed the message assertions ALONE do not
  ;; discriminate: expr-champ is #:transparent, so a record with the panic
  ;; buried in its :nope slot ALSO prints both "nope" and "invariant
  ;; violation". The discriminating half is `expr-panic?` on the WHOLE
  ;; result — kept here so this fixture is not a message pin sold as a
  ;; discriminator.
  (define result
    (nf (select-reduce (bogus-runtime-subject)
                       (list (list 'a) (list 'nope)) 'block #f)))
  (check-true (expr-panic? result)
              "the discriminating assertion — a buried panic would be an expr-champ")
  (check-regexp-match #rx"nope" (format "~a" result))
  (check-regexp-match #rx"invariant violation" (format "~a" result)))

(test-case "P4a whole-node abort: a non-map mid-descent aborts the NODE too"
  ;; :a holds an Int, so descending `a.b` hits champ-of's non-map path
  (define result
    (nf (select-reduce (bogus-runtime-subject) (list (list 'a 'b)) 'block #f)))
  (check-true (expr-panic? result))
  (check-regexp-match #rx"not a map at runtime" (format "~a" result)))

;; ---- P4a self-review regression: the "below a kept head" TWINS ----
;;
;; The four `memq`-guard sites must list EXACTLY the kinds their old `else`
;; caught, or the totality refactor is not behaviour-preserving. Sites 5
;; (typing-core `select-below-field`) and 8 (reduction `below-value`) sit
;; under arms taking TERMINAL `sub` and `ord-step`, so their else ALSO caught
;; `ord-branch` — and the first cut of both omitted it, turning a delegation
;; into a raise. Caught at the P4a gate by self-review, not by the suite:
;; the path is not reached from surface syntax today, which is exactly why it
;; needs a direct-call pin rather than trust.
;;
;; The assertion is deliberately NOT "returns value X" — it is "does not fail
;; the TOTALITY way". An `(@ord N)` below a kept head may still panic for an
;; honest reason (bad subject, OOB); what it must never do is report that the
;; walk has no arm for its kind.

(define (vector-under-key-subject)
  (let ([kw (expr-keyword 'a)])
    (expr-champ (champ-insert champ-empty (equal-hash-code kw) kw
                              (expr-rrb (rrb-from-list (list (expr-int 7) (expr-int 8))))))))

(test-case "P4a site 8 twin: an (@ord N) below a kept head still DELEGATES, never 'no arm'"
  (define result (nf (select-reduce (vector-under-key-subject)
                                    (list (list 'a '(@ord 0))) 'block #f)))
  (check-false (regexp-match? #rx"no arm for select step kind" (format "~a" result))
               "reduction's below-value must keep handling ord-branch — its old else did"))

(test-case "P4a site 5 twin: typing's select-below-field keeps handling ord-branch"
  (define tm (make-record 'keyword
                          (list (cons 'a (record-field (expr-PVec (expr-Int)) 'present)))
                          'closed))
  ;; must not raise the TOTALITY error; a select-fail is a legitimate outcome
  (check-not-exn
   (lambda ()
     (with-handlers ([exn:fail? (lambda (e)
                                  (when (regexp-match? #rx"no arm for select step kind"
                                                       (exn-message e))
                                    (raise e))
                                  (void))])
       (tc:select-project '() tm (list (list 'a '(@ord 0))) 'block)))
   "typing's select-below-field must keep handling ord-branch — its old else did"))

;; ============================================================
;; D4.P4a (post-verify) — the FIVE sites the first census missed
;; ============================================================
;;
;; The original census was SYNTAX-directed: grep the exported helper names,
;; then look for `cond` arms, in three files. That method structurally cannot
;; see (a) dispatchers that OPEN-CODE the shape tests, or (b) dispatchers
;; shaped as `and`/`if` rather than `cond`. Both classes existed. Five more
;; sites, in two more files — and the two LEAF classifiers run UPSTREAM of the
;; guarded walks, so a silent #f there DEFEATS the guards rather than sitting
;; beside them: the branch is mis-sorted (keyed vs keyless) with no raise
;; anywhere downstream, and that feeds the parser's L4 and duplicate checks.
;;
;; Owner ruling (2026-07-31): extend the routing; deliver the totality.

(test-case "P4a leaf classifier: select-branch-collapse RAISES on an unknown leaf kind"
  (check-exn totality-exn?
             (lambda () (select-branch-collapse (list 'a BOGUS-STEP)))
             "a silent #f here mis-sorts the branch BEFORE any guarded walk sees it"))

(test-case "P4a leaf classifier: select-branch-keyless? RAISES on an unknown leaf kind"
  (check-exn totality-exn?
             (lambda () (select-branch-keyless? (list 'a BOGUS-STEP)))
             "a silent #f here mis-sorts a keyless branch as KEYED"))

(test-case "P4a leaf classifiers keep their answers for all FIVE known kinds"
  ;; behaviour-preservation: only `caret` ever answered non-#f, and it still does
  (check-equal? (select-branch-collapse (list 'a '(@key b collapse))) 'collapse)
  (check-equal? (select-branch-collapse (list 'a '(@key b dissolve))) #f)
  (check-false  (select-branch-collapse (list 'a 'b)))
  (check-false  (select-branch-collapse (list 'a 0)))
  (check-false  (select-branch-collapse (list 'a '(@ord 0))))
  (check-false  (select-branch-collapse (list 'a '(@sub (x)))))
  (check-true   (select-branch-keyless? (list 'a '(@key b dissolve))))
  (check-false  (select-branch-keyless? (list 'a '(@key b collapse))))
  (check-false  (select-branch-keyless? (list 'a 'b)))
  (check-false  (select-branch-keyless? (list 'a 0)))
  (check-false  (select-branch-keyless? (list 'a '(@ord 0))))
  (check-false  (select-branch-keyless? (list 'a '(@sub (x))))))

(test-case "P4a render site: an unknown step kind gets a LOUD marker, never a raw s-expression"
  ;; pp-expr is on the error-message path, so this site renders rather than
  ;; raising (a raise would turn a diagnostic into an internal crash, and a
  ;; catch-all handler could swallow it). It must still never leak the raw
  ;; datum, which is what `[else (format "~a" s)]` used to do.
  (define rendered
    (pp-expr (expr-select (expr-fvar 'x) (expr-path (list (list 'a BOGUS-STEP)) 'block) #f) '()))
  ;; The marker NAMES the datum on purpose — that is the debugging value.
  ;; The property is that it is WRAPPED, not passed through as if it were
  ;; valid surface syntax, which is exactly what `[else (format "~a" s)]`
  ;; used to do (it rendered `x{a(@bogus-step-kind zzz)}`).
  (check-regexp-match #rx"unrendered-step-kind" rendered)
  (check-false (regexp-match? #rx"\\{a\\(@bogus-step-kind zzz\\)\\}" rendered)
               "the datum must be wrapped in the marker, not emitted as surface syntax")
  ;; and it must not RAISE — pp-expr is on the error-message path
  (check-true (string? rendered)))

;; ---- the consumer-side else: previously ZERO coverage ----
;;
;; The verify found that all eight totality pins raise from the CLASSIFIER,
;; never from `select-step-kind-unhandled`. That is true by construction today
;; (with five kinds, every consumer's arm list covers all five), so the
;; mechanism the design advertises — "a missed consumer RAISES naming itself"
;; — had no test at all. This pins its contract directly.

(test-case "P4a: select-step-kind-unhandled names the CONSUMER and the kind"
  (define msg
    (with-handlers ([exn:fail? exn-message])
      (select-step-kind-unhandled 'my-walk '(@key b collapse))
      "NO RAISE"))
  (check-regexp-match #rx"my-walk" msg "the consumer must name itself")
  (check-regexp-match #rx"caret" msg "the message must name the unhandled kind")
  (check-regexp-match #rx"no arm for select step kind" msg))

(test-case "P4a: select-step-kind classifies all five known kinds"
  (check-equal? (select-step-kind 'a) 'key)
  (check-equal? (select-step-kind 0) 'ord-step)
  (check-equal? (select-step-kind '(@key b collapse)) 'caret)
  (check-equal? (select-step-kind '(@sub (x))) 'sub)
  (check-equal? (select-step-kind '(@ord 0)) 'ord-branch)
  (check-exn totality-exn? (lambda () (select-step-kind BOGUS-STEP))))

;; ---- the whnf-trivial? container fast path (the verify's MINOR-4) ----

(test-case "P4a: whnf of a bare container VALUE carrier is identity"
  ;; the safety proof made executable rather than prose — whnf-impl/match has
  ;; no bare-head arm for these three, so they fell to `[_ e]`; the fast path
  ;; must return the SAME object.
  (define c (expr-champ champ-empty))
  (define v (expr-rrb (rrb-from-list (list (expr-int 1)))))
  (define h (expr-hset champ-empty))
  (check-eq? (whnf c) c)
  (check-eq? (whnf v) v)
  (check-eq? (whnf h) h))

;; ============================================================
;; D4.P4b-i — Q_U11: RETIRE the silently-broken `#p(…)` vocabulary
;; ============================================================
;;
;; Probed at `099ef690`, the First-Class Paths literal carries FOUR spellings
;; but only ONE of them works:
;;
;;   #p(a)  /  #p(a.a1)        → Path; `get-in m p` → the value      ✓ LIVE
;;   #p(a.*)   #p(a.**)        → Path; `get-in m p` → `<error>` value, 0 ERRORS
;;   #p(a.{b c})               → Path; `get-in m p` → `<error>` value, 0 ERRORS
;;
;; The broken half is a LIVE SILENT WRONG ANSWER — the P2.b fabrication class:
;; it produces a value where an error is owed, and the vacuous ground `Path`
;; type (typing-core.rkt:2050-2051 discards the branches with `_`) means no
;; shape constraint can bite. Their own acceptance file has them COMMENTED OUT
;; (examples/2026-03-20-first-class-paths.prologos:80,83,86), so there is no
;; live corpus use.
;;
;; ⚠ The P4b mini-audit did NOT catch this: its F3 confirmed "#p(a.b.c)
;; round-trips" and "get-in works", both TRUE — for the subset anyone probed.
;; The fuller vocabulary was never run end-to-end. (15th consecutive premise
;; refutation of this arc; this time the premise was the audit's own.)
;;
;; Owner ruling Q_U11 [2026-07-31]: RETIRE them with a guided error, rather
;; than carry a defect across the carrier unification (that would be the
;; blocking belt-and-suspenders shape) or fix them into new semantics inside a
;; slice that is meant to be behaviour-preserving. Monotone: a refusal can
;; become a meaning later, never the reverse.
;;
;; The refusal fires at ELABORATION — at the literal, not at its use — so the
;; error names the malformed thing at the site the user wrote it.

(test-case "P4b-i Q_U11: `#p(a.*)` REFUSES loudly (was an <error> value at 0 errors)"
  (define r (run-ws-raw-last "def m := {:a {:a1 1}}\ndef p := #p(a.*)\n"))
  (check-true (prologos-error? r)
              "a wildcard path literal must refuse, not define as a vacuous Path")
  (check-regexp-match #rx"\\*" (format "~a" r)))

(test-case "P4b-i Q_U11: `#p(a.**)` REFUSES loudly"
  (define r (run-ws-raw-last "def m := {:a {:a1 1}}\ndef p := #p(a.**)\n"))
  (check-true (prologos-error? r))
  (check-regexp-match #rx"\\*" (format "~a" r)))

(test-case "P4b-i Q_U11: multi-branch `#p(a.{a1 a2})` REFUSES loudly"
  (define r (run-ws-raw-last "def m := {:a {:a1 1 :a2 2}}\ndef p := #p(a.{a1 a2})\n"))
  (check-true (prologos-error? r)
              "a multi-branch path literal must refuse — every consumer truncates it with (car branches)"))

(test-case "P4b-i Q_U11: the guided error NAMES the surviving spelling"
  (define r (format "~a" (run-ws-raw-last "def p := #p(a.*)\n")))
  (check-regexp-match #rx"retired|no longer" r "the message must say the spelling is retired")
  (check-regexp-match #rx"select|flatten|\\{" r
                      "and must point at what replaced it in the current surface"))

(test-case "P4b-i Q_U11: the LIVE subset is untouched — a keyword chain still works"
  ;; the whole point of the retirement is that it costs the working surface nothing
  (define rs (run-ws-raw "def m := {:a {:a1 7}}\ndef p := #p(a.a1)\n[get-in m p]\n"))
  (check-false (ormap prologos-error? rs) "the single-branch keyword chain must keep working")
  (check-regexp-match #rx"7" (format "~a" (last rs))))

;; ============================================================
;; D4.P4b-i — FFI CHARACTERIZATION pins (must stay GREEN through the
;; encoding convergence; this is a behaviour-preserving refactor)
;; ============================================================
;;
;; `expr-path`'s branches hold `expr-keyword` STRUCTS; `expr-select`'s hold
;; bare symbols + `@key`/`@sub`/`@ord` s-expressions. b-i converges them onto
;; the STEP encoding so `#p(…)` and `x{…}` are one representation. These pins
;; are written BEFORE the change and must not move: for a refactor that claims
;; to preserve behaviour, the pins are the claim.
;;
;; The live FFI surface is `lib/prologos/core/path.prologos` — 6 foreign
;; primitives over `path-ops.rkt`. Characterized at `f072c115`:
;;   depth · branch-count · head · tail · leaf?   → WORK
;;   segments                                      → WHOLE-FILE ABORT
;; `path-segments` builds a Prologos cons-chain (`expr-app` of `cons`) but the
;; foreign marshaller wants a RACKET list, so the declared type
;; `Path -> [List Keyword]` never marshalled. That takes `from-segments` and
;; `path-append` (built on `segments`) with it. PRE-EXISTING and filed — NOT
;; caused by the encoding change, and deliberately not pinned here because a
;; whole-file abort would take the test file with it.
;;
;; `head` and `tail` are the load-bearing ones: they return segments AS
;; PROLOGOS VALUES, which works today only because segments are `expr-keyword`
;; structs. Under the step encoding the shims become the marshalling
;; boundary — which is where marshalling belongs.

(define FFI-PATH-PRELUDE
  (string-append "require [prologos::core::path :as p]\n"
                 "def q := #p(a.b.c)\n"))

(test-case "P4b-i FFI: `head` returns a Prologos KEYWORD value"
  (define r (format "~a" (run-ws-raw-last (string-append FFI-PATH-PRELUDE "[p::head q]\n"))))
  (check-regexp-match #rx":a" r)
  (check-regexp-match #rx"Keyword" r "the declared foreign type must still marshal"))

(test-case "P4b-i FFI: `tail` returns a Path, printed in surface spelling"
  (define r (format "~a" (run-ws-raw-last (string-append FFI-PATH-PRELUDE "[p::tail q]\n"))))
  (check-regexp-match #rx"#p\\(b\\.c\\)" r "tail must drop the head and round-trip its printed form")
  (check-regexp-match #rx"Path" r))

(test-case "P4b-i FFI: `depth` counts segments of the first branch"
  (define r (format "~a" (run-ws-raw-last (string-append FFI-PATH-PRELUDE "[p::depth q]\n"))))
  (check-regexp-match #rx"3" r))

(test-case "P4b-i FFI: `branch-count` is 1 for the surviving single-branch vocabulary"
  (define r (format "~a" (run-ws-raw-last (string-append FFI-PATH-PRELUDE "[p::branch-count q]\n"))))
  (check-regexp-match #rx"1" r))

(test-case "P4b-i FFI: `leaf?` composes over depth (a pure Prologos combinator)"
  (define rs (run-ws-raw (string-append FFI-PATH-PRELUDE
                                        "[p::leaf? q]\n"
                                        "[p::leaf? #p(a)]\n")))
  (check-false (ormap prologos-error? rs))
  (check-regexp-match #rx"false" (format "~a" (list-ref rs (- (length rs) 2))))
  (check-regexp-match #rx"true"  (format "~a" (last rs))))

(test-case "P4b-i: get-in / update-in still consume the path encoding"
  ;; both reduction arms pass segments DIRECTLY as expr-map-get keys, so they
  ;; are the consumers the encoding change must re-point
  (define rs (run-ws-raw (string-append
                          "def m := {:a {:b 5}}\n"
                          "def pp := #p(a.b)\n"
                          "[get-in m pp]\n"
                          "[update-in m pp [fn [x : Int] [int+ x 1]]]\n")))
  (check-false (ormap prologos-error? rs) "get-in/update-in over a path literal must keep working")
  (check-regexp-match #rx"5" (format "~a" (list-ref rs (- (length rs) 2))))
  (check-regexp-match #rx"6" (format "~a" (last rs))))

(test-case "P4b-i: whnf of a bare selector carrier is identity (the P4a argument, applied)"
  ;; the SELECTOR is a literal — no head reduction rule, so the fast path must
  ;; return the SAME object. `expr-select` (the APPLICATION) stays reducible.
  (define sel (expr-path '((a b)) 'block))
  (check-eq? (whnf sel) sel))

;; ============================================================
;; D4.P4b-i slice 3 — SLOT NESTING: `expr-select` holds the selector CARRIER
;; ============================================================
;;
;; Q_U5: `#p(…)`, `x{…}` and path position are three spellings of ONE
;; representation. Slice 2 converged the ENCODING (both hold step symbols);
;; this slice makes the STRUCT one too — `expr-select`'s `branches` slot holds
;; an `expr-path` (the reified selector) rather than a raw list. After this
;; there is exactly one way to hold a selector.
;;
;; ⚠ The audit's C3 finding (`uses-bvar0?`, pretty-print.rkt, recursing into
;; the SUBJECT ONLY under a comment asserting "subject is the only expr slot")
;; becomes technically live here — the slot now holds an expr. It is INERT at
;; P4 by the monomorphic ruling: a selector holds bare symbols, never exprs,
;; and all six `expr-path` walker arms are `[(expr-path _) e]` — pure
;; identity. It goes genuinely live when BOUND selectors land (F-row). The
;; walker is corrected anyway, because "inert today" is how the silent-walker
;; class starts.

(test-case "P4b-i slice 3: expr-select's branches slot holds the SELECTOR CARRIER"
  (define sel (expr-path '((a)) 'block))
  (define node (expr-select (expr-fvar 'x) sel #f))
  (check-true (expr-path? (expr-select-branches node))
              "one representation: the slot holds an expr-path, not a raw list"))

(test-case "P4b-i slice 3: select-map-exprs maps into BOTH slots and preserves the carrier"
  (define node (expr-select (expr-fvar 'x) (expr-path '((a)) 'block) #f))
  (define mapped (select-map-exprs (lambda (e) e) node))
  (check-true (expr-select? mapped))
  (check-true (expr-path? (expr-select-branches mapped))
              "the mapper must not flatten the carrier back to a list"))

(test-case "P4b-i slice 3: uses-bvar0? recurses into the selector slot"
  ;; inert at P4 (selectors hold symbols) but correct by construction — the
  ;; subject-only recursion is the pipeline.md Exhaustive-Walkers signature
  (check-false (uses-bvar0? (expr-select (expr-fvar 'x) (expr-path '((a)) 'block) #f))
               "no bvar anywhere → #f")
  (check-true (uses-bvar0? (expr-select (expr-bvar 0) (expr-path '((a)) 'block) #f))
              "a bvar in the SUBJECT is still found"))

(test-case "P4b-i slice 3: the surface is unchanged end-to-end"
  (define rs (run-ws-raw (string-append
                          "def cfg := {:server {:host \"h\" :port 80}}\n"
                          "cfg{server.host}\n"
                          "cfg.server.port\n")))
  (check-false (ormap prologos-error? rs) "nesting the carrier must not move the surface")
  (check-regexp-match #rx"h" (format "~a" (list-ref rs (- (length rs) 2))))
  (check-regexp-match #rx"80" (format "~a" (last rs))))

;; ============================================================
;; D4.P4b-ii-1 — the (subject kind × sort) SEMANTIC TABLE
;; ============================================================
;; Q_U10 ruled the `'path` sort gains a MAP POSTURE; Q_U12 scoped b-ii to the
;; `$dot-access` leg. The table is TWO-DIMENSIONAL and there are THREE
;; asymmetries (dyn row · Map · selection-typed), so the posture is pinned
;; CELL BY CELL here, typing-side only, BEFORE the fold migrates (b-ii-2).
;;
;; These are DIRECT-CALL pins by necessity. `select-project` is reached from
;; exactly ONE place — the `expr-select` typing arm (typing-core.rkt) — and
;; `expr-select` is minted at exactly ONE elaborator site (`surf-select`,
;; i.e. `x{…}`). `#p(…)` never reaches the walk (its typing arm is the
;; vacuous `[(expr-path _) (expr-Path)]`). So with no fold change EVERY
;; carrier reaching the walk is `'block`, and the `'path` column is
;; unreachable from surface syntax until b-ii-2 flips the fold.
;;
;; The `'block` column below is CHARACTERIZATION: it must be green before the
;; sort field lands and stay green after — those pins ARE the claim that
;; threading the sort changed nothing.

;; ---- subject fixtures, hoisted OUT of every guarded lambda ----
(define TBL-RECORD-CLOSED       ;; {:a Int} — the happy path
  (make-record 'keyword (list (cons 'a (record-field (expr-Int) 'present))) 'closed))

(define TBL-RECORD-DYN-UNKNOWN  ;; {:a? Int | _} — presence not sourced
  (make-record 'keyword (list (cons 'a (record-field (expr-Int) 'unknown))) 'dyn))

(define TBL-RECORD-DYN-EMPTY    ;; {| _} — `a` unlisted on a dyn row
  (make-record 'keyword '() 'dyn))

(define TBL-MAP (expr-Map (expr-Keyword) (expr-Int)))          ;; (Map Keyword Int)
(define TBL-TUPLE                                              ;; ⟨Int⟩ — nat key-domain
  (make-record 'nat (list (cons 0 (record-field (expr-Int) 'present))) 'closed))
(define TBL-NON-RECORD (expr-Int))                             ;; not a record at all

(define BRANCHES-A (list (list 'a)))   ;; the single branch `a`

;; helper: run the walk and report (kind-or-'row)
(define (tbl-outcome tm [branches BRANCHES-A] [sort 'block])
  (let-values ([(row fail) (tc:select-project '() tm branches sort)])
    (cond [fail (tc:select-fail-kind fail)]
          [row 'row]
          [else 'neither])))

(test-case "P4b-ii-1 table (block × record/closed/present): projects to a row"
  (check-equal? (tbl-outcome TBL-RECORD-CLOSED) 'row))

(test-case "P4b-ii-1 table (block × Map): refuses 'subject-map — ASYMMETRY 2, the block half"
  ;; `.field` on this same subject WORKS (probe: `m.a` -> 1 : Int, via
  ;; expr-map-get). That divergence IS Q_U10's Map posture; this pin holds
  ;; the BLOCK half fixed so b-ii-2 cannot move it by accident.
  (check-equal? (tbl-outcome TBL-MAP) 'subject-map))

(test-case "P4b-ii-1 table (block × nat-row): refuses 'subject-tuple"
  (check-equal? (tbl-outcome TBL-TUPLE) 'subject-tuple))

(test-case "P4b-ii-1 table (block × non-record): refuses 'subject-other"
  (check-equal? (tbl-outcome TBL-NON-RECORD) 'subject-other))

(test-case "P4b-ii-1 table (block × dyn row, presence 'unknown): refuses 'unknown-presence"
  ;; ASYMMETRY 1 (Q_T2), the block half: `.field` on a dyn row is
  ;; D19-PERMISSIVE (probe: `d1.host` -> "h" : ?meta), the block is loud.
  (check-equal? (tbl-outcome TBL-RECORD-DYN-UNKNOWN) 'unknown-presence))

(test-case "P4b-ii-1 table (block × dyn row, field unlisted): refuses 'miss-dyn"
  (check-equal? (tbl-outcome TBL-RECORD-DYN-EMPTY) 'miss-dyn))

(test-case "P4b-ii-1 table (block × closed row, field missing): refuses 'miss-closed"
  (check-equal? (tbl-outcome TBL-RECORD-CLOSED (list (list 'zzz))) 'miss-closed))

(test-case "P4b-ii-1 table: the Map refusal applies at EVERY DESCENT LEVEL, not just the leaf"
  ;; `outer.inner.a` through an intermediate Map is a pinned SURFACE (it works
  ;; via map-get). Under the block sort the intermediate Map must refuse the
  ;; same way the leaf does — the level-invariance the Map posture has to
  ;; preserve when b-ii-2 gives it the path sort.
  (define outer
    (make-record 'keyword
                 (list (cons 'inner (record-field TBL-MAP 'present)))
                 'closed))
  (check-equal? (tbl-outcome outer (list (list 'inner 'a))) 'subject-map))

;; ---- the PATH column: the MAP POSTURE (Q_U10) ----
;; Pinned at `select-row-of` — the subject-kind × sort DISPATCH — not through
;; `select-project`. The table IS that dispatch; `select-project`'s assembly
;; is block-shaped (it builds a row from components) and what the `'path`
;; sort ASSEMBLES is b-ii-2's question, because `'path` EXTRACTS where
;; `'block` projects. Pinning the admit-cell through the assembly would
;; therefore pin a shape this slice has not ruled.

(test-case "P4b-ii-1 table (PATH × Map): the MAP POSTURE admits, at the Map's value type"
  ;; Q_U10: `.field` on a (Map K V) subject keeps `map-get` semantics under
  ;; the unified carrier. There is NO per-field row — every key is admissible
  ;; at V, and a MISS is a RUNTIME panic (probed at HEAD: `m.zzz` →
  ;; "panic: map-get: key :zzz not found"), never a static refusal. So the
  ;; dispatch must hand back a UNIFORM value type, not a row and not a fail.
  (let-values ([(row fail) (tc:select-row-of '() TBL-MAP '() 'path)])
    (check-false fail
                 "the path sort must not refuse a Map subject — 'subject-map is the BLOCK posture")
    (check-true (tc:select-uniform? row)
                "a Map has no per-field row; the path sort admits any label uniformly")
    (check-equal? (tc:select-uniform-value-type row) (expr-Int)
                  "the uniform type is the Map's VALUE type")))

(test-case "P4b-ii-1 table (PATH × Map): the block sort is UNCHANGED by the posture"
  ;; the asymmetry is the point — same subject, other sort, still refuses
  (let-values ([(row fail) (tc:select-row-of '() TBL-MAP '() 'block)])
    (check-false row)
    (check-equal? (tc:select-fail-kind fail) 'subject-map)))

(test-case "P4b-ii-1 table: a uniform subject admits ANY label, including one no row lists"
  ;; the miss-deferral half: `m.zzz` must NOT fail statically under 'path
  (let-values ([(ft fail) (tc:select-project-field '() (tc:select-uniform (expr-Keyword) (expr-Int))
                                                   'zzz '() 'path)])
    (check-false fail "a Map key miss is a RUNTIME panic, not a static refusal")
    (check-equal? ft (expr-Int))))

(test-case "P4b-ii-1 table (PATH × record): the record posture is unchanged"
  ;; the Map posture must not leak into record subjects — they still project
  (let-values ([(row fail) (tc:select-row-of '() TBL-RECORD-CLOSED '() 'path)])
    (check-false fail)
    (check-false (tc:select-uniform? row) "a record still yields its ROW, not a uniform")))

(test-case "P4b-ii-1 sort totality: an unknown sort raises AT EVERY DIVERGENT CELL"
  ;; P4a's lesson applied to the new axis BEFORE it grows. Q_U12 already names
  ;; the next sorts (`#.field` nil-safe, `[k]` ordinal) as deferred follow-ups.
  ;; ⚠ SCOPE, stated honestly after the adversarial verify corrected an
  ;; overstatement in this pin's own name: the guard fires at the cells where
  ;; the sorts DIVERGE (the Map arm, the selection arm, and the two dyn-row
  ;; arms). A non-divergent cell — a plain closed-row hit, a closed miss —
  ;; still answers under an unknown sort, because it has no `case sort` to
  ;; reach. Totality here is over the DISPATCH POINTS, not over the walk.
  ;; The predicate is narrow on purpose — `exn:fail?` alone would pass on an
  ;; arity error or a malformed fixture.
  (define (sort-exn? e)
    (and (exn:fail? e)
         (regexp-match? #rx"no arm for selector sort" (exn-message e))))
  ;; all FOUR divergent cells, not just the one the first cut pinned
  (check-exn sort-exn? (lambda () (tc:select-row-of '() TBL-MAP '() 'nil-safe))
             "the Map cell must raise on an unknown sort")
  ;; ⚠ the SELECTION cell's sort dispatch is NOT pinned here, and the reason is
  ;; a real coverage limit rather than an oversight: its arm only fires for a
  ;; REGISTERED selection, and the registries are parameterized only for the
  ;; duration of `process-file` (see run-ws-raw), so a direct call cannot
  ;; reach it. An unregistered fvar falls to 'subject-other without consulting
  ;; the sort. Stated rather than papered over; it closes when b-ii-2 makes
  ;; the path sort reachable end-to-end.
  (check-exn sort-exn?
             (lambda () (tc:select-project-field '() TBL-RECORD-DYN-UNKNOWN 'a '() 'nil-safe))
             "the 'unknown-presence cell must raise on an unknown sort")
  (check-exn sort-exn?
             (lambda () (tc:select-project-field '() TBL-RECORD-DYN-EMPTY 'zzz '() 'nil-safe))
             "the miss-dyn cell must raise on an unknown sort")
  ;; and the guard is not vacuous: the two REAL sorts still answer
  (check-not-exn (lambda () (tc:select-row-of '() TBL-MAP '() 'path)))
  (check-not-exn (lambda () (tc:select-row-of '() TBL-MAP '() 'block))))

;; ---- the PATH column: ASYMMETRY #1, the dyn row (Q_T2) ----

(test-case "P4b-ii-1 table (PATH × dyn row, presence 'unknown): admits as a fresh META"
  ;; D19/D24: an 'unknown-marked HIT projects exactly like a tail miss — the
  ;; meta IS the observation, never the retained type (that courtesy upgrade
  ;; would assert a presence the compiler does not have). Mirrors
  ;; `record-project`, which is what `.field` reaches at HEAD (probed:
  ;; `d1.host` → "h" : ?meta, NOT : String).
  (let-values ([(ft fail) (tc:select-project-field
                           '() TBL-RECORD-DYN-UNKNOWN 'a '() 'path)])
    (check-false fail "the path sort is D19-PERMISSIVE on an 'unknown presence")
    (check-true (expr-meta? ft) "the observation is a fresh meta")
    (check-false (equal? ft (expr-Int))
                 "NOT the retained type — that would assert presence")))

(test-case "P4b-ii-1 table (PATH × dyn row, field unlisted): admits as a fresh META"
  (let-values ([(ft fail) (tc:select-project-field
                           '() TBL-RECORD-DYN-EMPTY 'zzz '() 'path)])
    (check-false fail "an unlisted field may live in the dyn remainder")
    (check-true (expr-meta? ft))))

(test-case "P4b-ii-1 table (× closed row, field missing): BOTH sorts refuse — no divergence"
  ;; the cell where the sorts deliberately AGREE; record-project returns
  ;; expr-error for a 'closed miss too. Pinned so a future edit cannot invent
  ;; a permissive path arm here on symmetry grounds.
  (for ([srt (in-list '(path block))])
    (let-values ([(ft fail) (tc:select-project-field
                             '() TBL-RECORD-CLOSED 'zzz '() srt)])
      (check-false ft)
      (check-equal? (tc:select-fail-kind fail) 'miss-closed
                    (format "closed-row miss must refuse under ~a too" srt)))))

;; ---- the PATH column: ASYMMETRY #3, selection-typed subjects ----

(define TBL-VIEW
  ;; a hand-built view allowing :name only. ⚠ `requires-paths` is a list of
  ;; PATHS (list of lists) — the first cut passed a FLAT '(#:name), which made
  ;; `selection-allows-field?` refuse EVERY label, so both pins below passed
  ;; because the gate refused everything and the admit branch had ZERO
  ;; coverage. Caught at the adversarial verify; the fixture-makes-the-pin-
  ;; vacuous class, on the very slice that quoted it.
  (tc:select-view (selection-entry 'NameOnly 'Person '((#:name)) '() '() #f)
                  (expr-fvar 'NameOnly)))

(test-case "P4b-ii-1 table (PATH × selection, out of view): refuses NAMING THE CAPABILITY"
  ;; today `u.age` is a bare "Could not infer type" with no explanation
  ;; (expr-map-get's selection arm returns a raw expr-error). Under the
  ;; carrier it carries the gate's reason. Reachable E2E at b-ii-2.
  (let-values ([(ft fail) (tc:select-project-field '() TBL-VIEW 'age '() 'path)])
    (check-false ft)
    (check-equal? (tc:select-fail-kind fail) 'selection-not-in-view)))

(test-case "P4b-ii-1 table (PATH × selection): the capability gate does NOT depend on the parent resolving"
  ;; 'Person is not registered in this fixture, so the parent lookup would
  ;; fail — an out-of-view field must still report the CAPABILITY, not the
  ;; missing parent. This is the ordering pinned.
  (let-values ([(_ft fail) (tc:select-project-field '() TBL-VIEW 'nope '() 'path)])
    (check-equal? (tc:select-fail-kind fail) 'selection-not-in-view
                  "an out-of-view field must not be reported as a parent-schema problem")))

(test-case "P4b-ii-1 ASYMMETRY #3 diagnostic: the block refusal no longer LIES — E2E"
  ;; the live half. Before this slice: "the subject is not a record" — false
  ;; of a selection view, and naming no remedy. The refusal itself stays
  ;; (DEFERRED 20); only the message was wrong.
  (define rs (run-ws-raw (string-append
                          "schema Person\n  :name String\n  :age Int\n"
                          "selection NameOnly from Person :requires [:name]\n"
                          "def u : NameOnly := {:name \"hana\" :age 9}\n"
                          "u{name}\n")))
  (define r (format "~a" (last rs)))
  (check-true (prologos-error? (last rs)) "a block over a view still refuses")
  (check-regexp-match #rx"SELECTION" r "the message must name what the subject IS")
  (check-regexp-match #rx"capability-restricted" r)
  (check-false (regexp-match #rx"is not a record" r)
               "the LIE must be gone — a selection view IS a record, restricted"))

(test-case "P4b-ii-1 ASYMMETRY #3: `.field` through a view still WORKS end-to-end"
  ;; the other half of the asymmetry — unchanged by this slice, pinned so
  ;; b-ii-2's fold migration cannot silently delete it (Q_U10's whole lesson)
  (define rs (run-ws-raw (string-append
                          "schema Person\n  :name String\n  :age Int\n"
                          "selection NameOnly from Person :requires [:name]\n"
                          "def u : NameOnly := {:name \"hana\" :age 9}\n"
                          "u.name\n")))
  (check-false (prologos-error? (last rs)))
  (check-regexp-match #rx"hana" (format "~a" (last rs))))

;; ---- gaps the P4b-ii-1 adversarial verify found in this slice's OWN pins ----

(test-case "P4b-ii-1 verify gap: the sort THREADS through the recursive walk"
  ;; Every 'path pin above enters at a LEAF (select-row-of / select-project-field),
  ;; so the ~15 recursive call sites that carry `sort` down through
  ;; select-project → select-level-components → select-branch-entries →
  ;; select-below-field were completely unexercised: replacing `sort` with the
  ;; literal 'block at ANY of them still passed all 260. This pin enters at
  ;; the TOP so the threading is load-bearing. It asserts a NEGATIVE (not the
  ;; assembled shape, which this slice has not ruled) so it rules nothing.
  (check-not-equal? (tbl-outcome TBL-MAP BRANCHES-A 'path) 'subject-map
                    "the path sort must survive the walk down to the subject dispatch")
  ;; and at DEPTH — the intermediate-Map case, which is where a dropped sort
  ;; in select-below-field/select-branch-entries would show
  (define outer
    (make-record 'keyword (list (cons 'inner (record-field TBL-MAP 'present))) 'closed))
  (check-not-equal? (tbl-outcome outer (list (list 'inner 'a)) 'path) 'subject-map
                    "the sort must survive a DESCENT, not just the top level"))

(test-case "P4b-ii-1 verify gap: whnf's re-construction PRESERVES the sort"
  ;; reduction.rkt's expr-select arm rebuilds the carrier after a subject whnf
  ;; step. Its own comment warns that dropping the sort there would silently
  ;; re-sort a 'path selector as 'block — the warning was written, the pin was
  ;; not. A beta-redex subject forces the reconstruction branch.
  (define node (expr-select (expr-app (expr-lam 'mw (expr-Int) (expr-bvar 0))
                                      (expr-fvar 'nosuch))
                            (expr-path '((a)) 'path) #f))
  (define r (whnf node))
  (check-true (expr-select? r) "the node stays stuck on an unbound subject")
  (check-eq? (expr-path-sort (expr-select-branches r)) 'path
             "the sort must survive reconstruction — 'block here is the silent re-sort"))

(test-case "P4b-ii-1 verify gap: the selection ADMIT branch, not just the refusal"
  ;; The first cut's fixture was malformed, so the capability gate refused
  ;; EVERY label and `selection-field-type` — the admit half of asymmetry #3 —
  ;; had zero coverage. With a well-formed view the gate must now DISTINGUISH.
  (check-true (tc:selection-allows-field? (tc:select-view-sel TBL-VIEW) 'name)
              "the fixture must ALLOW its :requires field — a gate that refuses everything makes both refusal pins vacuous")
  (check-false (tc:selection-allows-field? (tc:select-view-sel TBL-VIEW) 'age)
               "and must still refuse an out-of-view field"))

;; ---- ASYMMETRY #4 (union) + the two twin-dispatch folds, all from the verify ----

(define TBL-UNION
  (expr-union (expr-Map (expr-Keyword) (expr-Int))
              (expr-Map (expr-Keyword) (expr-String))))

(test-case "P4b-ii-1 table (PATH × union): ASYMMETRY #4 — projects per component"
  ;; probe at HEAD: `u.a` → 1 : Int | String at 0 errors, while `u{a}`
  ;; refuses. A fourth asymmetry, missed by the mini-audit's enumeration of
  ;; three and found by the adversarial verify. Without this arm b-ii-2's
  ;; wholesale minting silently deletes a working surface.
  ;; ⚠ UPDATED at b-ii-2a: this asserted a ROW because `'path` still assembled
  ;; block-shaped when it was written. 2a gave `'path` its own assembly — it
  ;; EXTRACTS the leaf type — so the union join now arrives DIRECTLY. The pin
  ;; caught its own slice's change, which is what it is for.
  (let-values ([(ty fail) (tc:select-project '() TBL-UNION (list (list 'a)) 'path)])
    (check-false fail "the path sort must project a union subject, not refuse it")
    (check-false (expr-Record? ty) "the path sort EXTRACTS — a row here would be the block assembly")
    (check-true (expr-union? ty) "the per-component value types join into a union")))

(test-case "P4b-ii-1 table (BLOCK × union): unchanged — still refuses"
  (let-values ([(row fail) (tc:select-project '() TBL-UNION (list (list 'a)) 'block)])
    (check-false row)
    (check-equal? (tc:select-fail-kind fail) 'subject-other)))

(test-case "P4b-ii-1 verify gap: the Map posture honours the KEY TYPE"
  ;; the reference is `(if (check ctx k kt) vt (expr-error))` — TWO
  ;; obligations. The first cut implemented only the miss half, so a
  ;; (Map Int String) subject would have admitted a keyword label and
  ;; degraded to a runtime panic at b-ii-2. Probe: `mi.a` REFUSES at HEAD.
  (let-values ([(row fail) (tc:select-project
                            '() (expr-Map (expr-Int) (expr-String))
                            (list (list 'a)) 'path)])
    (check-false row "a keyword label is not a legal key of a (Map Int String)")
    (check-equal? (tc:select-fail-kind fail) 'subject-map))
  ;; and the gate is not vacuous — a matching key type still admits
  (let-values ([(ty fail) (tc:select-project
                           '() (expr-Map (expr-Keyword) (expr-String))
                           (list (list 'a)) 'path)])
    (check-false fail)
    ;; UPDATED at b-ii-2a with the 'path assembly: the Map's VALUE type
    ;; arrives directly, not wrapped in a one-field row.
    (check-equal? ty (expr-String) "the path sort extracts the Map's value type")))

(test-case "P4b-ii-1 verify gap: select-index-of — the NAT TWIN — is total over sort"
  ;; the file's own comment calls it "the nat twin of select-row-of"; when its
  ;; twin became 2-D this stayed 1-D, so the ORDINAL column silently carried
  ;; block semantics and could never raise the guard. The two sorts agree here
  ;; today BY SCOPING (Q_U12: `.N` reuses $postfix-index, so 'path × ordinal is
  ;; unreachable at b-ii) — totality is what stops a THIRD sort inheriting it.
  (define (sort-exn? e)
    (and (exn:fail? e) (regexp-match? #rx"no arm for selector sort" (exn-message e))))
  (check-exn sort-exn?
             (lambda () (tc:select-project '() (expr-PVec (expr-Int))
                                           (list (list '(@ord 0))) 'nil-safe))
             "the ordinal dispatch must raise on an unknown sort, not default to block")
  ;; both real sorts still answer
  (check-not-exn (lambda () (tc:select-project '() (expr-PVec (expr-Int))
                                               (list (list '(@ord 0))) 'block))))

(test-case "P4b-ii-1 verify gap: pp-expr renders the selector BY SORT"
  ;; hard-coding `subject{…}` was correct while 'block was the only reachable
  ;; sort; after b-ii-2 every `x.a` would have printed as `x{a}` in error
  ;; messages and def echoes — silent wrong output on the diagnostic path.
  (check-equal? (pp-expr (expr-select (expr-fvar 'x) (expr-path '((a)) 'block) #f) '())
                "x{a}")
  (check-equal? (pp-expr (expr-select (expr-fvar 'x) (expr-path '((a)) 'path) #f) '())
                "x.a"
                "the path sort is the DOT spelling, not the brace one")
  ;; and it must not RAISE on an unknown sort — pp-expr is on the error path,
  ;; so it renders a visible marker instead (the P4a site-13 ruling)
  (check-true (string? (pp-expr (expr-select (expr-fvar 'x) (expr-path '((a)) 'nil-safe) #f) '()))
              "an unknown sort must degrade to a marker, never crash a diagnostic"))

;; ---- b-ii-1 DEFECT, found by the b-ii-2 mini-audit's completeness critic ----

(define TBL-RECORD-CLOSED-UNKNOWN
  ;; a CLOSED row carrying an 'unknown-presence field. Not constructible from
  ;; the surface today — `record-mark-all-unknown` (syntax.rkt) is the SOLE
  ;; 'unknown producer and it forces tail='dyn in the same constructor — so
  ;; this cell is latent BY LUCK, not by design. That is exactly the
  ;; pipeline.md "invariant asserted with no enforcement" shape, so it gets a
  ;; direct-call pin rather than an assurance.
  (make-record 'keyword (list (cons 'a (record-field (expr-Int) 'unknown))) 'closed))

(test-case "P4b-ii-1 defect: the 'unknown arm must be TAIL-SENSITIVE, like record-project"
  ;; `record-project`'s 'unknown HIT routes to `miss()`, which tests the ROW
  ;; TAIL: dyn -> fresh meta, closed -> expr-error. The b-ii-1 'path arm was
  ;; TAIL-BLIND — it minted a meta unconditionally — while its own comment
  ;; asserted both "mirror record-project's D19/D24 posture EXACTLY". On a
  ;; closed row that made `map-get` REFUSE where the carrier ADMITS: a
  ;; silent-accept divergence, the direction no red-set census can see.
  (let-values ([(ft fail) (tc:select-project-field
                           '() TBL-RECORD-CLOSED-UNKNOWN 'a '() 'path)])
    (check-false ft "a closed row cannot host the field in a remainder — there is none")
    (check-equal? (tc:select-fail-kind fail) 'unknown-presence))
  ;; and the DYN twin still admits — the tail test must discriminate, not just refuse
  (let-values ([(ft fail) (tc:select-project-field
                           '() TBL-RECORD-DYN-UNKNOWN 'a '() 'path)])
    (check-false fail "a DYN row's unknown field may live in the remainder")
    (check-true (expr-meta? ft))))

;; ============================================================
;; D4.P4b-ii-2a — BEFORE-THE-FOLD TRIPWIRES
;; ============================================================
;; These pin behaviour that the b-ii-2b fold migration WILL CHANGE. They are
;; TRIPWIRES, not invariants: their job is to make each change VISIBLE (a RED
;; test at 2b, updated deliberately with the delta recorded) instead of silent.
;;
;; They exist because the b-ii-2 mini-audit found a class no red-set census can
;; see — ACCEPT-DIRECTION flips. A migration that makes something start working,
;; or stop erroring, produces NO failing test. If it is not captured here, it
;; lands unrecorded. The other two capture a permissive→panic conversion and a
;; silent deletion, neither of which any existing test covers.

(test-case "b-ii-2b: the union LYING diagnostic is FIXED by the fold — delta recorded"
  ;; ⭐ THE TRIPWIRE FIRED, and this is the record it demanded. Before the fold
  ;; `def y := u.a` on a union subject reported "Multiplicity violation" —
  ;; qtt.rkt's `expr-map-get` arm is SUBJECT-TYPE-GATED with no `expr-union`
  ;; case, although typing-core's `infer` arm has one, so QTT fell to its
  ;; catch-all and reported a multiplicity error for a TYPING gap (the
  ;; infer/inferQ-twins signature from pipeline.md, live in the tree).
  ;;
  ;; Migrating fixes it because `expr-select`'s `inferQ` delegates
  ;; unconditionally. This is an ACCEPT-DIRECTION flip — it produces no failing
  ;; test, which is exactly why 2a pinned the BEFORE. Without that pin this
  ;; would have landed unrecorded.
  (define rs (run-ws-raw (string-append
                          "def u : <[Map Keyword Int] | [Map Keyword String]> := {:a 1}\n"
                          "def y := u.a\n")))
  (check-false (ormap prologos-error? rs)
               "the union subject now types cleanly through the carrier")
  (check-regexp-match #rx"Int \\| String" (format "~a" (last rs))
                      "and the per-component join is the ANSWER, not a lie about multiplicity"))

(test-case "b-ii-2a TRIPWIRE: the DOT spelling's miss on a dyn row is PERMISSIVE"
  ;; THE GAP THE AUDIT FOUND: all three D19 pins use the BRACKET spelling
  ;; (`[map-get d :zzz]`), which parses through the map-get PARSER KEYWORD, not
  ;; the `$dot-access` sentinel b-ii-2 migrates. So they stay green through the
  ;; regression and NOTHING pinned the dot spelling. This is that pin.
  ;; Mechanism: expr-map-get's strictness slot is only solved to (expr-true) by
  ;; the (Map K V) infer arm; a dyn-row subject never solves it, so reduction
  ;; takes the permissive `(expr-error)` branch instead of the loud panic.
  ;; AT 2b THIS REGRESSES TO A PANIC unless the tier rides the carrier.
  (define rs (run-ws-raw (string-append
                          "def base := {:host \"h\" :port 1}\n"
                          "def kk := :port\n"
                          "def d1 := [map-dissoc base kk]\n"
                          "d1.zzz\n")))
  (check-false (ormap prologos-error? rs)
               "a dyn-row miss via the DOT spelling is permissive — zero errors")
  (check-regexp-match #rx"error" (format "~a" (last rs))
                      "it degrades to the <error> VALUE, not a panic"))

(test-case "b-ii-2a TRIPWIRE: `_.field` sections work — THREE shapes, zero prior tests"
  ;; `_.a` sections because the $dot-access fold arm has NO `_` guard (its
  ;; $postfix-index sibling DOES — which is why `_[k]` is a guided refusal) and
  ;; `map-get` is in sectionable-op-keywords. `$select` is neither in that list
  ;; nor reachable by it: its parse-list clause PRECEDES the section clause in
  ;; the same cond, so "add $select to sectionable-op-keywords" is INERT.
  ;; AT 2b THIS SURFACE DISAPPEARS unless b-ii-3's rescue lands with it.
  ;; ⚠ PRELUDE fixture, deliberately: `map` does not exist under :no-prelude,
  ;; and a prologos-error? assertion cannot tell an Unbound-variable cascade
  ;; from the deletion this pin exists to catch (the Watching-4 false-green
  ;; class — it caught this pin on its first run).
  (define rs (run-ws-pre-raw (string-append
                              "def r := {:a 7}\n"
                              "[_.a r]\n"
                              "def recs := @[{:a 1} {:a 2}]\n"
                              "map _.a recs\n")))
  (check-false (ormap prologos-error? rs) "all three shapes must stay live")
  (check-regexp-match #rx"7 : Int" (format "~a" (list-ref rs 1))
                      "direct application of the section")
  (check-regexp-match #rx"@\\[1 2\\]" (format "~a" (last rs))
                      "the section as a HOF argument — the ergonomic case"))

(test-case "b-ii-2a: the `'path` ASSEMBLY extracts; the `'block` assembly projects"
  ;; the prerequisite the b-ii-2 mini-audit found nobody had named: BOTH walks
  ;; assembled a ROW unconditionally, under both sorts, so the fold could not
  ;; be flipped — `x.a` would have typed as `{:a T}` instead of `T`.
  (let-values ([(ty fail) (tc:select-project '() TBL-RECORD-CLOSED BRANCHES-A 'path)])
    (check-false fail)
    (check-equal? ty (expr-Int) "path EXTRACTS the leaf type"))
  (let-values ([(row fail) (tc:select-project '() TBL-RECORD-CLOSED BRANCHES-A 'block)])
    (check-false fail)
    (check-true (expr-Record? row) "block PROJECTS into a row")
    (check-equal? (record-field-type (cdr (car (expr-Record-fields row)))) (expr-Int))))

(test-case "b-ii-2a: a malformed multi-component `'path` carrier REFUSES, it does not take the first"
  ;; unconstructible from the surface under Q_U13's NEST encoding (one branch,
  ;; one step per level) — pinned anyway, because silently taking the first
  ;; component is how the P2.b fabrication class starts.
  (let-values ([(ty fail) (tc:select-project '() TBL-RECORD-CLOSED
                                             (list (list 'a) (list 'a)) 'path)])
    (check-false ty)
    (check-true (tc:select-fail? fail) "a 2-component path carrier must refuse")))

(test-case "b-ii-2a: select-reduce RECEIVES the sort (step zero for any tier work)"
  ;; its signature was `(subj-expr branches)` and the whnf call site discarded
  ;; the sort it had just bound — so every runtime outcome for a migrated
  ;; `.field` would have been decided by a sort-blind function.
  (define subj (expr-champ (let ([kw (expr-keyword 'a)])
                             (champ-insert champ-empty (equal-hash-code kw) kw (expr-int 7)))))
  ;; block: assembles a champ
  (check-true (expr-champ? (select-reduce subj '((a)) 'block #f)))
  ;; path: extracts the leaf VALUE
  (check-equal? (select-reduce subj '((a)) 'path (expr-true)) (expr-int 7)
                "the path sort must yield the value, not a one-key map")
  ;; and the sort axis is total here too
  (check-exn (lambda (e) (and (exn:fail? e)
                              (regexp-match? #rx"no arm for selector sort" (exn-message e))))
             (lambda () (select-reduce subj '((a)) 'nil-safe #f))))

(test-case "b-ii-2a: the tier field is carried, and MAPPED — not merely preserved"
  ;; INERT at 2a (every construction passes #f, nothing reads it), but the
  ;; walker contract has to be right BEFORE b-ii-2b puts a meta in it.
  (define node (expr-select (expr-fvar 'x) (expr-path '((a)) 'path) #f))
  (check-eq? (expr-select-tier node) #f "no claim is the 2a default")
  (check-eq? (expr-select-tier (select-map-exprs (lambda (e) e) node)) #f
             "#f is not an expr — it must pass through the mapper untouched")
  ;; the load-bearing half: a tier that is CARRIED but not MAPPED would never
  ;; zonk at 2b, `expr-true?` would never hold, and every Map miss would go
  ;; silently PERMISSIVE — a reverse regression with no signal.
  (define with-meta (expr-select (expr-fvar 'x) (expr-path '((a)) 'path) (expr-fvar 'TIER)))
  (define mapped (select-map-exprs (lambda (e) (if (equal? e (expr-fvar 'TIER))
                                                   (expr-true)
                                                   e))
                                   with-meta))
  (check-equal? (expr-select-tier mapped) (expr-true)
                "the mapper must DESCEND into the tier, or a meta there can never be solved"))

;; ============================================================
;; D4.P4b-ii-2b — the `$select-path` sentinel (machinery; the fold not yet flipped)
;; ============================================================

(test-case "b-ii-2b: `$select-path` parses to a 'path surf-select"
  ;; a DISTINCT sentinel from `$select` [owner ruling]: the sort cannot be
  ;; recovered downstream, because the fold mints in preparse and by the time a
  ;; surf-select exists the origin is gone — which is why the elaborator had to
  ;; hard-code 'block before this slice.
  (define r (parse-datum '($select-path foo bar)))
  (check-true (surf-select? r))
  (check-eq? (surf-select-sort r) 'path "the DOT spelling carries 'path")
  (check-equal? (surf-select-branches r) '((bar)) "exactly one branch, per Q_U13's NEST encoding"))

(test-case "b-ii-2b: the ARITY GATE restores the loud behaviour the pipe caller relies on"
  ;; THE POINT of the distinct sentinel. `map-get`'s parser arm imposes EXACT
  ;; arity 2; `$select`'s has NO upper bound, so every surplus arg becomes
  ;; another BRANCH. `apply-pipe-step` appends the accumulator into any
  ;; hole-free step, so a bare `$select` mint would turn `|> m foo.bar` from a
  ;; LOUD arity-error into a SILENT two-branch select — the piped value quietly
  ;; becoming a selection branch, at zero errors. The same append lives in the
  ;; `>>` compose twin, so a blacklist fix would have had to find BOTH; the
  ;; gate fixes every caller at once, structurally.
  (define r (parse-datum '($select-path foo bar m)))
  (check-true (prologos-error? r) "a surplus payload arg must REFUSE, not become a branch")
  (check-regexp-match #rx"exactly one field" (format "~a" r))
  (check-regexp-match #rx"\\|>" (format "~a" r)
                      "the message must name the pipe, since that is how the surplus arrives"))

(test-case "b-ii-2b: the BLOCK sentinel is untouched — multi-branch stays legal"
  ;; the gate must be scoped to the path sort; `x{a b}` is a legitimate
  ;; two-branch block and must not be caught by it
  (define r (parse-datum '($select foo bar m)))
  (check-true (surf-select? r))
  (check-eq? (surf-select-sort r) 'block)
  (check-equal? (surf-select-branches r) '((bar) (m))))

(test-case "b-ii-2b: the surf-select sort THREADS to the carrier through elaboration"
  ;; the elaborator no longer hard-codes 'block; before this the sort had no
  ;; channel at all from parser to carrier
  (define rs (run-ws-raw "def cfg := {:server {:host \"h\"}}\ncfg{server}\n"))
  (check-false (ormap prologos-error? rs))
  ;; the block spelling still round-trips as a block (pp renders by sort)
  (check-regexp-match #rx"server" (format "~a" (last rs))))

;; ============================================================
;; D4.P4b-ii-2c — the diagnostics are SORT-AWARE
;; ============================================================

(test-case "b-ii-2c: the DOT spelling's miss no longer tells the user to write what they wrote"
  ;; every `format-select-fail` arm was written when only `x{…}` could reach
  ;; it, so they say "a select block" and append block-specific advice. After
  ;; the b-ii-2b flip the dot spelling reaches them too, and the tail became
  ;; ACTIVELY MISLEADING — probe-confirmed before the fix:
  ;;   `r.zzz` → "…; in the select branch `zzz` — bare field access (no
  ;;              construction) is spelled `.zzz`"
  ;; which is exactly what the user wrote. Worse, `select-block-hint` runs
  ;; BEFORE `closed-row-miss-hint` in infer/err's `or`, so the bad message WON.
  (define rs (run-ws-raw "def r := {:a 1 :b 2}\nr.zzz\n"))
  (define msg (format "~a" (last rs)))
  (check-true (prologos-error? (last rs)))
  (check-regexp-match #rx"not present in the record" msg "the useful half stays")
  (check-regexp-match #rx"available fields" msg)
  (check-false (regexp-match #rx"is spelled" msg)
               "the block tail TEACHES the dot spelling — useless when they used it")
  (check-false (regexp-match #rx"select branch" msg)
               "there is no branch: a path access is not a block"))

(test-case "b-ii-2c: the BLOCK spelling KEEPS its wording — the fix is scoped, not a blanket strip"
  (define rs (run-ws-raw "def r := {:a 1 :b 2}\nr{zzz}\n"))
  (define msg (format "~a" (last rs)))
  (check-true (prologos-error? (last rs)))
  (check-regexp-match #rx"select branch" msg "a block miss IS in a branch")
  (check-regexp-match #rx"is spelled" msg
                      "and the dot spelling is genuinely the remedy there"))

(test-case "b-ii-2c: the Map BLOCK refusal is unchanged by the sort-awareness"
  (define rs (run-ws-raw "def m : [Map Keyword Int] := {:a 1}\nm{a}\n"))
  (define msg (format "~a" (last rs)))
  (check-regexp-match #rx"a select block needs a record subject" msg)
  (check-regexp-match #rx"seal|validate" msg "the remedies survive"))

;; ============================================================
;; D4.P4b-ii-2b — THE ADVERSARIAL VERIFY'S FINDINGS, pinned
;; ============================================================
;; Mutation testing proved the ASSERTIVE half of the two-tier fork was
;; COMPLETELY unpinned: disabling reduction's `expr-true?` arm, and separately
;; disabling typing's `solve-strict-assert!`, each left the whole battery
;; green. The permissive half was pinned (the 2a tripwire); the loud half —
;; the half whose failure STORES a wrong answer — was not. These are the three
;; direct analogues of the map-get pins the migration claims parity with.

(test-case "verify B1: an assertive (Map K V) miss via the DOT spelling is a COUNTED error"
  ;; the analogue of P2.b A1. Mutation M1 (reduction ignores the tier) and M2
  ;; (typing never solves it) both made this degrade to `<error>` at ZERO
  ;; errors with 283/283 still green.
  (define rs (run-ws-raw (string-append
                          "def d : [Map Keyword Int] := [map-assoc [map-assoc [map-empty Keyword Int] :a 1] :b 2]\n"
                          "d.zzz\n")))
  (check-true (prologos-error? (last rs))
              "a proved-Map miss must be LOUD — degrading here stores a wrong answer"))

(test-case "verify B1: the assertive miss names the key AND the available keys"
  ;; the analogue of P2.b A1b — the quality bar map-get set, which the dot
  ;; spelling must not lose. Also the ONLY test that executes
  ;; `assertive-miss-message`, whose extraction fixed a live shadowing crash.
  (define rs (run-ws-raw (string-append
                          "def d : [Map Keyword Int] := [map-assoc [map-assoc [map-empty Keyword Int] :alpha 1] :beta 2]\n"
                          "d.zzz\n")))
  (define msg (format "~a" (last rs)))
  (check-regexp-match #rx"zzz" msg "the missing key")
  (check-regexp-match #rx"available keys" msg)
  (check-regexp-match #rx"alpha" msg "the keys that ARE there")
  (check-regexp-match #rx"beta" msg))

(test-case "verify B1: an assertive miss must NOT silently COMMIT to a def"
  ;; the analogue of P2.b A2 — the stored-silent-wrong-answer class. Under the
  ;; mutations this bound `bad : Int` at zero errors.
  (define rs (run-ws-raw (string-append
                          "def d : [Map Keyword Int] := [map-assoc [map-empty Keyword Int] :a 1]\n"
                          "def bad := d.zzz\n")))
  (check-true (ormap prologos-error? rs)
              "binding a proved-Map miss must fail, not commit"))

(test-case "verify BLOCKING: a non-map union component DEGRADES like map-get, it does not panic"
  ;; TWO skeptics found this independently by A/B against a baseline tree. The
  ;; first cut tier-gated only the keyed MISS; the SUBJECT-kind arm one level
  ;; up stayed unconditional, so `.field` on a union whose runtime value is a
  ;; non-map PANICKED where `[map-get u :a]` degrades to `none` at 0 errors.
  ;; A permissive->panic conversion — the class this slice exists to prevent.
  (define rs (run-ws-raw (string-append
                          "def u : <[Map Keyword Int] | Int> := 42\n"
                          "u.a\n"
                          "[map-get u :a]\n")))
  (check-false (ormap prologos-error? rs) "neither spelling may error here")
  (check-equal? (format "~a" (list-ref rs 1)) (format "~a" (last rs))
                "the two spellings of ONE operation must agree — that is the whole point of the carrier"))

(test-case "verify S2: `^` in a DOT access REFUSES — it is not silently dropped"
  ;; the field rides as a bare SYMBOL now, so `segment-select-items` splits a
  ;; `^` out of it into a re-key continuation and the 'path assembly DROPPED
  ;; it: five spellings returned the plain field at ZERO errors where HEAD
  ;; refused, while pp-expr still rendered the `^` faithfully — honest display
  ;; over dishonest semantics. `^` sets an OUTPUT KEY; a path access has none.
  (for ([src (in-list '("m.foo^z" "m.foo^" "m.foo^_" "m.foo^-"))])
    (define rs (run-ws-raw (string-append "def m := {:foo 7 :bar 8}\n" src "\n")))
    (check-true (prologos-error? (last rs)) (format "~a must refuse" src))
    (check-regexp-match #rx"re-keys the OUTPUT" (format "~a" (last rs))))
  ;; and the plain access is untouched
  (check-regexp-match #rx"7 : Int"
                      (format "~a" (last (run-ws-raw "def m := {:foo 7}\nm.foo\n"))))
  ;; and the BLOCK spelling keeps `^` in full
  (define b (run-ws-raw "def c := {:server {:host \"h\"}}\nc{server.host^alias}\n"))
  (check-false (ormap prologos-error? b) "blocks still re-key")
  (check-regexp-match #rx"alias" (format "~a" (last b))))

(test-case "verify S1: pp-datum renders the carrier, not a raw sentinel"
  ;; the FOURTH consecutive missed pretty-print.rkt site. `expand r.a` emitted
  ;; `($select-path r a)` where HEAD emitted `(map-get r :a)` — a silent
  ;; regression on the introspection path, for the most common access surface
  ;; in the language. pp-expr was fixed at b-ii-1; that census stopped there.
  (define rs (run-ws-raw "def r := {:a {:b 1}}\nexpand r.a\nexpand r.a.b\n"))
  (check-regexp-match #rx"^r\\.a$" (format "~a" (list-ref rs 1)))
  (check-regexp-match #rx"^r\\.a\\.b$" (format "~a" (last rs))
                      "nesting must compose, not render as r.a{b} or a raw sentinel"))

;; ============================================================
;; D4.P4c-1 — the two PREREQUISITES + the classifier promotion
;; ============================================================
;;
;; P4c-1 carries NO new surface. It lands three things the P4c grounding audit
;; (wf_d7c035da-cee) found are owed under EVERY option, two of which are LIVE
;; DEFECTS at HEAD rather than prospective ones:
;;
;;   1. `adjacent-to-base?` hoisted to reader-forms.rkt — surface-rewrite.rkt
;;      hand-inlines the same four conjuncts today (a live F1b.7g drift
;;      instance), and P4c-2 would otherwise write them a THIRD time.
;;   2. The `ns` name guard made TOTAL — `ns foo:bar` SILENTLY DROPS `:bar` at
;;      ZERO errors today (probe-verified). The guard's `memq` catches only
;;      `$dot-access`/`$postfix-index`, and `:bar` is a bare symbol.
;;   3. `colon-annotation` promoted to a real token type (Q_U16b) — its
;;      classifier returns `'symbol` today, so `:0`/`:w`/`:m` are
;;      type-indistinguishable from any identifier and the P4c-2 gate could not
;;      dispatch on them.

;; ---- (2) the `ns` guard: a LIVE silent drop, and the fix is a POLARITY
;;         INVERSION, not another memq entry ----
;;
;; `ns` accepts exactly ONE option (`:no-prelude`, namespace.rkt:904-906). So
;; the total guard is a positive ALLOW-LIST of that option with everything else
;; refused — the same inversion `definitely-not-map?` took at P2.b slice 1 —
;; rather than a negative list of known-bad heads that must be extended every
;; time a new sentinel is minted. D4 records THREE unclosed instances of this
;; class; the inversion closes them all instead of opening a fourth.

(test-case "P4c-1: `ns foo:bar` REFUSES — the segment is not silently dropped"
  ;; RED at HEAD: defines ns `foo`, drops `:bar`, reports ZERO errors.
  ;; ⚠ CHANNEL CHANGED AT G2/B: refusal by VALUE, not by raise. The proposition
  ;; ("not silently dropped") is unchanged and is what this still asserts.
  (define rs (run-ws-raw "ns foo:bar\ndef x := 1\n"))
  (check-true (ormap (lambda (r) (regexp-match? #rx"namespace name" (format "~a" r))) rs)
              "a colon segment in an ns name must be REFUSED, not silently dropped")
  ;; …and the file CONTINUES, which is the whole point of the seam guard
  (check-true (ormap (lambda (r) (regexp-match? #rx"x : Int defined" (format "~a" r))) rs)
              "the command after a refused ns must still run"))

(test-case "P4c-1: the ns refusal names the segment and offers `::`"
  ;; Same CHANNEL as pin 1 — the guard raises, so the message is read off the
  ;; exn, not off a result list. (The first draft read `(car rs)`, which is
  ;; incoherent with a raising guard and contract-violated on '().)
  ;; ⚠ Same CHANNEL note as the pin above — read off the result list at G2/B.
  (define msgs (map (lambda (r) (format "~a" r)) (run-ws-raw "ns foo:bar\ndef x := 1\n")))
  (check-true (ormap (lambda (m) (and (regexp-match? #rx"namespace name" m)
                                      (regexp-match? #rx"::" m)))
                     msgs)
              "the refusal must name the namespace name and offer `::` as the remedy"))

(test-case "P4c-1: the ns guard stays TOTAL for the shapes it already caught"
  ;; ⚠ RECORDED, not endorsed: this guard RAISES (a raw Racket `error`), it does
  ;; not return a per-command `parse-error` VALUE — so it is a WHOLE-FILE ABORT,
  ;; the Q_L4 class P1a built the marker-form seat to prevent. Pinning the true
  ;; behaviour rather than the behaviour I assumed; the raise→value conversion
  ;; is a NAMED follow-up, deliberately out of P4c-1's scope because the
  ;; prerequisite is totality, not the error CHANNEL.
  ;; ✅ AND THE "NAMED FOLLOW-UP" THIS COMMENT DEFERRED HAS LANDED — see G2/B.
  ;; The guard is still TOTAL over these shapes; only the channel moved from a
  ;; raw raise to a per-command error value.
  (for ([src (in-list (list "ns foo.bar\ndef x := 1\n" "ns foo[2]\ndef x := 1\n"))])
    (define rs (map (lambda (r) (format "~a" r)) (run-ws-raw src)))
    (check-true (ormap (lambda (m) (regexp-match? #rx"namespace name" m)) rs)
                (format "must stay caught: ~a → ~a" src rs))))

(test-case "P4c-1: the ns guard does NOT refuse its one legitimate option"
  ;; The inversion's whole risk is over-refusing. `:no-prelude` is the ONLY
  ;; option `ns` accepts (namespace.rkt:904-906) and must survive.
  (check-false (ormap prologos-error? (run-ws-raw "ns foo :no-prelude\n"))
               ":no-prelude is a legitimate ns option and must NOT be refused")
  (check-false (ormap prologos-error? (run-ws-raw "ns foo::bar\n"))
               "`::` is the hierarchical separator, glued into ONE symbol — never a segment"))

(test-case "P4c-1: the promotion is DATUM-INVISIBLE — zero corpus A/B diffs owed"
  ;; The whole point of landing this in P4c-1 rather than P4c-2: a token-TYPE
  ;; change must not move a single datum, so the A/B baseline stays clean and
  ;; P4c-2's seven predicted diffs are attributable to the MINT alone.
  ;; ⚠ DELIBERATE FLIP at P4c-2 — `users:0` now MINTS (Q_U16b makes it a legal
  ;; ω step). Listed as a flip rather than silenced: this is the P4c hazard that
  ;; says the prior rung's flagship pin flips, for the third consecutive phase.
  (check-equal? (read-all-forms-string "users:0") '((users ($bcast-step :0))))
  (check-equal? (read-all-forms-string "[fn [x :0 Int] x]") '((fn (x :0 Int) x)))
  (check-equal? (read-all-forms-string "users:w") '((users ($bcast-step :w))))
  ;; baseline MEASURED, not guessed — the first draft of this pin asserted
  ;; `(((:0 v)))` from memory and failed for the wrong reason.
  (check-equal? (read-all-forms-string "{:0 v}") '(($brace-params :0 v))))

;; ============================================================
;; D4.P4c-2 — the `:` MINT + the reader-post-pass BINDER UNWRAP (Q_U16)
;; ============================================================
;;
;; Q_U8 as ruled could not be built: §Q8.5 site 8 (join `access-sentinel?` +
;; take a fold arm) and parser position-dispatch are MUTUALLY EXCLUSIVE,
;; because the preparse fold RUNS OVER BINDER POSITIONS (`defn f [x.a] x` →
;; a 3-arity function at ZERO errors). Q_U16 keeps BOTH surfaces by moving the
;; unwrap to the READER POST-PASS, which provably precedes all FOUR
;; `rewrite-dot-access` seats (macros.rkt :2004 · :2714 · :6564 · :6950 —
;; re-measured 2026-08-02; the previously-cited quadruple was all four wrong).
;;
;; So the contract is TWO-SIDED and both sides need pins:
;;   EXPRESSION position → the mint SURVIVES as `($bcast-step k)`
;;   BINDER position     → the post-pass UNWRAPS it back to the bare `:k`
;;
;; The binder table is MEASURED (D4 §5.P4c-2), not enumerated from memory.

;; ---- side 1: the mint fires in EXPRESSION position ----

(test-case "P4c-2: `users:name` mints the broadcast step, payload VERBATIM"
  ;; ⚠ The payload is the COLON-SYMBOL `:name`, not a stripped `name`. This pin
  ;; first asserted the stripped form — which would have forced the unwrap to
  ;; re-add `:`, i.e. a SECOND copy of the recognizer's accept-set: the exact
  ;; F1b.7g drift class reader-forms.rkt exists to forbid. `token-entry->stx`'s
  ;; keyword arm already yields `|:name|`; the mint WRAPS it untouched so the
  ;; unwrap is a plain `cadr`.
  (check-equal? (read-all-forms-string "users:name") '((users ($bcast-step :name)))))

(test-case "P4c-2: the ordinal band mints too (Q_U16b — `users:0` is a legal ω step)"
  (check-equal? (read-all-forms-string "users:0") '((users ($bcast-step :0))))
  (check-equal? (read-all-forms-string "users:w") '((users ($bcast-step :w)))))

(test-case "P4c-2: the mint is POSITIONAL — closers and `.N` join the focus set FREE"
  ;; `adjacent-to-base?` consults NO token type, so these come free under the
  ;; positional rule and would each have needed a hand entry under an
  ;; enumerated one.
  (check-equal? (read-all-forms-string "xs[0]:n") '((xs ($postfix-index 0) ($bcast-step :n))))
  ;; ⚠ UPDATED at D4.P4d slice 7 [owner ruling 2026-08-08]. The PROPOSITION of
  ;; this pin is unchanged and still holds: the `:name` sentinel mints adjacent
  ;; to a paren-group base, positionally, consulting no token type. What changed
  ;; is the BASE — a paren group that is the subject of an access at COMMAND
  ;; position now carries the `$goal-rhs` marker, so `(f x):name` gets the same
  ;; implicit solve that bare `(f x)` already had. `()` is the relational
  ;; delimiter (prologos-syntax.md § Delimiters: `[]` is the functional one), so
  ;; a paren subject is a goal subject; before slice 7 the access spelling
  ;; silently treated it as grouping while the bare spelling refused.
  ;; This assertion is the ONLY place in the tree that observes the reader
  ;; output for this input — it is the tripwire for that mint, and it fired.
  (check-equal? (read-all-forms-string "(f x):name")
                '((($goal-rhs (f x)) ($bcast-step :name))))
  ;; the BRACKET twin must NOT be marked — that asymmetry is the scope guard
  (check-equal? (read-all-forms-string "[f x]:name") '(((f x) ($bcast-step :name)))))

;; ---- side 2: BINDER positions unwrap — one row per MEASURED table entry ----
;;
;; ⚠ THESE ARE INVARIANCE PINS, GREEN BEFORE AND AFTER. Before the mint they
;; pass trivially (there is nothing to unwrap); their job is to go RED the
;; moment the mint LEAKS into a binder position. So "green" here is only
;; evidence once side 1 is green too — read the two sides together.
;;
;; A missing row is the 3-arity class: the binder consumer meets
;; `($bcast-step Int)` where it expects `:Int` and falls to a generic arm. The
;; consumer hardening makes that LOUD; these pins make it VISIBLE.

(test-case "P4c-2 binder row: def"
  (check-equal? (read-all-forms-string "def x:Int := 5") '((def x :Int := 5))))

(test-case "P4c-2 binder row: defn param group"
  (check-equal? (read-all-forms-string "defn f [a:Int b:Int] a")
                '((defn f (a :Int b :Int) a))))

(test-case "P4c-2 binder row: fn param group"
  (check-equal? (read-all-forms-string "[fn [x:Int] x]") '((fn (x :Int) x))))

(test-case "P4c-2 binder row: spec param group"
  (check-equal? (read-all-forms-string "spec g [a:Int] -> Int") '((spec g (a :Int) -> Int))))

(test-case "P4c-2 binder row: let binding"
  (check-equal? (read-all-forms-string "let x:Int 5\n  x") '((let x :Int 5 x))))

(test-case "P4c-2 binder row: property + functor param groups"
  (check-equal? (read-all-forms-string "property p [x:Int] x") '((property p (x :Int) x)))
  (check-equal? (read-all-forms-string "functor F [x:Int] x") '((functor F (x :Int) x))))

(test-case "P4c-2 binder row: trait METHOD params"
  (check-equal? (read-all-forms-string "trait T {A}\n  m [x:Int] : A")
                '((trait T ($brace-params A) (m (x :Int) : A)))))

(test-case "P4c-2 binder row: rel / defr param groups (the BARE-NAME spelling)"
  ;; The `?`-prefixed spelling is immune (glued by narrow-var-annot); the
  ;; bare-name one is NOT. An earlier draft of the table declared defr OUT on
  ;; the `?a:Nat` probe alone — the under-count this row exists to pin.
  (check-equal? (read-all-forms-string "defr r [a:Int]") '((defr r (a :Int))))
  (check-equal? (read-all-forms-string "def q := rel [a:Int] &> foo a")
                '((def q := rel (a :Int) $clause-sep foo a))))

(test-case "P4c-2 binder row: `$pipe` ARMS — defn AND match"
  ;; Owner-caught; named by neither the audit nor the options panel.
  (check-equal? (read-all-forms-string "defn f\n  | a:Int -> a") '((defn f ($pipe a :Int -> a))))
  (check-equal? (read-all-forms-string "match v\n  | c a:Int -> a")
                '((match v ($pipe c a :Int -> a)))))

(test-case "P4c-2 binder row: `$pipe` arm patterns NEST"
  ;; The unwrap cannot scan an arm's top-level items — the annotation is inside
  ;; a constructor pattern sub-group.
  (check-equal? (read-all-forms-string "defn g\n  | [cons h:Int t] -> h")
                '((defn g ($pipe (cons h :Int t) -> h)))))

(test-case "P4c-2 binder row: a header param group AND arms in ONE form"
  (check-equal? (read-all-forms-string "defn k [x:Int]\n  | 0 -> x")
                '((defn k (x :Int) ($pipe 0 -> x)))))

;; ---- the IMMUNE set: these must not move, and two of them are load-bearing ----

(test-case "P4c-2: the `?`-prefixed spelling is immune — ONE glued token"
  ;; narrow-var-annot (pri 96) glues it, so the mint structurally cannot fire.
  ;; This is the tree's own lexical solution to the collision, for one vocabulary.
  (check-equal? (read-all-forms-string "defr r [?a:Nat]") '((defr r (?a:Nat))))
  (check-equal? (read-all-forms-string "def q := rel [?x:Nat] &> foo x")
                '((def q := rel (?x:Nat) $clause-sep foo x))))

(test-case "P4c-2: SPACED never mints — contiguity is the discriminator (§Q8.3)"
  (check-equal? (read-all-forms-string "def x : Int := 5") '((def x : Int := 5)))
  (check-equal? (read-all-forms-string "f x :name") '((f x :name)))
  (check-equal? (read-all-forms-string "[fn [x :0 Int] x]") '((fn (x :0 Int) x))))

(test-case "P4c-2: BRANCH-INITIAL never mints — the local result is empty"
  ;; These two are declared safe-by-construction in the P4c hazard list and
  ;; must NOT be touched: admitting bare `colon` to the trigger would break them.
  (check-equal? (read-all-forms-string "{:a 1}") '(($brace-params :a 1)))
  (check-equal? (read-all-forms-string "schema S\n  :f Int") '((schema S (:f Int)))))

;; ============================================================
;; D4.P4c-2 condition (c) prerequisites — THE TABLE'S MEASURED MISSES
;; ============================================================
;;
;; The rows above pin the table as DESIGNED. These pin what MEASURING it found,
;; and they are the reason the owner scoped P4c-2's close as full unwrap-coverage
;; repair rather than consumer-hardening alone: the enumeration missed FOUR
;; distinct shapes inside a single session, which is the record that disqualifies
;; it as the safety property.
;;
;; ⚠ EVERY expectation below was MEASURED at HEAD before being written, never
;; recalled — the two guessed baselines earlier in this phase both produced pins
;; that failed for the wrong reason.
;;
;; The misses come in TWO DIRECTIONS, and only one of them is a leak:
;;   UNDER-REACH — the table misses a form, `($bcast-step …)` survives into its
;;                 binder position, and the consumer reads it as an extra
;;                 positional parameter. This is the 3-arity class.
;;   OVER-REACH  — the walk unwraps PAST the binder region and silently strips a
;;                 legitimate broadcast out of a BODY. Condition (c) structurally
;;                 CANNOT catch this one: no sentinel survives for a refusal arm
;;                 to see. It is inert only until P4c-3 gives `$bcast-step` a
;;                 consumer, at which point it becomes a silent wrong answer.

;; ---- UNDER-REACH 1: the private-suffix family (a LIVE end-to-end regression) ----

(test-case "P4c-2 (c): private-suffix heads bind too — `defn-` / `def-` / `spec-`"
  ;; `private-form-base` (macros.rkt) normalizes the `-` suffix at PREPARSE,
  ;; strictly AFTER this post-pass — so at unwrap time the head is literally
  ;; `defn-` and the table's `memq` misses. Eleven suffixed heads exist.
  (check-equal? (read-all-forms-string "defn- f [x:Int] x") '((defn- f (x :Int) x)))
  (check-equal? (read-all-forms-string "spec- f [x:Int] -> Int") '((spec- f (x :Int) -> Int)))
  (check-equal? (read-all-forms-string "def- x:Int := 5") '((def- x :Int := 5))))

(test-case "P4c-2 (c): the private-suffix leak is a LIVE REGRESSION — end to end"
  ;; ⚠ THE ONLY END-TO-END REGRESSION P4c-2 INTRODUCED, isolated by an A/B against
  ;; a worktree pinned at 182f1678 (the pre-mint baseline): there it prints
  ;; "priv : Int -> Int defined." and "7 : Int" at ZERO errors; at the mint commit
  ;; it is 2 errors. The corpus A/B could not see it — 161 files, and not one
  ;; combines a private form with a fused annotation.
  ;;
  ;; This pin is END-TO-END on purpose. Every one of the 18 reader-level pins in
  ;; the block above stayed green through this regression, which is the same
  ;; blindness that lets `def x:Int := 5` hold a green datum pin while aborting
  ;; the whole file in production.
  (check-equal? (run-ws "defn- priv [x:Int] x\n[priv 7]\n")
                '("priv : Int -> Int defined." "7 : Int")))

;; ---- UNDER-REACH 2: a form with TWO binder groups ----

(test-case "P4c-2 (c): an implicit-binder group does not consume the param group"
  ;; `scan-for-param-heads` disarms after the FIRST group it meets, so a leading
  ;; `{A}` eats the arming and the real param group leaks. `{A B : Type}` before
  ;; `[x:A]` is idiomatic per prologos-syntax.md § Type annotations, so this is a
  ;; first-class spelling, not a corner.
  (check-equal? (read-all-forms-string "spec f {A} [x:Int] -> Int")
                '((spec f ($brace-params A) (x :Int) -> Int)))
  (check-equal? (read-all-forms-string "defn f {A} [x:Int] x")
                '((defn f ($brace-params A) (x :Int) x))))

;; ---- UNDER-REACH 3: `defmacro` ----

(test-case "P4c-2 (c): `defmacro`'s param group binds — it is in no table"
  ;; A live binding param group (lib/prologos/core.prologos: `defmacro when
  ;; [$cond $body] …`) that appears in none of the three head lists.
  (check-equal? (read-all-forms-string "defmacro when [$c:Int $b] $c")
                ;; ⚠ G2: the sentinel now SURVIVES here. That is NOT a G2 defect —
                ;; measured, `($c :Int $b)` and `($c ($bcast-step :Int) $b)` are BOTH
                ;; three params, so the macro is unmatchable either way and the user
                ;; sees the same "Unbound variable" at the call site. Pre-existing;
                ;; spun out as DEFERRED 50 / chip task_204859b9.
                '((defmacro when ($c ($bcast-step :Int) $b) $c))))

;; ---- UNDER-REACH 4: single-line `$pipe` arms ----

(test-case "P4c-2 (c): a SINGLE-LINE arm group unwraps like the multi-line one"
  ;; ⚠ SPELLING-SPECIFIC, and the existing arm pins above only cover the
  ;; multi-line form — where `$pipe` becomes a SUB-GROUP whose head is `$pipe`,
  ;; so `apply-binder-unwrap`'s explicit arm fires. Written on ONE line the
  ;; `$pipe` stays a flat sibling under `match`, which is not a param head, and
  ;; the arm is never reached. Measured: the multi-line spelling is CORRECT today
  ;; and must stay so; only the flat one leaks.
  (check-equal? (read-all-forms-string "match v | c a:Int -> a")
                '((match v $pipe c a :Int -> a)))
  ;; the idiomatic spelling — already green, pinned here so a fix cannot trade
  ;; one spelling for the other
  (check-equal? (read-all-forms-string "match v\n  | c a:Int -> a")
                '((match v ($pipe c a :Int -> a)))))

;; ---- OVER-REACH: a BODY broadcast must survive ----

(test-case "P4c-2 (c): `let` without `:=` must not strip a body broadcast"
  ;; `unwrap-binders-until-terminator` runs to the END of the list when no
  ;; terminator is found, and `:=` is OPTIONAL in WS `let` — so the body's
  ;; broadcast is silently unwrapped. Measured today: `(let x 5 (users :name))`.
  ;; The binder region here is the name plus an optional fused annotation; the
  ;; value and body are not binders.
  (check-equal? (read-all-forms-string "def z := 0\nlet x 5\n  users:name")
                '((def z := 0) (let x 5 (users ($bcast-step :name)))))
  ;; the `:=` spelling already behaves — pinned so the bound cannot regress it
  (check-equal? (read-all-forms-string "def z := 0\nlet x := 5\n  users:name")
                '((def z := 0) (let x := 5 (users ($bcast-step :name))))))

(test-case "P4c-2 (c): an arms-only `defn` must not strip its arm BODY's broadcast"
  ;; `scan-for-param-heads` stays armed through every SYMBOL, so with no bracket
  ;; group to consume the arming it runs on until it meets ANY list — which for
  ;; an arms-only clause is the body's own `($bcast-step …)`. Arms-only `defn` is
  ;; the PRIMARY multi-arity form per CLAUDE.md, so this is the common shape.
  ;; Measured today: `(defn f ($pipe a -> users :name))` — stripped.
  (check-equal? (read-all-forms-string "defn f\n  | a -> users:name")
                '((defn f ($pipe a -> users ($bcast-step :name)))))
  ;; two arms already behave (arm 1's group consumes the arming) — pinned so the
  ;; fix does not trade the one-arm case for the two-arm case
  (check-equal? (read-all-forms-string "defn f\n  | 0 -> 1\n  | a -> users:name")
                '((defn f ($pipe 0 -> 1) ($pipe a -> users ($bcast-step :name)))))
  ;; and a header param group must still leave the body alone
  (check-equal? (read-all-forms-string "defn f [a]\n  users:name")
                '((defn f (a) (users ($bcast-step :name))))))

;; ============================================================
;; D4.P4c-2 condition (c) — the loud-refusal hardening
;; ============================================================
;;
;; ⚠ THE BINDER GUARDS CANNOT BE PINNED BY A STANDING TEST, and that is the
;; DESIRED end state rather than a gap in the battery. A guard fires only when
;; the reader post-pass binder table MISSES a form; with the table correct, no
;; `$bcast-step` reaches any binder consumer, so there is no input that reaches
;; them. Feeding the leaked shape by hand does not work either — a sexp-mode
;; `(defn f (x ($bcast-step :Int)) x)` goes through the SAME post-pass and is
;; unwrapped before it arrives (probe-verified: it defines `f : Int -> Int` at
;; zero errors).
;;
;; THE VERIFIER IS MUTATION, and it is reproducible in two minutes:
;;   1. in parse-reader.rkt set `binder-param-heads` and `binder-region-heads`
;;      to '()  (or drop a single head to test one row)
;;   2. PLT_CS_COMPILE_LIMIT=1000000 raco make driver.rkt
;;   3. run a file containing `defn a [x:Int] x`, `defr b [x:Int]`,
;;      `def g := [fn [x:Int] x]`, and a `let w:Int 5` block
;;   4. EXPECT: every one reports the guided "…read as a broadcast step, but
;;      this is a BINDER position…" message, per-command, file continuing.
;;      Before the hardening these were four DIFFERENT generic messages, two of
;;      which dumped raw syntax objects at the user.
;;   5. restore parse-reader.rkt and rebuild.
;;
;; That procedure is how the guards were validated, and it is also how the first
;; cut of `bcast-step-datum?` was caught as DEAD CODE (it compared a still-wrapped
;; syntax object to a symbol, so it never returned #t at any site while the suite
;; stayed green). A green suite is not evidence for a tripwire; only mutation is.
;;
;; What IS reachable, and therefore pinned below, is the EXPRESSION-position
;; half — which until now reported a LYING "Unbound variable".

(test-case "G2: an expression broadcast is LIVE at the default — the pin that was INERT"
  ;; ⚠⚠ THIS PIN HAS NOW FLIPPED TWICE, and both flips were the point.
  ;; At P4c-2 it asserted the mint was provably equivalent to NOT minting, because
  ;; `broadcast-enabled-contexts` was `'()` and the post-pass unwrapped uniformly.
  ;; Its own comment said the guided messages were "live code with an empty
  ;; enable-set in front of them", reachable "the moment the first context is
  ;; enabled". G2 removes the enable-set entirely, so that moment is now.
  ;;
  ;; What a user sees is no longer the PRE-MINT "Could not infer type" — it is the
  ;; feature. This is the single clearest before/after in the slice.
  (define r (run-ws "def users := @[{:name \"a\"}]\ndef bad := users:name\n"))
  (check-regexp-match #rx"\\[PVec String\\]" (last r))
  ;; and it must NOT be the sentinel leaking into a user-facing message
  (check-false (regexp-match? #rx"bcast-step" (last r))))

(test-case "P4c-2 (c): the inert path is still PER-COMMAND — the file is not aborted"
  ;; The whole-file-abort guard matters independently of the enable-set: a raise
  ;; at the reader seam loses every command in the file (Q_L4; DEFERRED 31
  ;; records a live instance).
  (define r (run-ws "def users := @[{:name \"a\"}]\ndef bad := users:name\ndef after := 99\nafter\n"))
  (check-equal? (last r) "99 : Int")
  (check-equal? (length r) 4))

(test-case "P4c-2 (c): a zero-payload `($bcast-step)` must not abort the file"
  ;; `unwrap-bcast-step`'s `cadr` was unguarded — a user writing the internal
  ;; head with no payload raised a raw Racket contract violation at READER time,
  ;; outside any per-command handler. THIRD instance of that shape in this track
  ;; (P1a's `$retired-selection`, P4c-2's `apply-binder-unwrap`, and this).
  ;; Found by the P4c-2 adversarial verify.
  (define r (run-ws "def before := 1\ndefn f [$bcast-step] 1\ndef after := 2\nafter\n"))
  (check-equal? (last r) "2 : Int"))

(test-case "P4c-2: the QUOTE bucket declines — it is neither expression nor binder"
  ;; `'` lexes as a loose token with no grouper arm, so it is pushed as a
  ;; SIBLING and the keyword IS byte-adjacent — the mint would fire in
  ;; expression position where no binder unwrap can rescue it. One live corpus
  ;; site (examples/homoiconicity.prologos:96). Declined via the
  ;; `prev-token-reader-form-head?` shape.
  ;; ⚠ baseline MEASURED. My first draft asserted `(quote :hello)` from memory;
  ;; the quote is a LOOSE `|'|` symbol with no grouper arm — which is exactly
  ;; WHY the bucket exists. Second guessed-baseline in this slice; the earlier
  ;; one was `{:0 v}` at P4c-1. Measure the baseline, always.
  (check-equal? (read-all-forms-string "':hello") '((|'| :hello))))

;; ============================================================
;; D4.P4c-3 — the SIXTH step kind, `(@bcast step)` (Q_U7)
;; ============================================================
;; The `ADDING A KIND` recipe in syntax.rkt is the AUTHORITY for this phase, not
;; D4. Its own header records that the FIRST cut of that recipe was
;; SYNTAX-directed and structurally could not see two whole classes (open-coded
;; shape tests; `and`/`if`-shaped dispatchers), leaving five sites wrong — two
;; of them UPSTREAM of the guards. The sixth kind was added THROUGH the recipe
;; and met all thirteen sites with no correction needed.
;;
;; The split these pins encode:
;;   NAME / KEY walks  → ω is TRANSPARENT: delegate to the wrapped step, because
;;                       ω changes container ARITY, not key behaviour.
;;   VALUE walks       → guided NOT-YET: the broadcast semantics land at P4c-4
;;                       with the PVec dispatcher. Delegating there would
;;                       project off the CONTAINER instead of broadcasting over
;;                       it — a silent wrong answer, which is the outcome the
;;                       totality dispatcher exists to prevent.

(test-case "P4c-3: the wrapper classifies, and its payload is recoverable"
  (define b (make-select-bcast 'name))
  (check-equal? b '(@bcast name))
  (check-equal? (select-step-kind b) 'bcast)
  (check-equal? (select-bcast-inner b) 'name)
  ;; extent is STRUCTURAL: the wrapper holds exactly ONE step, so a
  ;; broadcast-of-nothing is unconstructible (Q_U7 ruling 4b restated)
  (check-true (select-bcast-step? b)))

(test-case "P4c-3: ω is KEY-TRANSPARENT in the name walks"
  ;; `users:name` keys `:name` exactly as `users.name` does — NOT #f like an
  ;; ordinal step. Transparent here means DELEGATE, not "contributes nothing".
  (check-equal? (select-step-output-name (make-select-bcast 'name)) 'name)
  (check-equal? (select-branch-top-keys (list (make-select-bcast 'name))) '(name))
  ;; Q_U7's own examples: x:s:t is TWO one-step wrappers, not one two-step
  (check-equal? (map select-step-output-name
                     (list (make-select-bcast 's) (make-select-bcast 't)))
                '(s t))
  ;; users:{a b} — the wrapped step is a terminal sub-block, which contributes
  ;; no single name, exactly as a bare `sub` does
  (check-equal? (select-step-output-name
                 (make-select-bcast (cons '@sub (list (list 'a) (list 'b)))))
                #f))

(test-case "P4c-3: the FOUR [leaf] classifiers see THROUGH the wrapper"
  ;; The recipe flags these as mattering most: they run BEFORE the branch walks
  ;; and answer a silent #f on an unrecognized kind, so a missed arm mis-SORTS
  ;; the branch (keyed vs keyless) with no raise anywhere downstream.
  (check-equal? (select-branch-collapse
                 (list (make-select-bcast (list '@key 'k 'collapse))))
                'collapse)
  (check-true (select-branch-keyless?
               (list (make-select-bcast (list '@key 'k 'dissolve)))))
  ;; and the un-wrapped forms must still behave identically
  (check-equal? (select-branch-collapse (list (list '@key 'k 'collapse))) 'collapse)
  (check-true (select-branch-keyless? (list (list '@key 'k 'dissolve)))))

;; ⚠ THE FOURTEENTH SITE — `select-step-name`, which is OUTSIDE the `ADDING A
;; KIND` recipe's thirteen and was missed because of it. D4's P4c-3 partition
;; names "the two shape-test helpers OUTSIDE the recipe"; only
;; `select-step-cont` was covered, and it was covered by unwrapping at each of
;; its FIVE call sites rather than in the helper.
;;
;; The defect is an ASYMMETRY, which is why no existing pin caught it: the
;; branch CLASSIFIER (`select-branch-collapse`) sees through the wrapper, so the
;; branch is correctly sorted as collapsing — and then the LABEL is extracted
;; from the RAW leaf by `select-step-name`, which is ω-blind and returns the
;; whole `(@bcast …)` list. Measured before the fix:
;;   (select-branch-top-keys (list (make-select-bcast '(@key k collapse))))
;;     ⇒ ((@bcast (@key k collapse)))   -- a LIST where the contract at
;;                                         syntax.rkt:1099 says "a key SYMBOL
;;                                         (keyed sort) or #f"
;;
;; Three call sites share the shape `[else (select-step-name (car (reverse b)))]`
;; inside a `col`-guarded branch: syntax.rkt:1111, reduction.rkt:1773,
;; typing-core.rkt:1051. The latter two are MASKED today — their value walks hit
;; `select-bcast-not-yet` and raise before the label can escape — so they become
;; live exactly when P4c-4 lands the value semantics and removes the raise.
;; syntax.rkt's is live NOW: `select-branch-top-keys` is a pure STATIC key
;; computation feeding the parser's OUTPUT-key duplicate check and its L4
;; sort-homogeneity check, with no value walk to raise first. A non-symbol
;; component is compared by `eq?` in the duplicate check, so it can never match
;; and duplicates go undetected — silent, which is the outcome the totality
;; dispatcher exists to prevent.
;;
;; Fixed in the HELPER, not at the three call sites: a third copy of the unwrap
;; is the F1b.7g drift class this vocabulary has already paid for.

(test-case "P4c-3: `select-step-name` is ω-transparent (the fourteenth site)"
  ;; the helper itself — delegate to the wrapped step, per Q_U7's NAME/KEY rule
  (check-equal? (select-step-name (make-select-bcast 'name)) 'name)
  (check-equal? (select-step-name (make-select-bcast '(@key k collapse))) 'k)
  ;; the un-wrapped forms are unchanged
  (check-equal? (select-step-name 'name) 'name)
  (check-equal? (select-step-name '(@key k collapse)) 'k)
  ;; nested wrappers delegate all the way down. The SURFACE cannot write one
  ;; (extent is one-step, Q_U7), but the REPRESENTATION permits it and P5's
  ;; factoring rewrites branches — the same argument the `[(bcast)]` arm in
  ;; `select-branch-top-keys` is written on.
  (check-equal? (select-step-name (make-select-bcast (make-select-bcast 'name))) 'name))

(test-case "P4c-3: a collapse-terminated ω branch yields a SYMBOL component"
  ;; THE LIVE ONE. Wrapped and plain must agree — the classifier already did.
  (check-equal? (select-branch-top-keys
                 (list (make-select-bcast (list '@key 'k 'collapse))))
                '(k))
  (check-equal? (select-branch-top-keys (list (list '@key 'k 'collapse)))
                '(k))
  ;; and the component is a SYMBOL, not a list — the contract the parser's
  ;; duplicate check and L4 sort check both consume
  (check-true (symbol? (car (select-branch-top-keys
                             (list (make-select-bcast (list '@key 'k 'collapse)))))))
  ;; the rename and synth conts are computed from `col`, not from the raw leaf,
  ;; so they were already ω-safe — pinned so the fix cannot regress them
  (check-equal? (select-branch-top-keys
                 (list (make-select-bcast (list '@key 'k (cons 'collapse-rename 'k2)))))
                '(k2)))

(test-case "P4c-3a: `select-step-cont` is ω-transparent (the fifteenth site)"
  ;; ⚠ THE FIRST CUT OF THIS PIN COULD NOT FAIL. It defined a LOCAL copy of
  ;; parser.rkt's predicate and asserted against the copy, so reverting the
  ;; production fix left it green — a dead tripwire, which this track has already
  ;; recorded as reading like coverage while providing none. It now exercises the
  ;; SHIPPED helper, so reverting the fix turns it red.
  (check-equal? (select-step-cont (make-select-bcast '(@key k dissolve))) 'dissolve)
  (check-equal? (select-step-cont '(@key k dissolve)) 'dissolve)
  (check-equal? (select-step-cont (make-select-bcast '(@key k (collapse-rename . k2))))
                '(collapse-rename . k2))
  ;; a wrapper with no `^` inside still answers #f — transparency must not turn
  ;; parser.rkt's `^`-in-path-access refusal into a blanket one
  (check-equal? (select-step-cont (make-select-bcast 'name)) #f)
  (check-equal? (select-step-cont 'name) #f)
  (check-equal? (select-step-cont '(@sub (a) (b))) #f)
  ;; nested, for the same reason `select-step-name`'s delegation is recursive
  (check-equal? (select-step-cont (make-select-bcast (make-select-bcast '(@key k dissolve))))
                'dissolve)
  ;; and the predicate parser.rkt now actually ships — a bare `ormap` over the
  ;; helper. THE POINT of transparency: no unwrap, no copy, no standing
  ;; obligation on the nine call sites.
  (check-equal? (ormap select-step-cont (list 'a 'b (make-select-bcast '(@key k dissolve))))
                'dissolve)
  (check-equal? (ormap select-step-cont (list 'a 'b (make-select-bcast 'name))) #f)
  (check-equal? (ormap select-step-cont (list 'a 'b '(@key k dissolve))) 'dissolve))

;; ============================================================
;; D4.P4c-4c / G2 — THE ENABLE-SET IS RETIRED; PRESERVATION IS UNCONDITIONAL
;; ============================================================
;; This block WAS the P4c-4a test seam: seven cases exercising a guarded
;; `broadcast-enabled-contexts` parameter. G2 deletes the parameter, so every
;; grant-shaped pin here had to be re-expressed or retired.
;;
;; ⚠ THE TWO THAT MUST NOT BE DELETED, per the P4c-4c mini-audit: the
;; private-suffix normalization pin (its VEHICLE was a grant, but
;; `binder-head-base`'s normalization stays LIVE at three other arms, and this was
;; its ONLY standing coverage — its absence was a measured end-to-end regression
;; at P4c-2), and the ancestor-chain pin (G2 dissolves the grant chain but THREE
;; deep-strippers survive). Both are re-expressed below as binder-BEHAVIOUR pins.
;; Deleting them would have been the silently-vacuous outcome the audit named as
;; worse than a red one.
;;
;; RETIRED outright, because their propositions are now false BY DESIGN:
;;   · "the default is EMPTY and behaviour is unchanged" — behaviour changed, on
;;     purpose; the replacement is the unconditional pin below.
;;   · "the enable-set is GUARDED — a malformed grant cannot abort the file" —
;;     there is no parameter to malform. The hazard is removed at the root rather
;;     than guarded, which is strictly better than the pin it cost.

(test-case "G2: preservation is UNCONDITIONAL — no grant, no parameter"
  ;; The headline. Every one of these was STRIPPED at the production default
  ;; before G2, which is why the feature was reachable only from tests.
  (check-equal? (read-all-forms-string "def q := users:name")
                '((def q := users ($bcast-step :name))))
  (check-equal? (read-all-forms-string "users:name")
                '((users ($bcast-step :name))))
  (check-equal? (read-all-forms-string "defn f [x] [g users:name]")
                '((defn f (x) (g users ($bcast-step :name))))))

(test-case "G2: a FUSED BINDER ANNOTATION still unwraps — the population that must not mint"
  ;; The other half of Q_U18's safety argument. Binder positions are recognized by
  ;; the scanner and unwrap; only the annotation shape survives.
  (check-equal? (read-all-forms-string "defn f [x:Int] x") '((defn f (x :Int) x)))
  (check-equal? (read-all-forms-string "def x:Int := 5") '((def x :Int := 5)))
  ;; and the typed logic var glues to ONE token at the tokenizer, so it cannot
  ;; mint under ANY policy — the structural fact Q_U18 turned on
  (check-equal? (read-all-forms-string "[add ?x:Nat ?y:Nat] = 5N")
                '((= (add ?x:Nat ?y:Nat) ($nat-literal 5)))))

(test-case "G2: `binder-head-base`'s ELEVEN private-suffix spellings still normalize"
  ;; ⚠ RE-EXPRESSED, NOT DELETED. The old pin's vehicle was a grant of `def`
  ;; covering `def-`; G2 removes grants, but the normalizer stays live at the
  ;; `binder-region-heads`, `binder-deep-heads` and `take-param-region` arms.
  ;; Its absence was a MEASURED end-to-end regression at P4c-2 (`defn- f [x:Int] x`
  ;; leaked its annotation into the param group and became 2-arity), and the audit
  ;; flagged this as the most dangerous case to drop. Now pinned on BEHAVIOUR.
  (check-equal? (read-all-forms-string "defn- f [x:Int] x") '((defn- f (x :Int) x)))
  (check-equal? (read-all-forms-string "def- q := users:name")
                '((def- q := users ($bcast-step :name))))
  (check-equal? (read-all-forms-string "spec- f Int -> Int") '((spec- f Int -> Int))))

(test-case "G2: THREE deep-strippers SURVIVE — the chain is not fully dissolved"
  ;; ⚠ RE-EXPRESSED. The old pin asserted that a grant needed the whole ancestor
  ;; chain. G2 removes the grant chain — but "after G2 nothing strips ancestrally"
  ;; is FALSE, and the audit said so explicitly. These three arms still deep-unwrap
  ;; their regions, so a broadcast inside them is still stripped.
  ;;
  ;; ⚠⚠ MY FIRST DRAFT OF THIS PIN WAS VACUOUS: two of its three assertions
  ;; compared `(read-all-forms-string X)` to `(read-all-forms-string X)` — the same
  ;; call on both sides, a TAUTOLOGY that can never fail. Caught before commit,
  ;; and recorded because it is the third vacuity of mine this slice and the
  ;; pattern is identical each time: asserting a shape I had not MEASURED.
  ;; Each assertion below now carries the measured datum, and each is a BROADCAST
  ;; (not a bare annotation) so it fails if the region stops stripping.
  ;;
  ;; (1) the `trait` arm — binder-deep-heads
  (check-equal? (read-all-forms-string "trait T A\n  m [x users:name] : A")
                '((trait T A (m (x users :name) : A))))
  ;; (2) `take-param-region` — a `defn` param region
  (check-equal? (read-all-forms-string "defn f [x:Int] x") '((defn f (x :Int) x)))
  ;; (3) `$pipe` arms — the PATTERN side is a binder region
  (check-equal? (read-all-forms-string "defn g\n  | [c users:name] -> c")
                '((defn g ($pipe (c users :name) -> c))))
  ;; ⭐ THE CONTRAST THAT MAKES THIS DISCRIMINATING: the SAME broadcast in an
  ;; expression position DOES survive. Without this the three above could pass
  ;; under a build where nothing preserves anywhere.
  (check-equal? (read-all-forms-string "defn g\n  | c -> users:name")
                '((defn g ($pipe c -> users ($bcast-step :name))))))

(test-case "G2: a GROUP-HEADED node is still handled, not errored"
  ;; ⚠ RE-EXPRESSED from "the membership test is TOTAL on any head shape". There is
  ;; no membership test any more, but the walk must still be total on a node whose
  ;; head is not a symbol — that was what the totality argument protected.
  (check-equal? (read-all-forms-string "[[a b] users:name]")
                '(((a b) users ($bcast-step :name))))
  (check-equal? (read-all-forms-string "[[a b] c]") '(((a b) c))))

;; ============================================================
;; Q_U18 — the unknown-head default flips to PRESERVE
;; ============================================================
;; Owner ruling 2026-08-02 ("worth the trade"). What makes it safe is STRUCTURAL,
;; not a table: the binder population sharing this shape is the TYPED LOGIC VAR,
;; and `recognize-narrow-var-annot` GLUES `?x:Nat` into ONE TOKEN at the
;; tokenizer, so it can never mint and never reaches the arm as a sentinel.
;;
;; ⚠ THE RECORD THIS CORRECTS: D4 and DEFERRED both said PRESERVE was "refuted
;; from the corpus" by `[add ?x:Nat ?y:Nat] = 5N`. It was not — that line mints
;; NOTHING. The claim was inferred from "it runs 0 errors today" without checking
;; whether it MINTS, and parse-reader.rkt's own comment already said "Immune by
;; construction".

(test-case "Q_U18: the typed logic var is IMMUNE BY CONSTRUCTION — it never mints"
  ;; the load-bearing fact. If this ever fails, the PRESERVE flip is unsafe and
  ;; the whole ruling must be revisited — so it is pinned first and alone.
  (check-equal? (read-all-forms-string "[add ?x:Nat ?y:Nat] = 5N")
                '((= (add ?x:Nat ?y:Nat) ($nat-literal 5))))
  ;; …and identically under a grant of the enclosing head
  (let ()
    (check-equal? (read-all-forms-string "[add ?x:Nat ?y:Nat] = 5N")
                  '((= (add ?x:Nat ?y:Nat) ($nat-literal 5)))))
  ;; the glue survives chaining and the `:w` spelling
  (check-equal? (read-all-forms-string "defr r [?x:Int:Even]") '((defr r (?x:Int:Even))))
  (check-equal? (read-all-forms-string "defr r [?x:w]") '((defr r (?x:w)))))

(test-case "Q_U18: an UNKNOWN head now PRESERVES — application position works"
  ;; the flip itself. Pre-flip this was `(one users :name)` — the sentinel
  ;; blanket-stripped, leaving `one` with TWO arguments.
  (let ()
    (check-equal? (read-all-forms-string "def q := [one users:name]")
                  '((def q := (one users ($bcast-step :name))))))
  ;; and it nests
  (let ()
    (check-equal? (read-all-forms-string "def q := [f [g users:name]]")
                  '((def q := (f (g users ($bcast-step :name))))))))

(test-case "Q_U18: RECOGNIZED heads are untouched by the flip"
  ;; the flip changes only the `[else]` arm, which the scanner's `recognized?`
  ;; guards — so every binder form the walk knows behaves exactly as before.
  (let ()
    (check-equal? (read-all-forms-string "defn f [x:Int] x") '((defn f (x :Int) x)))
    (check-equal? (read-all-forms-string "defr r [?x:Nat]") '((defr r (?x:Nat))))
    (check-equal? (read-all-forms-string "def q:Int := 5") '((def q :Int := 5)))
    (check-equal? (read-all-forms-string "let w:Int 5") '((let w :Int 5)))))

(test-case "Q_U18: the flip is INERT AT DEFAULT — production is unchanged"
  ;; ⚠ AND IT IS INERT IN PRACTICE UNTIL G2. The enable-set's FIRST arm strips
  ;; any node whose own head is not granted, and granting every function name is
  ;; absurd — so the flip alone does NOT unlock application position. G2
  ;; (retiring the enable-set) is the operative half, and the owner ruled G4
  ;; (hold test-only until P4c-4c) with G2 as the recorded lean. Measured:
  (check-equal? (read-all-forms-string "def q := [one users:name]")
                ;; ⚠ G2 LANDED: application position now WORKS unconditionally.
                ;; This line was the pin that proved the flip was INERT; it is now
                ;; the pin that proves it is LIVE.
                '((def q := (one users ($bcast-step :name)))))
  ;; even granting the OUTER head only — the inner node's head is still ungranted
  (let ()
    (check-equal? (read-all-forms-string "def q := [one users:name]")
                  '((def q := (one users ($bcast-step :name)))))))

;; ============================================================
;; D4.P4c-4b — the fold arm + the producer bridge + the not-yet CHANNEL
;; ============================================================
;; The chain, end to end: reader PRESERVES the sentinel (needs a grant) → the
;; fold FUSES it onto its base → the parser CONSTRUCTS `(@bcast step)` → typing
;; REFUSES through the failure slot the walks already thread. The last link is
;; the one that makes this landable: `select-bcast-not-yet` RAISES, and
;; `process-command/solve-guard` catches only `exn:prologos-solve` (deliberately
;; — "any other raise still crashes loudly"), so before this slice the producer
;; bridge would have turned a not-yet into a WHOLE-FILE ABORT.

(define (bcast-e2e src)
  (let ()
    (map (lambda (r) (format "~a" r))
         (process-string-ws (string-append "ns bcast-e2e\ndef users := {:name \"alice\"}\n" src)))))

(test-case "P4c-4b: a broadcast goes END TO END, and the file CONTINUES"
  (define out (bcast-e2e "def q := users:name\ndef after := 42"))
  ;; the broadcast reports as a per-command error…
  ;; ⚠ RE-EXPRESSED AT P4c-4c, not deleted. This pin's proposition is "a
  ;; broadcast refusal is PER-COMMAND and the file continues" — still true and
  ;; still the point. What changed is WHICH refusal: `bcast-e2e`'s subject is a
  ;; MAP, and P4c-4c lands PVec only, so the generic not-yet has been replaced by
  ;; the sharper `bcast-carrier` message naming the carrier and P4d. Matching the
  ;; live message keeps the pin DISCRIMINATING; matching the dead one would have
  ;; made it vacuous.
  ;; ⚠ RE-EXPRESSED AT P4d slice 1: the Map carrier now ADMITS, so the refusal
  ;; moved one layer down — the per-FIELD projection over the String value is
  ;; what fails. Same proposition (per-command, file continues), third message.
  (check-true (ormap (lambda (s) (regexp-match? #rx"not a record, so it has no fields" s)) out)
              (format "expected the per-field projection failure; got ~a" out))
  ;; …and — THE POINT — the command AFTER it still runs. Before the channel fix
  ;; this line was lost with the whole file.
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)
              (format "the file did not continue past the broadcast: ~a" out)))

(test-case "P4c-4b: the payload's THREE sub-cases, two of which would be silent"
  ;; `$bcast-step` carries the token VERBATIM, so the payload is COLON-LEADING
  ;; (`|:name|`) where `$dot-access` carries a bare symbol. Merely stripping the
  ;; colon and handing it to `plain-key?` is silently wrong twice over.
  ;;
  ;; (a) ORDINAL — Q_U16b rules `users:0` a legal ω step. Stripped-and-handed-on
  ;; it would be a NOMINAL key named `0`. ⚠ RE-EXPRESSED AT P4d slice 1: the
  ;; carrier admits and the ordinal reaches the VALUE (a String) — the guided
  ;; ordinal message still proves the step stayed ORDINAL, which is the point.
  (check-true (ormap (lambda (s) (regexp-match? #rx"ordinal `0`" s))
                     (bcast-e2e "def a := users:0")))
  ;; (b) FLATTEN — `ident-continue?` admits `*`, so `tags*` arrives as ONE token
  ;; and no scheme keyed on token TYPE can see the operator. Stripped, it passes
  ;; `plain-key?` as a field LITERALLY NAMED `tags*`. Now loud.
  ;; ⚠ SEAT-MIGRATED at 1b-iii-B2 (the C31 BREAKING pin, re-pointed with its
  ;; reasoning): the parser now MINTS `[(@bcast tags) (@star flatten)]`, so the
  ;; error is the PREFIX's own — `users` has no `:tags` — which still proves
  ;; this pin's proposition: the token SPLIT (the miss names `:tags`, not a
  ;; field literally named `tags*`).
  (let ([out (bcast-e2e "def b := users:tags*")])
    (check-true (ormap (lambda (s) (regexp-match? #rx":tags" s)) out)
                "the star split off — the miss names :tags")
    ;; ⚠ the first cut of this check was over-broad — the error's ECHO renders
    ;; the user's spelling (`users.:tags*`), which is capture-fidelity working,
    ;; not the defect. The defect shape is a FIELD named `tags*` in the miss.
    ;; (That echo is also DEFERRED 113's live reproduction: the hardcoded `.`
    ;; before `:tags` — `users.:tags*` is not a spelling the language has.)
    (check-false (ormap (lambda (s) (regexp-match? #rx"field :tags\\*" s)) out)
                 "…and no miss names a field literally called `tags*`"))
  ;; (c) RE-KEY — `^` routes to the ONE splitter exactly as the `$dot-access`
  ;; twin does, rather than becoming part of a field name.
  ;;
  ;; ⚠⚠ RE-POINTED AT D4.P4d slice 4d. This asserted `#rx"re-keys the OUTPUT"`,
  ;; which FROZE AN ACCIDENT: the ω step landed on the pre-existing DOT refusal
  ;; only because P4c-3a made `select-step-cont` ω-transparent, and this pin's
  ;; own comment used to say so ("it lands on the pre-existing path-access
  ;; refusal") — i.e. it pinned ROUTING, not a decision. Worse, BOTH messages
  ;; open with "re-keys the OUTPUT", so the old assertion could not tell the two
  ;; apart and stayed green straight through the split.
  ;; Q_U19 is now RULED (A) and the wording is the owner's 2026-08-08 split, so
  ;; this pins the DECISION: the ω audience takes the BROADCAST noun, and must
  ;; not borrow the dot one.
  (check-true (ormap (lambda (s) (regexp-match? #rx"broadcast step has no output key" s))
                     (bcast-e2e "def c := users:name^alias")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"field access has no output key" s))
                      (bcast-e2e "def c := users:name^alias"))))

(test-case "G2: the DEFAULT now BROADCASTS — the inverse of the pin it replaces"
  ;; ⚠ INVERTED AT G2. This asserted "no grant, no change": the sentinel was
  ;; unwrapped at the reader and nothing downstream ever saw it. There is no grant
  ;; any more, and the chain runs unconditionally — so the proposition is now the
  ;; opposite, and pinning the old one would have been asserting the feature is off.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns bcast-on\ndef users := {:name \"alice\"}\ndef q := users:name\ndef after := 42")))
  ;; the subject is a MAP, so P4c-4c's carrier refusal fired here — and at P4d
  ;; slice 1 the carrier ADMITS, so the chain now runs even deeper: the
  ;; per-field projection failure is today's proof the chain is live at the
  ;; default. (⚠ RE-EXPRESSED at P4c-4c and again at P4d slice 1.)
  (check-true (ormap (lambda (s) (regexp-match? #rx"not a record, so it has no fields" s)) out)
              (format "the broadcast chain must be live at the default: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4c-4b: `$bcast-step` is an access-sentinel, so it inherits the fold"
  ;; Q_U16 ruling item 2 — membership is what buys all FOUR `rewrite-dot-access`
  ;; seats, because the fold's gate is this predicate's only production consumer.
  ;; It was a P4c-2 deliverable that did not land under a ✅ (DEFERRED 37); it
  ;; read as closed because `broadcast-access?` in that list is the RETIRED
  ;; `$broadcast-access`, a different head.
  (check-true (access-sentinel? '($bcast-step |:name|)))
  (check-true (bcast-step? '($bcast-step |:name|)))
  (check-false (bcast-step? '($dot-access name)))
  ;; the fold fuses onto the base, and the emitted head is NOT a sentinel —
  ;; that is the whole fixpoint obligation (a sentinel-headed result makes
  ;; preparse re-enter and swallow a LEFT sibling per pass)
  (define folded (rewrite-dot-access '(users ($bcast-step |:name|))))
  (check-equal? folded '($select-path users ($bcast-step |:name|)))
  (check-false (access-sentinel? folded))
  ;; and it NESTS one carrier per level, so `a.b:name` composes
  (check-equal? (rewrite-dot-access '(a ($dot-access b) ($bcast-step |:name|)))
                '($select-path ($select-path a b) ($bcast-step |:name|))))

(test-case "P4c-4a: the seam reaches the REAL pipeline, not just the reader harness"
  ;; Level 2. The reader-harness pins above prove the walk; this proves the
  ;; parameter is actually in force through `process-string-ws`, which is the
  ;; door users come through. A surviving sentinel reaches the parser's
  ;; `bcast-step` arm and reports the guided NOT-YET — the first time in this
  ;; track that message has been reachable from a test rather than from a
  ;; mutated build.
  ;; ⚠ RETARGETED AT P4c-4b, and the reason is the slice's whole point. This pin
  ;; originally asserted the PARSER's not-yet on a bare `def q := users:name`.
  ;; Once the fold fuses the sentinel onto its base, the parser takes the
  ;; `$select-path` arm and parses the SUBJECT — so the old spelling now reports
  ;; `Unbound variable users`, because that fixture never defined it. The
  ;; message did not disappear; it MOVED A LAYER, from parse to typing, which is
  ;; exactly what the producer bridge was for. Pinned against a bound subject so
  ;; it proves what it claims: the parameter is in force through the REAL
  ;; pipeline, not just the reader harness.
  (let ()
    (define out (map (lambda (r) (format "~a" r))
                     (process-string-ws
                      "ns seam-l2\ndef users := {:name \"alice\"}\ndef q := users:name")))
    ;; ⚠ RE-EXPRESSED AT P4c-4c and AGAIN at P4d slice 1: the proposition
    ;; ("the parameter is in force through the REAL pipeline") is unchanged and
    ;; is proved by a guided broadcast diagnostic ARRIVING; the diagnostic is
    ;; now the per-field projection failure (the Map carrier admits).
    (check-true (ormap (lambda (s) (regexp-match? #rx"not a record, so it has no fields" s)) out)
                (format "expected the guided per-field failure, got: ~a" out))))

;; ---------------------------------------------------------------------------
;; D4.P4c-4c — the ω VALUE semantics (PVec), the LAWS, and the carrier guards.
;; Failing-test-first. The subject is a PVec deliberately: `bcast-e2e` above is
;; a MAP, and the Map/keyword-row carrier is P4d — reusing it here would pass
;; for the wrong reason and prove nothing (mini-audit wf_a24f3e0f-d84).
;; ---------------------------------------------------------------------------

;; Grant covers `def` (def-position) AND the bare subjects used at top level.
;; ⚠ Bare top-level DOES mint since the Q_U18 PRESERVE flip — D4's "a bare
;; top-level ω is STRIPPED under every grant" was true at 17086a09 and died at
;; e71ef6b8. Pinned here so the corrected fact has a standing test.
(define (pvec-bcast src)
  (let ()
    (map (lambda (r) (format "~a" r))
         (process-string-ws
          (string-append "ns pvec-bcast\ndef xs := @[{:name \"a\"} {:name \"b\"}]\n" src)))))

(test-case "P4c-4c: THE HEADLINE — `xs:name` broadcasts to a PVec of the field"
  (define out (pvec-bcast "def ys := xs:name\nys\ndef after := 42"))
  (check-true (ormap (lambda (s) (regexp-match? #rx"ys : \\[PVec String\\] defined" s)) out)
              (format "expected [PVec String]; got ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"@\\[\"a\" \"b\"\\]" s)) out)
              (format "expected the broadcast VALUE @[\"a\" \"b\"]; got ~a" out))
  ;; the not-yet must be GONE — this is the discharge point its own message names
  (check-false (ormap (lambda (s) (regexp-match? #rx"ω value semantics land" s)) out)
               (format "the not-yet is still firing: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4c-4c: the ORACLE — broadcast agrees with the explicit `pvec-map` spelling"
  ;; The target semantics already exist under the explicit spelling, so this
  ;; slice has an oracle rather than a spec to interpret.
  ;; ⚠ SCOPE OF THE CLAIM, and it has been narrowed TWICE. The first comment said
  ;; "Same type, same value" flatly. The second blamed the tier and named Map,
  ;; dyn-tail and union carriers — the MAP clause is now FALSE (DEFERRED 43
  ;; landed; a Map miss under ω is loud, and that is pinned as direction A).
  ;; What survives is narrower and is a VALUE disagreement, not a loudness one:
  ;; on a PERMISSIVE carrier the ratified WHOLE-NODE ABORT (Q_U7) makes ω yield a
  ;; single `none` for the entire vector, where `pvec-map` preserves the elements
  ;; that hit — `@[1 none]` vs `none`. That is ruled semantics, not a defect, but
  ;; it means this pin asserts agreement only for a CLOSED ROW WHERE EVERY
  ;; ELEMENT HITS, which is exactly this fixture. See DEFERRED for the residual.
  (define out (pvec-bcast "def viaMap := [pvec-map [fn [m] m.name] xs]\ndef viaBcast := xs:name\nviaMap\nviaBcast"))
  (check-equal? (length (filter (lambda (s) (regexp-match? #rx"@\\[\"a\" \"b\"\\] : \\[PVec String\\]" s)) out))
                2
                (format "broadcast and pvec-map must agree in BOTH type and value; got ~a" out)))

(test-case "P4c-4c: BARE TOP-LEVEL ω mints and evaluates (D4's blocking fact #1 is dead)"
  ;; D4 §5.P4c-4c recorded "a bare top-level ω is STRIPPED under EVERY grant" and
  ;; re-scoped the slice around it. TRUE at 17086a09; the Q_U18 PRESERVE flip
  ;; (e71ef6b8) rewrote the [else] arm one commit later and a top-level command's
  ;; head IS the subject symbol. Pinned so it cannot silently revert.
  (define out (pvec-bcast "xs:name"))
  (check-true (ormap (lambda (s) (regexp-match? #rx"@\\[\"a\" \"b\"\\] : \\[PVec String\\]" s)) out)
              (format "bare top-level ω did not evaluate: ~a" out)))

(test-case "P4c-4c: L1 FUSION is a THEOREM — `nested:0:userName` collapses to ONE layer"
  ;; Q_U7: each ω step consumes ONE container layer and re-wraps ONE, so
  ;; fmap∘fmap = fmap arithmetically. ⚠ The discriminator is the TYPE, not the
  ;; value — the non-fusing composition produces a visibly different type, so a
  ;; pin asserting only the value list does not discriminate (mini-audit).
  (define out
    (let ()
      (map (lambda (r) (format "~a" r))
           (process-string-ws
            (string-append
             "ns l1-fusion\n"
             "def nested := @[@[{:userName \"Lisa\"}] @[{:userName \"John\"}]]\n"
             "def flat := nested:0:userName\nflat")))))
  ;; ONE layer — NOT [PVec [PVec String]], which is what naive nesting yields
  (check-true (ormap (lambda (s) (regexp-match? #rx"flat : \\[PVec String\\] defined" s)) out)
              (format "L1 fusion failed — expected ONE layer [PVec String]; got ~a" out))
  (check-false (ormap (lambda (s) (regexp-match? #rx"\\[PVec \\[PVec String\\]\\]" s)) out)
               (format "the composition did NOT fuse — two layers survived: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"@\\[\"Lisa\" \"John\"\\]" s)) out)
              (format "expected the fused VALUE; got ~a" out)))

(test-case "P4c-4c: the ORDINAL band broadcasts (Q_U16b — `:0` is an ω step, not a key named 0)"
  (define out
    (let ()
      (map (lambda (r) (format "~a" r))
           (process-string-ws
            (string-append
             "ns ord-bcast\n"
             "def nested := @[@[\"x\" \"y\"] @[\"p\" \"q\"]]\n"
             "def heads := nested:0\nheads")))))
  (check-true (ormap (lambda (s) (regexp-match? #rx"heads : \\[PVec String\\] defined" s)) out)
              (format "expected [PVec String]; got ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"@\\[\"x\" \"p\"\\]" s)) out)
              (format "expected the per-element index-0; got ~a" out)))

(test-case "P4c-4c: a still-unsupported carrier under ω refuses PER-COMMAND — never a whole-file abort"
  ;; ⚠ RE-EXPRESSED AT P4d slice 1 (Map admitted) and AGAIN at slice 2 (the
  ;; het tuple admitted): the still-refusing carrier is now the LIST. Same
  ;; proposition throughout: the refusal goes through the failure slot, and
  ;; the file continues.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns carrier-refusal\ndef xs := '[{:t 1} {:t 2}]\ndef q := xs:t\ndef after := 42")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)
              (format "THE FILE DID NOT CONTINUE — a raise escaped: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"needs a PVec, Map, tuple, or closed keyword-row subject" s)) out)
              (format "expected the carrier-accurate refusal: ~a" out)))

;; ---------------------------------------------------------------------------
;; D4.P4c-4c (DEFERRED 43, folded into the slice by owner ruling 2026-08-04) —
;; THE STRICTNESS TIER MUST FOLLOW THE ω UNWRAP.
;;
;; The tier is solved from the SUBJECT of an `expr-select` node. Non-ω nesting
;; is safe because Q_U13's NEST encoding gives every level its OWN node with its
;; own tier (verified: `x.inner.a` over a Map is LOUD). ω is different — it
;; unwraps INSIDE one node, below the tier decision — so the tier saw
;; `[PVec [Map K V]]`, which is not `expr-Map?`, and the miss went silent.
;;
;; ONE root cause, TWO OPPOSITE symptoms, and the slice's own `pvec-map` oracle
;; disagreed with it in BOTH directions. Both are pinned.
;; ---------------------------------------------------------------------------

(define (tier-probe src)
  (let ()
    (map (lambda (r) (format "~a" r)) (process-string-ws src))))

(test-case "P4c-4c/D43 direction A: a Map miss under ω is LOUD, as it is through `.` and `pvec-map`"
  (define out (tier-probe (string-append
                           "ns d43a\n"
                           "def ms : [PVec [Map Keyword Int]] := @[{:a 1} {:zzz 9}]\n"
                           "def viaB := ms:a\nviaB\n"
                           "def after := 42")))
  ;; BEFORE the fix this was `<error> : [PVec Int]` at ZERO errors, while both
  ;; `mm.a` and `[pvec-map [fn [m] m.a] ms]` panicked on the same data.
  (check-true (ormap (lambda (s) (regexp-match? #rx"key :a not found" s)) out)
              (format "the Map miss under ω must be LOUD; got ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"available keys" s)) out)
              (format "the loud miss must name the available keys; got ~a" out))
  ;; and it stays PER-COMMAND — the file continues
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4c-4c/D43 direction A: ω agrees with the `pvec-map` ORACLE on a Map carrier"
  ;; This is the general form of the claim the ORACLE pin above deliberately
  ;; does NOT make (its fixture is a closed row where every element hits).
  (define out (tier-probe (string-append
                           "ns d43a2\n"
                           "def ms : [PVec [Map Keyword Int]] := @[{:a 1} {:zzz 9}]\n"
                           "def viaM := [pvec-map [fn [m] m.a] ms]\nviaM\n"
                           "def viaB := ms:a\nviaB\n"
                           "def after := 42")))
  ;; both spellings must report the SAME miss — neither silently swallowing it
  (check-true (>= (length (filter (lambda (s) (regexp-match? #rx"key :a not found" s)) out)) 2)
              (format "ω and pvec-map must agree that this miss is loud; got ~a" out)))

(test-case "P4c-4c/D43 direction B: a permissive (union) carrier under ω DEGRADES, it does not panic"
  ;; The mirror failure: `champ-of` panicked unconditionally on a non-map,
  ;; where the language's permissive tier degrades quietly. Its top-level
  ;; sibling already tier-forks; `champ-of` did not.
  ;; ⚠ THIS PIN WAS VACUOUS IN ITS FIRST DRAFT and I caught it before committing —
  ;; the obvious spelling `@[w1 w2]` with mixed element types infers a HET TUPLE
  ;; `⟨[Map Keyword Int] Int⟩`, not a PVec, so it refuses at the P4c-4c carrier
  ;; gate and NEVER REACHES `champ-of`. The check-false then passed trivially.
  ;; The EXPLICIT union annotation is what actually drives a non-map element into
  ;; the ω walk. Same vacuity class the mini-audit flagged one slice ago; pinned
  ;; with the spelling that exercises the code, plus a positive assertion so it
  ;; cannot go quiet again.
  (define out (tier-probe (string-append
                           "ns d43b\n"
                           "def u1 : <[Map Keyword Int] | Int> := 7\n"
                           "def ws : [PVec <[Map Keyword Int] | Int>] := @[u1]\n"
                           "def r := ws:a\nr\n"
                           "def after := 42")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"invariant violation|is not a map at runtime" s)) out)
               (format "a permissive carrier must DEGRADE, not panic; got ~a" out))
  ;; ⚠ ANTI-VACUITY, AND MY FIRST GUARD DID NOT DISCRIMINATE. I claimed a
  ;; "positive assertion so it cannot go quiet again" while asserting
  ;; `<error> : [PVec Int]` — which the P4c-4c CARRIER-REFUSAL path also prints,
  ;; so both vacuous fixtures (het tuple, bare Map) satisfied it. The real
  ;; discriminator is that the live fixture BINDS its def and emits NO error
  ;; struct, where every refusal path leaves it UNBOUND. Verified against both
  ;; vacuous spellings.
  ;; ⚠⚠ INVERTED AT D4.P4d slice 3, DELIBERATELY. This fixture's union has a
  ;; NON-OFFERING, NON-Nil component (`Int`), which the keys-⋂ gate now REFUSES
  ;; at typing — so the ω walk never reaches `champ-of` and the permissive
  ;; degradation this pin was written to prove is UNREACHABLE THROUGH A UNION
  ;; CARRIER. The proposition did not become false; its subject disappeared.
  ;; What remains true and worth pinning is the OTHER half of the same ruling:
  ;; the refusal is a per-command VALUE, not a panic and not a whole-file abort.
  ;; The permissive-degradation proposition survives on the SINGLE-GET polarity,
  ;; pinned by the cross-carrier sibling test-case below (`ua.a`/`ub.a`/`us.a`),
  ;; which slice 3 deliberately left untouched.
  (check-true (ormap (lambda (s) (regexp-match? #rx"EVERY union component" s)) out)
              (format "expected the keys-⋂ refusal naming the component; got ~a" out))
  (check-false (ormap (lambda (s) (regexp-match? #rx"panic" s)) out)
               (format "a refusal must not panic: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)
              (format "the file must continue; got ~a" out)))

(test-case "P4c-4c/D43: the PERMISSIVE degradation agrees across carriers — and reaches PRODUCTION"
  ;; ⭐ THE REGRESSION THE ADVERSARIAL VERIFY CAUGHT, pinned so it cannot return.
  ;; NO GRANT — this is the ordinary dot path at the production default, which is
  ;; why DEFERRED 43's "not reachable in production" rationale was FALSE.
  ;; The `expr-select` entry admits **rrb** subjects into `select-reduce` before
  ;; the `definitely-not-map?` fork, and `expr-rrb?` is not a member of that
  ;; predicate (only `expr-hset?` is) — so a union whose runtime value is a PVec
  ;; reaches `champ-of` on a key step. It used to PANIC "invariant violation",
  ;; which was itself wrong (the union's Map branch is why typing admitted `.a`).
  ;; My first fix degraded it to `<error>`, giving a THIRD answer to a two-answer
  ;; question. All three siblings must agree.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    (string-append
                     "ns d43prod\n"
                     "def ua : <[Map Keyword Int] | Int> := 7\n"
                     "def ub : <[Map Keyword Int] | [PVec Int]> := @[1 2 3]\n"
                     "def us : <[Map Keyword Int] | [Set Int]> := #{1 2}\n"
                     "ua.a\nub.a\nus.a\n"
                     "def after := 42"))))
  (check-equal? (length (filter (lambda (s) (regexp-match? #rx"^none : Int$" s)) out))
                3
                (format "all three union-non-map carriers must degrade to `none`; got ~a" out))
  (check-false (ormap (lambda (s) (regexp-match? #rx"invariant violation" s)) out)
               (format "no invariant-violation panic on a permissive union; got ~a" out)))

(test-case "P4c-4c/D43: the tier peel does NOT over-fire — a closed row keeps its STATIC miss"
  ;; Guard against the fix over-reaching: a closed record's miss is caught
  ;; statically and must NOT become a runtime tier assertion.
  (define out (tier-probe (string-append
                           "ns d43c\n"
                           "def ms := @[{:name \"a\"}]\n"
                           "def bad := ms:nope\n"
                           "def after := 42")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"not found at runtime|invariant violation" s)) out)
               (format "a closed-row miss must stay STATIC; got ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

;; ---------------------------------------------------------------------------
;; D4.P4c-4c / G2 — THE PREPARSE SEAM IS GUARDED (owner ruling 2026-08-05,
;; "go with B"). A raise anywhere in preparse's per-form pass is now converted
;; to a per-command error VALUE instead of aborting the whole file.
;;
;; ⚠ WHY THIS EXISTS. G2 makes the `$bcast-step` sentinel survive into forms that
;; preparse CONSUMES — `require`, `ns`, `schema`, `foreign` — whose recognizers
;; raise on a shape they do not know. Measured as a REGRESSION against a pre-G2
;; build: `require [prologos::data::nat:refer [add]]` went from 0 errors to an
;; abort that took every command in the file with it, `before` included.
;;
;; That is the FIFTH instance of `pipeline.md` § "A Raise on the Parse/Expansion
;; Path Is a WHOLE-FILE Abort" in this track, and the owner ruled the STRUCTURAL
;; fix (option B) over enumerating directive heads (option A): an enumeration
;; leaves the next sentinel to rediscover the same class, which is exactly how
;; the first four happened.
;;
;; ⚠ ZERO corpus sites use a fused directive keyword — which is precisely why the
;; full suite, all five acceptance files AND the corpus A/B were blind to it. The
;; adjacent population is ~2400 spaced occurrences, each one deleted space away.
;; ---------------------------------------------------------------------------

(define (abort-probe src)
  (map (lambda (r) (format "~a" r))
       (process-string-ws (string-append "ns abrt\ndef before := 1\n" src "\ndef after := 42"))))

(test-case "G2/B: a fused directive keyword is a PER-COMMAND error, not a whole-file abort"
  ;; The signature of the bug this closes is EMPTY output — not even `before`.
  ;; So the load-bearing assertion is that BOTH neighbours survive.
  (for ([src (in-list (list "require [prologos::data::nat:refer [add]]"
                            "schema Person:name String"))])
    (define out (abort-probe src))
    (check-true (ormap (lambda (s) (regexp-match? #rx"before : Int defined" s)) out)
                (format "WHOLE-FILE ABORT — the form BEFORE it was lost: ~a → ~a" src out))
    (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)
                (format "the file did not continue past ~a: ~a" src out))))

(test-case "G2/B: the guarded seam still REPORTS — it degrades, it does not swallow"
  ;; ⚠ The failure mode of a guard is silence. `with-handlers … void` at three
  ;; earlier preparse passes already swallows; this seat must NOT join them, or
  ;; the fix trades a loud abort for a silent wrong answer, which is worse.
  (define out (abort-probe "schema Person:name String"))
  (check-true (ormap (lambda (s) (regexp-match? #rx"keyword field name|preparse" s)) out)
              (format "the error must still be REPORTED, not swallowed: ~a" out)))

(test-case "G2/B: the SPACED spellings are untouched"
  ;; The control. If these move, the guard is doing something it should not.
  (define out (abort-probe "require [prologos::data::nat :refer [add]]"))
  (check-true (ormap (lambda (s) (regexp-match? #rx"before : Int defined" s)) out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out))
  (check-false (ormap (lambda (s) (regexp-match? #rx"preparse|Unknown imports" s)) out)
               (format "the spaced spelling must produce NO diagnostic: ~a" out)))

;; ---------------------------------------------------------------------------
;; D4.P4d-0 slice 2 — THE SITE-LOCAL PARSER GUARD (owner ruling 2026-08-05).
;; parser.rkt's `$bcast-step` fold arm does `(symbol->string (cadr it))` with no
;; shape guard — a WHOLE-FILE ABORT reachable at HEAD by hand-written sentinels,
;; and sitting directly on the path the `:{` mint (slice 3) must traverse: the
;; real mint makes the payload a LIST. Found by the P4d-0 mini-audit
;; (wf_e15a1ef6-dfb), whose critic named it "the actual first blocker, named in
;; neither DEFERRED 42 nor 46". The CLASS-level parse-path guard is DEFERRED 56,
;; its own slice; this is the arm the phase cannot proceed without.
;; ---------------------------------------------------------------------------

(define (bcast-payload-probe form)
  (map (lambda (r) (format "~a" r))
       (process-string-ws
        (string-append "ns bpp\ndef before := 1\ndef m := {:a 1}\n" form "\ndef after := 42"))))

(test-case "P4d-0: a malformed $bcast-step payload is PER-COMMAND, not a whole-file abort"
  ;; The abort signature is EMPTY output — `before` lost too. So the load-bearing
  ;; assertion on every shape is that BOTH neighbours survive.
  (for ([form (in-list (list "m{[$bcast-step [a b]]}"    ;; list payload — the shape the mint will mint
                             "m{[$bcast-step 5]}"        ;; number payload
                             "m{[$bcast-step]}"))])      ;; NO payload — the (cadr it) abort
    (define out (bcast-payload-probe form))
    (check-true (ormap (lambda (s) (regexp-match? #rx"before : Int defined" s)) out)
                (format "WHOLE-FILE ABORT — `before` was lost: ~a → ~a" form out))
    (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)
                (format "the file did not continue past ~a: ~a" form out))
    ;; and it must REPORT, not swallow — the guard-that-silences is worse
    (check-true (ormap (lambda (s) (regexp-match? #rx"broadcast step" s)) out)
                (format "the refusal must be reported: ~a → ~a" form out))))

;; ---------------------------------------------------------------------------
;; D4.P4d-0 slices 3+4 — THE `:{…}` MINT (DEFERRED 42) + THE SUB-INNER LIFT
;; (DEFERRED 46, Q_U20). Landed TOGETHER: minting without the lift would turn
;; an honest "Unbound variable" into carrier-dependent silent accepts.
;; ---------------------------------------------------------------------------

(test-case "P4d-0: `users:{t r}` MINTS the wrapping datum — Q_U7's second canonical example"
  (check-equal? (read-all-forms-string "users:{t r}")
                '((users ($bcast-step ($select-brace t r)))))
  ;; nests after an ordinal ω — the mixed-mint shape from the corpus
  (check-equal? (read-all-forms-string "users:0:{userName}")
                '((users ($bcast-step :0) ($bcast-step ($select-brace userName))))))

(test-case "P4d-0: the mint keys on the colon GLUED TO THE OPENER — the near-misses must not move"
  ;; ⚠ THE DISCRIMINATOR THE AUDIT NAMED AS REQUIRED: `def b: [List Nat]` (colon
  ;; glued to the NAME, space before the opener) works today; base-adjacency
  ;; alone would break it. Each expectation below is the MEASURED HEAD datum.
  (check-equal? (read-all-forms-string "users :{t r}")
                '((users : ($select-brace t r))))          ;; spaced colon: unchanged
  ;; ⚠ my first draft of this assertion compared the call TO ITSELF — the same
  ;; tautology class caught twice already this arc. MEASURED datum below.
  (check-equal? (read-all-forms-string "def b: [List Nat] := '[3N 4N]")
                '((def b : (List Nat) := ($list-literal ($nat-literal 3) ($nat-literal 4)))))
  (check-equal? (read-all-forms-string "defn f [x: Int] : Int x")
                '((defn f (x : Int) : Int x)))
  (check-equal? (read-all-forms-string "x{a b}")
                '((x ($select-brace a b))))                ;; plain select block: unchanged
  (check-equal? (read-all-forms-string "{A : Type}")
                '(($brace-params A : Type))))              ;; spaced implicit binder: unchanged

(test-case "P4d-0/Q_U20: `xs:{a b}` NARROWS per element — a PVec of assembled rows"
  (define out
    (map (lambda (r) (format "~a" r))
         (process-string-ws
          (string-append "ns su1\n"
                         "def xs := @[{:a 1 :b \"x\" :c true} {:a 2 :b \"y\" :c false}]\n"
                         "def ys := xs:{a b}\nys\ndef after := 42"))))
  (check-true (ormap (lambda (s) (regexp-match? #rx"ys : \\[PVec \\{:a Int :b String\\}\\] defined" s)) out)
              (format "expected the NARROWED row type; got ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx":a 1" s)) out)
              (format "expected the narrowed VALUES; got ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-0/Q_U20: the CONVERSE holds — a symbol inner still EXTRACTS"
  ;; The audit's warning: re-pointing the lift at the assemble machinery
  ;; wholesale would turn `xs:a` into `[PVec {:a Int}]`. Pin the extract.
  (define out
    (map (lambda (r) (format "~a" r))
         (process-string-ws
          "ns su2\ndef xs := @[{:a 1 :b \"x\"}]\ndef ys := xs:a\nys")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"ys : \\[PVec Int\\] defined" s)) out)
              (format "a symbol inner must EXTRACT, not assemble: ~a" out)))

(test-case "P4d-0: an EMPTY `:{}` refuses PER-COMMAND, and the file continues"
  (define out
    (map (lambda (r) (format "~a" r))
         (process-string-ws
          "ns su3\ndef before := 1\ndef xs := @[{:a 1}]\ndef q := xs:{}\ndef after := 42")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"before : Int defined" s)) out)
              (format "whole-file abort on empty :{}: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

;; ---------------------------------------------------------------------------
;; D4.P4d-0 — THE TWO BLOCKING FIXES from the adversarial verify (wf_7d93efe5).
;; Both were invisible to the full suite, the acceptance files AND the corpus
;; A/B, because no test or corpus file spells `^:{` or a binder `:{`.
;; ---------------------------------------------------------------------------

(test-case "P4d-0/B1: dissolve + ω-sub in mixed keyed company is PER-COMMAND, not an abort"
  ;; `select-branch-top-keys`'s bcast arm spliced the sub's inner keys where the
  ;; branch walks contribute ONE KEYLESS component; the drift leaked past L4 and
  ;; `select-assemble-row` sorted a #f label — symbol<?: contract violation,
  ;; whole file lost. Now: top-keys says (#f), L4 refuses honestly.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns b1p\ndef before := 1\ndef x := {:k 5 :users @[{:a 1 :b 2}]}\nx{k users^:{a b}}\ndef after := 42")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"before : Int defined" s)) out)
              (format "WHOLE-FILE ABORT: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"mixed keyed/keyless" s)) out)
              (format "expected the honest L4 refusal: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-0/B1: the ORDER-SWAPPED sibling no longer silently DROPS the kept key"
  ;; `x{users^:{a b} k}` typed ⟨…⟩ and silently discarded `:k` at 0 errors —
  ;; the same top-keys root, grade 2. Now the honest mixed-sorts refusal.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns b1q\ndef x := {:k 5 :users @[{:a 1 :b 2}]}\ndef r := x{users^:{a b} k}\ndef after := 42")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"r : ⟨" s)) out)
               (format "the kept key must not be silently demoted to a tuple: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"mixed keyed/keyless|after : Int defined" s)) out)))

(test-case "P4d-0/B2: a `:{` in BINDER position refuses LOUDLY — it must never define"
  ;; `unwrap-bcast-step` unwrapped ANY pair payload, injecting a naked
  ;; $select-brace past every refusal arm: `defn f [x:{:a Int}] x` silently
  ;; DEFINED a garbled Pi at zero errors. Symbol-only unwrap restores the loud
  ;; per-command refusal, for defn AND defr.
  (for ([src (in-list (list "defn f [x:{:a Int}] x" "defn f2 [x:{Int}] x" "defr foo2 [?x:{a}]"))])
    (define out (map (lambda (r) (format "~a" r))
                     (process-string-ws (string-append "ns b2p\ndef before := 1\n" src "\ndef after := 42"))))
    (check-false (ormap (lambda (s) (regexp-match? #rx"defined\\." s))
                        (filter (lambda (s) (not (regexp-match? #rx"before|after" s))) out))
                 (format "~a must NOT define anything: ~a" src out))
    (check-true (ormap (lambda (s) (regexp-match? #rx"BINDER position|expected symbol" s)) out)
                (format "~a must refuse with a guided message: ~a" src out))
    (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out))))

;; ---------------------------------------------------------------------------
;; D4.P4d slice 0 — the pvec-literal homogeneity probe must not read
;; COERCIBILITY as SAMENESS. unify's Record↔Map arms (unify.rkt, the F1 s2
;; check-mode subsumption pair) fire in EITHER argument order, and the probe
;; consumed unify as an EQUALITY test — so `@[record map]` classified
;; homogeneous with the FIRST element's type (order-dependent), and a
;; broadcast over it produced `<error> : [PVec Int]` at ZERO errors (the
;; buried-error-in-an-output-slot class). Found by the P4d opening audit
;; (wf_4bc76d94-a2d), re-verified on the main thread. Design: D4 §5.P4d
;; slice 0. The fix: the probe requires unify-ok AND conv (definitional
;; equality on normal forms) — coercible-but-different pairs roll back to the
;; honest 'nat row.
;; ---------------------------------------------------------------------------

(test-case "P4d-s0: a het literal with a Map element forms the TUPLE — record-first"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s0a\ndef r1 := {:a 2 :b 3}\ndef m1 : [Map Keyword Int] := {:a 1}\ndef mixed := @[r1 m1]")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"mixed : \\[PVec" s)) out)
               (format "the FIRST element's type must not win — coercibility is not sameness: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"mixed : ⟨\\{:a Int :b Int\\} \\[Map Keyword Int\\]⟩ defined" s)) out)
              (format "expected the honest het tuple: ~a" out)))

(test-case "P4d-s0: map-first gives the SAME classification — order-independence"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s0b\ndef r1 := {:a 2 :b 3}\ndef m1 : [Map Keyword Int] := {:a 1}\ndef rev := @[m1 r1]")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"rev : \\[PVec" s)) out)
               (format "map-first must not collapse either — the literal's class cannot depend on element order: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"rev : ⟨\\[Map Keyword Int\\] \\{:a Int :b Int\\}⟩ defined" s)) out)
              (format "expected the honest het tuple, reversed row: ~a" out)))

(test-case "P4d-s0: broadcasting the mixed literal is the honest carrier refusal, never a buried <error>"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s0c\ndef r1 := {:a 2 :b 3}\ndef m1 : [Map Keyword Int] := {:a 1}\ndef mixed := @[r1 m1]\nmixed:b\ndef after := 42")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"<error>" s)) out)
               (format "an <error> value escaped into an output slot at zero errors: ~a" out))
  ;; ⚠ RE-EXPRESSED AT P4d slice 2: the mixed tuple now ADMITS (het carrier
  ;; live); position 1 is a Map, so the tier OR asserts and the runtime miss
  ;; (m1 lacks :b) aborts LOUDLY — the C9 (a) discriminator. If the SECOND
  ;; gate (the tier peel) were ever un-widened, this pin catches the silent
  ;; permissive variant.
  (check-true (ormap (lambda (s) (regexp-match? #rx"error|panic" s)) out)
              (format "expected the LOUD runtime abort: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)
              (format "the refusal must be per-command: ~a" out)))

(test-case "P4d-s0 guard: homogeneous literals still collapse — concrete and meta-solved"
  ;; The conv conjunct must not break meta-homogeneity: unify SOLVES the metas,
  ;; nf resolves them, conv compares the resolved forms (re-nf'd per pair —
  ;; earlier iterations may solve metas INSIDE the first element's type).
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s0d\ndef homog := @[1 2 3]\ndef nn := @[none none]")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"homog : \\[PVec Int\\] defined" s)) out)
              (format "concrete homogeneous collapse must survive: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"nn : \\[PVec \\[prologos::data::option::Option _\\]\\] defined" s)) out)
              (format "meta-solved homogeneous collapse must survive: ~a" out)))

(test-case "P4d-s0 guard: check-mode subsumption is UNTOUCHED — records still flow into a Map annotation"
  ;; The F1 s2 coercion itself (record-subtypes-map?) serves CHECK mode and
  ;; stays; only the probe's equality question changed. Distinct keys on
  ;; purpose — the subsumption is per-element against the annotation.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s0e\ndef ms : [PVec [Map Keyword Int]] := @[{:a 1} {:b 2}]")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"ms : \\[PVec \\[Map Keyword Int\\]\\] defined" s)) out)
              (format "annotation-driven subsumption must survive the probe fix: ~a" out)))

(test-case "P4d-s0 guard: the record↔PVec sibling pair stays honest (already het at HEAD)"
  ;; The record-subtypes-pvec? coercion pair did NOT reproduce the bug from
  ;; source (probed at the audit); pinned so the probe-level fix keeps it that
  ;; way rather than trusting the accident.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s0f\ndef ms : [PVec <Int | String>] := @[1 \"a\"]\ndef mixed2 := @[ms @[1 \"a\"]]")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"mixed2 : ⟨\\[PVec Int \\| String\\] ⟨Int String⟩⟩ defined" s)) out)
              (format "the tuple/PVec mix must stay a het tuple: ~a" out)))

;; ---------------------------------------------------------------------------
;; D4.P4d slice 0, round 2 — the adversarial verify's findings (wf_9d8f105c).
;; (1) BLOCKING: conv was spelling-sensitive on UNIONS while the engine's own
;;     equality is set-like (unify-union-components sorts + dedups) — the conv
;;     conjunct reclassified `@[[the <Int|String> 1] [the <String|Int> "x"]]`
;;     as a het tuple. conv-nf gained a union arm (mutual containment).
;; (2) The CLASS had three members in ONE function: the list-literal and
;;     map-literal-KEYS probes carried the same unify-as-equality defect,
;;     both reproduced from source (computed keys `{[expr] val}` make key
;;     types arbitrary). Same conjunct landed at both; the map-keys arm also
;;     gained the rollback wrapper its siblings already had.
;; ---------------------------------------------------------------------------

(test-case "P4d-s0/U: spelled-differently unions still collapse — conv agrees with the engine's set-like equality"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s0u\ndef a := [the <Int | String> 1]\ndef b := [the <String | Int> \"x\"]\ndef v := @[a b]\ndef d1 := [the <Int | Int | String> 1]\ndef v2 := @[d1 b]")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"v : \\[PVec Int \\| String\\] defined" s)) out)
              (format "component ORDER must not make a union pair het: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"v2 : \\[PVec Int \\| Int \\| String\\] defined" s)) out)
              (format "component DUPLICATION must not make a union pair het: ~a" out)))

(test-case "P4d-s0/B1: computed map KEYS of coercible-but-different types refuse, order-independently"
  (define src-common "ns s0k~a\ndef m : [Map Keyword Int] := {:a 1}\nspec idm [Map Keyword Int] -> [Map Keyword Int]\ndefn idm [x] x\n")
  (for ([tag (in-list '(1 2))]
        [lit (in-list (list "def x1 := {{:b 2} \"rec\" [idm m] \"map\"}"
                            "def x2 := {[idm m] \"map\" {:b 2} \"rec\"}"))])
    (define out (map (lambda (r) (format "~a" r))
                     (process-string-ws (string-append (format src-common tag) lit "\ndef after := 42"))))
    (check-false (ormap (lambda (s) (regexp-match? #rx"x[12] : \\[Map" s)) out)
                 (format "the FIRST key's type must not win (~a): ~a" lit out))
    (check-true (ormap (lambda (s) (regexp-match? #rx"Could not infer type" s)) out)
                (format "expected the key-conflict refusal (~a): ~a" lit out))
    (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out))))

(test-case "P4d-s0/B2: a list literal with a Map element forms the honest 'nat row, both orders"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s0l\ndef m : [Map Keyword Int] := {:a 1}\ndef xs := '[{:b 2} m]\ndef ys := '[m {:b 2}]")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"xs : ⟨\\{:b Int\\} \\[Map Keyword Int\\]⟩ defined" s)) out)
              (format "record-first must not claim a List of the first element's type: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"ys : ⟨\\[Map Keyword Int\\] \\{:b Int\\}⟩ defined" s)) out)
              (format "map-first must not collapse either: ~a" out)))

(test-case "P4d-s0 guard: three-element meta chain still collapses (per-pair nf, not hoisted)"
  ;; The comment's stated hazard made testable: pair 1 solves the metas
  ;; ([Option ?A] vs [Option Int]); pair 2 compares t0 AGAINST A LATER element
  ;; and must see the SOLVED form — a hoisted nf of t0 would compare stale.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s0t\ndef trio := @[none [some 1] none]")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"trio : \\[PVec \\[prologos::data::option::Option Int\\]\\] defined" s)) out)
              (format "the meta-solving chain must survive the conv conjunct: ~a" out)))

;; ---------------------------------------------------------------------------
;; D4.P4d slice 1 — the keyword-row + Map CARRIERS (design: D4 §5.P4d).
;; Keys preserved: a keyword-row broadcasts per-field (row out, presence/tail/
;; order carried); a genuine Map re-wraps uniform ([Map K proj(V)]). The tier
;; peel extends per-carrier (row = any-field-reaches-Map ⇒ assert — the
;; mini-C9, conservative direction only). Ordinal inners apply to VALUES
;; uniformly (no carrier-key indexing exists to refuse — the lean-1 premise
;; dissolved at implementation; recorded in D4).
;; ---------------------------------------------------------------------------

(test-case "P4d-s1: keyword-row broadcast — keys preserved as a ROW"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s1a\ndef regions := {:eu {:host \"eu.example.com\" :port 443} :us {:host \"us.example.com\" :port 443} :ap {:host \"ap.example.com\" :port 8443}}\nregions:host")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"\\{:ap String :eu String :us String\\}" s)) out)
              (format "expected the projected ROW type with the subject's keys: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx":eu \"eu\\.example\\.com\"" s)) out)
              (format "expected the keyed VALUE: ~a" out)))

(test-case "P4d-s1: genuine-Map broadcast — uniform re-wrap"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s1b\ndef mm : [Map Keyword [Map Keyword String]] := {:a {:host \"x\"} :b {:host \"y\"}}\nmm:host")))
  ;; ⚠ anchored on the RESULT line (the verify found the first cut VACUOUS —
  ;; the def echo `[Map Keyword [Map Keyword String]]` CONTAINS the fragment).
  (check-true (ormap (lambda (s) (regexp-match? #rx"\"x\".* : \\[Map Keyword String\\]" s)) out)
              (format "expected the keyed VALUES at the uniform type: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx":a \"x\"" s)) out)
              (format "keys must be preserved: ~a" out)))

(test-case "P4d-s1: a per-field STATIC miss refuses per-command (closed rows)"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s1c\ndef r := {:eu {:host \"e\"} :us {:port 1}}\nr:host\ndef after := 42")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"needs a PVec subject" s)) out)
               (format "must be the per-field miss, not the carrier refusal: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"error" s)) out)
              (format "the miss must be LOUD: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s1: a RUNTIME miss inside a row-of-Maps broadcast is LOUD (assertive tier — the mini-C9)"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s1d\ndef m1 : [Map Keyword Int] := {:x 1}\ndef m2 : [Map Keyword Int] := {:y 2}\ndef rm := {:a m1 :b m2}\nrm:x\ndef after := 42")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"needs a PVec subject" s)) out)
               (format "must reach the runtime, not the carrier refusal: ~a" out))
  (check-false (ormap (lambda (s) (regexp-match? #rx"\\{:a 1" s)) out)
               (format "a partial/silent result must not escape: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"error|panic" s)) out)
              (format "the runtime miss must abort LOUDLY: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s1: L1 fusion holds across row layers (two ω steps, two rows)"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s1e\ndef deep := {:x {:inner {:v 1}} :y {:inner {:v 2}}}\ndeep:inner:v")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"\\{:x Int :y Int\\}" s)) out)
              (format "each ω step consumes one row layer: ~a" out)))

(test-case "P4d-s1: a sub-inner assembles PER-FIELD over the row (Q_U20 extended to the carrier)"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s1f\ndef regions := {:eu {:host \"e\" :port 1} :us {:host \"u\" :port 2}}\nregions:{host}")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"\\{:eu \\{:host String\\} :us \\{:host String\\}\\}" s)) out)
              (format "expected per-field narrowed rows under the subject's keys: ~a" out)))

(test-case "P4d-s1: a sub-inner over a genuine Map takes the standing Q_U10 block refusal"
  ;; MEASURED, not predicted: the sub-inner assembles at 'block (Q_U20), and a
  ;; 'block over a Map VALUE refuses statically per Q_U10 (seal/validate is the
  ;; guided exit). The refusal is specifically about Map-VALUED values — a
  ;; row-valued Map ([Map Keyword {row}]; constructible from source via
  ;; `map-map-vals` inference even though row-type ANNOTATIONS do not parse)
  ;; sub-selects fine, pinned below. (The verify refuted this comment's first
  ;; cut, which claimed row-valued Maps unconstructible.)
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s1g\ndef mm : [Map Keyword [Map Keyword String]] := {:a {:host \"x\"}}\nmm:{host}\ndef after := 42")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"KEY TYPE does not admit" s)) out)
              (format "expected the guided Q_U10 block-over-Map refusal: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s1: a sub-inner over a ROW-VALUED Map succeeds (map-map-vals-inferred value rows)"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s1j\ndef mm : [Map Keyword String] := {:a \"x\"}\ndef m2 := [map-map-vals [fn [s] {:host s}] mm]\nm2:{host}")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"\\{:host \"x\"\\}.* : \\[Map Keyword \\{:host String\\}\\]" s)) out)
              (format "a row-valued Map sub-selects per value: ~a" out)))

(test-case "P4d-s1 boundary — INVERTED at slice 2: the het tuple now BROADCASTS"
  ;; ⚠ RE-EXPRESSED AT P4d slice 2 (the s1 boundary carrier landed): the same
  ;; fixture that pinned the refusal now pins the per-position result. The
  ;; boundary-refusal proposition lives on in the s2f List pin.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s1h\ndef evs := @[{:t 1} {:t 2 :x 3}]\nevs:t\ndef after := 42")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"@\\[1 2\\] : ⟨Int Int⟩" s)) out)
              (format "expected the per-position values at the nat-row type: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s1: an ordinal inner applies to VALUES uniformly — failing naturally, not by carrier fiat"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s1i\ndef users := {:name \"alice\"}\nusers:0\ndef after := 42")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"needs a PVec" s)) out)
               (format "the carrier admits; the VALUE projection is what fails: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"error" s)) out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

;; ---------------------------------------------------------------------------
;; D4.P4d slice 2 — the HET TUPLE carrier (design: D4 §5.P4d; owner assent
;; 2026-08-07). Per-position EXACT over 'nat closed rows: the slice-1 row
;; machinery widens at BOTH 'keyword gates (the lift AND the tier peel — the
;; audit refuted "one gate"; missing the peel recreates DEFERRED 43's silent
;; miss one carrier over). Output = the honest nat-row (P3c ruling 2a — no
;; collapse; the Tuple→PVec α keeps downstream PVec expectations satisfied).
;; C9 RULED (a): the conservative OR extends to positions. Misses NAME the
;; position/field via the label-aware walk + the 'bcast-at wrapping fail.
;; ---------------------------------------------------------------------------

(test-case "P4d-s2: per-position broadcast over the het tuple — nat-row out"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s2a\ndef events := @[{:t :click :x 10} {:t :key :code \"KeyA\"} {:t :click :x 3}]\nevents:t")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"@\\[:click :key :click\\] : ⟨Keyword Keyword Keyword⟩" s)) out)
              (format "expected the per-position values at the honest nat-row type: ~a" out)))

(test-case "P4d-s2: a static per-position miss NAMES THE POSITION (the events:x contract — corpus-pinned here)"
  ;; The corpus line `events:x` stays COMMENTED (it would be the acceptance
  ;; file's first error result, and no error-marker convention exists); its
  ;; '(NAMES the position)' contract is pinned HERE at Level 2.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s2b\ndef events := @[{:t :click :x 10} {:t :key :code \"KeyA\"} {:t :click :x 3}]\nevents:x\ndef after := 42")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"needs a PVec" s)) out)
               (format "the carrier must ADMIT; the per-position projection is what fails: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"fails at position 1" s)) out)
              (format "the miss must NAME the offending position: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s2: the KEYWORD twin names the carrier FIELD (the slice-1 sibling gap, closed in the same stroke)"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s2c\ndef kv := {:a {:t 1} :b {:u 2}}\nkv:t\ndef after := 42")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"fails at field :b" s)) out)
              (format "the row miss must NAME the carrier field: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s2: a sub-inner assembles PER-POSITION over the tuple"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s2d\ndef events := @[{:t :click :x 10} {:t :key :code \"KeyA\"}]\nevents:{t}")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"⟨\\{:t Keyword\\} \\{:t Keyword\\}⟩" s)) out)
              (format "expected per-position narrowed rows at nat keys: ~a" out)))

(test-case "P4d-s2: C9 (a) — a Map POSITION makes the runtime miss LOUD (the tier OR over positions)"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s2e\ndef m1 : [Map Keyword Int] := {:x 1}\ndef mixed2 := @[m1 {:b 2}]\nmixed2:b\ndef after := 42")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"needs a PVec" s)) out)
               (format "the tuple must ADMIT: ~a" out))
  ;; a silent-permissive variant would emit a VALUE line (tuple values print
  ;; `@[…]`); post-abort no result line exists at all — the def echo prints
  ;; only the TYPE. (First cut over-matched the echo line itself.)
  (check-false (ormap (lambda (s) (regexp-match? #rx"@\\[" s)) out)
               (format "no silent partial result: ~a" out))
  ;; `panic` specifically — `#rx"error|panic"` matches the SUBSTRING of a
  ;; quiet `<error>` value, so it could not distinguish loud from silent
  ;; (the slice-2 verify's F2).
  (check-true (ormap (lambda (s) (regexp-match? #rx"panic" s)) out)
              (format "the Map position's runtime miss must abort LOUDLY: ~a" out))
  (check-false (ormap (lambda (s) (regexp-match? #rx"<error>" s)) out)
               (format "no quiet <error> value may escape: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s2 boundary: the still-unsupported carriers refuse with the tuple-inclusive message"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s2f\ndef xs := '[{:a 1} {:a 2}]\nxs:a\ndef after := 42")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"needs a PVec, Map, tuple, or closed keyword-row subject" s)) out)
              (format "the supported set must name the tuple truthfully: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"pvec-from-list" s)) out)
              (format "the List guidance must survive: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s2 rider: a SUB inner in a fail path prints the stand-in, never the raw list"
  ;; DEFERRED 40-residual's live half: the two path-append sites interpolated
  ;; `select-step-name` of a sub inner — the RAW LIST — into branch strings.
  ;; ⚠ The first fixture (a single-step `kv:{zzz}`) was VACUOUS — the guarded
  ;; sites run only when steps FOLLOW the ω step, and only the BLOCK sort
  ;; surfaces the accumulated path (the slice-2 verify's F1). This fixture
  ;; reaches both: block sort, mid-branch sub-inner ω, trailing step.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s2g\ndef kv := {:v {:a {:t 1}}}\nkv{v:{t}:u}\ndef after := 42")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"@sub" s)) out)
               (format "a raw (@sub …) leaked into a user-facing message: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"select branch `v\\.\\{…\\}\\.u`" s)) out)
              (format "the stand-in must print in the branch string: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s2 rider (DEFERRED 45's DISSOLVE grade): a keyed step after a dissolve inner no longer mis-keys the branch"
  ;; The verify found the top-keys fix silently repaired a SECOND grade: the
  ;; old dissolve arm walked rest and computed `k^:w^:r` as keyed `r` while
  ;; the consumers label it keyless — same wrong-L4 class as the ordinal
  ;; grade, pinned here so the repair is advertised and held.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s2j\ndef x9 := {:q {:z 1} :k @[@[{:r 5}]]}\nx9{q^ k^:w^:r}\ndef after := 42")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"mixed keyed/keyless" s)) out)
               (format "the dissolve-grade branch is KEYLESS — the L4 refusal was wrong: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s2 rider (DEFERRED 45): an ordinal-ω branch is KEYLESS to the L4 check — no wrong mixed-sorts refusal"
  ;; top-keys' bcast arm recursed PAST an ordinal inner to the next keyed step
  ;; (`k^:0:nm` computed as keyed `nm`) while both consumers label by
  ;; select-step-output-name — a live WRONG L4 refusal. Post-fix the branch
  ;; flows to typing's own honest per-branch refusal.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s2h\ndef x := {:k2 {:z 1} :k @[@[{:nm 5}]]}\nx{k2^ k^:0:nm}\ndef after := 42")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"mixed keyed/keyless" s)) out)
               (format "the L4 refusal was WRONG (both branches are keyless): ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s2 rider control: the rest-null ordinal-ω sibling still succeeds keyless"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s2i\ndef x2 := {:k2 {:z 1} :k @[@[{:nm 5}]]}\nx2{k2^ k^:0}")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"⟨\\{:z Int\\} \\[PVec ⟨\\{:nm Int\\}⟩\\]⟩" s)) out)
              (format "the keyless het assembly must survive the top-keys fix: ~a" out)))

;; ---------------------------------------------------------------------------
;; D4.P4d slice 3 — PVec-of-UNION: keys-⋂ / types-⋃ (design: D4 §5.P4d; owner
;; assent 2026-08-07, Nil ruling (a)). TWO halves over DISJOINT populations:
;;   · the ⋂ GATE catches ROW components that do not offer the key (today a
;;     SILENT WRONG ANSWER — the type lies and the value is a buried <error>);
;;   · the TIER (C9 (a)'s OR extended through components) catches MAP-bearing
;;     unions, where the gate is a structural NO-OP (an open Map statically
;;     offers every keyword).
;; ⭐ RULED (a): `Nil` is SKIPPED — it is the absence marker of the option
;; type, not a carrier alternative, so `<T | Nil>` broadcasts as T and the
;; `nil-safe-get` idiom keeps composing.
;; The types-⋃ half ALREADY SHIPPED (build-union-type); the new work is the
;; gate, the refusal, and the tier.
;; ---------------------------------------------------------------------------

(test-case "P4d-s3: every component offers — types-⋃, unchanged"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s3a\ndef k := 0N\ndef rows := @[{:a 1 :b \"x\"} {:a 2 :c true}]\ndef sl := [pvec-slice rows k 2N]\nsl:a")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"@\\[1 2\\] : \\[PVec Int\\]" s)) out)
              (format "the all-offer case must keep working: ~a" out)))

(test-case "P4d-s3: a component that does NOT offer the key REFUSES, naming it — no buried <error>"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s3b\ndef k := 0N\ndef rows := @[{:a 1 :b \"x\"} {:a 2 :c true}]\ndef sl := [pvec-slice rows k 2N]\nsl:b\ndef after := 42")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"<error>" s)) out)
               (format "a buried <error> escaped at zero errors: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"EVERY union component" s)) out)
              (format "the refusal must state the all-must-offer rule: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx":a Int :c Bool" s)) out)
              (format "the refusal must NAME the offending component: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s3 ⭐ Nil is SKIPPED (ruling a): `<Nil | Map>` broadcasts as the Map"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s3c\ndef mz : [Map Keyword Int] := {:z 9}\ndef zs : [PVec <Nil | [Map Keyword Int]>] := @[mz]\nzs:z")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"@\\[9\\] : \\[PVec Int\\]" s)) out)
              (format "Nil is the absence marker, not a non-offering component: ~a" out)))

(test-case "P4d-s3 ⭐ Nil skipped: the nil-safe-get idiom still composes with broadcast"
  ;; ⚠ THE FIXTURE IS NIL-BEARING ON PURPOSE. My first cut used a ONE-ELEMENT
  ;; never-nil vector, so `nil-safe-get` never actually returned nil and the pin
  ;; was VACUOUS for the proposition it names — the slice-3 verify caught it,
  ;; and with the nil element present the first implementation PANICKED
  ;; (`q is not a map at runtime`), defeating ruling (a) outright. The gate
  ;; skipped Nil while the TIER witness did not; both now agree.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s3d\ndef ms : [PVec [Map Keyword [Map Keyword Int]]] := @[{:a {:q 1}} {}]\ndef ys := [pvec-map [fn [m] [nil-safe-get m :a]] ms]\nys:q\ndef after := 42")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"EVERY union component" s)) out)
               (format "the Nil remainder must not refuse the broadcast: ~a" out))
  (check-false (ormap (lambda (s) (regexp-match? #rx"panic" s)) out)
               (format "an ACTUALLY-ABSENT element must not panic — (a) says the idiom composes: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s3: a per-component failure carries the TRUE inner reason, not a false key-miss"
  ;; The first cut DISCARDED the inner fail and asserted a keys-intersection
  ;; failure for every per-component failure — so an ORDINAL inner over a Map
  ;; component read "`[Map Keyword Int]` does not offer `:0`", replacing a true,
  ;; actionable message with a false one (the slice-3 verify's HIGH finding).
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s3g\ndef mm : [Map Keyword Int] := {:a 1}\ndef bb : [PVec <[Map Keyword Int] | [Map Keyword String]>] := @[mm]\nbb:0\ndef after := 42")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"has no positions" s)) out)
              (format "the inner reason must survive the wrapper: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"requires EVERY union component to succeed" s)) out)
              (format "the wrapper must state the rule: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s3: a union-typed row FIELD is gated too (the witness and the gate cover one population)"
  ;; The gate started at the PVec/Map call site only, while the tier witness
  ;; reached row fields and tuple positions — so a Map-bearing union FIELD went
  ;; assertive but UNGATED and panicked with a carrier-kind message. The gate
  ;; now lives in the per-element applier, which every carrier routes through.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s3h\ndef k := 0N\ndef rows := @[{:a 1 :b \"x\"} {:a 2 :c true}]\ndef wide := [pvec-slice rows k 2N]\ndef holder := {:xs wide}\nholder:b\ndef after := 42")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"panic" s)) out)
               (format "a union-typed field must be GATED at typing, not panic at runtime: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s3: a MAP-bearing union's runtime miss is LOUD (the tier OR through components)"
  ;; The gate is a structural NO-OP here — an open Map offers every keyword
  ;; statically — so only the tier can catch this. Pre-slice it was
  ;; `<error> : [PVec Int | String]` at ZERO errors.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s3e\ndef m1 : [Map Keyword Int] := {:a 1}\ndef both : [PVec <[Map Keyword Int] | [Map Keyword String]>] := @[m1]\nboth:zzz\ndef after := 42")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"<error>" s)) out)
               (format "a quiet <error> escaped — the tier stayed permissive: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"panic" s)) out)
              (format "the runtime miss must be LOUD: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s3: the SUB-inner cell over a union no longer lies (it refused 'not a record' for a union of rows)"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s3f\ndef k := 0N\ndef rows := @[{:a 1 :b \"x\"} {:a 2 :c true}]\ndef sl := [pvec-slice rows k 2N]\nsl:{a}\ndef after := 42")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"not a record" s)) out)
               (format "the lying message must be gone — the subject IS a union of records: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"\\{:a Int\\}" s)) out)
              (format "the sub-block must assemble per component: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

;; ---------------------------------------------------------------------------
;; D4.P4d slice 4a — HISTORY. The `bcast-carrier` arm once appended a taught
;; spelling (`; otherwise spell it `[pvec-map [fn [m] m.LABEL] xs]``) gated on
;; `(and label (symbol? label))`. Slice 4a vouched that gate producer-side after
;; five populations were measured getting unwritable-or-wrong spellings; slice
;; 4c then RETIRED the whole mechanism, because the remedy now points back at
;; the spelling the user already wrote (see `format-select-fail`'s bcast-carrier
;; arm). Neither the append nor the guard exists at HEAD.
;;
;; The two test-cases below were written to justify that advice and are KEPT
;; because they incidentally pin real semantics nothing else does — block ω
;; ASSEMBLES while path ω PROJECTS, and L1 fusion as an equivalence (Q_U7's
;; theorem). They are re-pointed at the semantics, not the message.
;; ---------------------------------------------------------------------------

;; ⚠ D4.P4d slice 4d-2: the next two were labelled `P4d-s4b` while sitting under
;; the slice-4a header — they ORIGINATE in 4a (written to justify its advice) and
;; were re-pointed at semantics when 4c retired that advice. Relabelled `s4a` so
;; the prefix matches the section; the six genuine `s4b` cases below are untouched.
(test-case "P4d-s4a: block ω ASSEMBLES, path ω PROJECTS — the semantic fact itself"
  ;; Originally pinned to justify slice 4a's block-sort advice suppression;
  ;; that advice is retired, but the FACT is load-bearing on its own — it is
  ;; why a dot-path is not the block spelling, and it is not pinned anywhere
  ;; else. Kept, re-pointed at the semantics rather than at a message.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    (string-append
                     "ns s4a6b\ndef P := @[{:aa {:bb 1}} {:aa {:bb 2}}]\ndef RP := {:items P}\n"
                     "RP{items:aa}\n[pvec-map [fn [m] m{aa}] P]\n[pvec-map [fn [m] m.aa] P]\ndef after := 42"))))
  ;; the block form KEEPS the key — same shape as the brace spelling…
  (check-true (ormap (lambda (s) (regexp-match? #rx"\\{:items \\[PVec \\{:aa \\{:bb Int\\}\\}\\]\\}" s)) out)
              (format "block ω must ASSEMBLE (keep the key): ~a" out))
  ;; …and the dot spelling drops it, which is why it must not be advised here
  (check-true (ormap (lambda (s) (regexp-match? #rx"\\[PVec \\{:bb Int\\}\\]" s)) out)
              (format "the dot spelling must PROJECT — that is the divergence: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s4a: L1 FUSION as a theorem — fmap g ∘ fmap f = fmap (g ∘ f)"
  ;; Q_U7 records this identity as the L1-fusion theorem and the battery is
  ;; where it lives. It was written to justify slice 4a's fused advice; that
  ;; advice is retired, but the THEOREM is not, and nothing else pins it as an
  ;; equivalence against a real carrier.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    (string-append
                     "ns s4a9\ndef P := @[{:a {:b 1}} {:a {:b 2}}]\n"
                     "def viaBcast := P:a:b\n"
                     "def viaFused := [pvec-map [fn [m] m.a.b] P]\n"
                     "viaBcast\nviaFused\ndef after := 42"))))
  (define hits (filter (lambda (s) (regexp-match? #rx"@\\[1 2\\] : \\[PVec Int\\]" s)) out))
  (check-equal? (length hits) 2
                (format "the broadcast and its fused spelling must agree: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

;; ---------------------------------------------------------------------------
;; D4.P4d slice 4b — A SCHEMA-TYPED SUBJECT IS THE ROW IT DENOTES.
;;
;; `select-row-of` resolves a schema fvar to its closed row, so `p{name}` and
;; `p.name` both work on a schema-typed value. `select-bcast-lift` tested
;; `expr-Record?` on the RAW type and had no such step, so the same value was
;; told it "needs a … closed keyword-row subject" — about a subject that is
;; exactly that, two spellings over. Uniformity, not a new carrier.
;;
;; ⚠ Measured before implementing, because the obvious framing was wrong: this
;; does NOT make `p:name` succeed on a FLAT schema. `:` projects from each
;; field VALUE, so `{:name String}` + `:name` fails on a plain row too (the
;; value is a String). The fix makes the schema behave as its row — which
;; SUCCEEDS exactly where the row succeeds, i.e. when the field values are
;; themselves records.
;; ---------------------------------------------------------------------------

(test-case "P4d-s4b: a CLOSED schema broadcasts exactly as the row it denotes"
  ;; ⚠ `:closed` is LOAD-BEARING here and the first cut of this pin omitted it —
  ;; see the open-schema pin below for what that cost.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    (string-append
                     "ns s4b1\nschema Host :closed\n  :host String\n\nschema Region :closed\n  :us Host\n  :eu Host\n\n"
                     "def rg := [the Region {:us [the Host {:host \"u\"}] :eu [the Host {:host \"e\"}]}]\n"
                     "def plain := {:us {:host \"u\"} :eu {:host \"e\"}}\n"
                     "plain:host\nrg:host\ndef after := 42"))))
  ;; the PLAIN row is the oracle — whatever it does, the schema must do
  (check-true (>= (length (filter (lambda (s) (regexp-match? #rx"\\{:eu \"e\", :us \"u\"\\}" s)) out)) 2)
              (format "the schema-typed subject must broadcast like its row (both lines): ~a" out))
  (check-false (ormap (lambda (s) (regexp-match? #rx"needs a PVec, Map, tuple, or closed keyword-row subject" s)) out)
               (format "a closed schema row must not be told it is not a keyword row: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s4b: the FLAT closed schema fails like its row, not differently"
  ;; The uniformity claim cuts both ways: where the plain row refuses, the
  ;; schema must refuse the SAME way. `:name` over `{:name String}` projects
  ;; `.name` from the String value and fails — it is not a carrier refusal.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    (string-append
                     "ns s4b2\nschema Person :closed\n  :name String\n\n"
                     "def p := [the Person {:name \"a\"}]\np:name\ndef after := 42"))))
  (check-false (ormap (lambda (s) (regexp-match? #rx"needs a PVec, Map, tuple, or closed keyword-row subject" s)) out)
               (format "the flat schema must reach the carrier, not be refused by it: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"broadcast fails at field :name" s)) out)
              (format "it must fail per-field, exactly as the plain row does: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s4b: an OPEN schema is NOT admitted — its row would be a WIDTH LIE"
  ;; `schema` is OPEN by default and `schema->row` mints `'closed` regardless —
  ;; harmless for `.` (one field) and `{}` (named fields), but broadcast is the
  ;; first consumer that ENUMERATES the row. The first cut admitted open
  ;; schemas and produced, on this very fixture, a THREE-field value typed as
  ;; TWO fields at zero errors:
  ;;   {:ap "a", :eu "e", :us "u"} : {:eu String :us String}
  ;; An open schema genuinely is not a closed keyword row, so the carrier
  ;; refusal is the honest answer and stays. Monotone: it can become a meaning
  ;; later if the row ever carries a faithful dyn tail.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    (string-append
                     "ns s4b3\nschema Host :closed\n  :host String\n\nschema Region\n  :us Host\n  :eu Host\n\n"
                     "def rg : Region := {:us [the Host {:host \"u\"}] :eu [the Host {:host \"e\"}] :ap [the Host {:host \"a\"}]}\n"
                     "rg:host\ndef after := 42"))))
  (check-false (ormap (lambda (s) (regexp-match? #rx":ap" s)) out)
               (format "an undeclared key escaped through an open schema's row: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"needs a PVec, Map, tuple, or closed keyword-row subject" s)) out)
              (format "an open schema must keep the carrier refusal: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s4b: a DEFAULTED field is not admitted — the width lie's OTHER direction"
  ;; The closedness gate closes the EXTRAS direction (a runtime key the type
  ;; does not declare). This is the ABSENCE direction, and the second cut had
  ;; it live: `schema->row` marks every field `'present` while the fill "happens
  ;; at the seal boundary" — and a `spec f -> S` RETURN has no fill at all.
  ;; Measured before this gate:
  ;;   c := [build …]  →  {:a {:h "q"}} : Cfg          (:b never filled)
  ;;   c:h             →  {:a "q"} : {:a String :b String}   1 field, type says 2
  ;;   broad.b         →  <error> : String              silent, 0 errors
  ;; Broadcast is the only consumer that reads EVERY field, so it is the only
  ;; one that touches the unfilled slot.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    (string-append
                     "ns s4b6\nschema Inner :closed\n  :h String\n\n"
                     "schema Cfg :closed\n  :a Inner\n  :b Inner :default [the Inner {:h \"zz\"}]\n\n"
                     "spec build Inner -> Cfg\ndefn build [x]\n  {:a x}\n\n"
                     "def c := [build [the Inner {:h \"q\"}]]\nc:h\ndef after := 42"))))
  (check-false (ormap (lambda (s) (regexp-match? #rx"\\{:a String :b String\\}" s)) out)
               (format "a row wider than its value escaped through a defaulted field: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"needs a PVec, Map, tuple, or closed keyword-row subject" s)) out)
              (format "a defaulted-field schema must keep the carrier refusal: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s4b: a schema/selection NAME COLLISION must not bypass `:requires`"
  ;; ⚠ THE FIRST CUT WAS A CAPABILITY BYPASS. Both registries accept the same
  ;; name, so `schema Person` + `selection Person from Person` is constructible.
  ;; Testing the schema registry FIRST handed the row over with the per-field
  ;; read capability stripped — measured: `u.age` and `u{name}` were both
  ;; refused by the view while `u:h` returned `{:name "a", :age "SECRET"}` at
  ;; ZERO errors. `select-row-of` puts the selection arm first and its comment
  ;; calls the order load-bearing; the resolver now mirrors it.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    (string-append
                     "ns s4b4\nschema Inner :closed\n  :h String\n\nschema Person :closed\n  :name Inner\n  :age Inner\n\n"
                     "selection Person from Person\n  :requires [:name]\n\n"
                     "def u : Person := {:name [the Inner {:h \"a\"}] :age [the Inner {:h \"SECRET\"}]}\n"
                     "u:h\ndef after := 42"))))
  (check-false (ormap (lambda (s) (regexp-match? #rx"SECRET" s)) out)
               (format "a restricted field's CONTENTS escaped through the broadcast: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s4b: the TIER agrees between a closed schema and its row (DEFERRED 43's class)"
  ;; The lift and `select-tier-subject` BOTH see the subject; the first cut
  ;; resolved only the lift, so the tier stayed permissive and a runtime Map
  ;; miss went QUIET where the identical plain row PANICS. Map-typed schema
  ;; fields construct via the type-alias route, which is how this is reachable.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    (string-append
                     "ns s4b5\ndef MKI : Type := [Map Keyword Int]\n"
                     "schema One :closed\n  :a MKI\n  :b MKI\n\n"
                     "def m1 : MKI := {:x 1}\ndef m2 : MKI := {:y 2}\n"
                     "def rowv := {:a m1 :b m2}\ndef s : One := {:a m1 :b m2}\n"
                     "rowv:x\ndef mid := 1\ns:x\ndef after := 42"))))
  (check-false (ormap (lambda (s) (regexp-match? #rx"<error>" s)) out)
               (format "the schema's runtime miss went QUIET while its row panics: ~a" out))
  (check-true (>= (length (filter (lambda (s) (regexp-match? #rx"panic" s)) out)) 2)
              (format "BOTH the row and the schema must be LOUD: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

;; ---------------------------------------------------------------------------
;; D4.P4d slice 4c — THE PER-CARRIER SPLIT. One arm used to tell List, Set,
;; Int, String, Bool, a dyn row AND a function alike to "convert first with
;; `[pvec-from-list xs]`", then teach `[pvec-map [fn [m] m.NAME] xs]` — a
;; spelling that cannot work on this arm's audience, since `pvec-map` needs a
;; PVec and a PVec never reaches here.
;;
;; ⭐ The remedy now names the CONVERSION for the actual carrier and points back
;; at the spelling the USER WROTE, which works unchanged once converted
;; (verified for the plain, chained and Set cases). That is why slice 4a's
;; advice machinery is gone rather than fixed.
;; ---------------------------------------------------------------------------

(test-case "P4d-s4c: a LIST names its own conversion and stops teaching pvec-map"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s4c1\ndef L := '[{:t 1} {:t 2}]\nL:t\ndef after := 42")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"pvec-from-list xs" s)) out)
              (format "a List must name its conversion: ~a" out))
  ;; ⚠ and must NOT promise the whole expression then works — false for an
  ;; ordinal inner and for non-row elements, both measured after converting
  (check-false (ormap (lambda (s) (regexp-match? #rx"the same spelling works" s)) out)
               (format "the conversion fixes the carrier, not the expression: ~a" out))
  (check-false (ormap (lambda (s) (regexp-match? #rx"pvec-map" s)) out)
               (format "the unusable second spelling must be gone: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s4c: a USER-DEFINED `List` must NOT be offered `pvec-from-list`"
  ;; ⚠ This slice's own first cut reintroduced the very class it exists to
  ;; remove. `select-list-type?` used `bare-name`, which strips the module
  ;; prefix — so a user's `data List` in their own namespace (`u::List`) matched
  ;; the stdlib recognizer and was handed `[pvec-from-list xs]`. Measured:
  ;; that conversion over it → "Could not infer type".
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s4c7 :no-prelude\ndata List := empty | full\ndef v := empty\nv:t\ndef after := 42")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"pvec-from-list" s)) out)
               (format "a user's own List type was offered the stdlib conversion: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"needs a PVec, Map, tuple, or closed keyword-row" s)) out)
              (format "it must still get the carrier refusal: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s4c: a SET gets its OWN conversion, which is not the List one"
  ;; `[pvec-from-list [set-to-list xs]]` — verified end to end, and the order
  ;; caveat is real (a set is unordered; the probe returned @[2 1] from a
  ;; literal written {1,2}).
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s4c2\ndef S := #{ {:t 1} }\nS:t\ndef after := 42")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"set-to-list" s)) out)
              (format "a Set must get the set conversion, not the list one: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"unordered" s)) out)
              (format "the order caveat must be stated: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s4c: an LSEQ gets its own ONE-STEP conversion"
  ;; The last convertible carrier, and it reached the no-remedy arm. The
  ;; stdlib inventory of conversions INTO PVec is closed and small —
  ;; `pvec-from-list` (List), `into-vec` (LSeq), `set-to-list`+`pvec-from-list`
  ;; (Set) — so this completes it.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    (string-append
                     "ns s4c8\ndef LS := [list-to-seq '[{:t 1} {:t 2}]]\nLS:t\n"
                     "def P := [into-vec LS]\ndef viaConv := P:t\nviaConv\ndef after := 42"))))
  (check-true (ormap (lambda (s) (regexp-match? #rx"into-vec xs" s)) out)
              (format "an LSeq must name its own conversion: ~a" out))
  (check-false (ormap (lambda (s) (regexp-match? #rx"pvec-from-list" s)) out)
               (format "an LSeq must not be given the List conversion: ~a" out))
  ;; the advised conversion must actually work
  (check-true (ormap (lambda (s) (regexp-match? #rx"@\\[1 2\\] : \\[PVec Int\\]" s)) out)
              (format "the advised `into-vec` must unblock the broadcast: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s4c: a SCALAR gets NO remedy — there is no conversion to name"
  ;; The old message told an Int to convert a list. `pvec-map` is meaningless
  ;; here too; naming the carriers and stopping is the honest answer.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s4c3\ndef n := 5\nn:t\ndef s := \"hi\"\ns:t\ndef f := [fn [x : Int] x]\nf:t\ndef after := 42")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"pvec-from-list|pvec-map|set-to-list" s)) out)
               (format "a scalar/function must be offered no conversion at all: ~a" out))
  (check-true (>= (length (filter (lambda (s) (regexp-match? #rx"needs a PVec, Map, tuple, or closed keyword-row" s)) out)) 3)
              (format "all three must still name the supported carriers: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s4c: a DYN-TAIL row is told to VALIDATE — the half that actually runs"
  ;; ⚠ THIS PIN ONCE CLAIMED A VERIFICATION IT NEVER PERFORMED. Its title said
  ;; "a remedy slice 4b made TRUE" and it asserted only that the substring
  ;; "seal the subject against a schema" appeared — while its own fixture
  ;; falsifies it: `[the W dyn]` → "Could not infer type", because a `:closed`
  ;; schema refuses an open actual and an OPEN schema is not an ω carrier.
  ;; `[validate W dyn]` DOES run (returns a Result). The message and this pin
  ;; now name that half, and the pin executes it.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    (string-append
                     "ns s4c4\nschema Inner :closed\n  :h String\n"
                     "def base := {:a [the Inner {:h \"x\"}]}\ndef kk := :zz\n"
                     "schema W :closed\n  :a Inner\n\n"
                     "def dyn := [map-assoc base kk [the Inner {:h \"y\"}]]\ndyn:h\n"
                     "def validated := [validate W dyn]\ndef after := 42"))))
  (check-true (ormap (lambda (s) (regexp-match? #rx"validate Schema subj" s)) out)
              (format "an open row must be pointed at validate, the remedy that runs: ~a" out))
  (check-false (ormap (lambda (s) (regexp-match? #rx"pvec-from-list" s)) out)
               (format "an open row must not be told to convert a list: ~a" out))
  ;; and the advised call must actually typecheck on this very subject
  (check-true (ormap (lambda (s) (regexp-match? #rx"validated : .*Result" s)) out)
              (format "the advised `validate` must run on the fixture: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s4c: an OPEN schema is told the one thing that fixes it — `:closed`"
  ;; Slice 4b refuses it correctly but SILENTLY (DEFERRED 64). The remedy is one
  ;; keyword and the message now says so.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    (string-append
                     "ns s4c5\nschema Host :closed\n  :host String\n\nschema Region\n  :us Host\n\n"
                     "def rg := [the Region {:us [the Host {:host \"u\"}]}]\nrg:host\ndef after := 42"))))
  (check-true (ormap (lambda (s) (regexp-match? #rx"OPEN" s)) out)
              (format "the message must say the schema is open: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx":closed" s)) out)
              (format "the admitted form `:closed` must be named: ~a" out))
  ;; ⚠ but NOT as an unconditional promise — reached from the dyn arm's own
  ;; advice, sealing into a closed schema does not typecheck, so "and the
  ;; broadcast works" was false. Measured; the wording no longer claims it.
  (check-false (ormap (lambda (s) (regexp-match? #rx"and the broadcast works" s)) out)
               (format "the message must not promise the broadcast then works: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s4c: a collided SELECTION is told it is a view, not that it is not a row"
  ;; `select-row-of`'s own comment calls the generic carrier wording a LIE for a
  ;; view — "a view IS a record, restricted". The broadcast path said it anyway.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    (string-append
                     "ns s4c6\nschema Inner :closed\n  :h String\n\nschema Person :closed\n  :name Inner\n\n"
                     "selection Person from Person\n  :requires [:name]\n\n"
                     "def u : Person := {:name [the Inner {:h \"a\"}]}\nu:h\ndef after := 42"))))
  (check-true (ormap (lambda (s) (regexp-match? #rx"SELECTION" s)) out)
              (format "a view must be named as one: ~a" out))
  (check-false (ormap (lambda (s) (regexp-match? #rx"pvec-from-list" s)) out)
               (format "a view must not be offered a list conversion: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))

(test-case "P4d-s4a': the binder refusal must never print raw SYNTAX OBJECTS (its guard was dead)"
  ;; `retired-selection-error`'s `bcast-step-binder` arm carries
  ;;   (let ([f* (if (pair? f) '|{…}| f)]) …)
  ;; under a comment that says "render `{…}`, never the raw stx-bearing datum".
  ;; The guard could never fire: `f` is `(base-name detail)`, and `base-name`
  ;; returns a STRING on every branch (symbol->string / keyword->string /
  ;; (format "~a" d)), so `(pair? f)` is structurally impossible. The `:{` mint's
  ;; payload therefore reached `(format "~a" …)` and printed syntax objects —
  ;; complete with ABSOLUTE FILESYSTEM PATHS — into the user's message TWICE,
  ;; the second time inside the advice the user is told to type.
  ;;
  ;; ⚠ The pre-existing pin for this arm accepts `BINDER position|expected
  ;; symbol` and asserts NO message content, which is why a green suite never
  ;; saw it. This one asserts the content.
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws
                    "ns s4ap\ndefn f1 [x:{a b}] 1\ndef after := 42")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"#<syntax" s)) out)
               (format "a raw syntax object leaked into a user-facing message: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"BINDER position" s)) out)
              (format "the guided refusal must still fire: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"\\{…\\}" s)) out)
              (format "the payload must render as the stand-in: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after : Int defined" s)) out)))


;; ---------------------------------------------------------------------------
;; D4.P4d slice 4d — Q_U19: `^` ON A BROADCAST TAKES ITS OWN MESSAGE.
;; [owner 2026-08-08: "leave the dot string alone, add a broadcast sibling";
;; then "all three" routes; then route 3 takes "Q_T4a's message".]
;;
;; The REFUSAL was ratified at the P4d opening (Q_U19 (A)): in BLOCK position the
;; ω output HAS a key for `^` to rename, in PATH position `xs:name` is a bare
;; [PVec String] and there is none. What 4d fixes is that the path-position
;; spellings said three DIFFERENT wrong things — route 1 borrowed the DOT message
;; ("a field access has no output key", the wrong noun for an ω step), and routes
;; 2 and 3 were unguided `Unbound variable` fall-throughs blaming a stray token.
;;
;; ⚠⚠ BOTH messages contain "re-keys the OUTPUT", so a pin on that substring
;; CANNOT DISCRIMINATE — that is exactly how the old sub-case (c) froze an
;; accident. Every pin below asserts the NOUN **and the absence of its twin**.
;; ---------------------------------------------------------------------------

(define (u19-raw src)
  (process-string-ws (string-append "ns u19\n" src "\ndef after := 42")))

(define (u19 src) (map (lambda (r) (format "~a" r)) (u19-raw src)))

(define (u19-has? out rx) (ormap (lambda (s) (regexp-match? rx s)) out))

(define U19-PVEC "def xs := @[{:name \"a\"} {:name \"b\"}]\n")

(test-case "P4d-s4d Q_U19 route 1: `xs:name^…` takes the BROADCAST noun, not the dot one"
  ;; RED before the split: all four land on the shared dot string.
  ;; ⚠ `^-` (the COLLAPSE family) is in the set — the design's three-spelling
  ;; enumeration under-counted it, measured at 2fd6b68e.
  (for ([src (in-list '("xs:name^alias" "xs:name^" "xs:name^_" "xs:name^-"))])
    (define out (u19 (string-append U19-PVEC src)))
    (check-true (u19-has? out #rx"broadcast step has no output key")
                (format "~a must take the BROADCAST noun: ~a" src out))
    (check-false (u19-has? out #rx"field access has no output key")
                 (format "~a must NOT borrow the dot noun: ~a" src out))
    (check-true (u19-has? out #rx"after : Int defined")
                (format "~a must stay PER-COMMAND: ~a" src out))))

;; ⚠ ROUTES 2 AND 3 ARE DELIBERATELY UNPINNED HERE — they are NOT shipped.
;; `xs:{name}^alias` and `xs:0^alias` still report `Unbound variable`. Both were
;; implemented at this slice and REVERTED [owner 2026-08-08: "ship route 1"]:
;; the datum layer cannot see the ADJACENCY that separates `xs:{name}^alias`
;; from a legitimate `[f xs:{name} ^]`, and the attempt BROKE MONOTONICITY —
;; `^` is a bindable name (`def ^ := 7` → `^ : Int defined.`), so
;; `[snd2 xs:name ^]` is a program HEAD accepts and the arm turned it into an
;; error. They need a grouper-side adjacency mint (DEFERRED 75 / 76).
;; No pin asserts their CURRENT output on purpose: pinning `Unbound variable`
;; would freeze an accident, which is the defect the re-pointed sub-case (c)
;; below exists to undo.

(test-case "P4d-s4d Q_U19: a MIXED chain is decided by the caret's own step"
  ;; ⚠ NAMED HONESTLY, after mutation-testing refuted the name I first gave it
  ;; ("the split is PER-STEP, not per-branch"). A per-BRANCH implementation
  ;; (`ormap` over the branch instead of `findf` + the step's kind) passes this
  ;; test and the whole battery — because Q_U13's NEST gives ONE carrier PER
  ;; LEVEL, so the branch at this arm holds exactly ONE step and the two
  ;; formulations are observationally identical. `findf` is the honest shape, not
  ;; an observable fix; do not claim otherwise.
  ;;
  ;; What this DOES pin, and nothing else did: a chain the user opened with `:`
  ;; gets the message belonging to the step the caret actually rides.
  ;;   `ys.a:b^c` — caret on the ω step  ⇒ BROADCAST noun
  ;;   `xs:a.b^c` — caret on a DOT step  ⇒ DOT noun, even though `:` is in the chain
  (define omega (u19 (string-append U19-PVEC "def ys := {:a xs}\nys.a:b^c")))
  (check-true (u19-has? omega #rx"broadcast step has no output key")
              (format "caret on the ω step must take the BROADCAST noun: ~a" omega))
  (define dotted (u19 (string-append U19-PVEC "xs:a.b^c")))
  (check-true (u19-has? dotted #rx"field access has no output key")
              (format "caret on a DOT step must take the DOT noun even in a `:` chain: ~a" dotted))
  (check-false (u19-has? dotted #rx"broadcast step has no output key")
               (format "a `:` somewhere in the chain must not decide it: ~a" dotted)))

(test-case "P4d-s4d Q_U19 PRECEDENCE: `^^` keeps split-caret-lexeme's specific error"
  ;; GUARD (green before AND after). `xs:name^^a` takes the well-formedness error
  ;; FIRST. Installing the sibling above it would replace a TRUE, specific message
  ;; with a generic refusal — the class the slice-3 verify already caught once.
  (define out (u19 (string-append U19-PVEC "xs:name^^a")))
  (check-true (u19-has? out #rx"one `\\^` per segment")
              (format "the well-formedness error must still win: ~a" out))
  (check-false (u19-has? out #rx"has no output key")
               (format "the Q_U19 sibling must NOT pre-empt it: ~a" out)))

(test-case "P4d-s4d Q_U19: the DOT audience is BYTE-IDENTICAL — the ruling's whole point"
  ;; GUARD (green before AND after). The shared string served two audiences; only
  ;; the broadcast one moves. If this ever takes the broadcast noun, the split
  ;; leaked into the dot route.
  (for ([src (in-list '("m.foo^z" "m.foo^" "m.foo^_" "m.foo^-"))])
    (define out (u19 (string-append "def m := {:foo 7 :bar 8}\n" src)))
    (check-true (u19-has? out #rx"field access has no output key")
                (format "~a must keep the DOT noun: ~a" src out))
    (check-false (u19-has? out #rx"broadcast step")
                 (format "~a must not acquire broadcast wording: ~a" src out))))

(test-case "P4d-s4d Q_U19 MONOTONICITY: block-position ω-caret still SUCCEEDS"
  ;; GUARD. The refusal is 'path-scoped. Block-position ω-caret is live at 0
  ;; errors and the acceptance file carries commented [D4.P5] targets — a wider
  ;; refusal would refuse a spelling the track has committed to meaning.
  ;; These are also the remedies the new message POINTS AT, so a false remedy
  ;; here would repeat slice 4c's own defect class.
  ;;
  ;; ⚠ STRENGTHENED after the adversarial verify: asserting only the ABSENCE of
  ;; the refusal text is satisfiable by a DIFFERENT error, so it would pass over a
  ;; broken remedy. These assert NO prologos-error at all, on the RAW results.
  (define a-raw (u19-raw (string-append U19-PVEC "xs:{name^alias}")))
  (check-false (ormap prologos-error? a-raw)
               (format "the sub-block remedy must WORK, not merely fail differently: ~a"
                       (map (lambda (r) (format "~a" r)) a-raw)))
  (check-true (u19-has? (map (lambda (r) (format "~a" r)) a-raw) #rx":alias")
              "the sub-block remedy must actually RE-KEY")
  (define b-raw (u19-raw "def cfg := {:admins @[{:name \"a\"}]}\ncfg{admins:name^alias}"))
  (check-false (ormap prologos-error? b-raw)
               (format "the block remedy must WORK, not merely fail differently: ~a"
                       (map (lambda (r) (format "~a" r)) b-raw)))
  (check-true (u19-has? (map (lambda (r) (format "~a" r)) b-raw) #rx":alias")
              "the block remedy must actually RE-KEY"))

;; ---------------------------------------------------------------------------
;; D4.P4d slice 4d-2 — THE BROADCAST AXIS IN `format-select-fail`
;; (DEFERRED 47 ≡ 59.1 · DEFERRED 59.2).
;;
;; Two independent defects, measured at `bd8b8bcf`:
;;
;; (1) The PVec/Map carrier's inner failure reaches the formatter RAW. The closed
;;     keyword/nat-row arm of `select-bcast-lift` wraps every inner fail as
;;     `bcast-at`; the `else` arm does not, so `emp:t` printed "the subject is not
;;     a record" — no broadcast context at all, and "the subject" naming the WRONG
;;     thing (the subject is the PVec; what failed is the ELEMENT).
;; (2) `not-indexable`'s remedy `select named fields instead (\`x{k}\`)` sat in the
;;     UNCONDITIONAL template tail while the 3-way `cond` above it discriminated
;;     only the carrier kind. So a broadcast got block advice — and worse, a
;;     `[PVec Int]` got a field-spelling remedy that CANNOT work, which is the
;;     false-promise class slice 4c removed everywhere else.
;;
;; ⚠ Remedies are EXECUTED here, not asserted (the 4c discipline).
;; ---------------------------------------------------------------------------

(test-case "P4d-s4d2 (47 ≡ 59.1): a PVec-carrier ω miss names the BROADCAST and the ELEMENT"
  (define out (u19 "def emp := @[]\nemp:t"))
  (check-true (u19-has? out #rx"broadcast")
              (format "the failure must say it happened in a broadcast: ~a" out))
  (check-true (u19-has? out #rx"element")
              (format "it must name the ELEMENT as what failed: ~a" out))
  (check-false (u19-has? out #rx"the subject is not a record")
               (format "\"the subject\" misattributes — the subject is the PVec: ~a" out))
  (check-true (u19-has? out #rx"after : Int defined") "must stay per-command"))

(test-case "P4d-s4d2 (59.2): inside a broadcast the ordinal remedy names the BROADCAST spelling — and it WORKS"
  (define out (u19 "def evs := @[{:t 1} {:t 2}]\nevs:0"))
  (check-false (u19-has? out #rx"x\\{k\\}")
               (format "`x{k}` is block advice, off-key inside a broadcast: ~a" out))
  (check-true (u19-has? out #rx"evs:t|xs:field|:field")
              (format "it must point at the broadcast field spelling: ~a" out))
  ;; EXECUTE the remedy rather than trusting the text.
  (define fixed (u19-raw "def evs := @[{:t 1} {:t 2}]\nevs:t"))
  (check-false (ormap prologos-error? fixed)
               (format "the advised spelling must actually WORK: ~a"
                       (map (lambda (r) (format "~a" r)) fixed))))

(test-case "P4d-s4d2 (59.2): a non-row element gets NO field remedy — there is nothing true to say"
  ;; `[PVec Int]`: an ordinal fails, and so would a field. HEAD advised `x{k}`
  ;; anyway. Slice 4c's rule — scalars get no remedy, because none is true.
  (define out (u19 "def nums := @[1 2]\nnums:0"))
  (check-true (u19-has? out #rx"no positions")
              (format "the explanation must survive: ~a" out))
  (check-false (u19-has? out #rx"x\\{k\\}|named fields")
               (format "a field remedy is FALSE for a scalar element: ~a" out)))

(test-case "P4d-s4d2 GUARD: the non-broadcast audience keeps a TRUE remedy in all three arms"
  ;; ⚠ WIDENED after the adversarial verify. The first version tested only
  ;; `m{0}` — the keyword-row arm, the ONE arm the change did not touch — while
  ;; its name asserted a proposition three arms wide. Underneath it, the `else`
  ;; arm had silently dropped a WORKING remedy for schema-typed subjects. A pin
  ;; whose name is wider than its body is how that stayed green.
  ;; keyword row — unchanged, and `x{k}` is TRUE here
  (define kw (u19 "def m := {:a 1 :b 2}\nm{0}"))
  (check-true (u19-has? kw #rx"select named fields instead \\(`x\\{k\\}`\\)")
              (format "the keyword-row remedy must stay verbatim: ~a" kw))
  (check-false (u19-has? kw #rx"broadcast") (format "a plain block is not a broadcast: ~a" kw))
  ;; scalar — NO remedy, because none is true (`x{k}` cannot work on an Int)
  (define sc (u19 "def s := 5\ns{0}"))
  (check-false (u19-has? sc #rx"x\\{k\\}|named fields")
               (format "a scalar has no fields either — say nothing: ~a" sc))
  ;; Map — `x{k}` was FALSE here even before this slice; dot is the true one
  (define mp (u19-raw "def d : [Map Keyword Int] := {:a 1}\nd{0}"))
  (define mp-s (map (lambda (r) (format "~a" r)) mp))
  (check-false (u19-has? mp-s #rx"select named fields instead")
               (format "`x{k}` never worked on a Map: ~a" mp-s))
  ;; …and the remedy it now names must EXECUTE
  (define mp-fix (u19-raw "def d : [Map Keyword Int] := {:a 1}\nd.a"))
  (check-false (ormap prologos-error? mp-fix)
               (format "the Map remedy must actually work: ~a"
                       (map (lambda (r) (format "~a" r)) mp-fix))))

(test-case "P4d-s4d2 (47 ≡ 59.1): a VECTOR element must not be told to `broadcast instead` — it already did"
  ;; The axis was INCOMPLETE at the first cut: `subject-other` has TWO branches and
  ;; only the non-PVec one was made broadcast-aware. Under a broadcast whose
  ;; ELEMENT is itself a vector (`[PVec [PVec Int]]`), the PVec branch advised
  ;; "To reach fields of EACH element, broadcast instead: `xs:t`" — which is the
  ;; spelling the user had just written. That is the advise-what-they-wrote class
  ;; the function's OWN header documents (`r.zzz` → "spelled `.zzz`"), and slice
  ;; 4c removed it everywhere else.
  (define out (u19 "def nest := @[@[1] @[2]]\nnest:t"))
  (check-false (u19-has? out #rx"broadcast instead")
               (format "must not advise the spelling the user already wrote: ~a" out))
  (check-true (u19-has? out #rx"ordinal|`:0`")
              (format "a vector element takes an ORDINAL, and that is what to say: ~a" out))
  ;; EXECUTE the remedy.
  (define fixed (u19-raw "def nest := @[@[1] @[2]]\nnest:0"))
  (check-false (ormap prologos-error? fixed)
               (format "the advised ordinal must actually WORK: ~a"
                       (map (lambda (r) (format "~a" r)) fixed))))

;; ---------------------------------------------------------------------------
;; D4.P4d slice 5 — THE UNION META-FALLBACK IS A NON-TERMINATING LOOP.
;;
;; `select-union-lift`'s unsolved-meta arm calls `select-bcast-inner-apply` with
;; the SAME union `u`, and that function's FIRST arm dispatches straight back to
;; `select-union-lift` with the same union. `comps`/`offering` derive purely from
;; `u` (`flatten-union` + a filter), so NOTHING changes between iterations — it is
;; an unconditional infinite mutual recursion, not a slow path.
;;
;; It needs a union whose component set contains an unsolved META, which a single
;; broadcast does not produce — it takes a CHAIN: `sl:a` yields
;; `[PVec Int | ?meta]`, and the second step's union then hits the meta arm.
;; Measured at `730e017f`: `fuel exhausted`, exit 1, and the output is EMPTY —
;; `before` never prints. That is `pipeline.md`'s whole-file-abort signature, the
;; 7th instance in this track, in P4d's own slice-3 code, and it violates the
;; constraint the phase itself states (per-command error VALUES, never a raise).
;; ---------------------------------------------------------------------------

(test-case "P4d-s5: a CHAINED broadcast over a meta-bearing union must not abort the file"
  ;; RED before the fix: the fuel raise escapes `process-string-ws` and this test
  ;; ERRORS rather than failing — which is exactly how the P4d-0 slice-2 abort
  ;; pin behaved, and is the honest shape for an abort.
  (define out (u19 (string-append
                    "def before := 1\n"
                    "def rows := @[{} {:a 1}]\n"
                    "def k := 0N\n"
                    "def sl := [pvec-slice rows k 2N]\n"
                    "sl:a:b")))
  ;; the proposition is PARTIAL OUTPUT — an abort produces none at all
  (check-true (u19-has? out #rx"before : Int defined")
              (format "the file must survive the chained broadcast: ~a" out))
  (check-true (u19-has? out #rx"after : Int defined")
              (format "and must continue past it: ~a" out)))

(test-case "P4d-s5: the meta fallback must not LAUNDER the escape-projection guard"
  ;; ⚠ ADDED after the adversarial verify, which found the first cut traded the
  ;; abort for something quieter and worse. Landing the meta arm in the
  ;; `/non-union` tail sends a UNION subject into `select-project-field`'s union
  ;; arm — the SINGLE-GET optimistic filter, which that arm's own comment forbids
  ;; broadcast from reusing ("never 'unify' them"). Its fold DROPS a meta
  ;; component, so the stored type came out CLEAN, `check-escaping-projection-metas`
  ;; never fired, and `def q := sl:a:b` was ACCEPTED where the SHORTER
  ;; `def q := sl:a` is hard-refused — more projection and less knowledge walking
  ;; past the guard, at zero errors.
  ;;
  ;; The survival pin above is green over all of that; it asserts nothing about
  ;; the ANSWER. This one does.
  (define src (string-append "def k := 0N\n"
                             "def rows := @[{} {:a {:b 1}}]\n"
                             "def sl := [pvec-slice rows k 2N]\n"))
  ;; the ONE-step form is refused by the D23 escape guard — the oracle
  (define one (u19 (string-append src "def one := sl:a")))
  (check-true (u19-has? one #rx"undischarged open-row projection")
              (format "baseline: the one-step def must trip the escape guard: ~a" one))
  ;; the TWO-step form must be refused the SAME way — never silently bound
  (define two (u19 (string-append src "def two := sl:a:b")))
  (check-true (u19-has? two #rx"undischarged open-row projection")
              (format "the chained def must trip the SAME guard, not launder it: ~a" two))
  (check-false (u19-has? two #rx"two : \\[PVec Int\\] defined")
               (format "it must not bind a confident type over a buried error: ~a" two))
  ;; ⚠ THE DISCRIMINATOR: adding an empty `{}` contributes strictly LESS
  ;; information, and must NOT convert a correct refusal into acceptance.
  (define decided (u19 (string-append
                        "def k := 0N\ndef rowsA := @[{:a {:b 1}} {:a 5}]\n"
                        "def slA := [pvec-slice rowsA k 2N]\ndef qA := slA:a:b")))
  (check-true (u19-has? decided #rx"EVERY union component")
              (format "a fully-decided union must still refuse: ~a" decided))
  (define uncertain (u19 (string-append
                          "def k := 0N\ndef rowsB := @[{} {:a {:b 1}} {:a 5}]\n"
                          "def slB := [pvec-slice rowsB k 3N]\ndef qB := slB:a:b")))
  (check-false (u19-has? uncertain #rx"qB : \\[PVec Int\\] defined")
               (format "adding UNCERTAINTY must not buy ACCEPTANCE: ~a" uncertain)))

;; ---------------------------------------------------------------------------
;; D4.P4d slice 6 — SPLIT ABSENCE FROM KEY-MISS  [owner 2026-08-08: "split the
;; flag — don't trade one against the other"; then "C9 governs"].
;;
;; Q_U21 (a) ruled Nil SKIPPED at the TYPE layer. Its VALUE-layer price was that
;; ONE scalar tier answers TWO different questions: `champ-of` fires when an
;; element is NOT a champ (a nil element = ABSENCE) and `project` fires when the
;; element IS a champ but the key is missing (a genuine MISS). Arming the flag to
;; make a miss loud also made an absent element PANIC, so `tier-union-witness`
;; short-circuited on Nil and disarmed the whole union — which made a genuine miss
;; QUIET, the silent-wrong-answer class.
;;
;; THE SPLIT: absence is decided by the VALUE (structurally, at `champ-of`), the
;; tier decides only the key-miss. Both can then be true at once.
;;
;; ⚠ THE ARM IS `expr-nil?` ONLY, and that is measured, not assumed: a non-nil
;; non-champ component cannot survive the keys-⋂ gate (a `[PVec Int]` component is
;; refused at TYPING — "one does not"), so at runtime an element under an armed
;; broadcast is either nil or a champ. The `expr-rrb?` value that reaches
;; `champ-of` in production arrives on the SINGLE-GET path, which `peeled?` keeps
;; permissive and this slice does not touch.
;;
;; ⚠ C9 GOVERNS where it meets Q_U21 (a) [owner]. A Map SIBLING arms the node via
;; C9's conservative OR even when another field is Nil-bearing — that coupling is
;; accepted and is what makes the miss loud there. Q_U21 (a) is scoped to "no
;; armed sibling". The absence panic that coupling used to cause is fixed here by
;; the structural arm, so both rulings hold without weakening either.
;; ---------------------------------------------------------------------------

(define S6 "def MKI : Type := [Map Keyword Int]\ndef m1 : MKI := {:a 1}\ndef m2 : MKI := {:b 2}\ndef nn : <Nil | MKI> := [nil-safe-get {:zz {:q 1}} :a]\n")

(test-case "P4d-s6: a genuine key MISS inside a Nil-bearing union is LOUD"
  ;; RED: today the Nil short-circuit disarms the tier and this is a buried
  ;; `<error>` at ZERO errors — the exact silent-wrong-answer class.
  (define out (u19 (string-append S6 "def ms : [PVec <Nil | MKI>] := @[m1 m2]\nms:a")))
  (check-false (u19-has? out #rx"<error>")
               (format "a genuine miss must not bury an <error>: ~a" out))
  (check-true (u19-has? out #rx"key :a not found")
              (format "it must name the miss: ~a" out))
  ;; and it must match the Nil-FREE control byte for byte in kind
  (define ctl (u19 (string-append S6 "def plain : [PVec MKI] := @[m1 m2]\nplain:a")))
  (check-true (u19-has? ctl #rx"key :a not found")
              (format "the Nil-free control is the oracle: ~a" ctl)))

(test-case "P4d-s6: an ABSENT element stays QUIET — ruling (a) preserved"
  ;; GUARD: green before AND after. This is what Q_U21 (a) protects, and the
  ;; whole point of splitting rather than arming.
  (define out (u19 (string-append S6 "def ab : [PVec <Nil | MKI>] := @[m1 nn]\nab:a")))
  (check-false (u19-has? out #rx"panic")
               (format "an absent element must never panic: ~a" out))
  (check-true (u19-has? out #rx"none")
              (format "it degrades to none: ~a" out)))

(test-case "P4d-s6: an absent element beside an ARMED SIBLING stays quiet too"
  ;; RED: C9's OR arms the node from the Map sibling, and at HEAD that makes an
  ;; ACTUALLY-ABSENT element PANIC — the precise failure ruling (a) exists to
  ;; prevent, live and unpinned. The structural arm fixes it for free, because it
  ;; fires on the VALUE regardless of tier.
  (define out (u19 (string-append S6 "def rB := {:f nn :g m2}\nrB:y")))
  (check-false (u19-has? out #rx"is not a map at runtime")
               (format "an armed sibling must not make ABSENCE panic: ~a" out))
  ;; the union field ALONE is the oracle — quiet at HEAD and after
  (define solo (u19 (string-append S6 "def rA := {:f nn}\nrA:y")))
  (check-false (u19-has? solo #rx"is not a map at runtime")
               (format "the solo control must stay quiet: ~a" solo)))

(test-case "P4d-s6 GUARD: a non-champ NON-nil component is still refused at TYPING"
  ;; The arm is `expr-nil?` only because the gate never lets anything else reach
  ;; `champ-of` under a broadcast. If this ever stops refusing, the arm's width
  ;; assumption is void and must be revisited.
  (define out (u19 (string-append S6
                    "def mixed : [PVec <Nil | MKI | [PVec Int]>] := @[m1 m1]\nmixed:a")))
  (check-true (u19-has? out #rx"EVERY union component")
              (format "a non-offering component must be gate-refused: ~a" out)))

;; ============================================================
;; D4.P4e-0 — THE STAR MINT SUBSTRATE
;; ============================================================
;; Design: D4 §5.P4e-0 (#p4e-0) · rulings Q_U23 (corrected lexical-dividend
;; block) · Q_U27 (the forced hybrid) · Q_U28 · Q_U29 · DEFERRED 90.
;;
;; SCOPE IS THE MINT ONLY. No `*` semantics land in this slice — every arm
;; below asserts either a DATUM shape or a guided REFUSAL.
;;
;; ⚠ THE DEFECT THIS SECTION EXISTS FOR: at HEAD a trailing `*` fuses only
;; after an IDENTIFIER. After a number or a closer it shatters, so `m{0*}` and
;; `m{0 *}` are BYTE-IDENTICAL — the ordinal splat is UNSPELLABLE and no
;; splitter, however written, can recover the distinction.

(define (p4e0-star-e2e src)
  (map (lambda (r) (format "~a" r))
       (process-string-ws
        (string-append "ns p4e0\n"
                       "def cfg := {:database {:url \"u\" :port 1} :version \"v\"}\n"
                       "def r := {:ab* 1 :c*d 2 :plain 3}\n"
                       "def xs := @[{:tags @[1 2]} {:tags @[3]}]\n"
                       src))))

(define (p4e0-has? out rx)
  (ormap (lambda (s) (regexp-match? rx s)) out))

;; ---- A. THE MINT IS REVERTED (D4.P4e-0 re-cut, 2026-08-09) ----
;; The adjacency mint that made `m{0*}` / `x{a}*` / `[f x]*` spellable is GONE.
;; It was count-changing at the READER, which silently shortened preparse forms
;; (a `bundle` body went from a guided error to accepting garbage) and broke the
;; glued Sigma spelling `<(x : Nat)* Nat>`. What remains below is the IDENTIFIER
;; band, which never needed a mint: `ident-continue?` admits `*`, so
;; `database*` / `:tags*` / `c*d` arrive as ONE token and the parser splits them.
;; The non-identifier carriers are a FILED GAP, not a silent one — DEFERRED 101.

;; ---- B. the splitter: IDENTIFIER heads ----

(test-case "P4e-0 B1: an identifier-headed trailing star is SPLIT, not read as a field name"
  ;; At HEAD `cfg{database*}` selects a field literally named `:database*`.
  ;; Q_U28: the operator wins (matching `^`). The mint slice's consumer is a
  ;; guided not-yet, so the observable is a REFUSAL naming the operator.
  (define out (p4e0-star-e2e "def q := cfg{database*}\ndef after := 42"))
  (check-true (p4e0-has? out #rx"not implemented yet")
              (format "identifier-headed star must be split and refused, not read as a field: ~a" out))
  (check-false (p4e0-has? out #rx"database\\*` is not present|field :database\\*")
               (format "must NOT read `database*` as a field name: ~a" out)))

;; ---- C. Q_U29: a mid-lexeme star is a guided error in ALL THREE bands ----

(test-case "P4e-0 C1: mid-star refuses in the BLOCK band, and names the escape"
  (define out (p4e0-star-e2e "def q := r{c*d}\ndef after := 42"))
  (check-true (p4e0-has? out #rx"map-get")
              (format "the mid-star refusal must name the reachable spelling: ~a" out)))

(test-case "P4e-0 C2: mid-star refuses in the DOT band"
  (define out (p4e0-star-e2e "def q := r.c*d\ndef after := 42"))
  (check-true (p4e0-has? out #rx"map-get")
              (format "dot band must refuse mid-star: ~a" out)))

(test-case "P4e-0 C3: mid-star refuses in the OMEGA band (unchanged — it already did)"
  (define out (p4e0-star-e2e "def q := xs:c*d\ndef after := 42"))
  (check-true (p4e0-has? out #rx"map-get")
              (format "omega band keeps refusing mid-star, with the unified message: ~a" out)))

;; ---- D. DEFERRED 90: FOUR members, all silent at HEAD ----

(test-case "P4e-0 D1: a caret continuation bearing a star is REFUSED, not renamed to"
  ;; At HEAD all three define a record field at ZERO errors:
  ;;   cfg{database^_*} -> {:_* …}   cfg{database^a*} -> {:a* …}   cfg{database^*} -> {:* …}
  (for ([src (in-list '("cfg{database^_*}" "cfg{database^a*}" "cfg{database^*}"))])
    (define out (p4e0-star-e2e (string-append "def q := " src "\ndef after := 42")))
    (check-false (p4e0-has? out #rx"q : \\{:[_a]?\\*")
                 (format "~a must NOT define a star-bearing field: ~a" src out))
    (check-true (ormap prologos-error? (process-string-ws
                  (string-append "ns p4e0d\ndef cfg := {:database {:url \"u\"} :version \"v\"}\ndef q := " src)))
                (format "~a must be a guided error" src))))

(test-case "P4e-0 D2: a star BEFORE a caret is refused — a splat has no single output key"
  (define out (p4e0-star-e2e "def q := cfg{database*^a}\ndef after := 42"))
  (check-false (p4e0-has? out #rx"\\.database\\*")
               (format "must not advise the unparseable `.database*`: ~a" out)))

;; ---- E. MUST STAY GREEN: the star is a live VALUE in expression position ----

(test-case "P4e-0 E1: bare `*` stays a bound binary function"
  ;; Q_U26's census correction: `*` is not merely a legal identifier char.
  (define out (p4e0-star-e2e "def s := *\ndef t := [* 3 4]"))
  (check-false (ormap (lambda (s) (regexp-match? #rx"[Ee]rror" s)) out)
               (format "bare `*` must keep working as multiply: ~a" out)))

(test-case "P4e-0 E2: `*`-suffixed identifiers keep working (int* is 148 uses at HEAD)"
  (define out (map (lambda (r) (format "~a" r))
                   (process-string-ws "ns p4e0e\ndef v := [int* 3 4]")))
  (check-false (ormap (lambda (s) (regexp-match? #rx"[Ee]rror" s)) out)
               (format "int* must keep working: ~a" out)))

;; ============================================================
;; DEFERRED 102 — THE ABORT SEAM
;; ============================================================
;; The option-B preparse seam (D4.P4c-4c / G2) converts a preparse RAISE into a
;; `($preparse-error msg)` VALUE so the file continues. It emits that value as a
;; BARE LIST, and Phase-5b's hoist partition calls `syntax->datum` on every
;; element — so whenever a `data`/`trait`/`impl` succeeded in the same file, the
;; guard that exists to prevent whole-file aborts CAUSES one.
;;
;; ⚠ THE TEST OBLIGATION THIS ENTRY EARNED, and it is why the defect survived
;; five parallel censuses: the probe file MUST contain a SUCCESSFUL declaration.
;; Without one, `generated-decl-names` is empty, the partition is skipped by the
;; fast path, and the seam looks clean.

(test-case "DEFERRED 102: a preparse error ALONGSIDE a successful `data` keeps the file alive"
  ;; Measured before the fix: `syntax->datum: contract violation … given:
  ;; '($preparse-error "bundle: …")` and ZERO output — not even `before`.
  (define out
    (map (lambda (r) (format "~a" r))
         (process-string-ws
          (string-append "ns d102a\n"
                         "def before := 1\n"
                         "data Col := Red | Green\n"
                         "bundle Bx := (Add Sub) *\n"
                         "def after := 2\n"))))
  ;; the file CONTINUES — both guard forms survive
  (check-true (ormap (lambda (s) (regexp-match? #rx"before" s)) out)
              (format "the form BEFORE the preparse error must survive: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after" s)) out)
              (format "the form AFTER the preparse error must survive: ~a" out))
  ;; …and the preparse error is reported as a per-command error, not swallowed
  (check-true (ormap (lambda (s) (regexp-match? #rx"preparse" s)) out)
              (format "the preparse error must still be REPORTED: ~a" out)))

(test-case "DEFERRED 102: the CONTROL — no declaration, so the fast path hides it"
  ;; The same file minus the `data` took the fast path and was ALREADY correct.
  ;; Pinned so the fix is not credited with something that already worked, and
  ;; so the pair documents why the defect was invisible.
  (define out
    (map (lambda (r) (format "~a" r))
         (process-string-ws
          (string-append "ns d102b\n"
                         "def before := 1\n"
                         "bundle Bx := (Add Sub) *\n"
                         "def after := 2\n"))))
  (check-true (ormap (lambda (s) (regexp-match? #rx"before" s)) out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"after" s)) out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"preparse" s)) out)))

;; ---------------------------------------------------------------------------
;; Q_U32 — a bare `*` is REFUSED in pattern position; every ARITHMETIC use is
;; untouched  [owner, 2026-08-10]
;;
;; These pins are the RULING'S GUARD RAIL, landed BEFORE the refusal is designed
;; so that "what must not move" is a measured datum rather than a memory. The
;; track's own lesson applies (Q_U23's recorded symptoms went stale inside one
;; arc): a measurement that is not pinned is a measurement that will drift.
;;
;; ⚠ The discriminator is POSITION, not spelling. Since Numerics N6e-E2 operators
;; are FIRST-CLASS VALUES, a BARE `*` is live surface in argument and binding
;; position (`reduce * 1 xs`, `let op *`). A refusal keyed on the bare token
;; would break these; it must key on the position being a PATTERN.
;; ---------------------------------------------------------------------------

(define (q-u32-run src)
  (map (lambda (r) (format "~a" r)) (process-string-ws src)))

(test-case "Q_U32 guard rail: prefix, bracketed, and mixfix `*` are arithmetic"
  (define out (q-u32-run (string-append "ns qu32a\n"
                                        "* 3 5\n"
                                        "[* 3 5]\n"
                                        ".(4 * 5)\n")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"15" s)) out)
              (format "`* 3 5` must stay 15: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"20" s)) out)
              (format "mixfix `.(4 * 5)` must stay 20: ~a" out))
  (check-false (ormap (lambda (s) (regexp-match? #rx"[Ee]rror" s)) out)
               (format "no arithmetic `*` spelling may error: ~a" out)))

(test-case "Q_U32 guard rail: `*` sections keep working in both hole positions"
  (define out (q-u32-run (string-append "ns qu32b\n"
                                        "map [* _ 2] '[1 2 3]\n"
                                        "map [* 3 _] '[1 2 3]\n")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"2 4 6" s)) out)
              (format "`[* _ 2]` section must stay '[2 4 6]: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"3 6 9" s)) out)
              (format "`[* 3 _]` section must stay '[3 6 9]: ~a" out)))

(test-case "Q_U32 guard rail: a BARE `*` is live surface as a first-class operator"
  ;; THE CASE THE RULING'S FOUR NAMED SPELLINGS DID NOT COVER. `reduce * 1 xs`
  ;; and `let op *` put a bare, unglued `*` in argument and binding position.
  ;; If a future refusal keys on "a bare `*` token" instead of on POSITION,
  ;; THIS is the pin that catches it.
  (define out (q-u32-run (string-append "ns qu32c\n"
                                        "reduce * 1 '[2 3 4]\n"
                                        "let op *\n"
                                        "  [op 3 4]\n")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"24" s)) out)
              (format "bare `*` as a HOF argument must stay 24: ~a" out))
  (check-true (ormap (lambda (s) (regexp-match? #rx"12" s)) out)
              (format "bare `*` bound by `let` must stay 12: ~a" out)))

(test-case "Q_U32 TRIPWIRE: pattern-position `*` behaves as a catch-all TODAY"
  ;; ⚠ THIS PIN FREEZES THE PRE-RULING STATE ON PURPOSE. Q_U32 refuses a bare `*`
  ;; in pattern position, so when that lands THIS TEST MUST FAIL and be rewritten
  ;; to assert the guided error. It is a deliberate tripwire, not a decision —
  ;; the same distinction Q_U19's pin is warned about. Measured at 19560a7c.
  (define out (q-u32-run (string-append "ns qu32d\n"
                                        "def q := 5\n"
                                        "match q\n"
                                        "  | * -> 99\n")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"99" s)) out)
              (format "TODAY a lone `| *` binds everything and yields 99: ~a" out)))

;; ---------------------------------------------------------------------------
;; D4.P4e-0 attempt 3, SLICE A — the postfix-star TOKEN TYPE  [Q_U33]
;;
;; The mint is a TOKEN TYPE, assigned at `disambiguate-tokens`, and it is
;; COUNT-PRESERVING (one `*` token in, one `*` token out, re-typed). That is the
;; whole reason it is not attempt 1: no item count moves, so none of the ~416
;; count-gated validator arms can absorb it.
;;
;; ⚠⚠ WHY THE TYPE AND NOT A CHARACTER LOOKBACK — the finding that decides the
;; home. A tokenizer recognizer sees only the previous CHARACTER, and `>` IS NOT
;; A CLOSER CHARACTER: it is the last char of `->` `->>` `&>` `|>` `+>`, all of
;; which classify to 'symbol. A char lookback mints on all five. The previous
;; token's TYPE separates them perfectly — `rangle` is a closer, `symbol` is not.
;; The `>`-final cases below are that guard; they are not decoration.
;; ---------------------------------------------------------------------------

(define (p4e-token-types src)
  ;; (lexeme . type) per token, through the SAME pass production uses
  ;; (`parse-string-to-cells` and `compat-tokenize-string` both call it).
  (register-default-token-patterns!)
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string src)))
  (define bd-rrb (make-bracket-depth-rrb tok-rrb src))
  (define-values (narrowed _changed?) (disambiguate-tokens tok-rrb bd-rrb))
  (for/list ([t (in-list (rrb-to-list narrowed))])
    (cons (token-entry-lexeme t) (set-first (token-entry-types t)))))

(define (p4e-star-type src)
  ;; the type of the FIRST lone `*` token, or #f if there is none
  (cond [(assoc "*" (p4e-token-types src)) => cdr] [else #f]))

(define (p4e-last-star-type src)
  ;; ⚠ USE THIS WHEN THE SOURCE CONTAINS MORE THAN ONE `*`. `p4e-star-type` takes
  ;; the FIRST, and a source like `def a := .(1 * 2)` / `def b := [f x]*` has an
  ;; arithmetic `*` BEFORE the one under test — so the first-match helper reports
  ;; `symbol` and the row fails for a reason unrelated to its name. That is the
  ;; result-narrowing test-helper hazard this track has already paid for once
  ;; (`run-last` swallowing a first-form refusal); it cost a false RED here.
  (let loop ([ts (p4e-token-types src)] [found #f])
    (cond [(null? ts) found]
          [(string=? (car (car ts)) "*") (loop (cdr ts) (cdr (car ts)))]
          [else (loop (cdr ts) found)])))

(test-case "P4e-0 A: a `*` glued to a CLOSER gets the postfix-star type"
  (check-equal? (p4e-star-type "[f x]* ") 'postfix-star "] closer")
  (check-equal? (p4e-star-type "(f x)* ") 'postfix-star ") closer")
  (check-equal? (p4e-star-type "cfg{a}* ") 'postfix-star "} closer"))

(test-case "P4e-0 A: a SPACED `*` after a closer stays an ordinary symbol"
  ;; Q_U33: the space is significant. This is the first-class operator surface
  ;; the Q_U32 guard rail pins — it must not move.
  (check-equal? (p4e-star-type "[f x] * ") 'symbol)
  (check-equal? (p4e-star-type "cfg{a} * ") 'symbol))

(test-case "P4e-0 A: the `>`-FINAL OPERATORS are not closers — a char lookback would mint here"
  ;; ⚠ THE GUARD THAT DECIDED THE DESIGN. Each of these has the `*` byte-adjacent
  ;; to a token whose LAST CHARACTER is `>`, so a character-level closer test
  ;; mints on every one. They are `symbol`-typed, so the TYPE test does not.
  (check-equal? (p4e-star-type "a &>* b")  'symbol "&> clause-sep")
  (check-equal? (p4e-star-type "x |>* y")  'symbol "|> pipe-right")
  (check-equal? (p4e-star-type "a ->* b")  'symbol "-> arrow")
  (check-equal? (p4e-star-type "s ->>* t") 'symbol "->> double-arrow")
  (check-equal? (p4e-star-type "p +>* q")  'symbol "+> choice-arrow"))

(test-case "P4e-0 A: `>>` compose — the lookback must read the OUTPUT, not the input"
  ;; ⚠⚠ THE ROW THE FIRST CUT OF THIS BLOCK DID NOT HAVE, AND THE DEFECT IT MISSED.
  ;; `compose-merge?` folds two `>` into one `>>` and SKIPS an index, so
  ;; `token-rrb[i-1]` is the CONSUMED second `>` — still typed `rangle`, and absent
  ;; from the output. Reading the input minted off a ghost, and the mint was STICKY
  ;; across the second disambiguation round. Reading `result` makes the arm's
  ;; postcondition true by construction.
  (check-equal? (p4e-star-type "a >>* b")  'symbol "compose-merge, glued")
  (check-equal? (p4e-star-type "a > >* b") 'symbol "compose-merge, spaced source")
  (check-equal? (p4e-star-type "a >>>* b") 'symbol "leftover third `>`")
  (check-equal? (p4e-star-type "[f >>* g]") 'symbol "compose inside a bracket group"))

(test-case "P4e-0 A: a bare `>` is `rangle` but is NOT a closer — comparison must not mint"
  ;; `>` is typed `rangle` unconditionally; closer-hood is decided far later by
  ;; `langle-matched?`. `.(3 > 2)` is live comparison. No target carrier uses a
  ;; `>` closer, so `rangle` is excluded from the closer set outright.
  (check-equal? (p4e-star-type "1 >* 2")     'symbol "comparison at depth 0")
  (check-equal? (p4e-star-type "[f a >* b]") 'symbol "comparison at depth 1, no matching `<`")
  (check-equal? (p4e-star-type "<a>* ")      'symbol "an angle group closer does not mint either"))

(test-case "P4e-0 A [Q_U34]: `.( … )` is ARITHMETIC territory — no mint inside mixfix"
  ;; ⚠⚠ THE DESIGN DEFECT, not a code bug. `)*(` is genuinely BOTH readings, and
  ;; `.( )` is the language's live infix surface: `.((1 + 2)*(3 + 4))` → 21 at 0
  ;; errors. What separates them is CONTEXT, and it is measured — infix `*` exists
  ;; ONLY inside mixfix (`rec.n * 2` at command position errors; `.(rec.n * 2)`
  ;; is 42). Accepted narrowing: a star STEP cannot appear inside `.( … )`.
  (check-equal? (p4e-star-type ".((1 + 2)*(3 + 4))") 'symbol "closer-adjacent infix product")
  (check-equal? (p4e-star-type ".((1 + 2)* 3)")      'symbol "closer-adjacent, spaced right")
  (check-equal? (p4e-star-type ".((a + b)* c)")      'symbol "symbolic operands")
  (check-equal? (p4e-star-type ".(xs[0]*(2 + 1))")   'symbol "postfix-index then product")
  ;; …and the gate is scoped to mixfix: the SAME spelling outside it still mints.
  (check-equal? (p4e-star-type "(1 + 2)* ") 'postfix-star "outside mixfix, unambiguous"))

(test-case "P4e-0 A: the glued Sigma DOES mint — pinned as measured, and it is a SEQUENCING constraint"
  ;; ⚠⚠ PINNED AS AN ACCIDENT, NOT A DECISION — the distinction this track has
  ;; had to make before (Q_U19's pin froze one). `<(x : Nat)* Nat>` is legal today
  ;; and elaborates to [Sigma Nat Nat]; its `*` follows `)`, a GENUINE closer, and
  ;; is not inside mixfix — so it mints, and no closer-set or mixfix repair
  ;; reaches it. Gating on angle frames was considered and REJECTED: `<` is typed
  ;; `langle` whether it opens a group or is the less-than OPERATOR, so an angle
  ;; frame stack would mis-nest on `a < b` and suppress legitimate later mints.
  ;;
  ;; HARMLESS IN THIS SLICE, and the reason is exact: `tree-parser.rkt` finds the
  ;; Sigma `*` by LEXEME, not by type (`grep -c token-entry-types tree-parser.rkt`
  ;; → 0), so a type-only mint is invisible to it. Verified: the form still
  ;; elaborates to [Sigma Nat Nat] at 0 errors.
  ;;
  ;; ⛔ THE SEQUENCING CONSTRAINT THIS PIN EXISTS TO CARRY: [Q_U31] refuses the
  ;; glued Sigma spelling, and that refusal MUST land before any consumer keys on
  ;; `postfix-star` — otherwise a live Sigma type silently becomes a star step.
  ;; That is a Tier-A silent-wrong-answer, deferred by exactly one slice.
  (check-equal? (p4e-star-type "<(x : Nat)* Nat>") 'postfix-star)
  ;; the SPACED spelling — the one Q_U31 keeps — is unaffected
  (check-equal? (p4e-star-type "<(x : Nat) * Nat>") 'symbol))

(test-case "P4e-0 A: the mint is COUNT-PRESERVING (and its datum-invisibility ENDED at 1a-iii)"
  ;; Count: one `*` token in, one out — this is what makes it not attempt 1.
  ;; ⭐ STILL THE LOAD-BEARING HALF, and unchanged by the rename. The count is what
  ;; keeps the ~416 count-gated validator arms out of it; the datum was only ever
  ;; the A/B convenience.
  (check-equal? (length (p4e-token-types "[f x]* ")) (length (p4e-token-types "[f x] * "))
                "glued and spaced must produce the SAME token count")
  ;; ⚠⚠ THE DATUM HALF IS DELIBERATELY RETIRED HERE — D4.P4e-1a slice 1a-iii.
  ;; This asserted `'(((f x) *))` with the rationale "the datum must not move — the
  ;; A/B baseline depends on it". That was TRUE OF SLICE A and is the exact thing
  ;; 1a-iii exists to undo: datum-invisibility is also what made the mint INERT, so
  ;; no consumer could see it. Moving the datum IS the rename. Rewritten rather than
  ;; deleted, because "a fact has a timestamp" is this arc's own lesson and a pin
  ;; that silently disappears takes its reasoning with it.
  (check-equal? (read-all-forms-string "[f x]*") '(((f x) $postfix-star))
                "the glued star now carries a DISTINCT datum — this is the rename")
  ;; and the space is what makes them differ, which is Q_U33's whole ruling
  (check-equal? (read-all-forms-string "[f x] *") '(((f x) *))
                "the SPACED spelling keeps the bare `*` — a space is significant")
  (check-not-equal? (read-all-forms-string "[f x]*") (read-all-forms-string "[f x] *")
                    "glued and spaced now DIFFER at the datum layer"))

(test-case "P4e-0 A: a `*` at position 0 does not abort (the rrb-char-at -1 class)"
  ;; `rrb-char-at` guards only the UPPER bound and `rrb-get` RAISES on -1, and a
  ;; raise in the reader is a WHOLE-FILE ABORT (pipeline.md). A lone `*` at file
  ;; position 0 is legal today (`* 3 5` → 15). Pinned so no lookback loses its
  ;; `(= pos 0)` / `(> i 0)` guard.
  (check-equal? (p4e-star-type "*") 'symbol)
  (check-equal? (p4e-star-type "* 3 5") 'symbol)
  (check-equal? (read-all-forms-string "* 3 5") '((* 3 5))))

(test-case "P4e-0 A: ALL NINE openers push a frame — the leak that the first cut shipped"
  ;; ⚠⚠ THE ROWS THE FIRST TWO CUTS OF THIS BLOCK DID NOT HAVE. The frame stack
  ;; was hand-written with a 4-opener PUSH set against a 3-closer POP set, so
  ;; `'[` `@[` `~[` `#{` `.{` were each a NET POP that silently ate the enclosing
  ;; `'mixfix` frame — and the Q_U34 gate then leaked on LIVE INFIX MULTIPLICATION
  ;; at zero errors (`.('[1 2] + (1 + 2)*(3 + 4))` evaluates to 27 and minted).
  ;; That is this file's own 31d27c83 wrong-frame-pop class, committed 280 lines
  ;; below the comment that names it. The fix shares ONE enumeration; these rows
  ;; are what make the sharing testable rather than merely intended.
  ;; ⚠ Every row uses a DIFFERENT opener inside the mixfix. A block that only
  ;; spells `(` `[` `{` passes green while five doors stand open — which is
  ;; exactly what happened twice.
  (check-equal? (p4e-star-type ".((1 + 2)*(3 + 4))")          'symbol "( control")
  (check-equal? (p4e-star-type ".([1 2] + (1 + 2)*(3 + 4))")  'symbol "[ bracket")
  (check-equal? (p4e-star-type ".({a 1} + (1 + 2)*(3 + 4))")  'symbol "{ brace")
  (check-equal? (p4e-star-type ".('[1 2] + (1 + 2)*(3 + 4))") 'symbol "'[ quote-lbracket")
  (check-equal? (p4e-star-type ".(@[1 2] + (1 + 2)*(3 + 4))") 'symbol "@[ at-lbracket")
  (check-equal? (p4e-star-type ".(~[1 2] + (1 + 2)*(3 + 4))") 'symbol "~[ tilde-lbracket")
  (check-equal? (p4e-star-type ".(#{1 2} + (1 + 2)*(3 + 4))") 'symbol "#{ hash-lbrace")
  (check-equal? (p4e-star-type ".(.{a 1} + (1 + 2)*(3 + 4))") 'symbol ".{ dot-lbrace"))

(test-case "P4e-0 A: `lparen` is KIND-SENSITIVE and `in-mixfix?` is TOP-OF-STACK"
  ;; Two properties copied from the authoritative stack rather than invented.
  ;; (a) a `(` inside mixfix STAYS mixfix — otherwise the inner group's closer
  ;;     would re-enable the mint on the arithmetic it encloses.
  (check-equal? (p4e-star-type ".( ( (1 + 2)*(3 + 4) ) )") 'symbol "nested parens stay mixfix")
  ;; (b) the test is the TOP frame, not `memq` over the whole stack. A bracket
  ;;     nested in mixfix re-enters application territory — measured: the star is
  ;;     NOT infix there (`.([+ 1 (1 + 2)*(3 + 4)])` is a type error). A `memq`
  ;;     test suppressed legitimate mints inside `.( [ … ] )`.
  (check-equal? (p4e-star-type ".( [f [g x]* ] )") 'postfix-star
                "inside a bracket nested in mixfix, the star step is live again"))

(test-case "P4e-0 A: the frame stack does not leak across commands or literals"
  ;; A leaked `'mixfix` frame would SILENTLY suppress every later mint in the
  ;; file — the quiet twin of the leak above, and the reason these are pinned.
  (check-equal? (p4e-star-type ".(1 + 2)\n[f x]* ")                'postfix-star "after a closed mixfix")
  (check-equal? (p4e-star-type ".(@[1 2])\n[f x]* ")               'postfix-star "…containing a leak-prone opener")
  ;; two stars in this one — the mixfix multiply, then the step. Assert the LAST.
  (check-equal? (p4e-last-star-type "def a := .(1 * 2)\ndef b := [f x]* ") 'postfix-star "across commands")
  (check-equal? (p4e-star-type      "def a := .(1 * 2)\ndef b := [f x]* ") 'symbol
                "…and the mixfix multiply itself must stay a plain symbol")
  ;; unbalanced closers must not underflow the stack
  (check-equal? (p4e-star-type "a) b [f x]* ")  'postfix-star "stray closer")
  (check-equal? (p4e-star-type "a]]] [f x]* ")  'postfix-star "stray closers")
  ;; frame characters inside strings / chars / comments must never reach the stack
  (check-equal? (p4e-star-type "def s := \"(\" \n[f x]* ") 'postfix-star "paren in a string")
  (check-equal? (p4e-star-type ";; .( a comment\n[f x]* ")  'postfix-star "mixfix in a comment"))

(test-case "P4e-0 A: a STRAY closer inside mixfix must not eat the frame (over-pop)"
  ;; ⚠⚠ THE MIRROR IMAGE of the under-push leak above, and the third verify's find.
  ;; Popping on ANY closer is an over-pop: `.( } (1 + 2)*(3 + 4) )` evaluates to
  ;; 21 at ZERO errors, and the stray `}` ate the `'mixfix` frame so the star
  ;; minted on live multiplication.
  ;; ⭐ THE AUTHORITY FOR MIXFIX EXTENT IS `group-items`, NOT
  ;; `make-bracket-depth-rrb`. `group-items` carries a `close-type` and lets a
  ;; NON-matching closer fall through as a plain item — which is why that probe
  ;; still prints 21. The bracket-depth stack pops unconditionally and over-pops
  ;; too, so mirroring it FAITHFULLY reproduced its bug. The gate matches the
  ;; grouper: pop only on the frame's own expected closer.
  (check-equal? (p4e-star-type ".( (1 + 2)*(3 + 4) )")     'symbol "control")
  (check-equal? (p4e-star-type ".( } (1 + 2)*(3 + 4) )")   'symbol "stray }")
  (check-equal? (p4e-star-type ".( ] (1 + 2)*(3 + 4) )")   'symbol "stray ]")
  (check-equal? (p4e-star-type ".( } } (1 + 2)*(3 + 4) )") 'symbol "two stray }")
  (check-equal? (p4e-last-star-type ".( } (1 + 2)*(3 + 4) + (5 + 6)*(7 + 8) )")
                'symbol "two products, neither mints")
  ;; …but a MATCHING `)` genuinely CLOSES the group, so what follows is outside
  ;; mixfix and minting there is correct. Not a silent hazard: the empty group is
  ;; a LOUD per-command error, with the rest of the file still produced.
  (check-equal? (p4e-star-type ".( ) (1 + 2)*(3 + 4) )") 'postfix-star
                "a matching `)` closes the mixfix — `.( )` itself errors loudly"))

;; ---------------------------------------------------------------------------
;; D4.P4e-1a — THE MINT GETS A CONSUMER  [Q_U33 · Q_U34 · Q_U35]
;;
;; Slice A minted a `postfix-star` TOKEN TYPE and deliberately kept it
;; DATUM-INVISIBLE, so the corpus A/B baseline stayed clean. That safety property
;; is also why the mint is INERT: `token-entry->stx` renders it as a plain `*`,
;; so no consumer can see it, and the carriers give `Could not infer type`
;; instead of the guided message the fused identifier band gets.
;;
;; ⚠⚠ THE ARRIVAL INVENTORY, GENERATED NOT READ (the last three defects were all
;; bad enumerations): a `postfix-star` token reaches a datum in **40 of 44**
;; carrier x context spellings — command position, `def` RHS, application
;; argument, bracket application, nested bracket, map-literal value, vector and
;; list literals, select-block item, `defn` body. Only the four mixfix spellings
;; do not, which is [Q_U34]'s gate working. So making the datum visible has a
;; blast radius of ELEVEN contexts, and every one needs a consumer or a refusal —
;; a bare sentinel reaching the user is the class the revert `d0ac2a58` itemised.
;;
;; [Q_U35] is what makes that tractable: `*` after a NON-SELECTION expression is
;; REFUSED, so the sentinel never has to be armed outside the selection surface.
;; The fuse rule is therefore: `$postfix-star` immediately following a
;; SELECTION-SHAPED item fuses; everywhere else it is a guided refusal.
;; ---------------------------------------------------------------------------

;; ⚠⚠ THE TWO TARGET TEST-CASES BELOW ARE COMMENTED OUT — they are P4e-1a's
;; FAILING-TEST-FIRST artifacts and they fail at HEAD BY DESIGN. Uncomment them as
;; the implementation lands, following this repo's acceptance-file idiom (target
;; expressions ship commented and are uncommented as phases complete).
;; They fail for exactly the right reasons, verified: `x{a}*` does not reach
;; `star-not-yet-message`, and `[f x]*` gets `Could not infer type` rather than
;; [Q_U35]'s refusal.
;; ⚠ MEASUREMENT NOTE worth keeping: rackunit ABORTS a `test-case` at its first
;; failed check, so "2 FAILURES" here meant 2 failing test-CASES, not 2 failing
;; assertions — the later checks in each never ran. Do not read a failure count
;; as an assertion count.
(define (p4e1-msgs src)
  ;; full per-command output for a WS string, as strings
  (map (lambda (r) (format "~a" r)) (process-string-ws src)))

;; ⭐⭐ D4.P4e-1b slice 1b-iii-A — THE INSTRUMENT WAS VACUOUS, AND SYSTEMICALLY SO.
;; `p4e1-has?` used to `ormap` over EVERY per-command output — INCLUDING the
;; setup `def` lines — so any expectation whose regex is a substring of a
;; SUBJECT's printed value or type could never fail. Measured at `7fd25f35` on
;; the attempt-2 patch's headline new pin (`rowsv:tags*` "collapses the type to
;; [PVec Int]"), against the STARLESS control:
;;
;;   [0] "rowsv : [PVec {:tags [PVec Int]}] defined."   ← the SETUP line matches
;;   [1] "@[@[1 2] @[3]] : [PVec [PVec Int]]"           ← the WRONG answer matches
;;   (p4e1-has? … #rx"\\[PVec Int\\]")  ⇒  #t
;;
;; Vacuous twice over, while the patch's comment called it "the assertion that
;; caught the implementation's one real defect".
;;
;; THE FIX IS DELIBERATELY LOUD RATHER THAN CAREFUL: `p4e1-has?` keeps its name
;; and all its call sites but now looks ONLY at the final command's output — the
;; expression under test. Any pin that was passing on a setup line's rendering
;; turns RED, which converts a silent systemic weakness into an enumerable list.
;; A pin that GENUINELY needs an earlier line (e.g. "`before` survived") says so
;; with `p4e1-any-has?`; that is a deliberate, visible opt-out.
;; ⚠ This closes the SETUP-LINE half only. The CONTAINMENT half — `[PVec [PVec
;; Int]]` contains `[PVec Int]` — is a weak REGEX, not a weak instrument; assert
;; a type with `p4e1-type=?`, which compares the rendered type EXACTLY.
(define (p4e1-last src)
  (let ([ms (p4e1-msgs src)])
    (if (null? ms) "" (car (reverse ms)))))

(define (p4e1-has? src rx)
  (and (regexp-match? rx (p4e1-last src)) #t))

;; the deliberate opt-out: match ANY per-command output, setup lines included.
(define (p4e1-any-has? src rx)
  (and (ormap (lambda (s) (regexp-match? rx s)) (p4e1-msgs src)) #t))

;; the rendered TYPE of the final command, or #f when it printed no `V : T`.
;; Splits on the LAST " : " so a record type's `{:k T}` interior cannot confuse
;; it, and drops a trailing `defined.` so a `def` line is comparable too.
(define (p4e1-type src)
  (let* ([s (p4e1-last src)]
         [ms (regexp-match #rx"^.* : (.*)$" s)])
    (and ms
         (let ([t (cadr ms)])
           (if (regexp-match? #rx" defined[.]$" t)
               (substring t 0 (- (string-length t) (string-length " defined.")))
               t)))))

(define (p4e1-type=? src expected)
  (equal? (p4e1-type src) expected))

(test-case "P4e-1b [1b-iii-A]: the INSTRUMENT discriminates — a setup line can no longer satisfy a pin"
  ;; The exact source the attempt-2 patch's headline pin used, minus the star.
  ;; If `p4e1-has?` ever goes back to scanning every output, line 1 turns this red.
  (define starless "ns v1t\ndef rowsv := @[{:tags @[1 2]} {:tags @[3]}]\nrowsv:tags")
  ;; Measured outputs at `7fd25f35`:
  ;;   [0] "rowsv : [PVec {:tags [PVec Int]}] defined."
  ;;   [1] "@[@[1 2] @[3]] : [PVec [PVec Int]]"
  ;;
  ;; ⚠ THIS PIN'S FIRST CUT WAS ITSELF AN OVER-CLAIM, and running it is what
  ;; caught that — it asserted the restriction kills `#rx"\\[PVec Int\\]"` on the
  ;; starless control. It does not, and cannot: the WRONG answer on line [1]
  ;; contains that substring. The two defects are independent and the pin now
  ;; separates them instead of conflating them.
  ;;
  ;; HALF 1 — THE SETUP-LINE DEFECT, pinned as fixed. `{:tags` appears ONLY in
  ;; the subject's own printed type on line [0], never in the expression's output.
  (check-false (p4e1-has? starless #rx"\\{:tags")
               "a setup line's rendering can no longer satisfy a pin")
  (check-true (p4e1-any-has? starless #rx"\\{:tags")
              "…and it really is there — the deliberate opt-out still sees it, which is what makes the check above discriminating")
  ;; HALF 2 — THE CONTAINMENT DEFECT is a weak REGEX, not a weak instrument, and
  ;; the restriction does NOT rescue it: `[PVec [PVec Int]]` contains `[PVec Int]`,
  ;; so the attempt-2 pin would still pass on the starless control AND on the
  ;; wrong answer. Pinned as STILL TRUE so nobody reads half 1 as covering it.
  (check-true (p4e1-has? starless #rx"\\[PVec Int\\]")
              "a substring type regex remains satisfiable by the WRONG answer — restricting the instrument does not fix a weak expectation")
  ;; …and the exact comparison is what separates them. 1b-iii's join pins must
  ;; use `p4e1-type=?`, not a substring regex, for every type claim.
  (check-true (p4e1-type=? starless "[PVec [PVec Int]]")
              "the starless projection's type, exactly")
  (check-false (p4e1-type=? starless "[PVec Int]")
               "…and it is NOT the collapsed type — which the substring regex above cannot tell"))

(test-case "P4e-1a: the SELECTION carriers reach a guided STAR message"
  ;; ⚠ SEAT-MIGRATED at 1b-iii-B2, with the reasoning recorded (C31): this
  ;; pin's PROPOSITION is REACHABILITY — the carriers arrive at a guided star
  ;; diagnostic instead of `Could not infer type`. Which message is now
  ;; CONTENT-dependent: `c{a}*`'s layer is `{:a Int}`, a LEAF content, so the
  ;; honest message is the PERMANENT leaf refusal (1b-iii's kind split), not
  ;; the old uniform not-yet. The proposition survives; the text moved.
  (check-true (p4e1-has? "ns q1\ndef c := {:a 1}\ndef b := c{a}*"
                         #rx"a leaf has no join")
              "x{a}* — reaches the star's own guided (leaf-permanent) message")
  (check-true (p4e1-has? "ns q2\ndef xs := @[{:a 1}]\ndef b := xs:{a}*"
                         #rx"\\(flatten\\) is not implemented yet")
              "xs:{a}* — preceding step is a broadcast"))

(test-case "P4e-1a [Q_U35]: `*` after a NON-SELECTION expression is refused"
  ;; Not "Could not infer type" (today's accident) and not a leaked sentinel —
  ;; a guided refusal. The star is a PATH-SELECTION operator only.
  (check-true (p4e1-has? "ns q3\ndefn f [z] z\ndef b := [f 1]*" #rx"selection|flatten")
              "[f x]* — no preceding step")
  (check-true (p4e1-has? "ns q4\ndefn f [z] z\ndef b := (f 1)*" #rx"selection|flatten")
              "(f x)* — no preceding step")
  ;; ⚠ and the refusal must NOT be a leaked internal sentinel
  (check-false (p4e1-has? "ns q5\ndefn f [z] z\ndef b := [f 1]*" #rx"\\$postfix-star")
               "no internal sentinel may reach the user"))

(test-case "P4e-1a: the SPACED forms keep their current meaning [Q_U32 guard rail]"
  ;; `*` is a first-class operator; the spaced spelling must stay an ordinary
  ;; application argument. This is the whole point of the space being significant.
  (check-false (p4e1-has? "ns q6\ndef c := {:a 1}\ndef b := c{a} *"
                          #rx"\\(flatten\\) is not implemented yet")
               "spaced select must NOT take the flatten refusal")
  (check-false (p4e1-has? "ns q7\ndefn f [z] z\ndef b := [f 1] *" #rx"\\$postfix-star")
               "spaced application must not leak a sentinel"))

;; ---------------------------------------------------------------------------
;; D4.P4e-1a slice 1a-i — THE INVENTORY AS A GATE, GENERATED NOT HAND-LISTED
;;
;; ⚠⚠ WHAT THIS REPLACED, and why the replacement is the point. The previous
;; version of this gate hand-listed SIX sources and commented itself "One row per
;; context that mints" — against D4's own TEN. It used 2 of the 10 minting
;; carriers and covered 6 of 190 cells (3.2%). That is the BAD-ENUMERATION shape
;; which produced the last three blocking defects in this arc, sitting inside the
;; instrument meant to catch them. **An instrument written from the
;; implementation inherits its blind spot.**
;;
;; The enumeration now lives in ONE place — `tools/star-arrival-matrix.rkt` —
;; and is read, never copied. Adding a carrier or context there widens this gate
;; automatically. Measured there: 11 minting carriers x 19 arrival contexts =
;; **190 cells**, plus 4 controls that must never mint and a mixfix context where
;; Q_U34's gate blocks everything.
;;
;; ⚠ COST NOTE, since it decides the shape: one `process-*` call per cell is
;; ~324 ms (env setup dominates), i.e. ~123 s for 190 cells — the file's whole
;; 120 s budget. Cells are therefore BATCHED: many forms per source, one call per
;; batch. The property is preserved exactly, because every form's output is still
;; inspected; only the env setup is shared.
;;
;; TWO assertions per batch, and the first one matters as much as the second:
;;   (a) output is NON-EMPTY — an empty result is the WHOLE-FILE ABORT signature
;;       (`pipeline.md`: output stops being partial, it does not become partial),
;;   (b) no line contains `$postfix-star` — a leaked internal sentinel is
;;       `d0ac2a58`'s class.
;; Both pass VACUOUSLY today: the mint is datum-invisible, so no sentinel exists
;; yet. They ARM on slice 1a-iii's rename. That is deliberate — the instrument
;; lands BEFORE the change it guards, never after.
;; ---------------------------------------------------------------------------

;; ⚠⚠ NINETEEN CELLS WHOLE-FILE ABORT AT HEAD — PRE-EXISTING, and the star's
;; MINT is NOT implicated. Measured (DEFERRED 108): a trailing `*` in PATTERN
;; position or MATCH-SCRUTINEE position raises out of preparse. The decisive
;; differential is glued-vs-spaced on the SAME shape:
;;     `| '[1 2]* -> 1`   mint=Y  RAISE list-ref: contract violation
;;     `| '[1 2] * -> 1`  mint=n  RAISE list-ref: contract violation   <- identical
;;     `| '[1 2] -> 1`    (no star)         4 outputs, fine
;; A SPACED `*` is ordinary first-class-operator surface (Q_U32's guard rail), so
;; this predates the whole P4e mint. Three non-minting CONTROLS abort too, which
;; is what rules slice A out.
;;
;; They are PINNED, not skipped. Skipping would silently narrow the gate — the
;; failure mode a coverage instrument cannot self-report. The set is recorded as
;; a MEASURED SNAPSHOT and compared as a whole, so a NEW abort turns this red and
;; so does a FIX (which should then update the snapshot and file the win).
;; ⭐⭐ 21 → 19, AND THE NUMBER'S HISTORY IS THE LESSON. The fuse retired the two
;; `match-scrut` aborts for the USABLE carriers (`c{a}*`, `xs:{a}*` now get a
;; guided message where they used to kill the whole file) — that stands. An
;; intermediate cut measured 13 here and celebrated it: its preparse-refusal
;; marker also shielded six `pattern-pos` cells from `compile-match-tree`'s
;; `list-ref` abort. [Q_U37](#q-u37) removed the marker — it was pre-empting the
;; Sigma seat and breaking quasiquote — and those six cells RETURNED, which is
;; honest: they were shielded by the wrong mechanism, not fixed. They are
;; DEFERRED 108's pre-existing residue (a SPACED star aborts them identically),
;; and their fix belongs to the `compile-match-tree` sibling of DEFERRED 103,
;; not to the star surface.
(define p4e1-known-aborting-cells   ;; DEFERRED 108 — context . carrier, MEASURED
  '(;; pattern position — 7, `list-ref` family (DEFERRED 103's sibling)
    ("pattern-pos" . "bcast-brace")  ("pattern-pos" . "quote-list")
    ("pattern-pos" . "pvec")         ("pattern-pos" . "hset")
    ("pattern-pos" . "map-lit")      ("pattern-pos" . "mixfix-close")
    ("pattern-pos" . "postfix-index")
    ;; match scrutinee — 12, `car` family; THREE CONTROLS sit here, which is what
    ;; rules the mint out as the cause
    ("match-scrut" . "bracket-app")  ("match-scrut" . "paren-app")
    ("match-scrut" . "quote-list")   ("match-scrut" . "pvec")
    ("match-scrut" . "hset")         ("match-scrut" . "map-lit")
    ("match-scrut" . "quasiquote")   ("match-scrut" . "mixfix-close")
    ("match-scrut" . "postfix-index")
    ("match-scrut" . "ord-bcast!")   ("match-scrut" . "ord-dot!")
    ("match-scrut" . "path-literal!")))

;; ⚠⚠ THE OBSERVABLE IS THE **DATUM**, NOT THE RENDERED MESSAGE. This is the
;; slice's most expensive lesson and it was found by adversarial verify, after
;; the message-grep version had gone green.
;;
;; The first cut grepped user-visible output for the string `$postfix-star`.
;; Simulating slice 1a-iii — planting the sentinel in each cell and running this
;; gate's own machinery — showed it could only ever go red in **72 of 190** cells.
;; In the other 118 the clean and planted outputs are BYTE-IDENTICAL:
;;
;;   app-arg  clean  : arity-error … Too many arguments to 'f'
;;   app-arg  planted: arity-error … Too many arguments to 'f'      <- identical
;;
;; The cause is structural, not cosmetic: an unconsumed sentinel is an EXTRA
;; DATUM, so the form fails on SHAPE (arity, parse, map-literal parity) long
;; before anything renders the symbol. `quasiquote-body` was worse — it renders
;; only the TYPE (`q0 : Datum defined.`), so no message improvement could ever
;; reach it, on the one surface where a renamed sentinel survives into user data.
;;
;; The real invariant is not "the sentinel never appears in text". It is:
;;   ⭐ **NO UNCONSUMED `$postfix-star` SURVIVES PREPARSE INTO THE DATUM.**
;; After preparse a star has either FUSED into a step or been REFUSED; a bare
;; sentinel left in the tree is exactly the defect. It needs no elaboration, so
;; it is nearly free.
;;
;; ⚠ AND IT IS NOT TOTAL EITHER — measured, by planting the sentinel in every
;; cell and running both observables (11 minting carriers x 20 contexts = 220):
;;
;;      DATUM observable   187 / 220
;;      MESSAGE observable  92 / 220
;;      UNION              208 / 220   <- 12 cells can turn NEITHER red
;;
;; They are COMPLEMENTARY, not nested: `let-nested` is 0/10 the other way (the
;; message sees it, the datum does not), which is why BOTH are kept. The 12
;; residual blind cells cluster in `let-bracket` (8), `quasiquote-body` (3) and
;; `let-nested` (1) — the same `let` seat DEFERRED 106 records as reached by none
;; of the four `rewrite-dot-access` call sites, plus the `Datum` value that
;; renders only its type.
;;
;; The number is stated rather than rounded up to "total" on purpose: the first
;; cut of this gate claimed 190 cells and could fire in 72, and the claim is what
;; the next session would have trusted.
;;
;; ⚠ COST: the message layer runs on the CACHED-PRELUDE fixture (`run-ws-pre`),
;; not a fresh `process-string-ws`. Measured on this machine: cached ~76 ms/call,
;; fresh-with-prelude ~103 ms/call. (An earlier comment here said 324 ms and
;; derived "~123 s for 190 cells"; both were wrong — 0.324 x 190 is 61.6 s, not
;; 123 s. The batching CONCLUSION survives the correction, the arithmetic did
;; not. Recorded rather than quietly deleted: asserting a number instead of
;; measuring it is this arc's recurring failure.)
;; The file's own history is median 22 s, p90 79 s, **max 115 s** against the
;; runner's 120 s `--all` cap, so the batch pass is MEMOIZED — it used to run
;; twice, which was 2.2 s of pure duplication.
(define (p4e1-batch-src k)
  ;; one source per CONTEXT, carrying every carrier as a separate form
  (string-append
   star-prelude
   (string-join (for/list ([c (in-list star-carriers)] [n (in-naturals)])
                  (star-cell-source k c n))
                "\n")
   "\n"))

(define (p4e1-cell-src k c) (string-append star-prelude (star-cell-source k c 0) "\n"))

(define (p4e1-pre-msgs src)
  (with-handlers ([(lambda (e) #t) (lambda (e) 'RAISED)]) (run-ws-pre src)))

;; memoized: the batch pass used to run twice (abort scan + leak loop) = +2.2 s
(define p4e1-batch-cache (make-hash))
(define (p4e1-batch-msgs k)
  (hash-ref! p4e1-batch-cache (car k) (lambda () (p4e1-pre-msgs (p4e1-batch-src k)))))

(define (p4e1-raises? src) (eq? (p4e1-pre-msgs src) 'RAISED))

;; ---- THE PRIMARY OBSERVABLE: the post-preparse datum ----
;; `read-all-forms-string` then `preparse-expand-form`, exactly the two stages a
;; star must survive to reach the parser. No elaboration, no typing — ~free.
(define (p4e1-preparsed src)
  (with-handlers ([(lambda (e) #t) (lambda (e) 'RAISED)])
    (for/list ([d (in-list (read-all-forms-string src))]) (preparse-expand-form d))))

;; ⚠⚠ THE PREPARSE OBSERVABLE IS A THREE-WAY PARTITION, NOT A BOOLEAN — and the
;; boolean version of this gate has now been WRONG TWICE, in opposite directions,
;; which is why the partition is pinned cell-by-cell against a measured table.
;;   Cut 1 ("no star survives preparse") flagged the FUSED form as a leak.
;;   Cut 2 refined "survives" to "unconsumed" — and then FORCED the implementation
;;   into refusing at preparse-everywhere to satisfy it, which pre-empted the
;;   Sigma seat and broke the quasiquote lowering. The instrument shaped the code;
;;   [Q_U37](#q-u37) is the ruling that unwound it.
;; Under Q_U37 a star's preparse fate is one of THREE, each legitimate somewhere:
;;   'consumed — payload of a `$select-path`/`$select` node (the fuse, or an
;;               in-block arg). These heads route their args through
;;               `segment-select-items`, where the star's parser arm lives.
;;   'bare     — passed through untouched, for a DOWNSTREAM territory seat:
;;               `parse-datum` (expression → Q_U35), `unwrap-angle-type` (type →
;;               Q_U31). Cut 2 called every one of these a defect; they are the
;;               design.
;;   'gone     — no `$postfix-star` remains: data territory captured it as `*`
;;               (quasiquote), or a `let` error marker embedded the offending
;;               datum as a STRING (the message-leak pin owns that seat).
;; What is NOT legitimate is a cell CHANGING class silently — a fusion break
;; demotes consumed→bare, a regression to cut 2's marker turns bare→gone, a
;; normalization break turns gone→bare. The table below is the measured truth.
(define p4e1-star-consuming-heads '($select-path $select))

(define (p4e1-star-class src)
  ;; 'consumed | 'bare | 'gone | 'RAISED over the cell's preparsed forms.
  ;; 'bare wins over 'consumed when both occur — a leak beside a fuse is a leak.
  (define ds (p4e1-preparsed src))
  (cond
    [(eq? ds 'RAISED) 'RAISED]
    [else
     (define has-consumed #f)
     (define has-bare #f)
     (let scan ([d ds] [parent #f])
       (cond
         [(eq? d '$postfix-star)
          (if (memq parent p4e1-star-consuming-heads)
              (set! has-consumed #t)
              (set! has-bare #t))]
         [(pair? d)
          (let ([h (and (symbol? (car d)) (car d))])
            (let loop ([xs d] [first? #t])
              (when (pair? xs)
                (scan (car xs) (if first? parent h))
                (loop (cdr xs) #f))
              (when (and (not (pair? xs)) xs) (scan xs h))))]
         [(vector? d) (for ([x (in-vector d)]) (scan x parent))]
         [else (void)]))
     (cond [has-bare 'bare] [has-consumed 'consumed] [else 'gone])]))

;; The EXPECTED table — rules plus measured exceptions, stated openly.
;; ⚠ RAISED cells are excluded ON EVIDENCE, not convenience: every preparse-level
;; raise was differentialed STAR-FREE — `.(1 + [f 1] *)` raises identically
;; SPACED (a dangling arithmetic operator, correctly diagnosed), and the
;; quasiquote raises reproduce with NO star at all (`` `['[1 2]] `` — nested
;; `$list-literal`/`$mixfix` in a quasiquote body, pre-existing). E2E the option-B
;; seam guard converts all of them to per-command errors.
(define (p4e1-expected-class kname cname)
  (cond
    ;; in-block position: every carrier is an arg of `$select` — consumed
    [(equal? kname "select-item") 'consumed]
    ;; data territory: the star is captured as the `*` the user wrote
    [(equal? kname "quasiquote-body") 'gone]
    ;; DEFERRED 106's seat: the `let` error paths embed the datum as a STRING
    ;; (let-nested) or split by binding shape (let-bracket — measured: the
    ;; 3-item bindings surface the datum, the others embed it)
    [(equal? kname "let-nested") 'gone]
    [(equal? kname "let-bracket")
     (if (member cname '("select-brace" "bcast-brace" "postfix-index")) 'bare 'gone)]
    ;; everywhere the fold runs: Q_U36's positive list decides
    [(member cname '("select-brace" "bcast-brace")) 'consumed]
    [else 'bare]))

;; What the prelude ALONE emits — MEASURED, not assumed. The dead assertion this
;; replaces was `(pair? msgs)`, which can never fail: the prelude always
;; contributes lines, so a non-raising batch is never empty.
(define star-prelude-results (p4e1-pre-msgs star-prelude))

(define p4e1-observed-leaks '())

(test-case "P4e-1a slice 1a-i: no arrival position leaks the sentinel at the user"
  ;; Batched for cost (env setup dominates); a batch that RAISES falls back to
  ;; per-cell so the aborting cells can be named. The fallback is automatic — no
  ;; hand-split of "which contexts are broken", which would be the same
  ;; bad-enumeration shape this gate replaced.
  (define observed-aborts
    (for*/list ([k (in-list star-contexts)]
                #:when (p4e1-raises? (p4e1-batch-src k))
                [c (in-list star-carriers)]
                #:when (p4e1-raises? (p4e1-cell-src k c)))
      (cons (car k) (car c))))
  (check-equal? (list->seteq (map (lambda (p) (string->symbol (format "~a/~a" (car p) (cdr p))))
                                  observed-aborts))
                (list->seteq (map (lambda (p) (string->symbol (format "~a/~a" (car p) (cdr p))))
                                  p4e1-known-aborting-cells))
                "the DEFERRED 108 abort set changed — a NEW abort, or one was fixed")
  ;; ---- PRIMARY: the preparse PARTITION — every minting cell lands in exactly
  ;; the class the table predicts. A cell changing class is the regression:
  ;; consumed→bare = fusion broke · bare→gone = cut 2's marker came back ·
  ;; gone→bare = a data-capture normalization broke.
  ;; ⚠ The preparse-RAISED cells are a PINNED SNAPSHOT too — the verify caught
  ;; the skip being open-ended: without the snapshot, a change that makes a
  ;; minting cell RAISE at preparse would green its partition cell silently
  ;; (the E2E abort pin cannot see it — the G2 seam converts preparse raises to
  ;; per-command errors — and the leak pin only fires if the message happens to
  ;; carry the sentinel). All three members reproduce with NO STAR AT ALL
  ;; (nested `$list-literal`/`$mixfix` inside a quasiquote body), so they are
  ;; pre-existing, but the SET is what must not move unnoticed.
  (define observed-preparse-raises '())
  (for* ([k (in-list star-contexts)]
         #:unless (equal? (car k) "mixfix!")   ;; control context: no mint at all
         [c (in-list star-carriers)]
         #:when (star-minting-carrier? c))
    (define got (p4e1-star-class (p4e1-cell-src k c)))
    (if (eq? got 'RAISED)
        (set! observed-preparse-raises
              (cons (string->symbol (format "~a/~a" (car k) (car c)))
                    observed-preparse-raises))
        (check-equal? got (p4e1-expected-class (car k) (car c))
                      (format "preparse star class moved: ~a / ~a" (car k) (car c)))))
  (check-equal? (list->seteq observed-preparse-raises)
                (seteq 'quasiquote-body/quote-list
                       'quasiquote-body/quasiquote
                       'quasiquote-body/mixfix-close)
                "the preparse-RAISED set changed — a new raw-level raise, or one was fixed")

  ;; ---- SECONDARY: the user-facing message channel.
  ;; Only ~38% of cells can ever show the sentinel in rendered text (see the note
  ;; above), so this is a genuine but PARTIAL property — kept because those cells
  ;; are real, not because the coverage is total.
  ;; ⚠ Per-CELL inside a raising context, not skip-the-context: two batches raise
  ;; while only 19 of their 28 cells do, and 4 of the 9 survivors are MINTING
  ;; arrival cells. Skipping the context dropped them silently — the failure mode
  ;; this gate exists to prevent, committed inside the gate itself.
  (for ([k (in-list star-contexts)])
    (define batch (p4e1-batch-msgs k))
    (define per-cell? (eq? batch 'RAISED))
    (define msg-lists
      (if per-cell?
          (for/list ([c (in-list star-carriers)])
            (p4e1-pre-msgs (p4e1-cell-src k c)))
          (list batch)))
    ;; the live "did anything come out" check is the COUNT, not `pair?`:
    ;; `star-prelude` alone yields 5 lines, so a non-raising batch is never '().
    (unless per-cell?
      (check-true (> (length batch) (length star-prelude-results))
                  (format "context ~a produced only the prelude's lines — the carrier forms vanished"
                          (car k))))
    (for* ([ms (in-list msg-lists)] #:unless (eq? ms 'RAISED) [m (in-list ms)])
      (when (regexp-match? #rx"\\$postfix-star" m)
        (set! p4e1-observed-leaks (cons (car k) p4e1-observed-leaks)))))
  ;; ⚠⚠ THE MESSAGE LEAKS ARE PINNED AS A SET, exactly like the abort set, and for
  ;; the same reason: silently excluding them would narrow the gate, which is the
  ;; one failure a coverage instrument cannot self-report. TWO members, both
  ;; PRE-EXISTING seats the star merely joins — each proven by a star-free
  ;; differential:
  ;; · `let-nested` — [DEFERRED 106](DEFERRED.md): the binding value is reached by
  ;;   NONE of the four `rewrite-dot-access` seats, and `let`'s "unrecognized
  ;;   format" error prints the raw datum verbatim. It leaked `$select-brace`
  ;;   before this slice existed.
  ;; · `spec-type` — [DEFERRED 109](DEFERRED.md): a SELECTION sentinel in a spec's
  ;;   type region mis-fuses with the `$angle-type` HEAD SYMBOL as its subject
  ;;   (`spec s c{a} -> Int` → `($select $angle-type a)`, NO STAR INVOLVED — `c.a`
  ;;   garbles identically) and the defn/spec seam prints raw SYNTAX OBJECTS.
  ;;   The star lands beside an already-garbled message; note the seam even
  ;;   INSERTS an arrow, so the star's fold-time predecessor is `->`, which is
  ;;   why Q_U36's fuse correctly declines it there.
  ;; Pinning both is what turns this red the day either seat is fixed.
  (check-equal? (list->seteq (map string->symbol p4e1-observed-leaks))
                (seteq 'let-nested 'spec-type)
                "the set of contexts leaking the sentinel into a user message changed"))

(test-case "P4e-1a slice 1a-i: the matrix's own mint expectations hold"
  ;; The gate above is only meaningful if the matrix still describes reality.
  ;; This pins the generator against the tokenizer, so a mint-rule change that
  ;; silently shrinks the covered surface turns this RED instead of quietly
  ;; narrowing the gate above. (A gate that stops covering things is the failure
  ;; mode a coverage instrument cannot self-report.)
  ;; ⚠ MEMBERSHIP, not cardinality. The first cut asserted `mints = 19`, which
  ;; holds for ANY 19 of the 20 contexts — a carrier that started minting inside
  ;; `mixfix!` while losing one arrival context passed green, and `mixfix!` is
  ;; Q_U34's gate, i.e. exactly what P4e-1 is about to touch. Its stronger twin
  ;; (the abort pin) was already using `list->seteq` twenty lines above.
  (for ([c (in-list star-carriers)])
    (define non-minting
      (for/list ([k (in-list star-contexts)]
                 #:unless (star-mints? (string-append star-prelude (star-cell-source k c 0))))
        (car k)))
    (if (star-minting-carrier? c)
        (check-equal? (list->seteq (map string->symbol non-minting))
                      (seteq 'mixfix!)
                      (format "carrier ~a must mint in every arrival context and ONLY fail in mixfix"
                              (car c)))
        (check-equal? (list->seteq (map string->symbol non-minting))
                      (list->seteq (map (lambda (k) (string->symbol (car k))) star-contexts))
                      (format "control carrier ~a must never mint, anywhere" (car c))))))

;; ---------------------------------------------------------------------------
;; D4.P4e-1a slice 1a-ii — THE TIER-O ARMS, LANDED INERT
;;
;; `$postfix-star` does not exist as an emitted datum until slice 1a-iii. These
;; arms go in FIRST so the rename cannot detonate a recognizer, and every pin
;; below therefore exercises the arm by writing the symbol DIRECTLY.
;;
;; ⚠⚠ THE INVENTORY WAS GENERATED, AND MOST SITES TURNED OUT NOT TO NEED AN ARM.
;; Recorded because "add it everywhere" would have been the expensive wrong move:
;;   · `access-sentinel?` / the `reader-forms.rkt` head sets — NO. They open
;;     `(and (list? x) (pair? x) …)`; a bare ATOM can never be a member. This is
;;     [Q_U36](../docs)'s point: the star is not a head, so it is not a head-set
;;     question at all.
;;   · `flatten-ws-datum` (tree-parser) — NO. Both arms require `(pair? item)`
;;     before the `memq`, so a bare atom never reaches the negative list.
;;   · `preparse-expand-form`'s opacity list / `preparse-expand-subforms`' skip
;;     list — NO. Both test `(car datum)`, i.e. list heads only.
;;   · `parse-list`'s arms + `segment-select-items` — NOT HERE. Those are the
;;     Q_U35 REFUSAL seats and belong to 1a-iii with the consumer.
;;
;; ⚠ `pattern-var?` DID get a 21st exclusion — after a first attempt to fix the
;; class structurally instead was reverted (see the splice pin below). An earlier
;; draft of this line said it did not; the sentence survived the reversal and had
;; to be corrected, which is the same comment-asserts-a-false-mechanism failure
;; this slice's own header is about. Two sites, one truth: `macros.rkt`'s
;; exclusion list and this note.
;;
;; ⚠ NOT CLOSED HERE, recorded so the enumeration above is not read as complete:
;; two message seats render a bare atom into user-facing TEXT and would print the
;; sentinel's internal name — `pol8-bad-head-error` (parser.rkt) and
;; `process-ns-declaration`'s segment message (namespace.rkt). Neither is
;; reachable from any star CONTEXT in the matrix (no cell is a `defr` clause head
;; or an `ns` name), so 1a-i's gate cannot see them and they are not this slice's
;; obligation — but they are real, and they belong to whoever widens the surface.
;; ---------------------------------------------------------------------------

(test-case "P4e-1a 1a-ii: pp-datum prints the sentinel's INTERNAL NAME, by design"
  ;; ⚠ THIS PIN IS THE REVERSE OF THE ONE I FIRST WROTE. I gave `pp-datum` an arm
  ;; rendering `$postfix-star` as `*`; the adversarial verify showed that is
  ;; actively harmful. Every arm in that cond is a form that legitimately reaches
  ;; the parser; every CONSUMED marker has none and prints its internal name.
  ;; `$postfix-star` is consumed — its appearance in a printed datum IS the
  ;; defect — so `*` would make a leak indistinguishable from correct output in
  ;; `expand`. The absence of an arm is the diagnostic.
  (check-equal? (pp-datum '$postfix-star) "$postfix-star")
  ;; it shares that treatment with its consumed siblings
  (check-equal? (pp-datum '$bcast-step) "$bcast-step")
  ;; while the SURVIVING forms keep their renderings
  (check-equal? (pp-datum '$rest) "...")
  (check-equal? (pp-datum '$pipe) "|"))

(test-case "P4e-1a 1a-ii: the sentinel is not a pattern var, so the splice arm never sees it"
  ;; ⚠⚠ THIS PIN REPLACED ONE THAT ASSERTED THE OPPOSITE, and the story is the
  ;; slice's second lesson. `$postfix-star` is the FIRST BARE-SYMBOL sentinel, so
  ;; it falsifies the invariant `datum-subst-list`'s splice arm is justified by
  ;; ("a sentinel is … never a bare symbol followed by `...`"). I concluded the
  ;; arm should therefore ask "is it DECLARED?", matching what `446070fc` did one
  ;; function above — and the neighbourhood run turned
  ;; `test-defmacro.rkt`'s "the SPLICE branch keeps its unbound error" RED.
  ;; That behaviour is a RULING, stated in `446070fc`'s own discharge note; only
  ;; its RATIONALE was wrong. **A falsified rationale does not license reversing
  ;; the decision it was offered for** — check for an existing pin before
  ;; "completing" someone's fix.
  ;; The fix belongs where the sentinel/user-var distinction lives:
  ;; `pattern-var?`'s exclusion list.
  ;; `datum-subst-list` is internal; `datum-subst` delegates to it for any list
  ;; template, which is the path a defmacro body actually takes.
  (define (subst elems bindings) (datum-subst elems bindings))
  ;; the SENTINEL passes through — it is not a pattern var at all
  (check-equal? (subst '($postfix-star ...) (hasheq))
                '($postfix-star ...)
                "a bare-symbol sentinel is not a pattern var, so no raise")
  ;; a genuine USER typo still raises — the signal 446070fc ruled to keep
  (check-exn exn:fail? (lambda () (subst '($nope ...) (hasheq)))
             "an unbound USER pattern var still raises")
  ;; a DECLARED splice var still splices
  (check-equal? (subst '($xs ...) (hasheq '$xs '(1 2 3)))
                '(1 2 3)
                "a declared splice var still splices"))

(test-case "P4e-1a 1a-ii: the exclusion's PATTERN-SIDE cost, pinned rather than discovered"
  ;; ⚠ THE COST OF THE EXCLUSION, NAMED. `pattern-var?` governs the PATTERN side
  ;; too (`datum-match`), and `macros.rkt` says in as many words that that side is
  ;; "a separate question and out of scope here" — so adding an exclusion crosses
  ;; a boundary the file declares. Consequence: a macro whose PARAMETER is
  ;; literally named `$postfix-star` now registers and then silently never
  ;; matches, because the param is no longer a pattern variable.
  ;;
  ;; This is the pre-existing class shared by all 21 exclusions, not a new one —
  ;; `process-defmacro` performs no param validation, so every excluded sentinel
  ;; behaves this way. It is pinned here because the slice CREATED a new instance
  ;; of it, and an unpinned known cost is indistinguishable from an unknown one.
  ;; (The name is unwritable in practice: the WS reader mints `$postfix-star`, so
  ;; a user typing it means it literally.)
  (define msgs (run-ws-pre "defn fp [z] z\ndefmacro mp [$postfix-star] [fp $postfix-star]\ndef vp := [mp 1]"))
  (check-true (ormap (lambda (m) (regexp-match? #rx"Unbound variable" m)) msgs)
              (format "a sentinel-named macro param does not bind — known cost: ~s" msgs))
  ;; the control: an ordinary param name works
  (define ok (run-ws-pre "defn fp [z] z\ndefmacro mq [$q] [fp $q]\ndef vq := [mq 1]"))
  (check-false (ormap (lambda (m) (regexp-match? #rx"Unbound variable" m)) ok)
               (format "an ordinary macro param binds normally: ~s" ok)))

;; ---------------------------------------------------------------------------
;; D4.P4e-1a slice 1a-iii — THE TERRITORY SEATS  [Q_U37]
;; Each seat that owns a territory gets its own E2E pin, because the failure
;; mode Q_U37 fixed was precisely a seat SHIPPING UNREACHABLE: attempt 1's
;; preparse marker pre-empted the Sigma arm, so a refusal existed in the tree,
;; was green under every gate, and never fired. A pin per seat is what makes
;; "the seat is reachable" a tested property instead of an architectural hope.
;; ---------------------------------------------------------------------------

(test-case "P4e-1a [Q_U31]: the glued star in TYPE territory takes the type-seat message"
  ;; type territory: `unwrap-angle-type` owns it, and its message must be the
  ;; type-seat guidance ("needs a SPACE"), NOT Q_U35's generic expression
  ;; refusal — the difference between the two is exactly what attempt 1 lost.
  (check-true (p4e1-has? "def v : <(x : Nat)* Nat> := 1"
                         #rx"needs a SPACE")
              "glued Sigma takes the type-seat guidance")
  ;; the spaced spelling — the one Q_U31 keeps — still elaborates as a Sigma
  (check-true (p4e1-has? "def v : <(x : Nat) * Nat> := 1"
                         #rx"Sigma")
              "spaced Sigma still IS a Sigma (the type-mismatch names it)")
  ;; the message is ANGLE-GENERIC: a union with a glued star gets the same
  ;; add-a-space guidance, not advice about a product type it never wrote
  (check-true (p4e1-has? "defn f [z] z\ndef u : <Int | [f 1]*> := 1"
                         #rx"needs a SPACE")
              "a union with a glued star gets the angle-generic guidance")
  ;; family 2: the $angle-type synthesized AT PREPARSE from a grouped param type.
  ;; ⚠ The live route is the **SPEC** spelling — an earlier version of this leg
  ;; probed the DEFN spelling with a `|defn requires` alternation, and the verify
  ;; showed that spelling dies at the generic defn shape check BEFORE the family-2
  ;; arm is reached, star or no star: the pin passed on a star-independent
  ;; message, i.e. it was hedged into exactly the blind spot it existed to catch.
  ;; This leg is what makes deleting `param-type->angle-type`'s
  ;; `$postfix-star` disjunct turn the battery red.
  (check-true (p4e1-has? "spec g2 ([List Nat]* Nat) -> Int\ndefn g2 [z] 1"
                         #rx"needs a SPACE")
              "the grouped SPEC param routes to the type seat"))

(test-case "P4e-1a [Q_U37]: data territory captures the star as `*`, never the internal name"
  ;; quasiquote: the Datum VALUE must carry the `*` the user wrote — capture
  ;; fidelity. (Contrast pp-datum, which prints the internal name because THERE
  ;; an escaped sentinel is the defect. Same symbol, opposite obligations.)
  (define msgs (p4e1-msgs "defn f [z] z\ndef q := `[[f 1]*]\nq"))
  (check-true (ormap (lambda (m) (regexp-match? #rx"datum-sym '\\*" m)) msgs)
              (format "the quoted star renders as `*` in the Datum value: ~s" msgs))
  (check-false (ormap (lambda (m) (regexp-match? #rx"\\$postfix-star" m)) msgs)
               "and the internal name appears nowhere"))

(test-case "P4e-1a [Q_U35]: an application bracket BREAKS the selection chain"
  ;; `[c{a}]*` — the selection is wrapped in a bracket app, so the star's
  ;; syntactic predecessor is the APP, not the selection: refused, with the
  ;; expression-territory message. Pinned because the opposite reading (fuse
  ;; through the wrapper) is plausible enough that someone will propose it;
  ;; folding is OUTSIDE-IN, so the fold sees the raw bracket app — making this
  ;; a structural consequence, not a choice a later edit could quietly flip.
  (check-true (p4e1-has? "def c := {:a 1}\ndef q := [c{a}]*"
                         #rx"applies to a SELECTION step")
              "bracket-wrapped selection + star is refused (expression territory)")
  ;; and the direct spelling still FUSES — seat-migrated at 1b-iii-B2: the
  ;; proposition is the FOLD FUSED (vs the expression-territory refusal), and
  ;; any star-family message proves it; with a leaf content that is now the
  ;; permanent leaf refusal.
  (check-true (p4e1-has? "def c := {:a 1}\ndef q := c{a}*"
                         #rx"a leaf has no join")
              "the unwrapped spelling fuses and reaches the star's own message"))

(test-case "P4e-1a 1a-iii: error ECHOES render the user's `*`, never the sentinel"
  ;; TWO seats the attempt-2 verify found OFF-MATRIX (def-name position and fn
  ;; binder position are not arrival contexts, so the leak-set pin structurally
  ;; cannot see them): both echo the offending source datum into their message,
  ;; and the rename had silently changed the echoed content from `*` to
  ;; `$postfix-star`. `unmint-star-for-echo` restores the user's spelling.
  (define d1 (p4e1-msgs "defn f [z] z\ndef [f 1]* := 2"))
  (check-false (ormap (lambda (m) (regexp-match? #rx"\\$postfix-star" m)) d1)
               (format "def-seam echo carries no sentinel: ~s" d1))
  (check-true (ormap (lambda (m) (regexp-match? #rx"unexpected tokens" m)) d1)
              "and the def-seam error itself still fires")
  (define d2 (p4e1-msgs "defn f [z] z\ndef g := [fn [x [f 1]*] x]"))
  (check-false (ormap (lambda (m) (regexp-match? #rx"\\$postfix-star" m)) d2)
               (format "fn-binder echo carries no sentinel: ~s" d2))
  (check-true (ormap (lambda (m) (regexp-match? #rx"Expected binder" m)) d2)
              "and the binder error itself still fires"))

(test-case "P4e-1a 1a-iii: the pipe-TERMINAL fused star — DEFERRED 110's measured accident, pinned"
  ;; `|> c{a}*` (terminal): the fold FUSES correctly, then `expand-pipe-block`'s
  ;; single-element unwrap re-wrap cannot tell "one fused item that is a list"
  ;; from "a list of parts" and SPREADS the fused node — so the star lands bare
  ;; and takes Q_U35's message, which is factually FALSE here (there IS a
  ;; selection to its left). PRE-EXISTING ambiguity (`|> c{a}` starless →
  ;; `Unbound variable`, same spread); the star only makes it deterministic.
  ;; Pinned AS the accident, exactly like Q_U19's pin froze one: this documents
  ;; today's routing, it must not be read as a ruling. Fixing DEFERRED 110 turns
  ;; this red, which is how the fix claims the cell.
  (check-true (p4e1-has? "def c := {:a 1}\ndef r1 := |> c{a}*"
                         #rx"applies to a SELECTION step")
              "terminal pipe star currently takes the (wrong) expression refusal")
  ;; the NON-terminal spelling is correct today and must stay so — seat-migrated
  ;; at 1b-iii-B2: mid-pipe the fused node parses and TYPES, and with a leaf
  ;; content the star's own message is the permanent leaf refusal.
  (check-true (p4e1-has? "defn f [z] z\ndef c := {:a 1}\ndef r2 := |> c{a}* f"
                         #rx"a leaf has no join")
              "a mid-pipe fused star reaches the star's own message"))

;; ---------------------------------------------------------------------------
;; D4.P4e-1b — THE `*` SEMANTICS.  ⚠⚠ EVERYTHING BELOW IS PARKED (COMMENTED).
;; ---------------------------------------------------------------------------
;; Failing-test-first artifacts for P4e-1b, written at slice 1b-i against the
;; rulings and PARKED per this repo's acceptance-file idiom. They fail at HEAD by
;; design: the star reaches `star-not-yet-message` and has no semantics yet.
;;
;; UNCOMMENT BY SLICE — the grouping is the slicing plan (D4 §5.P4e-1b):
;;   1b-iii  → the VECTOR block (contents joined are vectors / keyless)
;;   1b-iv   → the NOMINAL blocks (keywise join, Q_U38 collisions, Q_U41 `*_`,
;;             Q_U42 same-key vectors, and the Q_U40 law + its ω qualifier)
;;
;; THE RULE UNDER TEST — [Q_U40], one sentence: `*` deletes the container layer
;; the PRECEDING STEP contributed, joining its contents into the enclosing level;
;; the join's SORT follows the CONTENTS — vectors CONCAT · Maps join KEYWISE
;; ([Q_U38] refuses collisions) · keyless components CONCAT (spec §3.6 rule 5) ·
;; leaves ERROR (rule 4). [Q_U42] makes that one RECURSIVE rule: a shared key
;; whose two values are vectors CONCATENATES rather than erroring.
;;
;; ⚠ EXPECTED-VALUE PROVENANCE: every subject below was MEASURED at HEAD and the
;; starless forms print as shown in the comments; the STARRED expectations are
;; derived from the rulings and cannot be run until the slice lands. That is the
;; point of parking them — but it also means a wrong expectation here is a wrong
;; expectation that will look like an implementation bug. Re-derive from Q_U40's
;; sentence, not from these strings, if one of them fights you.
;; ⚠ DISPLAY NOTE, measured: a TUPLE prints `@[…]` at the VALUE level and `⟨…⟩`
;; at the TYPE level, so a keyless result is not distinguishable from a PVec by
;; its value alone — assert on the TYPE where the sort is the thing under test.

;; ---- 1b-iii: VECTOR contents CONCAT (spec v1's ω·ω→ω; no collision possible)
;;
;; (test-case "P4e-1b [Q_U40] 1b-iii: vector contents CONCATENATE"
;;   ;; `rowsv:tags` measures at HEAD as @[@[1 2] @[3]] : [PVec [PVec Int]].
;;   ;; The ω step contributed the outer layer; deleting it joins the contents,
;;   ;; which are vectors — the spec's own normative `build.modules:diags*:msg`.
;;   (check-true (p4e1-has? "ns v1\ndef rowsv := @[{:tags @[1 2]} {:tags @[3]}]\nrowsv:tags*"
;;                          #rx"@\\[1 2 3\\]")
;;               "rowsv:tags* mapcats to @[1 2 3]")
;;   ;; keyless/ordinal components concatenate in written order (§3.6 rule 5), so
;;   ;; a collision is STRUCTURALLY impossible on this axis — Q_U38 never fires.
;;   ;; `vv{0 1}` measures as @[@[1 2] @[3 4]] : ⟨[PVec Int] [PVec Int]⟩.
;;   (check-true (p4e1-has? "ns v2\ndef vv := @[@[1 2] @[3 4]]\nvv{0 1}*"
;;                          #rx"@\\[1 2 3 4\\]")
;;               "vv{0 1}* concatenates the two keyless components")
;;   ;; the ω twin: `vv:{0 1}` measures as @[@[1 2] @[3 4]] : [PVec ⟨Int Int⟩] —
;;   ;; per element a 2-tuple. Deleting the ω layer ravels the matrix.
;;   (check-true (p4e1-has? "ns v3\ndef vv := @[@[1 2] @[3 4]]\nvv:{0 1}*"
;;                          #rx"@\\[1 2 3 4\\]")
;;               "vv:{0 1}* is a RAVEL, and it needs no special case"))

;; ---- 1b-iv: NOMINAL contents join KEYWISE
;;
;; (test-case "P4e-1b [Q_U40] 1b-iv: Map contents join KEYWISE"
;;   ;; `m2{a b}` measures as {:a {:x 1}, :b {:y 2}}. The block contributed that
;;   ;; layer; deleting it joins {:x 1} and {:y 2} — distinct keys, so no Q_U38.
;;   (check-true (p4e1-has? "ns n1\ndef m2 := {:a {:x 1} :b {:y 2}}\nm2{a b}*"
;;                          #rx":x 1.*:y 2")
;;               "m2{a b}* splices both branches into one level")
;;   ;; n = 1 is an IDENTITY with the dot spelling, exactly as `{p^}` is an honest
;;   ;; 1-tuple at n = 1 (spec §3.3). `cfg.database` measures {:url "u", :pool-size 10}.
;;   (check-true (p4e1-has? "ns n2\ndef cfg := {:database {:url \"u\" :pool-size 10} :version \"1.0.0\"}\ncfg{database}*"
;;                          #rx":url \"u\".*:pool-size 10")
;;               "cfg{database}* is cfg.database — the n=1 identity, harmless")
;;   ;; the headline splat from [Q_U23], branch-level, alongside a sibling
;;   (check-true (p4e1-has? "ns n3\ndef cfg := {:database {:url \"u\" :pool-size 10} :version \"1.0.0\"}\ncfg{database* version}"
;;                          #rx":version \"1.0.0\"")
;;               "cfg{database* version} lifts database's keys beside :version")
;;   ;; under a BROADCAST, Map contents join across elements
;;   (check-true (p4e1-has? "ns n4\ndef rowsm := @[{:cfg {:a 1}} {:cfg {:b 2}}]\nrowsm:cfg*"
;;                          #rx":a 1.*:b 2")
;;               "rowsm:cfg* joins the per-element Maps — distinct keys")
;;   ;; same key, both values Map-shaped → §3.6 rule 2 recurses
;;   (check-true (p4e1-has? "ns n5\ndef rowsm := @[{:cfg {:a 1}} {:cfg {:b 2}}]\nrowsm:{cfg}*"
;;                          #rx":cfg \\{:a 1, :b 2\\}")
;;               "rowsm:{cfg}* recurses under the shared :cfg"))

;; ---- 1b-iii [Q_U45]: L★'s SECOND qualifier, and the LEGALITY pair -----------
;;
;; PARKED, per the acceptance-file idiom: all six spellings below refuse at HEAD
;; (`7fd25f35`, measured — the guided not-yet, `a*` / `zz*` / "the preceding
;; step, flattened"), so these fail for exactly the right reason. Slice 1b-iii-B
;; uncomments them.
;;
;; ⭐⭐ WHY THIS BLOCK EXISTS AT ALL: Q_U40's law L★ was recorded with ONE
;; qualifier (no intervening ω) and every worked example behind it used MAPS.
;; [Q_U45] widened it — L★ also fails for VECTOR contents with no ω anywhere,
;; and it fails on ARITY before order ever enters: the distributed form is an
;; n-TUPLE of vectors, the result form ONE FLAT vector. The Map side is equal
;; only because a Map-valued branch star SPLICES its keys, which is the same
;; operation the result form's keywise join performs.
;;
;; ⚠ VALUES/TYPES below are PREDICTED FROM THE RULINGS, not measured — nothing is
;; implemented. Adjust the rendering if it lands differently; do NOT adjust the
;; PROPOSITIONS (equal for Maps · NOT equal for vectors · the legality pair).
;; Subject order is measured though: `mm : {:aa [PVec Int] :zz [PVec Int]}`, i.e.
;; `make-record`'s `symbol<?` canonical order, which is what [Q_U44] names.
;;
;; (test-case "P4e-1b [Q_U45]: L★ holds for MAP contents and FAILS for VECTOR contents"
;;   (define M "ns u1\ndef m2 := {:a {:x 1} :b {:y 2}}\n")
;;   (define V "ns u2\ndef mm := {:zz @[1 2] :aa @[3 4]}\n")
;;   ;; MAP contents — the two sides agree, which is L★ holding.
;;   (check-equal? (p4e1-last (string-append M "m2{a* b*}"))
;;                 (p4e1-last (string-append M "m2{a b}*"))
;;                 "L★ HOLDS for Map contents — the branch stars SPLICE, which is what the result form's keywise join does")
;;   ;; VECTOR contents — the two sides differ, and they differ in ARITY.
;;   ;; Use the EXACT type comparison: a substring regex cannot separate
;;   ;; `[PVec Int]` from `⟨[PVec Int] [PVec Int]⟩`, which is the vacuity this
;;   ;; slice's instrument fix exists to prevent.
;;   (check-false (equal? (p4e1-last (string-append V "mm{zz* aa*}"))
;;                        (p4e1-last (string-append V "mm{zz aa}*")))
;;                "L★ FAILS for vector contents — [Q_U45]")
;;   (check-true (p4e1-type=? (string-append V "mm{zz* aa*}") "⟨[PVec Int] [PVec Int]⟩")
;;               "distributed: each branch contributes ONE keyless component → a TUPLE, written order")
;;   (check-true (p4e1-type=? (string-append V "mm{zz aa}*") "[PVec Int]")
;;               "result: one keyed layer deleted, contents concatenated → ONE flat vector")
;;   (check-true (p4e1-has? (string-append V "mm{zz aa}*") #rx"@\\[3 4 1 2\\]")
;;               "…in CANONICAL key order (aa before zz), per [Q_U44]"))
;;
;; (test-case "P4e-1b [Q_U45]: the LEGALITY pair — absorption is observable WITHOUT computing the answer"
;;   ;; ⭐ The owner's criterion, and it is the better test: a Map-valued branch
;;   ;; star contributes KEYED components, which sit beside an unstarred keyed
;;   ;; branch; a vector-valued one contributes ONE KEYLESS component, which
;;   ;; cannot. Checkable as a LEGALITY difference, not an equality one.
;;   (check-true (p4e1-has? "ns u3\ndef m2 := {:a {:x 1} :b {:y 2}}\nm2{a* b}"
;;                          #rx":x 1.*:b \\{:y 2\\}")
;;               "m2{a* b} is LEGAL — splice `a`, KEEP `b`'s key. [Q_U40] calls this the reason the branch form is strictly more expressive")
;;   (check-true (p4e1-has? "ns u4\ndef mm := {:zz @[1 2] :aa @[3 4]}\nmm{zz* aa}"
;;                          #rx"mixed keyed/keyless")
;;               "mm{zz* aa} is an L4 mixed-sorts error — one keyless component beside one keyed")
;;   ;; ⛔ AND THIS PAIR IS WHY THE PARSER GATE MUST NOT CLASSIFY. Attempt 2
;;   ;; answered `(list #f)` for every star branch, i.e. KEYLESS, which makes the
;;   ;; FIRST check above an L4 error too — refusing [Q_U40]'s own headline
;;   ;; example. The parser cannot tell Map contents from vector contents; that is
;;   ;; the whole reason [Q_U43] moved the decision to typing. See D4 § the
;;   ;; attempt-3 audit, finding A2, and the `'()` pin above.
;;   )

;; ---- 1b-iii-B: THE ARRIVAL POSITIONS ---------------------------------------
;;
;; ⭐⭐ THE PIN NOTHING HAD. Round 2 of attempt 2 was reverted because the
;; `$postfix-star` arm called `(closed-acc)` unconditionally, so a postfix star
;; arriving INSIDE a block was re-based onto the SUBJECT — `vh{0.{0}*}` returned
;; `concat(vh)` at ZERO errors. D4 recorded ONE continuation shape. The
;; attempt-3 audit measured SIX, and all seven spellings below were re-measured
;; on the main thread at `7fd25f35`: every one reaches the SAME arm
;; (`parser.rkt`'s `$postfix-star`), returning that arm's exact text
;; ("the preceding step, flattened"). So the arm is the single seat, and the only
;; question is what it does with `cur`.
;;
;; ⭐ THE POSITION RULE IS DERIVED, NOT TRANSPLANTED [audit A1]. The reader mints
;; `postfix-star` only for a `*` byte-adjacent to a preceding token in
;; `group-closer-types` = '(rbracket rparen rbrace) — and a block's own `{` is an
;; OPENER. So a bare `$postfix-star` can NEVER be the first item of a block or
;; sub-block payload, and therefore:
;;
;;     cur = #f      ⇔  the outer `$select-path` carrier  ⇔  operate on the SUBJECT
;;     cur non-#f    ⇔  in-block                          ⇔  CONS onto the branch
;;
;; ⚠ A fix keyed on `cur-subbed?` instead covers exactly ONE of the six (B), which
;; is why "respect `cur` like the siblings" was the wrong instruction: two
;; siblings are CONTINUATION arms and respect `cur`, while `star-sym?` correctly
;; does not (a bare name always starts a branch, exactly like its neighbour
;; `plain-key?`). This arm is the only one reachable in BOTH positions.
;;
;; LIVE since 1b-iii-B2 (the seat migration). Pin A's PARKED version predicted a
;; JOIN for `cfg{database}*` — wrong for 1b-iii, whose scope is vector contents
;; only (Map contents are 1b-iv); corrected to assert the honest nominal not-yet
;; PLUS a vector-contents subject that genuinely joins. Everything below was
;; measured on the b2live probe before being pinned.

(test-case "P4e-1b [1b-iii-B2]: a postfix star operates on its BRANCH in-block, and on the SUBJECT only as the outer carrier"
  (define C "ns w1\ndef cfg := {:database {:url \"u\" :host \"h\"} :version \"1.0.0\"}\n")
  (define V "ns w2\ndef vh := @[@[@[1 2]] @[@[3]]]\n")
  (define M "ns w3\ndef m := {:k {:a 1}}\n")
  ;; (A) BRANCH-INITIAL — the outer carrier, VECTOR contents: the join fires.
  ;;     `vh{0}` is a keyless 1-tuple ⟨[PVec [PVec Int]]⟩; the star deletes that
  ;;     tuple layer and concats its ONE vector content.
  (check-true (p4e1-type=? (string-append V "vh{0}*") "[PVec [PVec Int]]")
              "A: the outer carrier flattens the SUBJECT's selection — exact type")
  (check-true (p4e1-has? (string-append V "vh{0}*") #rx"@\\[@\\[1 2\\]\\]")
              "A: …and the value")
  ;; (A') Map contents at the outer carrier: the honest nominal not-yet — which
  ;;      ALSO proves the star operated on the subject's layer (it renders it).
  (check-true (p4e1-has? (string-append C "cfg{database}*")
                         #rx"not implemented yet for Map-valued")
              "A': Map contents refuse with the nominal not-yet, 1b-iv's seam")
  ;; (B) after a `.{…}` sub-block — ⭐ THE ROUND-2 DEFECT: must NOT re-base onto
  ;;     the subject. concat(vh) would be `@[@[1 2] @[3]]`.
  (check-false (p4e1-has? (string-append V "vh{0.{0}*}") #rx"@\\[@\\[1 2\\] @\\[3\\]\\]")
               "B: `vh{0.{0}*}` must NOT be concat(vh)")
  (check-true (p4e1-type=? (string-append V "vh{0.{0}*}") "⟨[PVec Int]⟩")
              "B: …the star belongs to its BRANCH, not the subject — FLIPPED at 1b-iii-C2 from a refusal to a keyless success, deliberately")
  ;; (C) after an ORDINAL step — in NO record before the attempt-3 audit.
  (check-true (p4e1-has? (string-append C "cfg{database[0]*}") #rx".")
              "C: after an ordinal step the star still belongs to its branch (no abort)")
  ;; (D) after an in-block ω sub-block.
  (check-true (p4e1-has? (string-append M "m{k:{a}*}") #rx".")
              "D: after an in-block ω the star belongs to its branch (no abort)")
  ;; (E) after a `^`-dissolve plus sub-block.
  (check-true (p4e1-has? (string-append C "cfg{database^.{host}*}") #rx".")
              "E: a caret earlier in the branch does not move the star's operand (no abort)")
  ;; (F) ONE LEVEL DOWN, via the recursive call (`sub?` = #t).
  (check-true (p4e1-has? (string-append C "cfg{database.{host[0]*}}") #rx".")
              "F: the recursive call is the same seat with the same rule (no abort)")
  ;; (G) mid-payload, with a SIBLING branch after the star.
  (check-true (p4e1-has? (string-append C "cfg{database.{host}* version}") #rx".")
              "G: a sibling AFTER the star is still its own branch (no abort)"))

(test-case "P4e-1b [Q_U44] E2E: canonical key order, and the order-RECOVERING spelling"
  (define S "ns w4\ndef mm := {:zz @[1 2] :aa @[3 4] :mm @[5 6]}\n")
  ;; canonical: aa · mm · zz — NOT written order, NOT champ hash order
  (check-true (p4e1-has? (string-append S "mm{zz aa mm}*") #rx"@\\[3 4 5 6 1 2\\]")
              "the keyed layer's positional join takes canonical (symbol<?) order")
  (check-true (p4e1-type=? (string-append S "mm{zz aa mm}*") "[PVec Int]"))
  ;; the owner's recovery spelling: order via KEYLESSNESS — written order
  (check-true (p4e1-has? (string-append S "mm{zz* aa* mm*}*") #rx"@\\[1 2 3 4 5 6\\]")
              "each inner star contributes ONE keyless component; the outer star deletes a genuinely ordered layer")
  ;; and the two spellings genuinely DIFFER — the recovery is real
  (check-false (p4e1-has? (string-append S "mm{zz* aa* mm*}*") #rx"@\\[3 4 5 6 1 2\\]")))

(test-case "P4e-1b [Q_U45] E2E: L★ fails for VECTOR contents on ARITY — and the LEGALITY pair's refusal half"
  (define S "ns w5\ndef mm := {:zz @[1 2] :aa @[3 4]}\n")
  ;; distributed: each branch = ONE keyless component → a TUPLE, written order
  (check-true (p4e1-type=? (string-append S "mm{zz* aa*}") "⟨[PVec Int] [PVec Int]⟩")
              "distributed form: an n-TUPLE of vectors")
  ;; result form: one keyed layer deleted → ONE flat vector, canonical order
  (check-true (p4e1-type=? (string-append S "mm{zz aa}*") "[PVec Int]")
              "result form: one flat vector — the two sides differ in ARITY, hence L★'s widened qualifier")
  ;; the legality pair's VECTOR half: keyless star beside a keyed sibling → L4,
  ;; guided, naming the star spelling (the Map half — `m2{a* b}` LEGAL — is
  ;; 1b-iv's, parked below)
  (check-true (p4e1-has? (string-append S "mm{zz* aa}") #rx"mixed keyed/keyless")
              "mm{zz* aa} is an L4 mixed-sorts error")
  (check-true (p4e1-has? (string-append S "mm{zz* aa}") #rx"zz\\*")
              "…and the message names the user's star spelling, not a caret remedy"))

;; ⚠ (H) IS AN UNDECIDED ARGUMENT, NOT A PIN — recorded so it is decided rather
;; than defaulted. All four star arms pass `cur-subbed?` = #f, which RESETS the
;; sub-block-terminal seal, so `cfg{database.{host}*.{q}}` would become legal
;; while `cfg{database.{host}.{q}}` stays refused. The star arm also sits ABOVE
;; all three `cur-subbed?` guards, so it is the one step gated by PLACEMENT
;; rather than by decision. Measured at HEAD: the star arm wins that race today.
;;
;; ---- 1b-iii-B: THE TRIPWIRE at the four raise sites -------------------------
;;
;; ⚠⚠ THE AUDIT ARGUED THIS UNREACHABLE, AND AN ARGUED-UNREACHABLE PRECONDITION
;; LIVING IN A DOCUMENT IS THE ARTIFACT CLASS THAT CAUSED BOTH REVERTS. The four
;; `select-step-kind-unhandled` sites (typing-core `select-below-field` ×2 and
;; the reduction twins) are plain `error`, i.e. a WHOLE-FILE ABORT — and reaching
;; them needs a branch that both STARTS with a star and CONTINUES, which the
;; position rule above proves a user cannot spell. That argument may be right and
;; it must not be the only thing standing between us and an abort: pin it.
;;
;; ⚠ THE CALL SHAPE IS NOT WRITTEN HERE ON PURPOSE. The obvious sketch —
;; `(tc:select-project <a type> (list (list (make-select-star 'flatten) 'host)) 'block)`
;; — names an argument I have NOT verified (`select-project`'s subject/type
;; parameter, and whether a hand-built branch reaches `select-below-field` at all
;; from that entry point). Shipping a plausible-looking call that a later reader
;; uncomments and trusts is the hedged-instrument failure this file has already
;; paid for twice (1a-iii's vacuous family-2 alternation; 1b-ii's documentary
;; `select-step-cont` pin). WHAT THE PIN OWES, when 1b-iii-B writes it:
;;   · derive `select-project`'s real signature and a subject type that reaches
;;     `select-below-field` with a multi-step branch;
;;   · assert `check-not-exn` — the failure mode is a RAISE, so an assertion on
;;     the returned message would pass vacuously if the call never got there;
;;   · MUTATION-TEST it by removing the star arm and confirming it raises,
;;     otherwise it does not discriminate;
;;   · and pin the reduction twin the same way — both twins have the same [else].

;; ---- 1b-iii-B1: the twins' star arms — UNIT pins, LIVE while the parser still
;;      refuses. The parser mints no (@star …) step at HEAD, so E2E cannot reach
;;      the twins — but `tc:select-project` and `select-reduce` are exported, and
;;      the P4a totality pins established exactly this idiom (hand-built subjects,
;;      hand-built branches). FAILING-TEST-FIRST: at HEAD every case below dies in
;;      `select-step-kind-unhandled` (an ERROR, not a FAILURE — count both), which
;;      is the right reason: the arms do not exist yet.

(define B1-STAR   (make-select-star 'flatten))
(define B1-STAR-S (make-select-star 'flatten-synth))
(define B1-PVI    (expr-PVec (expr-Int)))
(define (b1-row . fields) (make-record 'keyword fields 'closed))
(define (b1-f ty) (record-field ty 'present))

(test-case "1b-iii-B1 typing: a trailing star JOINS vector contents — EXACT type, on the discriminating key set"
  ;; {:a [PVec Int] :a! [PVec Int]} — slice A's key set, so a comparator regression
  ;; shows here too. `'path` sort = the outer `$select-path` carrier's sort.
  (define row (b1-row (cons 'a (b1-f B1-PVI)) (cons 'a! (b1-f B1-PVI))))
  (let-values ([(t f) (tc:select-project '() row (list (list B1-STAR)) 'path)])
    (check-false f "the all-vectors join must succeed")
    (check-true (equal? t B1-PVI)
                "concat of n [PVec Int] is [PVec Int] — EXACT equality, the anti-vacuous form")))

(test-case "1b-iii-B1 typing: the star flattens ITS branch's layer, not the subject — the prefix walk"
  ;; branch (tags ★) over {:name Keyword :tags [PVec Int]}: the layer is the
  ;; re-nested {:tags [PVec Int]}, contents = one vector → [PVec Int]
  (define row (b1-row (cons 'name (b1-f (expr-Keyword))) (cons 'tags (b1-f B1-PVI))))
  (let-values ([(t f) (tc:select-project '() row (list (list 'tags B1-STAR)) 'path)])
    (check-false f)
    (check-true (equal? t B1-PVI))))

(test-case "1b-iii-B1 typing TRIPWIRE: a star in a REST position is a FAIL VALUE, never a raise"
  ;; The audit argued the four `select-step-kind-unhandled` sites unreachable for
  ;; stars. An argued-unreachable precondition living in a document is the
  ;; artifact class that caused both reverts — so it is pinned, both shapes.
  (define row (b1-row (cons 'a (b1-f B1-PVI))))
  (check-not-exn
   (lambda ()
     (let-values ([(t f) (tc:select-project '() row (list (list B1-STAR 'a)) 'block)])
       (check-false t "a mid-branch star must not project")
       (check-equal? (tc:select-fail-kind f) 'star-mid-branch))))
  (check-not-exn
   (lambda ()
     (let-values ([(t f) (tc:select-project '() row (list (list B1-STAR B1-STAR)) 'block)])
       (check-equal? (tc:select-fail-kind f) 'star-mid-branch
                     "two stars in one branch: the first is mid-branch")))))

(test-case "1b-iii-B1 typing: each failure KIND says the true thing — no conflated star-not-yet"
  ;; attempt 2 routed leaf AND nominal AND synth through ONE kind, telling a
  ;; String leaf it "needs the nominal (Map-valued) case" — both wrong.
  (define nom-inner (b1-row (cons 'x (b1-f (expr-Int)))))
  ;; leaf contents → PERMANENT
  (let-values ([(t f) (tc:select-project '() (b1-row (cons 'a (b1-f (expr-Int))))
                                         (list (list B1-STAR)) 'path)])
    (check-equal? (tc:select-fail-kind f) 'star-leaf))
  ;; Map contents → genuinely not-yet (1b-iv)
  (let-values ([(t f) (tc:select-project '() (b1-row (cons 'a (b1-f nom-inner)))
                                         (list (list B1-STAR)) 'path)])
    (check-equal? (tc:select-fail-kind f) 'star-nominal))
  ;; open row → not statically known (Q_U38 conservative on the tail)
  (let-values ([(t f) (tc:select-project '() (make-record 'keyword
                                                          (list (cons 'a (b1-f B1-PVI))) 'dyn)
                                         (list (list B1-STAR)) 'path)])
    (check-equal? (tc:select-fail-kind f) 'star-open-row))
  ;; non-present field → same: the contents are not statically known
  (let-values ([(t f) (tc:select-project '() (make-record 'keyword
                                                          (list (cons 'a (record-field B1-PVI 'unknown))) 'closed)
                                         (list (list B1-STAR)) 'path)])
    (check-equal? (tc:select-fail-kind f) 'star-open-row))
  ;; `*_` over vector contents → Q_U41: nominal-only, names the alternative
  (let-values ([(t f) (tc:select-project '() (b1-row (cons 'a (b1-f B1-PVI)))
                                         (list (list B1-STAR-S)) 'path)])
    (check-equal? (tc:select-fail-kind f) 'star-synth-positional))
  ;; heterogeneous element types → needs a union join, not landed
  (let-values ([(t f) (tc:select-project '() (b1-row (cons 'a (b1-f B1-PVI))
                                                     (cons 'b (b1-f (expr-PVec (expr-Keyword)))))
                                         (list (list B1-STAR)) 'path)])
    (check-equal? (tc:select-fail-kind f) 'star-hetero)))

(test-case "1b-iii-B1 typing: the ω-container layer — element type stands for every content"
  ;; [PVec [PVec Int]] ★ → [PVec Int] — rowsv:tags*'s type collapse as a UNIT
  ;; pin with exact equality (the E2E version was the vacuous instrument).
  (let-values ([(t f) (tc:select-project '() (expr-PVec B1-PVI) (list (list B1-STAR)) 'path)])
    (check-false f)
    (check-true (equal? t B1-PVI)))
  ;; [PVec {:x Int}] ★ → nominal, not-yet
  (let-values ([(t f) (tc:select-project '() (expr-PVec (b1-row (cons 'x (b1-f (expr-Int)))))
                                         (list (list B1-STAR)) 'path)])
    (check-equal? (tc:select-fail-kind f) 'star-nominal))
  ;; [PVec ⟨Int⟩] ★ → tuple arity × runtime length is not static
  (let-values ([(t f) (tc:select-project '() (expr-PVec (make-record 'nat (list (cons 0 (b1-f (expr-Int)))) 'closed))
                                         (list (list B1-STAR)) 'path)])
    (check-equal? (tc:select-fail-kind f) 'star-omega-tuple))
  ;; [PVec Int] ★ → leaf elements, permanent
  (let-values ([(t f) (tc:select-project '() B1-PVI (list (list B1-STAR)) 'path)])
    (check-equal? (tc:select-fail-kind f) 'star-leaf)))

(test-case "1b-iii-B1 typing: mixed keyed/keyless under a star is a GUIDED L4 fail — BOTH branch orders"
  ;; Q_U44's obligation: `m{name tags*}` must be a guided error, not a
  ;; make-record #f-label raise — and `m{tags* name}` must not silently drop.
  (define row (b1-row (cons 'name (b1-f (expr-Keyword))) (cons 'tags (b1-f B1-PVI))))
  (check-not-exn
   (lambda ()
     (let-values ([(t f) (tc:select-project '() row (list (list 'name) (list 'tags B1-STAR)) 'block)])
       (check-equal? (tc:select-fail-kind f) 'star-l4-mixed))))
  (check-not-exn
   (lambda ()
     (let-values ([(t f) (tc:select-project '() row (list (list 'tags B1-STAR) (list 'name)) 'block)])
       (check-equal? (tc:select-fail-kind f) 'star-l4-mixed
                     "the reordered block takes the SAME guided error — round 1 silently dropped :name here")))))

(test-case "1b-iii-B1: the star messages say the true thing — and render the user's spelling"
  (define row (b1-row (cons 'name (b1-f (expr-Keyword))) (cons 'tags (b1-f B1-PVI))))
  (define (msg-of branches [sort 'path])
    (let-values ([(t f) (tc:select-project '() row branches sort)])
      (te:format-select-fail f '())))
  ;; the LEAF message must claim permanence, not "not yet"
  (let-values ([(t f) (tc:select-project '() (b1-row (cons 'a (b1-f (expr-Int))))
                                         (list (list B1-STAR)) 'path)])
    (check-true (regexp-match? #rx"permanent" (te:format-select-fail f '()))
                "a leaf refusal is permanent and says so"))
  ;; the NOMINAL message keeps the established not-yet substring (C31 pins)
  (let-values ([(t f) (tc:select-project '() (b1-row (cons 'a (b1-f (b1-row (cons 'x (b1-f (expr-Int)))))))
                                         (list (list B1-STAR)) 'path)])
    (check-true (regexp-match? #rx"not implemented yet" (te:format-select-fail f '()))))
  ;; the L4 message names the STAR spelling, not a caret remedy the user never wrote
  (check-true (regexp-match? #rx"tags\\*" (msg-of (list (list 'name) (list 'tags B1-STAR)) 'block))
              "the guided L4 error interpolates the user's star spelling"))

(test-case "1b-iii-B: EVERY star fail kind RENDERS — a raising format arm is worse than the trapdoor"
  ;; ⚠ B-verify F2: star-omega-tuple's arm shipped with ONE ~a and TWO args, so
  ;; `format` raised on every render and the blanket hint handler swallowed it
  ;; to the bare generic. The battery had pinned KINDS, never MESSAGES — this
  ;; loop closes that class for the whole axis: every kind must yield a STRING
  ;; mentioning the star, under check-not-exn.
  (define row (b1-row (cons 'a (b1-f B1-PVI))))
  (for ([kind (in-list '(star-mid-branch star-leaf star-nominal star-hetero
                         star-omega-tuple star-not-yet star-open-row
                         star-synth-positional star-l4-mixed star-deep-prefix
                         ;; 1b-iii-C2's new kind. The loop cannot self-report an
                         ;; UNLISTED kind, so adding a kind obliges this line in
                         ;; the same commit as typing-errors.rkt — that coupling
                         ;; is the whole reason the loop is hand-written.
                         star-dup-key))])
    (check-not-exn
     (lambda ()
       (let ([msg (te:format-select-fail (tc:select-fail kind '() 'probe-label row) '())])
         (check-true (string? msg) (format "~a must render a string" kind))
         (check-true (regexp-match? #rx"\\*" msg)
                     (format "~a's message must mention the star" kind))))
     (format "rendering ~a must not raise" kind))))

(test-case "1b-iii-B1 reduction: the join concatenates in CANONICAL key order — the value layer, discriminating set"
  (define ka  (expr-keyword 'a))
  (define ka! (expr-keyword 'a!))
  (define m-a  (expr-int 11))
  (define m-a! (expr-int 22))
  (define subj (expr-champ
                (champ-insert
                 (champ-insert champ-empty (equal-hash-code ka!) ka!
                               (expr-rrb (rrb-from-list (list m-a!))))
                 (equal-hash-code ka) ka
                 (expr-rrb (rrb-from-list (list m-a))))))
  (define r (select-reduce subj (list (list B1-STAR)) 'path #f))
  (check-true (expr-rrb? r) "the join yields a vector")
  (check-equal? (rrb-to-list (expr-rrb-racket-rrb r)) (list m-a m-a!)
                "canonical (symbol<?) order — :a before :a!; the struct-display order reverses this pair"))

(test-case "1b-iii-B1 reduction: an rrb layer concatenates in ELEMENT order — and the empty layer is the concat identity"
  (define m1 (expr-int 1)) (define m2 (expr-int 2)) (define m3 (expr-int 3))
  (define subj (expr-rrb (rrb-from-list
                          (list (expr-rrb (rrb-from-list (list m1 m2)))
                                (expr-rrb (rrb-from-list (list m3)))))))
  (define r (select-reduce subj (list (list B1-STAR)) 'path #f))
  (check-equal? (rrb-to-list (expr-rrb-racket-rrb r)) (list m1 m2 m3)
                "written/element order for a positional layer")
  ;; the empty champ layer: concat of nothing is @[] — the identity, decided
  ;; deliberately rather than inherited (typing is conservative here; the value
  ;; layer is total)
  (define r0 (select-reduce (expr-champ champ-empty) (list (list B1-STAR)) 'path #f))
  (check-true (expr-rrb? r0))
  (check-equal? (rrb-to-list (expr-rrb-racket-rrb r0)) '()))

(test-case "1b-iii-B1 reduction TRIPWIRE: star misuse PANICS through the let/ec — never a raise"
  (define ka (expr-keyword 'a))
  (define subj (expr-champ (champ-insert champ-empty (equal-hash-code ka) ka
                                         (expr-rrb (rrb-from-list (list (expr-int 1)))))))
  ;; mid-branch star: typing refuses this; the value layer must panic, not raise
  (check-not-exn
   (lambda ()
     (check-true (expr-panic? (select-reduce subj (list (list B1-STAR 'a)) 'path #f))
                 "a star in a REST position panics per-command")))
  ;; leaf contents: invariant guard, same channel
  (define leaf-subj (expr-champ (champ-insert champ-empty (equal-hash-code ka) ka (expr-int 7))))
  (check-not-exn
   (lambda ()
     (check-true (expr-panic? (select-reduce leaf-subj (list (list B1-STAR)) 'path #f)))))
  ;; mixed keyed/keyless with a star present: the L4 invariant guard, both orders
  (define mix-subj
    (expr-champ (champ-insert
                 (champ-insert champ-empty (equal-hash-code ka) ka
                               (expr-rrb (rrb-from-list (list (expr-int 1)))))
                 (equal-hash-code (expr-keyword 'name)) (expr-keyword 'name)
                 (expr-int 9))))
  (check-not-exn
   (lambda ()
     (check-true (expr-panic? (select-reduce mix-subj
                                             (list (list 'name) (list 'a B1-STAR)) 'block #f))
                 "a star's keyless component beside keyed siblings panics — typing's L4 check owns the user-facing form"))))

;; ---- 1b-iii-C1: THE SHARED JOIN, pinned SYMMETRICALLY in both twins ----
;;
;; C1 is a pure EXTRACTION: the join is hoisted to module level in both files
;; (`star-join-type` / `star-join-value`) and returns the joined type/value
;; **BARE**. Everything above is the regression proof that behaviour did not
;; move; these two pin the NEW contract, which is BARENESS.
;;
;; ⚠ WHY BARENESS IS WORTH A PIN OF ITS OWN. [Q_U47]'s landing — keyed under a
;; surviving label, keyless at the level — belongs to the CALLER, because each
;; caller IS the branch remainder's own arm. If the join wrapped its own result
;; it would force ONE landing on all three callers, and the wrapper it would
;; naturally choose is the keyless one, which assembles into the **B-tuple
;; Q_U46 rejected**. That is not hypothetical: it is live and legal today as
;; `cfg{db.{hosts*}}` → `{:db @[@[1 2]]} : {:db ⟨[PVec Int]⟩}`. So a future
;; re-wrap here is a silent regression to a REJECTED design, and these are what
;; catch it.
;;
;; ⚠ BOTH use a TWO-CONTENT layer. A one-content layer — which is every
;; key-terminal chain, `cfg{db.hosts*}` included — makes the concat an IDENTITY,
;; so it cannot discriminate a broken join. That is the audit's finding and it
;; is why the headline spelling is the weak pin.
;;
;; ⚠ The reduction side is pinnable AT ALL only because C1 hoisted it: both of
;; that file's walks live inside `select-reduce`'s ~470-line scope, where the
;; parameter `sort` also shadows Racket's `sort`. Before the hoist this twin
;; could only have been mutation-tested while its partner was directly pinned.

(define (c1-fail-k kind r) (values #f (list 'c1-fail kind)))

(test-case "1b-iii-C1 typing: the shared join returns the joined type BARE — not a component"
  (define layer (b1-row (cons 'x (b1-f B1-PVI)) (cons 'y (b1-f B1-PVI))))
  (let-values ([(ty f) (tc:star-join-type layer B1-STAR c1-fail-k)])
    (check-false f "two vector contents join")
    (check-true (equal? ty B1-PVI)
                "concat of two [PVec Int] is [PVec Int] — EXACT, the anti-vacuous form")
    (check-false (pair? ty)
                 "BARE: a component wrapper here forces one landing on all three callers")))

(test-case "1b-iii-C1 typing: the shared join reports through the CALLER's fail-k"
  ;; leaf contents — the caller supplies the failure constructor, so the failure
  ;; carries the caller's path/label rather than the helper's
  (define layer (b1-row (cons 'x (b1-f (expr-Int)))))
  (let-values ([(ty f) (tc:star-join-type layer B1-STAR c1-fail-k)])
    (check-false ty)
    (check-equal? f (list 'c1-fail 'star-leaf)
                  "the kind is the caller's to render — C1 moves no message")))

(test-case "1b-iii-C1 reduction: the shared join returns the joined VALUE bare, in canonical key order"
  (define ka  (expr-keyword 'a))
  (define ka! (expr-keyword 'a!))
  (define v-a  (expr-rrb (rrb-from-list (list (expr-int 11)))))
  (define v-a! (expr-rrb (rrb-from-list (list (expr-int 22)))))
  ;; inserted a!-first so insertion order DISAGREES with canonical order
  (define layer (expr-champ
                 (champ-insert
                  (champ-insert champ-empty (equal-hash-code ka!) ka! v-a!)
                  (equal-hash-code ka) ka v-a)))
  (define r (star-join-value layer B1-STAR
                             (lambda (why) (error 'c1-pin "unexpected invariant escape: ~a" why))))
  (check-true (expr-rrb? r) "the join is a vector")
  (check-false (pair? r)
               "BARE: the value twin must not wrap either, or the twins diverge on shape")
  (check-equal? (rrb-to-list (expr-rrb-racket-rrb r)) (list (expr-int 11) (expr-int 22))
                "canonical (symbol<?) order — :a before :a!, against insertion order"))


;; ---- 1b-iii-C2: THE DEEP FLATTEN, E2E ----
;;
;; ⚠⚠ WRITTEN BEFORE EITHER SHIELD MOVED, and that ordering is the point.
;; Removing the shields does NOT produce a failure to chase — it produces a GREEN
;; WRONG ANSWER: under the shipped branch-root algorithm `rows{k:s*}` returns the
;; raw field keyless at 0 errors. Five of the six pre-existing deep-shape pins
;; assert `#rx"."`, which matches anything, and every star UNIT pin uses the
;; `'path` sort, whose arm discards the key and so cannot see the keyed/keyless
;; flip [Q_U47] rules on. So this block is the instrument, and it exists first.
;;
;; Assertions compare the FULL rendered line (value AND type) rather than a
;; regex: `[PVec [PVec Int]]` contains `[PVec Int]`, so a containment match would
;; pass on the wrong answer — the weakness slice A recorded and did not close.

(define C2V (string-append
             "ns c2s\n"
             "def cfg := {:db {:hosts @[1 2] :ports @[80]}}\n"
             "def two := {:a {:x @[1] :y @[2 3]}}\n"
             "def mm := {:zz @[1 2] :aa @[3 4]}\n"
             "def vh := @[@[@[1 2]] @[@[3]]]\n"
             "def rows := {:k @[{:s @[1]} {:s @[2 3]}]}\n"
             "def nested := {:a @[{:b @[1]} {:b @[2]}]}\n"))

(define (c2-line src) (p4e1-last (string-append C2V src)))

;; ⚠ AN ERROR IS NOT A LINE STARTING WITH "ERROR" AT THIS SEAM, and my first cut
;; of the refusal pins below assumed it was. `p4e1-msgs` yields the error
;; STRUCT's printed form (`#(struct:inference-failed-error …)`), not the numbered
;; `process-file` display line — so `#rx"^ERROR"` matched nothing and four pins
;; were red for the wrong reason. Running them BEFORE implementing is what caught
;; it; had they been written after, they would have been "fixed" by the
;; implementation and shipped vacuous. A refusal is therefore asserted as
;; (no successful `V : T`) AND (the guidance text is present) — a negative and a
;; positive, because either alone passes on the wrong thing.
(define (c2-refused? src) (not (p4e1-type (string-append C2V src))))

;; ⚠⚠ SIX OF THE TEN PINS BELOW ARE PARKED COMMENTED — the acceptance-file idiom
;; this track already used to land P4e-1a's failing tests. They are WRITTEN and
;; were RUN: at C1's HEAD exactly these six are RED, each for the reason its name
;; claims, and the other four are GREEN because they assert behaviour that is
;; already correct (depth-1 unmoved; the two refusals that the shield supplies
;; today and the nominal join must keep supplying tomorrow). C2 uncomments the
;; six as it lands. Parking rather than deleting is what keeps the instrument
;; from being written AFTER the implementation, which is how a pin ends up
;; asserting whatever the code happens to do.

(test-case "1b-iii-C2: a deep star lands KEYED under the surviving step — [Q_U47]"
  (check-equal? (c2-line "cfg{db.hosts*}") "{:db @[1 2]} : {:db [PVec Int]}"
                "the layer `hosts` made is deleted; `db` survives and holds the join"))

(test-case "1b-iii-C2: the DISCRIMINATING shapes — two contents, where a broken concat shows"
  ;; ⚠ `cfg{db.hosts*}` above has ONE content, so its concat is an IDENTITY and
  ;; cannot discriminate. These two can, and they are also the idiom Q_U46 says
  ;; the whole ruling buys: group N siblings under a chosen key.
  (check-equal? (c2-line "two{a.{x y}*}") "{:a @[1 2 3]} : {:a [PVec Int]}"
                "sub-block layer, two contents, CANONICAL key order (:x then :y)")
  (check-equal? (c2-line "cfg{db.{hosts ports}*}") "{:db @[1 2 80]} : {:db [PVec Int]}"
                "canonical order :hosts before :ports — champ insertion order would differ"))

(test-case "1b-iii-C2: with NO surviving step that names a key, the join lands KEYLESS"
  ;; Q_U47's `keyless otherwise` case. Both reachable spellings.
  (check-equal? (c2-line "cfg{db^.hosts*}") "@[@[1 2]] : ⟨[PVec Int]⟩"
                "`db^` dissolves the only survivor — the join splices in keyless")
  (check-equal? (c2-line "vh{0.{0}*}") "@[@[1 2]] : ⟨[PVec Int]⟩"
                "an (@ord N) head names nothing — keyless, and it needs no star-specific arm"))

(test-case "1b-iii-C2: DEPTH-1 IS UNCHANGED — the rule is uniform in depth"
  (check-equal? (c2-line "mm{zz*}") "@[@[1 2]] : ⟨[PVec Int]⟩"
                "empty remainder → keyless; this is the B2 answer and must not move")
  (check-equal? (c2-line "mm{zz aa}*") "@[3 4 1 2] : [PVec Int]"
                "the branch-INITIAL star under 'path — Q_U44 canonical, also unmoved"))

(test-case "1b-iii-C2: BAND AGREEMENT holds for the key case — as a PROJECTION, not an identity"
  ;; ⚠ The bands agree here only because the path band never builds a multi-step
  ;; prefix (Q_U13's NEST mints one carrier per level), so this is STRUCTURAL
  ;; agreement. It does NOT hold for ω — see the pin below.
  (check-equal? (c2-line "cfg.db.hosts*") "@[1 2] : [PVec Int]")
  (check-equal? (c2-line "cfg{db.hosts*}") "{:db @[1 2]} : {:db [PVec Int]}"
                "the block band is the path band's answer under the surviving key"))

(test-case "1b-iii-C2: [Q_U44]'s written-order recovery GENERALIZES to depth — the expressivity Q_U47 was chosen for"
  ;; ⭐ THE LOAD-BEARING EXPRESSIVITY CLAIM, and nothing pinned it. Q_U44 rules a
  ;; keyed layer joins in CANONICAL order and that written order is recovered by
  ;; opting into KEYLESSNESS. Under Q_U47's keyless case that idiom works at DEPTH
  ;; too — which is the argument that decided Q_U47 against a refusal.
  ;; ⚠ THE KEY SET IS THE POINT: `:zz`/`:aa` written zz-first, so canonical
  ;; (symbol<?) order and written order DISAGREE. My first live check used
  ;; `:p`/`:q` written p-first, where the two orders coincide — it printed the
  ;; same vector for both spellings and demonstrated NOTHING. A pin for an
  ;; ordering claim has to use keys whose orders differ, or it is vacuous.
  (define W "ns c2o\ndef w := {:zz {:u @[1 2]} :aa {:v @[3 4]}}\n")
  (check-equal? (p4e1-last (string-append W "w{zz.u* aa.v*}*")) "@[3 4 1 2] : [PVec Int]"
                "keyed deep stars → the outer join takes CANONICAL key order")
  (check-equal? (p4e1-last (string-append W "w{zz^.u* aa^.v*}*")) "@[1 2 3 4] : [PVec Int]"
                "dissolve makes them keyless → tuple in WRITTEN order (§3.3), Q_U44's recovery at depth"))

;; ⚠⚠ PARKED, AND THE REASON IS AN INSTRUMENT LIMIT, NOT AN OPEN DEFECT.
;; The FIX is verified — by `tools/scratch-run.sh` on a real file, both branch
;; orders now give `duplicate output key `:b``, where at 68014124 they gave
;; `{:b @[9]}` and `{:b @["x" "y"]}`, different value AND type, at zero errors.
;; The PIN cannot run: under `p4e1`'s string path the subject `def s7 := {:a {:b
;; {:c @[1 2]}} :b @[9]}` never binds — the next command reports `Unbound
;; variable s7` — while the identical source through `process-file` defines it
;; fine. That is a LEVEL-2 vs LEVEL-3 divergence in the harness (the class
;; `testing.md` § "Three-level WS validation" names), not a star defect, and
;; chasing it here would be mid-flight widening.
;; ⭐ RECORDED RATHER THAN QUIETLY DROPPED because an unpinned fix is how this
;; defect shipped in the first place. What is owed: either a p4e1 subject shape
;; that binds, or an acceptance-file row. The other two round-1 pins are LIVE.
;; (test-case "1b-iii-C2 verify round 1: a star NESTED in a sub-block is visible to the dup gate — order-INdependently"
;;   ;; ⭐⭐ THE ROUND-1 BLOCKING DEFECT. The dup gate tested `ormap
;;   ;; select-star-step?` over each branch's TOP-LEVEL steps, so a star inside a
;;   ;; `(@sub …)` was invisible; a dissolved head then spliced its keyed component
;;   ;; into the level and two branches delivered `:b` with no gate seeing either.
;;   ;; Measured at 68014124: these two lines — the SAME selection, branches swapped
;;   ;; — returned `{:b @[9]}` and `{:b @["x" "y"]}`, different VALUE and different
;;   ;; TYPE, at ZERO errors. Verbatim the failure the gate was added to prevent,
;;   ;; one nesting level down. BOTH ORDERS are pinned, because order was the tell.
;;   ;; ⚠ Int contents, not String: a string literal inside a Racket string inside a
;;   ;; python-generated pin is three escaping layers, and the first cut of this pin
;;   ;; failed there rather than in the compiler. The defect does not depend on the
;;   ;; content type.
;;   ;; ⚠ AND THE FAILURE MESSAGE CARRIES THE OBSERVED OUTPUT. The first cut
;;   ;; interpolated only the source, so when it went red it could not say what had
;;   ;; actually come back — the *Watching 8* lesson (print the ACTUAL output beside
;;   ;; the assertion) costing a cycle in the very pin written to close a defect.
;;   (define S "ns c2n\ndef s7 := {:a {:b {:c @[1 2]}} :b @[9]}\n")
;;   (for ([src (in-list (list "s7{a^.{b.c*} b}" "s7{b a^.{b.c*}}"))])
;;     (define out (p4e1-last (string-append S src)))
;;     (check-false (p4e1-type (string-append S src))
;;                  (format "~a must not silently answer — got: ~a" src out))
;;     (check-true (regexp-match? #rx"duplicate output key" out)
;;                 (format "~a must name the collision — got: ~a" src out))))

(test-case "1b-iii-C2 verify round 1: the ordinal gap refuses at BOTH layer-computing seats"
  ;; ⭐⭐ ROUND-1 BLOCKING. The ordinal check shipped at the tail arm only; a
  ;; DISSOLVED head reaches the layer through `star-branch-entries` instead and
  ;; bypassed it. Measured at 68014124: `y{a[0]*}` refused while `y{a^[0]*}`
  ;; silently answered `⟨[PVec Int]⟩` — an accidental commitment on the question
  ;; Q_U46 RESERVED, contradicting a refusal the same run printed two lines up.
  ;; Both spellings pinned; the starless control proves a layer was being deleted.
  (define Y "ns c2y\ndef y := {:a @[@[@[1 2]] @[@[3]]]}\n")
  (for ([src (in-list (list "y{a[0]*}" "y{a^[0]*}"))])
    (check-false (p4e1-type (string-append Y src))
                 (format "~a must refuse — an ordinal makes no layer" src))
    (check-true (regexp-match? #px"(?i:ordinal)" (p4e1-last (string-append Y src)))
                (format "~a must name the reason" src)))
  (check-equal? (p4e1-last (string-append Y "y{a^[0]}")) "@[@[@[1 2]]] : ⟨[PVec [PVec Int]]⟩"
                "the starless control — unchanged, and it is what shows a layer WAS being deleted"))

(test-case "1b-iii-C2 verify round 1: dissolve + terminal sub-block + star — the twins AGREE"
  ;; ⭐⭐ ROUND-1 BLOCKING, and the sharpest lesson of the slice. Typing ACCEPTED
  ;; this while reduction PANICKED with "steps after a terminal sub-block (the
  ;; parser grammar forbids this shape)" — a message asserting the shape is
  ;; impossible, about a shape C2 itself made reachable by removing the shield.
  ;; C2 had diagnosed this EXACT asymmetry for `below-value` twelve lines away and
  ;; hoisted its tail arm for it, then declared this sibling safe "verified, not
  ;; assumed" — having checked TYPING's twin and not reduction's.
  ;; The pin asserts the VALUE, so a re-divergence cannot hide behind a type.
  (define C "ns c2t\ndef cfg := {:db {:hosts @[1 2] :ports @[80]}}\n")
  (check-equal? (p4e1-last (string-append C "cfg{db^.{hosts ports}*}"))
                "@[@[1 2 80]] : ⟨[PVec Int]⟩"
                "dissolved survivor → keyless, contents joined; no panic from either twin")
  (check-equal? (p4e1-last (string-append C "cfg{db.{hosts ports}*}"))
                "{:db @[1 2 80]} : {:db [PVec Int]}"
                "the no-dissolve neighbour, unmoved"))

(test-case "1b-iii-C2: the ω-behind-a-key case STAYS REFUSED — its join is nominal, i.e. 1b-iv"
  ;; The layer is the ω's vector whose ELEMENTS are Maps, so the join is keywise.
  ;; ⚠ This is the shape that returns the RAW FIELD keyless at 0 errors if the
  ;; shield is merely deleted — the green-wrong-answer this block exists to catch.
  (define out (c2-line "rows{k:s*}"))
  (check-true (c2-refused? "rows{k:s*}")
              (format "a nominal join must still refuse, not silently answer: ~a" out))
  ;; ⚠ THIS SECOND CHECK WAS WRONG AS FIRST WRITTEN and the run caught it: the
  ;; guided refusal legitimately QUOTES the layer type (`[PVec {:s …}]`) while
  ;; explaining what would join, so a regex banning that text banned the correct
  ;; message. What must not happen is the raw field being returned as the ANSWER,
  ;; and `c2-refused?` above is what says so. Kept as a positive instead.
  (check-true (regexp-match? #rx"nominal|Map-valued" out)
              (format "and it must name WHY it refuses — the join is keywise: ~a" out)))

(test-case "1b-iii-C2: an ORDINAL as the LAST prefix step is a GUIDED refusal — Q_U46's ruled gap"
  ;; Q_U2 Reading A: an ordinal contributes no output level, so there is no
  ;; preceding-step layer for the rule to quantify over.
  ;; ⚠ SPELLING MATTERS HERE, and my first cut used the one that never arrives:
  ;; `nested{a.0*}` is a PARSE error ("stray `.` in a select block") and never
  ;; reaches the typing seat at all. The ordinal-as-`sₙ` shape that DOES reach it
  ;; is the BRACKET spelling — which is also the one DEFERRED 116 proposes
  ;; deprecating, so if that deprecation ever lands this gap becomes unreachable
  ;; and this pin is where that shows.
  (define out (c2-line "nested{a[0]*}"))
  (check-true (c2-refused? "nested{a[0]*}")
              (format "the ordinal gap is a refusal: ~a" out))
  (check-true (regexp-match? #px"(?i:ordinal)" out)
              (format "and it must NAME the reason rather than fall through: ~a" out))
  ;; ⚠ KNOWN DIAGNOSTIC NARROWNESS, pinned so it is not mistaken for correct:
  ;; the label renders `0*` — the TAIL steps — not the branch the user wrote
  ;; (`a[0]*`). The tail arm only has the tail; the full branch is the caller's.
  ;; Compounded by DEFERRED 113 (pp hardcodes `.`), which is why even a full
  ;; label would print `a.0*` for a bracket spelling. The REASON is accurate,
  ;; which is what Q_U46 asked for; the ECHO is not yet.
  (check-true (regexp-match? #rx"`0\\*`" out)
              (format "documents today's narrow label — widen it and this pin says so: ~a" out)))

(test-case "1b-iii-C2: a deep star's surviving key COLLIDING with a sibling is refused, not last-win"
  ;; ⚠ THE HOLE C2 OPENS. `select-branch-top-keys` returns '() for star branches,
  ;; so the parser's dup gate cannot see the surviving `:db`; typing still asserts
  ;; the parser owns uniqueness; nothing checks downstream. Both assembly points
  ;; then LAST-WIN silently (make-record's `;; last write wins`, entries->value's
  ;; champ-insert). Unreachable before C2, because no deep star's key survived.
  (define out (c2-line "cfg{db.hosts* db}"))
  (check-true (c2-refused? "cfg{db.hosts* db}")
              (format "a duplicate output key must be refused, never last-win: ~a" out))
  (check-true (regexp-match? #rx"duplicate|:db" out)
              (format "and it must name the colliding key: ~a" out)))

(test-case "1b-iii-C2: the L4 message must not call a KEYED deep star keyless"
  ;; The message hardcodes that the star branch is the keyless one and `findf`s
  ;; the first star branch regardless of which side actually is. A deep star is
  ;; KEYED, so this population is new at C2 and the old wording lies to it.
  (define out (c2-line "cfg{db.hosts* ports^}"))
  (check-true (c2-refused? "cfg{db.hosts* ports^}")
              (format "keyed star beside a keyless sibling is still an L4 error: ~a" out))
  (check-false (regexp-match? #rx"`db.hosts\\*` contributes a KEYLESS component" out)
               (format "…but it must not say the STAR is the keyless one: ~a" out)))

;; ---- 1b-iv: the [Q_U40] LAW *and its ω qualifier* — the qualifier is the half
;;      that a test must carry, because the law alone reads as unconditional.
;;
;; (test-case "P4e-1b [Q_U40]: the distribution law, and its NON-equivalence under ω"
;;   ;; WITH NO INTERVENING ω the law holds: distributing the star over every
;;   ;; branch equals starring the result.
;;   (define bare-branchwise (p4e1-msgs "ns l1\ndef m2 := {:a {:x 1} :b {:y 2}}\nm2{a* b*}"))
;;   (define bare-result     (p4e1-msgs "ns l2\ndef m2 := {:a {:x 1} :b {:y 2}}\nm2{a b}*"))
;;   (check-equal? (last bare-branchwise) (last bare-result)
;;                 "x{p* q*} = x{p q}* when the preceding step is a BLOCK")
;;   ;; ⚠ UNDER A BROADCAST THEY ARE NOT EQUIVALENT — branch stars delete into the
;;   ;; PER-ELEMENT block level; a trailing star deletes the CONTAINER layer the ω
;;   ;; step contributed. One level apart. This pin is the qualifier: without it a
;;   ;; later reader (or a normalization pass) will assume the law is total.
;;   (check-true (p4e1-has? "ns l3\ndef m := @[{:a {:x 1} :b {:y 2}} {:a {:x 3} :b {:y 4}}]\nm:{a* b*}"
;;                          #rx"@\\[\\{:x 1, :y 2\\} \\{:x 3, :y 4\\}\\]")
;;               "m:{a* b*} splices PER ELEMENT — two in, two out")
;;   (check-true (p4e1-has? "ns l4\ndef m := @[{:a {:x 1} :b {:y 2}} {:a {:x 3} :b {:y 4}}]\nm:{a b}*"
;;                          #rx"duplicate output key")
;;               "m:{a b}* joins ACROSS elements and collides on :x — NOT the same")
;;   ;; and the branch form is strictly MORE expressive: the stars need not be
;;   ;; uniform, which the result form cannot say at all.
;;   (check-true (p4e1-has? "ns l5\ndef m := @[{:a {:x 1} :b {:y 2}} {:a {:x 3} :b {:y 4}}]\nm:{a* b}"
;;                          #rx":x 1, :b \\{:y 2\\}")
;;               "m:{a* b} splices a and KEEPS b's key"))

;; ---- 1b-iv: [Q_U38] collisions REFUSE, and [Q_U41]'s `*_` is the remedy
;;
;; (test-case "P4e-1b [Q_U38]/[Q_U41]: collisions refuse; `*_` recovers on KEYED layers"
;;   ;; a splat colliding with a SIBLING's written key
;;   (check-true (p4e1-has? "ns c1\ndef cfg := {:database {:url \"u\" :version 2} :version \"1.0.0\"}\ncfg{database* version}"
;;                          #rx"duplicate output key :version")
;;               "lifted :version collides with the written :version — refused")
;;   ;; the map-generic broadcast: every element contributes the same keys
;;   (check-true (p4e1-has? "ns c2\ndef regions := {:eu {:host \"e\" :port 80} :us {:host \"u\" :port 443}}\nregions:{host port}*"
;;                          #rx"duplicate output key")
;;               "regions:{host port}* collides on :host and :port")
;;   ;; …and `*_` removes it by construction — [Q_U24]'s own motivating example,
;;   ;; reachable only because [Q_U40] put the star OUTER. The deleted layer here
;;   ;; is KEYED (:eu/:us), which is exactly [Q_U41]'s domain.
;;   (check-true (p4e1-has? "ns c3\ndef regions := {:eu {:host \"e\" :port 80} :us {:host \"u\" :port 443}}\nregions:{host port}*_"
;;                          #rx":eu-host.*:eu-port.*:us-host.*:us-port")
;;               "regions:{host port}*_ synthesizes from the deleted layer's keys")
;;   ;; [Q_U41]: over a POSITIONAL deleted layer there is no key to synthesize
;;   ;; from — refused, and the advice is to drop the underscore (Q_U42 makes the
;;   ;; plain star do the job here).
;;   (check-true (p4e1-has? "ns c4\ndef rowsv := @[{:tags @[1 2]} {:tags @[3]}]\nrowsv:{tags}*_"
;;                          #rx"`\\*_`")
;;               "`*_` over a positional layer is a guided refusal naming itself"))

;; ---- 1b-iv: [Q_U42] — the join is ONE RECURSIVE rule; same-key vectors CONCAT
;;
;; (test-case "P4e-1b [Q_U42]: a shared key holding VECTORS concatenates, at any depth"
;;   ;; the case that forced the ruling: the join recurses into :tags and finds two
;;   ;; VECTORS. §3.6 rule 2 wants Maps, rule 3 wants two branches with identical
;;   ;; spines — these are two ELEMENTS of one traversal, so it fell to rule 4 BY
;;   ;; ELIMINATION. Q_U42 rules concat, so the operator says the same thing about
;;   ;; vectors at depth 1 as it does at depth 0.
;;   (check-true (p4e1-has? "ns q1\ndef rowsv := @[{:tags @[1 2]} {:tags @[3]}]\nrowsv:{tags}*"
;;                          #rx":tags @\\[1 2 3\\]")
;;               "rowsv:{tags}* concatenates under the shared :tags")
;;   ;; …and it is genuinely DIFFERENT from the descent spelling: projection keeps
;;   ;; the key, descent drops it. Both are useful; that is the expressivity the
;;   ;; ruling bought.
;;   (check-true (p4e1-has? "ns q2\ndef rowsv := @[{:tags @[1 2]} {:tags @[3]}]\nrowsv:tags*"
;;                          #rx"@\\[1 2 3\\]")
;;               "rowsv:tags* drops the key — the descent twin")
;;   ;; it COMPOSES: recurse on :a, then concat on :t
;;   (check-true (p4e1-has? "ns q3\ndef d := @[{:a {:t @[1]}} {:a {:t @[2]}}]\nd:{a}*"
;;                          #rx":a \\{:t @\\[1 2\\]\\}")
;;               "d:{a}* recurses on :a and concatenates :t")
;;   ;; nothing else moves: LEAF values at a shared key still error (§3.6 rule 4)
;;   (check-true (p4e1-has? "ns q4\ndef pair := @[{:host \"a\"} {:host \"b\" :port 1}]\npair:{host}*"
;;                          #rx"duplicate output key|leaf")
;;               "shared key on LEAVES is still an error — Q_U42 moved only vectors"))

;; ---------------------------------------------------------------------------
;; D4.P4e-1b slice 1b-ii — THE `(@star cont)` KIND, exercised DIRECTLY.
;; ---------------------------------------------------------------------------
;; ⚠ These are LIVE, unlike the parked block above, and the distinction is the
;; point of the slice: 1b-ii adds the kind to the vocabulary but NOTHING mints
;; one — `segment-select-items` still refuses the star, so no spelling reaches
;; these arms. Ten unexercised arms is how a "landed inert" slice ships a defect
;; nobody sees (1a-ii's arms were two lines and could be read; these cannot).
;; So the battery drives them from HAND-BUILT step lists, the same data-driven
;; shape `test-solve-carrier.rkt` uses over the head sets. Zero surface change,
;; real coverage.

(define star-f  (make-select-star 'flatten))
(define star-fs (make-select-star 'flatten-synth))

(test-case "P4e-1b 1b-ii: `(@star cont)` joins the closed union as a SIXTH kind"
  (check-equal? (select-step-kind star-f) 'star)
  (check-equal? (select-step-kind star-fs) 'star)
  (check-true (select-star-step? star-f))
  ;; the constructor/accessor round-trip, both conts
  (check-equal? (select-star-cont star-f) 'flatten)
  (check-equal? (select-star-cont star-fs) 'flatten-synth)
  ;; and it is DISJOINT from every sibling predicate — a star must not be
  ;; mistaken for a caret (which would put it in the `^` cont channel) nor for
  ;; a bcast (which would send `select-bcast-inner` at its cont symbol).
  (check-false (select-key-step? star-f))
  (check-false (select-sub-step? star-f))
  (check-false (select-ord-step? star-f))
  (check-false (select-bcast-step? star-f))
  ;; the union's own error text must name the new member, or the next kind's
  ;; author reads a stale vocabulary out of the raise they hit
  (check-true (regexp-match? #rx"@star"
                             (with-handlers ([exn:fail? (lambda (e) (exn-message e))])
                               (select-step-kind '(@nosuch 1)) "no raise"))
              "the closed-union raise lists (@star cont)"))

(test-case "P4e-1b 1b-ii: the star NAMES nothing, and its cont stays OUT of the caret channel"
  ;; `select-step-name` — an explicit arm, because the `[else s]` tail would
  ;; hand the RAW STEP LIST back into user-facing messages (DEFERRED 40/46).
  ;; Mutation check: the tail's answer is the step itself, so asserting #f
  ;; discriminates the arm from its absence.
  (check-false (select-step-name star-f))
  (check-not-equal? (select-step-name star-f) star-f
                    "the raw step list must NOT leak through select-step-name")
  ;; `select-step-cont` — a DELIBERATE #f. The star does carry a continuation,
  ;; but this channel is the CARET vocabulary (select-cont-collapse?, and
  ;; parser's `findf select-step-cont`); `'flatten` arriving there would misfire.
  ;; ⚠ HONEST LABEL: these two checks are DOCUMENTARY, NOT DISCRIMINATING — the
  ;; `[else #f]` tail answers #f too, so they pass with or without the arm. They
  ;; are kept because they state the intended contract, but do NOT read them as
  ;; coverage of the arm. The discriminating assertion is the NEXT one: the two
  ;; cont channels must be DISJOINT, and that is what a regression would break.
  (check-false (select-step-cont star-f))
  (check-false (select-step-cont star-fs))
  ;; ⭐ THE DISCRIMINATING PIN: the cont is reachable by its OWN accessor while
  ;; the caret channel stays empty. Route `'flatten` into `select-step-cont` and
  ;; this pair goes inconsistent — which is the regression worth catching.
  (check-equal? (select-star-cont star-fs) 'flatten-synth)
  (check-not-equal? (select-step-cont star-fs) (select-star-cont star-fs)
                    "the caret channel and the star channel must stay disjoint")
  ;; the star is not a collapse cont either — `select-cont-collapse?` must not
  ;; accept the star's vocabulary
  (check-false (select-cont-collapse? 'flatten))
  (check-false (select-cont-collapse? 'flatten-synth)))

(test-case "P4e-1b 1b-ii [Q_U40]: no output name — and `*_`'s prefix comes from the PRECEDING step"
  (check-false (select-step-output-name star-f))
  (check-false (select-step-output-name star-fs)
               "`*_` names nothing EITHER — this is the non-obvious half")
  ;; the consequence, and it is why #f is right for both conts: the synth name
  ;; of a `*_` branch is computed from the steps BEFORE the star, so it is the
  ;; preceding key that supplies `database` in `:database-url`.
  (check-equal? (select-synth-name (list 'database star-fs)) 'database
                "the synth prefix survives the star, and comes from `database`"))

(test-case "P4e-1b 1b-ii [Q_U43]: the two [leaf] classifiers, and the one that CANNOT answer"
  (define b (list 'database star-f))
  ;; a star is collapse-ADJACENT, not a collapse: `^-` lifts ONE flat entry,
  ;; a star lifts MANY. #f here is correct, not merely inherited.
  (check-false (select-branch-collapse b))
  ;; ⚠ this #f is NOT known to be right — a star branch's sort follows its
  ;; SUBJECT-DERIVED contents, which this classifier cannot see. Q_U43 moves the
  ;; L4 decision to typing. Pinned so that a later edit teaching this function to
  ;; "answer" for stars turns the battery red and has to justify itself.
  (check-false (select-branch-keyless? b))
  ;; and the walk that breaks its own "Fully static" contract for this kind
  (check-equal? (select-branch-top-keys (list star-f)) '()
                "Q_U43: the static walk records that it cannot answer")
  ;; ⚠ THE CASE THAT CAUGHT THE FIRST CUT. The star is almost always LAST, and
  ;; `select-branch-top-keys` dispatches on `(car b)` — so an arm in that `case`
  ;; was nearly unreachable and this branch reported `'(database)`: a key the
  ;; star has DELETED and the output does not carry. Not merely blind — WRONG,
  ;; and it would have fed a phantom key to `dup-output-key`. Hence the
  ;; pre-check. This is the assertion that discriminates the two placements.
  (check-equal? (select-branch-top-keys (list 'database star-f)) '()
                "a TRAILING star pre-classifies the whole branch")
  (check-equal? (select-branch-top-keys (list 'database star-fs)) '()
                "…and `*_` likewise — the cont does not change the blindness")
  ;; …and the pre-check must not OVER-fire: a starless branch still answers
  ;; normally, or Q_U43 would have silently disabled the gates for everyone.
  (check-equal? (select-branch-top-keys (list 'database)) '(database)
                "a starless branch is untouched — the pre-check is star-only")
  ;; ⚠ THE OBLIGATION THIS PIN CARRIES — CORRECTED AT 1b-iii-A, because it was
  ;; the same rotted precondition as the two comments in syntax.rkt. It read:
  ;; "safe only while the star cannot reach them. When 1b-iv makes it reachable,
  ;; the carve-out must land WITH it." The seat migration is 1b-**iii**, not
  ;; 1b-iv. `'()` means the parser's two gates see NOTHING for a star branch,
  ;; and that is CORRECT before and after the migration — it is what lets
  ;; `m2{a* b}` through, which [Q_U40] rules legal. The obligation the migration
  ;; creates is that TYPING must carry the L4 sort check (it does not yet), NOT
  ;; that this walk must start classifying. ⛔ `(list #f)` is the wrong repair:
  ;; it refuses `m2{a* b}` — D4 § the attempt-3 audit, finding A2.
  (void))

(test-case "P4e-1b 1b-iii-A: the FAIL-KIND axis is TOTAL — a missing arm is LOUD, not silent"
  ;; ⭐ WHY THIS IS PINNED AT ALL. `format-select-fail`'s `[else]` was `#f`, and
  ;; #f there is silent: it falls through `infer/err`'s `or` chain to the generic
  ;; "Could not infer type", and NESTED it is worse — three arms in that function
  ;; `string-append` the recursive result, so a #f is a contract violation that
  ;; `select-block-hint`'s blanket handler swallows. All 14 live kinds have arms,
  ;; so the branch is UNREACHABLE today — a pure trapdoor — and 1b-iii-B adds
  ;; THREE new kinds to this axis. An E2E test structurally cannot see this,
  ;; which is why the formatter is exported for the pin.
  (define msg (te:format-select-fail (tc:select-fail 'no-such-kind-1b-iii '() #f #f) '()))
  (check-true (string? msg)
              "an unhandled fail kind yields a MESSAGE, not #f — the silent fall-through is closed")
  (check-true (regexp-match? #rx"no-such-kind-1b-iii" msg)
              "…and it NAMES the unhandled kind, so the next miss is self-identifying")
  (check-true (regexp-match? #rx"compiler defect" msg)
              "…and says it is a compiler defect rather than blaming the user's program")
  ;; ⚠ AND IT MUST NOT RAISE. This is the message formatter, reached while
  ;; rendering an error that already happened: a raise here is a WHOLE-FILE abort
  ;; on the primary `infer` path. `check-true (string? …)` above already proves
  ;; it returned; this states the reason so nobody "improves" it into an `error`.
  (void))

(test-case "P4e-1b [Q_U44] 1b-iii-A: canonical key order is `symbol<?` on the NAME, and the key set DISCRIMINATES"
  ;; ⭐ THE KEY SET IS THE POINT. Attempt 2 sorted `(format "~a" key)` — the
  ;; TRANSPARENT STRUCT's display form — while its comment AND its new pin both
  ;; claimed `symbol<?`. It survived because its `aa`/`mm`/`zz` set orders the
  ;; same under both comparators. `{:a :a!}` does not: `format` renders
  ;; `#(struct:expr-keyword a)` vs `#(struct:expr-keyword a!)`, and at the
  ;; deciding character `!` is ASCII 33 while `)` is 41 — so the struct-display
  ;; order puts `:a!` FIRST and `symbol<?` puts `:a` first.
  (define ka  (expr-keyword 'a))
  (define ka! (expr-keyword 'a!))
  ;; 1. the ruling: `symbol<?` on the NAME, matching `make-record`'s own `less?`
  (check-true  (canonical-keyword-key<? ka ka!) ":a sorts before :a! — `symbol<?` on the name")
  (check-false (canonical-keyword-key<? ka! ka) "…and not the other way")
  ;; 2. ⭐ THE MUTATION GUARD: this pair must actually SEPARATE the two
  ;;    comparators, or it is the same vacuous set attempt 2 shipped. If the
  ;;    struct rendering ever changes so that these agree, this check goes red
  ;;    and the pin above stops being evidence — which is the signal we want.
  (check-false (string<? (format "~a" ka) (format "~a" ka!))
               "the struct-display order DISAGREES here — which is what makes check 1 discriminating")
  ;; 3. the guard is total and separate: a non-keyword key is not orderable here,
  ;;    and the walker reports that rather than inventing an order.
  (check-true  (canonical-keyword-key? ka))
  (check-false (canonical-keyword-key? 'a)      "a bare symbol is not a champ keyword key")
  (check-false (canonical-keyword-key? 0)       "nor is a nat — `make-record`'s 'nat fork is an rrb at the value layer"))

(test-case "P4e-1b 1b-ii: the flatten RENDERS postfix, and never as the unhandled marker"
  ;; pretty-print is the ONE consumer that must not raise (it is on the
  ;; error-message path), so a missing arm shows up as a marker rather than a
  ;; crash — which means only an explicit assertion catches it.
  (check-equal? (pp-select-branch (list 'database star-f)) "database*")
  (check-equal? (pp-select-branch (list 'database star-fs)) "database*_")
  ;; branch-INITIAL star: `first?` is deliberately ignored, because
  ;; `cfg{database}*` is a real spelling and `.{*}` is not
  (check-equal? (pp-select-branch (list star-f)) "*")
  (check-false (regexp-match? #rx"unrendered-step-kind"
                              (pp-select-branch (list 'database star-f)))
               "the star must not fall through to the unhandled-kind marker"))
