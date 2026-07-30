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
         (prefix-in tr: "../trait-resolution.rkt")
         (prefix-in u: "../unify.rkt")
         (prefix-in gc: "../global-constraints.rkt")
         "../errors.rkt"
         "../champ.rkt"
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
  ;; ⚠ RENAMED + CORRECTED. This test was titled "inside fn params too" while
  ;; asserting on `[fn [x : Int] cfg{host}]` — where the select block is in the
  ;; BODY and the param list is the untouched `[x : Int]`. It passed for a
  ;; reason unrelated to its name (body-position select blocks give the guided
  ;; error everywhere), i.e. it was a VACUOUS pin of the exact class this track
  ;; keeps catching. Caught by adversarial verify, pre-commit.
  (define r (run-ws-last "def cfg := {:host \"h\"}\ndef y := [fn [x : Int] cfg{host}]\n"))
  (check-regexp-match #rx"select block" r)
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
  (check-equal? (preparse-expand-form '(h base ($select-brace a)))
                '(h ($retired-selection select-block #f)))
  (check-equal? (preparse-expand-form '(h base ($dot-brace a)))
                '(h ($retired-selection select-block #f))))

(test-case "P1b-iii BLOCKING pin: a multi-arity defn clause is NOT silently dropped"
  ;; Was: `bad : Int -> Int defined.` with 0 errors and `[bad 0]` returning the
  ;; WRONG arm, because the `| 0 -> …` clause head had been eaten.
  (define rs (run-ws-raw
              (string-append
               "def mm := {:a 1 :b 2}\n"
               "defn bad\n"
               "  | 0 -> mm{a}\n"
               "  | n -> [int+ n 100]\n")))
  (check-true (ormap prologos-error? rs)
              "the clause was silently dropped — the function defined with the wrong arms"))

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
