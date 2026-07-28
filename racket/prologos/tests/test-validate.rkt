#lang racket/base
;; ============================================================================
;; CIU T6 F1b.5-s2 — [validate Schema e] Level-3 ROUTE tests (full pipeline:
;; WS read → preparse → parse keyword arm → elaboration BAKE → typing rule →
;; QTT → reduction tabulation). Tabulation SEMANTICS are unit-pinned in
;; test-validate-node.rkt; this file pins the ROUTES: the A2-e attachment
;; (incl. the bail-list-load-bearing nested-in-defn case), the def-bound QTT
;; gate, the `_`-eta HOF beat, the loud bake errors, and end-to-end Result
;; consumption (err? / match — the dual-arity ctor-minting contract).
;; Helper = the run-file-string L3 template (test-schema-seal precedent).
;; ============================================================================

(require rackunit
         racket/file
         racket/path
         racket/list
         racket/string
         "test-support.rkt"
         "../driver.rkt"
         "../errors.rkt"
         "../macros.rkt"
         "../namespace.rkt"
         "../relations.rkt"
         "../global-env.rkt"
         (only-in "../metavar-store.rkt" current-persistent-registry-net-box current-prop-net-box)
         (only-in "../propagator.rkt" with-forked-network))

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define (run-file-string content)
  (define tmp (make-temporary-file "validate-~a.prologos"))
  (call-with-output-file tmp
    (lambda (out) (display content out)) #:exists 'truncate)
  (define results
    ;; Seed from the ONCE-per-subprocess prelude snapshot rather than reloading
    ;; all 39 prelude modules per test case. `(hasheq)` here cost ~4s of
    ;; deserialize-module-state + pnet-stale? per test — over half the runtime of
    ;; a Level-3 route test, and none of it the thing under test. The registry
    ;; family must be seeded TOGETHER: a preloaded module registry means modules
    ;; are not re-loaded, so seeding only `current-module-registry` leaves the
    ;; trait/impl registries empty and `Seqable for List` goes missing. Mirrors
    ;; test-support.rkt's own run-ns-* helpers exactly.
    ;; The schema/selection/defn-param registries stay FRESH — those are what
    ;; these tests register into, and per-test isolation there is the point.
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
                   [current-ns-context-cell-id #f]
                   [current-schema-registry (hasheq)]
                   [current-selection-registry (hasheq)]
                   [current-defn-param-names (hasheq)])
      (with-forked-network current-prop-net-box
        (install-module-loader!)
        (process-file (path->string tmp)))))
  (delete-file tmp)
  results)

(define (result-str r)
  (cond [(prologos-error? r) (format "ERROR: ~a" (prologos-error-message r))]
        [(string? r) r]
        [else (format "~a" r)]))

(define (ok? r) (not (prologos-error? r)))

