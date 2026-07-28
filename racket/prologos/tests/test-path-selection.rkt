#lang racket/base

;;;
;;; CIU T6 Path Selection — the track's test file (created P2.a, grown per phase).
;;; P2.a: prerequisite repairs — the record-project Int gate, the pvec-nth
;;; discipline guard, the ground-expr? twin fallbacks, and the
;;; expr-broadcast-get walker-safety arms.
;;; Design: docs/tracking/2026-07-26_CIU_T6_PATH_SELECTION_DESIGN.md §2 P2 + §5.10.
;;;

(require rackunit
         racket/list
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
;; P2.a — expr-broadcast-get walker safety (whnf + definitely-not-map?)
;; ============================================================

(define champ-alice
  (whnf (expr-map-assoc (expr-map-empty (expr-Keyword) (expr-String))
                        (expr-keyword 'name) (expr-string "alice"))))

(define bg-live
  ;; (broadcast-get (cons {:name "alice"} nil) :name) — reducible.
  (expr-broadcast-get
   (expr-app (expr-app (expr-fvar 'cons) champ-alice) (expr-fvar 'nil))
   (list (expr-keyword 'name))))

(test-case "broadcast-get: whnf now reduces it (was: [_ e] fallthrough, nf-only)"
  (define w (whnf bg-live))
  (check-false (eq? w bg-live))
  (check-equal? w (nf bg-live)))

(test-case "broadcast-get: a STUCK broadcast no longer degrades map-get to `none`"
  ;; definitely-not-map? now exempts expr-broadcast-get like its two path
  ;; siblings (the 2026-07-16 value-loss fix left it out): map-get over a stuck
  ;; broadcast stays STUCK instead of fabricating (expr-fvar 'none).
  (define bg-stuck (expr-broadcast-get (expr-fvar 'unknown-list)
                                       (list (expr-keyword 'name))))
  (check-false (definitely-not-map? bg-stuck))
  (define r (whnf (expr-map-get bg-stuck (expr-keyword 'k))))
  (check-false (equal? r (expr-fvar 'none))))

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
