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
         (prefix-in tr: "../trait-resolution.rkt")
         (prefix-in u: "../unify.rkt")
         (prefix-in gc: "../global-constraints.rkt")
         "../errors.rkt"
         "../champ.rkt"
         (only-in "../rrb.rkt" rrb-from-list)   ;; D4.P4a: twin-regression fixture
         "test-support.rkt"
         "../parse-reader.rkt"
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
  (define result
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
  (delete-file tmp)
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
  ;; ⚠ The guard RAISES (`(error 'ns …)`) rather than returning a per-command
  ;; error value, so this is a whole-file abort — PRE-EXISTING behaviour, shared
  ;; with `ns foo.bar`, and the same class Q_L4's marker seat exists for. Left
  ;; as-is deliberately: `ns` is the first command in a file, so aborting there
  ;; is near-indistinguishable from a per-command error. Pinned with check-exn
  ;; so the SHAPE is deliberate and a future change to the seat is visible.
  (check-exn #rx"namespace name cannot contain"
             (lambda () (run-ws-raw "ns foo.2\n"))
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
  (check-exn exn:fail? (lambda () (run-ws-raw "ns foo:bar\ndef x := 1\n"))
             "a colon segment in an ns name must be REFUSED, not silently dropped"))

(test-case "P4c-1: the ns refusal names the segment and offers `::`"
  ;; Same CHANNEL as pin 1 — the guard raises, so the message is read off the
  ;; exn, not off a result list. (The first draft read `(car rs)`, which is
  ;; incoherent with a raising guard and contract-violated on '().)
  (check-exn (lambda (e)
               (and (exn:fail? e)
                    (regexp-match? #rx"namespace name" (exn-message e))
                    (regexp-match? #rx"::" (exn-message e))))
             (lambda () (run-ws-raw "ns foo:bar\ndef x := 1\n"))
             "the refusal must name the namespace name and offer `::` as the remedy"))

(test-case "P4c-1: the ns guard stays TOTAL for the shapes it already caught"
  ;; ⚠ RECORDED, not endorsed: this guard RAISES (a raw Racket `error`), it does
  ;; not return a per-command `parse-error` VALUE — so it is a WHOLE-FILE ABORT,
  ;; the Q_L4 class P1a built the marker-form seat to prevent. Pinning the true
  ;; behaviour rather than the behaviour I assumed; the raise→value conversion
  ;; is a NAMED follow-up, deliberately out of P4c-1's scope because the
  ;; prerequisite is totality, not the error CHANNEL.
  (check-exn exn:fail? (lambda () (run-ws-raw "ns foo.bar\ndef x := 1\n"))
             "dot segment — already caught, must stay caught")
  (check-exn exn:fail? (lambda () (run-ws-raw "ns foo[2]\ndef x := 1\n"))
             "index segment — already caught, must stay caught"))

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
  (check-equal? (read-all-forms-string "users:w") '((users ($bcast-step :w))))  ;; deliberate flip, as above
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
;; `rewrite-dot-access` seats (macros.rkt :1965 · :2672 · :6316 · :6702).
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
  (check-equal? (read-all-forms-string "(f x):name") '(((f x) ($bcast-step :name)))))

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
                '((defmacro when ($c :Int $b) $c))))

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

(test-case "P4c-2 (c): an expression-position broadcast is an HONEST not-yet error"
  ;; Measured before the arm existed: `ERROR: Unbound variable` — a diagnostic
  ;; that names the wrong subsystem for a surface that simply is not built until
  ;; P4c-3. It rides the P1a marker seat's NOT-YET family (zero new
  ;; registrations: `$bcast-step` needs no `pattern-var?` entry it does not
  ;; already have, and the seat is already total).
  (define r (run-ws "def users := @[{:name \"a\"}]\ndef bad := users:name\n"))
  (check-regexp-match #rx"not implemented yet" (last r))
  (check-regexp-match #rx"P4c-3" (last r))
  ;; and it must name the workaround, not just refuse
  (check-regexp-match #rx"map" (last r)))

(test-case "P4c-2 (c): that error is PER-COMMAND — the file is not aborted"
  ;; The whole point of the marker seat: a classifier-level RAISE is a whole-file
  ;; abort by construction (Q_L4), and DEFERRED 31 records a live instance of
  ;; getting this wrong. A command AFTER the offending one must still run.
  (define r (run-ws "def users := @[{:name \"a\"}]\ndef bad := users:name\ndef after := 99\nafter\n"))
  (check-equal? (last r) "99 : Int")
  (check-equal? (length r) 4))

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
