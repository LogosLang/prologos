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
         "../parse-reader.rkt")

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

(test-case "P2: `.N` folds in ALL THREE rewrite-dot-access callers"
  ;; rewrite-dot-access has THREE production callers, so a `.N` arm inside it
  ;; inherits them free: preparse-expand-subforms (the re-entry),
  ;; preparse-map-literal-contents (map-literal VALUES), and expand-mixfix-form
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

(test-case "P3a verify: compound select SUBJECTS are preparse-expanded (partial opacity)"
  ;; The fold runs BEFORE subform recursion, so the subject arrives raw; the
  ;; $select arm now expands the SUBJECT while the payload stays protected.
  ;; F2a shape — bracket-group subject with an inner dot-access:
  (check-equal? (preparse-expand-form '((f m ($dot-access x)) ($select-brace a)))
                '($select (f (map-get m :x)) a))
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
  (define r (whnf (expr-select (expr-int 5) '((a)))))
  (check-true (expr-panic? r) "a ground non-map subject must panic, not stick")
  ;; and a stuck NEUTRAL still sticks (fvar subject — no panic, no loop):
  (define stuck (whnf (expr-select (expr-fvar 'nosuch) '((a)))))
  (check-true (expr-select? stuck)))

(test-case "P3a verify: trailing steps after a terminal sub-block panic (constructed IR)"
  ;; The parser grammar forbids the shape; the reducer now enforces it rather
  ;; than silently discarding the trailing steps.
  (define subj (whnf (expr-select (expr-fvar 'x) '((a)))))
  (check-true (expr-select? subj)) ;; sanity: stuck neutral stays stuck
  (define bad-branches '((a (@sub (b)) c)))
  ;; construct the champ directly — no fixture dependency
  (define inner
    (champ-insert champ-empty (equal-hash-code (expr-keyword 'b)) (expr-keyword 'b) (expr-int 1)))
  (define champ-subj
    (expr-champ (champ-insert champ-empty (equal-hash-code (expr-keyword 'a)) (expr-keyword 'a)
                              (expr-champ inner))))
  (define r (whnf (expr-select champ-subj bad-branches)))
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
             (lambda () (tc:select-project '() BOGUS-TYPING-SUBJ (list (list BOGUS-STEP))))
             "an unknown step kind must not be silently projected as a nominal key"))

(test-case "P4a totality site 5: select-below-field RAISES on an unknown step kind below a kept head"
  ;; `a` descends, then the bogus step is BELOW it -> select-below-field's guard
  (check-exn totality-exn?
             (lambda () (tc:select-project '() BOGUS-TYPING-SUBJ (list (list 'a BOGUS-STEP))))
             "an unknown step kind below a kept head must not be silently projected"))

(test-case "P4a totality site 3: walk-to-leaf RAISES on an unknown step kind (collapse branch)"
  ;; a `^-` collapse leaf pre-classifies into walk-to-leaf -> its guard
  (check-exn totality-exn?
             (lambda () (tc:select-project '() BOGUS-TYPING-SUBJ
                                           (list (list BOGUS-STEP '(@key a collapse)))))
             "walk-to-leaf must not silently treat an unknown step kind as a nominal key"))

;; ---- sites 6-8: the reduction walk, via the newly-exported `select-reduce` ----

(define (bogus-runtime-subject)
  (let ([kw (expr-keyword 'a)])
    (expr-champ (champ-insert champ-empty (equal-hash-code kw) kw (expr-int 1)))))

;; hoisted, as above
(define BOGUS-RUNTIME-SUBJ (bogus-runtime-subject))

(test-case "P4a totality site 7: select-reduce's branch-entries RAISES on an unknown step kind"
  (check-exn totality-exn?
             (lambda () (nf (select-reduce BOGUS-RUNTIME-SUBJ (list (list BOGUS-STEP)))))
             "an unknown step kind must not be silently projected at runtime"))

(test-case "P4a totality site 8: select-reduce's below-value RAISES on an unknown step kind"
  (check-exn totality-exn?
             (lambda () (nf (select-reduce BOGUS-RUNTIME-SUBJ (list (list 'a BOGUS-STEP)))))
             "an unknown step kind below a kept head must not be silently projected at runtime"))

(test-case "P4a totality site 6: select-reduce's walk-to-leaf RAISES on an unknown step kind"
  (check-exn totality-exn?
             (lambda () (nf (select-reduce BOGUS-RUNTIME-SUBJ
                                           (list (list BOGUS-STEP '(@key a collapse))))))
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
                             (list 'nope))))) ;; misses at runtime
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
                       (list (list 'a) (list 'nope)))))
  (check-true (expr-panic? result)
              "the discriminating assertion — a buried panic would be an expr-champ")
  (check-regexp-match #rx"nope" (format "~a" result))
  (check-regexp-match #rx"invariant violation" (format "~a" result)))

(test-case "P4a whole-node abort: a non-map mid-descent aborts the NODE too"
  ;; :a holds an Int, so descending `a.b` hits champ-of's non-map path
  (define result
    (nf (select-reduce (bogus-runtime-subject) (list (list 'a 'b)))))
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
                                    (list (list 'a '(@ord 0))))))
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
       (tc:select-project '() tm (list (list 'a '(@ord 0))))))
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
    (pp-expr (expr-select (expr-fvar 'x) (list (list 'a BOGUS-STEP))) '()))
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