(define person-preamble
  "ns vt~a\n
schema Person\n  :name String\n  :age Int\n
def m := [map-assoc [map-assoc {} :name \"alice\"] :age 30]\n
def bad := [map-assoc [map-assoc {} :name \"bob\"] :age \"x\"]\n")

(define (person-file n body) (string-append (format person-preamble n) body))

;; ---- the demo beat + result typing ------------------------------------------

(test-case "validate/ok-with-result-type"
  (define rs (run-file-string (person-file 1 "[validate Person m]\n")))
  (define out (result-str (last rs)))
  (check-regexp-match #rx"result::ok \\{" out)
  ;; F1b.5-s3: validate resolves S to the ns-QUALIFIED schema name (so a
  ;; validate value unifies with a `def x : Schema :=` annotation; short and
  ;; qualified schema fvars are distinct types).
  (check-regexp-match #rx"Result vt[0-9]+::Person \\[Map Keyword prologos::data::reason::Reason\\]" out))

(test-case "validate/err-and-err?-consumption"
  (define rs (run-file-string (person-file 2 "[validate Person bad]\n\n[err? [validate Person bad]]\n")))
  (check-regexp-match #rx"type-mismatch \"Int\" \"String\"" (result-str (list-ref rs (- (length rs) 2))))
  (check-regexp-match #rx"^true" (result-str (last rs))))

(test-case "validate/fill-defaults-nonliteral-debt-discharged"
  (define rs (run-file-string
              "ns vt3\n
schema Cfg\n  :host String :default \"localhost\"\n  :port Int :default 8080\n
[validate Cfg {}]\n"))
  (define out (result-str (last rs)))
  (check-regexp-match #rx"result::ok" out)
  (check-regexp-match #rx":host \"localhost\"" out)
  (check-regexp-match #rx":port 8080" out))

(test-case "validate/check-as-recoverable-result"
  (define rs (run-file-string
              "ns vt4\n
schema Checked\n  :name String\n  :age Int :check (> _ 0)\n
[validate Checked {:name \"d\" :age 0}]\n
[validate Checked {:name \"d\" :age 5}]\n"))
  (check-regexp-match #rx"check-failed \"\\(> _ 0\\)\"" (result-str (list-ref rs (- (length rs) 2))))
  (check-regexp-match #rx"result::ok" (result-str (last rs))))

(test-case "validate/check-unevaluable-lambda-guard"
  ;; F1b.7a Layer B: a :check that cannot be evaluated (a [fn ..] value; a stuck
  ;; trait method like `eq?`/`le?` pre-7b) must FAIL LOUD, never silently pass —
  ;; validate errs (check-unevaluable), the constructor door panics at commit.
  (define rs (run-file-string
              "ns vtu\n
schema Never\n  :d Int :check [fn [x : Int] false]\n
[validate Never {:d 5}]\n
def bad := [Never {:d 5}]\n"))
  (check-regexp-match #rx"check-unevaluable" (result-str (list-ref rs (- (length rs) 2))))
  (check-true (prologos-error? (last rs))))

(test-case "validate/lever-i-comparison-family"
  ;; F1b.7b lever (i): le?/lt?/ge?/gt? → dict-free keywords that work on Int
  ;; (were monomorphic Nat → check-unevaluable on Int pre-7b). No arg-reversal.
  (define rs (run-file-string
              "ns vtli\n
schema R\n  :n Int :check (le? _ 100)\n
[validate R {:n 50}]\n
[validate R {:n 200}]\n"))
  (check-regexp-match #rx"result::ok" (result-str (list-ref rs (- (length rs) 2))))
  (check-regexp-match #rx"check-failed \"\\(le\\? _ 100\\)\"" (result-str (last rs))))

(test-case "validate/slash-eq-and-default-unevaluable"
  ;; F1b.7b: `/=` → (not (eq ..)) (the neq target was unbound); and a trait-
  ;; method :default reads as default-unevaluable, not a type-mismatch.
  (define rs-ne (run-file-string
                 "ns vtne\nschema N\n  :n Int :check (/= _ 0)\n[validate N {:n 0}]\n"))
  (check-regexp-match #rx"check-failed \"\\(/= _ 0\\)\"" (result-str (last rs-ne)))
  (define rs-du (run-file-string
                 "ns vtdu\nschema D\n  :flag Bool :default [eq? 3 3]\n[validate D {}]\n"))
  (check-regexp-match #rx"default-unevaluable" (result-str (last rs-du))))

(test-case "validate/check-polarity-upper-bound-golden"
  ;; the arg-REVERSAL pin at L3: (> 10 _) → subst → (> 10 x) → normalize →
  ;; (lt x 10) — an upper bound. (`(< _ 10)` itself is unusable in WS files:
  ;; `<` opens an angle-type group — a PRE-EXISTING reader class, noted for
  ;; the F1b.close sweep; the workaround is exactly this flipped form.)
  (define rs (run-file-string
              "ns vt5\n
schema Small\n  :n Int :check (> 10 _)\n
[validate Small {:n 3}]\n
[validate Small {:n 30}]\n"))
  (check-regexp-match #rx"result::ok" (result-str (list-ref rs (- (length rs) 2))))
  (check-regexp-match #rx"check-failed" (result-str (last rs))))

;; ---- routes: def-bound (QTT), nested-in-defn (bail list), HOF (_-eta) ------

(test-case "validate/def-bound-exercises-qtt"
  (define rs (run-file-string (person-file 6 "def r := [validate Person m]\n\n[err? r]\n")))
  (for ([r (in-list rs)]) (check-pred ok? r (result-str r)))
  (check-regexp-match #rx"^false" (result-str (last rs))))

(test-case "validate/nested-in-defn-body-bail-list"
  ;; the tree-parser bail entry's load-bearing case: inside a defn body the
  ;; tree surf would otherwise win with a plain application
  (define rs (run-file-string (person-file 7 "defn vp [x]\n  [validate Person x]\n
[err? [vp m]]\n\n[err? [vp bad]]\n")))
  (check-regexp-match #rx"^false" (result-str (list-ref rs (- (length rs) 2))))
  (check-regexp-match #rx"^true" (result-str (last rs))))

(test-case "validate/hof-beat-underscore-eta"
  (define rs (run-file-string (person-file 8 "def rows := '[{:name \"a\" :age 1} {:name \"b\" :age 2}]\n
[map [validate Person _] rows]\n")))
  (define out (result-str (last rs)))
  (check-regexp-match #rx"result::ok \\{" out)
  (check-regexp-match #rx"List \\[.*Result vt[0-9]+::Person" out))  ; s3: qualified S

;; ---- loud bake errors + static reject ---------------------------------------

(test-case "validate/static-reject-non-map"
  (define rs (run-file-string (person-file 9 "[validate Person 42]\n")))
  (check-true (prologos-error? (last rs)) "non-map subject must reject statically"))

(test-case "validate/unknown-schema-loud"
  (define rs (run-file-string "ns vt10\n\n[validate Nope {}]\n"))
  (check-regexp-match #rx"unknown schema Nope" (result-str (last rs))))

;; ---- closed/open + collect-all + deterministic rendering --------------------

(test-case "validate/closed-unexpected-open-extras"
  (define rs (run-file-string
              "ns vt11\n
schema Locked :closed\n  :a Int\n
schema Open1\n  :a Int\n
[validate Locked [map-assoc [map-assoc {} :a 1] :extra 2]]\n
[validate Open1 [map-assoc [map-assoc {} :a 1] :extra 2]]\n"))
  (check-regexp-match #rx":extra prologos::data::reason::unexpected-field"
                      (result-str (list-ref rs (- (length rs) 2))))
  (define open-out (result-str (last rs)))
  (check-regexp-match #rx"result::ok" open-out)
  (check-regexp-match #rx":extra 2" open-out))

(test-case "validate/collect-all-rendered-deterministically"
  ;; two failures flow through the Result GENERIC (map-err ∘ errors-to-list —
  ;; the dual-arity minting contract end-to-end) and render field-sorted
  (define rs (run-file-string (person-file 12 "[result::map-err errors-to-list [validate Person [map-assoc {} :age \"x\"]]]\n")))
  (define out (result-str (last rs)))
  (check-regexp-match #rx":age.*type-mismatch" out)
  (check-regexp-match #rx":name.*missing-required" out)
  ;; :age sorts before :name (the deterministic renderer)
  (check-true (< (car (car (regexp-match-positions #rx":age" out)))
                 (car (car (regexp-match-positions #rx":name" out))))))

(test-case "validate/match-destructures-def-bound-result"
  ;; user match over a validate result (def-bound scrutinee — the inline-
  ;; scrutinee match-typing wrinkle is a noted route-sensitivity, close sweep)
  (define rs (run-file-string (person-file 13 "def vr := [validate Person bad]\n
match vr\n  | [ok v] -> 0\n  | [err es] -> 1\n")))
  (check-regexp-match #rx"^1" (result-str (last rs))))
