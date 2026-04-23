#lang racket/base

;;;
;;; Tests for mixed-type (heterogeneous value) maps.
;;;
;;; PPN 4C T-2 (2026-04-23): "Open by Design" map semantics.
;;; Unannotated map literals infer value type as `Open` — an α-semantic
;;; universal type (compatible with anything in both directions).
;;; Annotated maps (e.g., `(Map Keyword Nat)` or `(Map Keyword <Nat | String>)`)
;;; check strictly against the annotation. Schema system provides structured
;;; per-field validation.
;;;
;;; Tests updated 2026-04-23 for Open-default semantics:
;;; - Unannotated heterogeneous literals → (Map Keyword Open)
;;; - map-get returns Open on Open maps; Open trusted in α (downstream usage
;;;   via annotation, schema, or pattern match)
;;; - Narrow-union annotations (e.g., `<Nat | String>`) continue to work
;;; - Strict annotation rejection (e.g., can't map-assoc String into
;;;   `(Map K Nat)`) is now structurally enforced, no auto-widening
;;;

(require rackunit
         racket/string
         racket/list
         racket/path
         "test-support.rkt"
         "../syntax.rkt"
         "../prelude.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../unify.rkt"
         "../pretty-print.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../metavar-store.rkt"
         "../namespace.rkt"
         "../macros.rkt"
         "../champ.rkt")

;; Helper to run sexp code with clean global env
(define (run s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (process-string s)))

;; Helper: run prologos code with namespace system active
(define (run-ns s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    (process-string s)))

;; Helper: extract last string result, skipping errors
(define (last-string results)
  (define strings (filter string? results))
  (if (null? strings) "" (last strings)))

;; ========================================
;; A. Unit tests: build-union-type
;; ========================================

(test-case "build-union-type: single type is identity"
  (check-equal? (build-union-type (list (expr-Nat)))
                (expr-Nat)))

(test-case "build-union-type: two distinct types"
  (define result (build-union-type (list (expr-Nat) (expr-String))))
  (check-true (expr-union? result))
  ;; After sort: Nat < String (by union-sort-key)
  (check-equal? (expr-union-left result) (expr-Nat))
  (check-equal? (expr-union-right result) (expr-String)))

(test-case "build-union-type: deduplicates identical types"
  (check-equal? (build-union-type (list (expr-Nat) (expr-Nat)))
                (expr-Nat)))

(test-case "build-union-type: three types, right-associated"
  (define result (build-union-type (list (expr-String) (expr-Nat) (expr-Bool))))
  ;; Sort order by key: Bool < Nat < String
  (check-true (expr-union? result))
  (check-equal? (expr-union-left result) (expr-Bool))
  (check-true (expr-union? (expr-union-right result)))
  (define inner (expr-union-right result))
  (check-equal? (expr-union-left inner) (expr-Nat))
  (check-equal? (expr-union-right inner) (expr-String)))

(test-case "build-union-type: flattens nested union input"
  (define input-union (expr-union (expr-Nat) (expr-Bool)))
  (define result (build-union-type (list input-union (expr-String))))
  ;; Should flatten to {Bool, Nat, String}
  (check-true (expr-union? result))
  (check-equal? (expr-union-left result) (expr-Bool))
  (define inner (expr-union-right result))
  (check-equal? (expr-union-left inner) (expr-Nat))
  (check-equal? (expr-union-right inner) (expr-String)))

;; ========================================
;; B. AST-level infer: map-assoc widening
;; ========================================

(test-case "infer: map-assoc with matching value type -- no widening"
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
      (let* ([m (expr-map-empty (expr-Keyword) (expr-Nat))]
             [m1 (expr-map-assoc m (expr-keyword 'x) (expr-zero))])
        (define ty (tc:infer ctx-empty m1))
        (check-true (expr-Map? ty))
        (check-equal? (expr-Map-k-type ty) (expr-Keyword))
        (check-equal? (expr-Map-v-type ty) (expr-Nat))))))

(test-case "infer: map-assoc with annotated Nat value type rejects String (no auto-widening post-T-2)"
  ;; Pre-T-2 this test expected silent widening to (Nat | String). Under
  ;; Open by Design semantics, annotated value types are strict — writing
  ;; a String value into a (Map Keyword Nat) is a type error. Opt into
  ;; narrow unions via explicit annotation: (Map Keyword <Nat | String>).
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
      (let* ([m (expr-map-empty (expr-Keyword) (expr-Nat))]
             [m1 (expr-map-assoc m (expr-keyword 'x) (expr-zero))]
             [m2 (expr-map-assoc m1 (expr-keyword 'y) (expr-string "hello"))])
        (define ty (tc:infer ctx-empty m2))
        ;; Strict annotation → type error; no silent widening
        (check-true (expr-error? ty)
                    "strict annotated Nat map rejects String value (no auto-widening)")))))

(test-case "infer: map-assoc with Open value type accepts heterogeneous values"
  ;; Open-by-design: unannotated literals use expr-Open for value type.
  ;; map-assoc with ANY value type succeeds trivially (α-semantic).
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
      (let* ([m (expr-map-empty (expr-Keyword) (expr-Open))]
             [m1 (expr-map-assoc m (expr-keyword 'x) (expr-zero))]
             [m2 (expr-map-assoc m1 (expr-keyword 'y) (expr-string "hello"))])
        (define ty (tc:infer ctx-empty m2))
        (check-true (expr-Map? ty) "result should be a Map type")
        (check-equal? (expr-Map-k-type ty) (expr-Keyword))
        (check-equal? (expr-Map-v-type ty) (expr-Open)
                      "value type stays Open (no union accumulation)")))))

;; ========================================
;; C. Surface syntax: sexp mode
;; ========================================

(test-case "surface/sexp: mixed map literal infers (Map Keyword Open)"
  ;; Post-T-2: unannotated heterogeneous map literal uses Open for value type
  (define result (run "(infer {:name \"Alice\" :age zero})"))
  (define r (last-string result))
  (check-true (string-contains? r "Map") "should produce a Map type")
  (check-true (string-contains? r "Open")
              "value type should be Open (not narrow union)"))

(test-case "surface/sexp: homogeneous map literal also infers (Map Keyword Open)"
  ;; Post-T-2: unannotated literals are ALWAYS Open by design, regardless
  ;; of whether values happen to be homogeneous. Users wanting narrow
  ;; homogeneous types annotate: `def m : (Map Keyword Nat) := {...}`.
  (define result (run "(infer {:x zero :y (suc zero)})"))
  (define r (last-string result))
  (check-true (string-contains? r "Map"))
  (check-true (string-contains? r "Open")
              "unannotated map infers Open value type"))

(test-case "surface/sexp: map-get on Open-valued map returns Open"
  (define result
    (run (string-append
          "(def m {:name \"Alice\" :age zero})\n"
          "(infer (map-get m :name))")))
  (define r (last-string result))
  (check-equal? r "Open" "map-get on Open map returns Open"))

(test-case "surface/sexp: check mixed map against annotated union type (Concern B preserved)"
  ;; Sexp union syntax: <(Map Keyword <Nat | String>)> — nested angle brackets
  ;; Narrow-union annotations continue to check against literal values.
  (define result
    (run "(check {:name \"Alice\" :age zero} <(Map Keyword <Nat | String>)>)"))
  (define r (last-string result))
  (check-equal? r "OK" "narrow union annotation still checks against literal"))

(test-case "surface/sexp: map-assoc on annotated (Map K Nat) rejects String (no widening)"
  ;; Post-T-2: annotated maps are STRICT. No silent widening. Rejection is
  ;; structural. To accept heterogeneous values, use `<Nat | String>` or omit
  ;; the annotation (Open by default).
  (define result
    (run (string-append
          "(def m <(Map Keyword Nat)> {:x zero})\n"
          "(infer (map-assoc m :name \"hello\"))")))
  ;; Second result (the map-assoc) should error — not a valid type string
  (define r (last-string result))
  ;; Either an error or absence of a narrow union in output
  (check-false (and (string-contains? r "Nat") (string-contains? r "String"))
               "no auto-widening to (Nat | String)"))

(test-case "surface/sexp: map-assoc on annotated union (Map K <Nat | String>) accepts both"
  ;; Concern B preservation: narrow union annotation accepts either component.
  (define result
    (run (string-append
          "(def m <(Map Keyword <Nat | String>)> {:x zero})\n"
          "(infer (map-assoc m :name \"hello\"))")))
  (define r (last-string result))
  (check-true (and (string-contains? r "Nat") (string-contains? r "String"))
              "narrow union annotation accepts values matching any union component"))

;; ========================================
;; C2. map-get on union types (chained access)
;; ========================================

(test-case "surface/sexp: chained map-get on nested Open-valued map returns Open"
  ;; Post-T-2: nested unannotated maps → (Map K Open). Inner accesses return
  ;; Open (α — trust it might be a map). Runtime preserves actual values;
  ;; annotate for static narrow types (see next test for schema path).
  (define result
    (run (string-append
          "(def m {:name \"Alice\" :age 43 :address {:street \"Main\"}})\n"
          "(infer (map-get (map-get m :address) :street))")))
  (define r (last-string result))
  (check-equal? r "Open" "chained map-get on Open-valued map returns Open"))

(test-case "surface/sexp: chained map-get on typed nested map preserves narrow type"
  ;; Concern B path: explicit annotation preserves narrow per-key types.
  (define result
    (run (string-append
          "(def inner <(Map Keyword String)> {:street \"Main\"})\n"
          "(def m <(Map Keyword (Map Keyword String))> {:address inner})\n"
          "(infer (map-get (map-get m :address) :street))")))
  (define r (last-string result))
  (check-equal? r "String" "explicit narrow annotation preserves String through chain"))

(test-case "surface/sexp: map-get on Open value — α-semantic succeeds (runtime returns none on non-map)"
  ;; Pre-T-2 this errored statically. Under α-semantic, the static check
  ;; succeeds (trust) and runtime returns none if value is not a map.
  ;; This matches Clojure-style dynamics. Users wanting strict static
  ;; rejection annotate with concrete types.
  (define result
    (run (string-append
          "(def m {:x 1 :y 2})\n"
          "(infer (map-get (map-get m :x) :z))")))
  (define r (last-string result))
  (check-equal? r "Open" "map-get on Open succeeds trivially under α"))

(test-case "surface/sexp: map-get on Open-valued map returns Open"
  ;; When outer map is (Map K Open), all chained accesses return Open.
  (define result
    (run (string-append
          "(def inner1 <(Map Keyword Nat)> {:x zero})\n"
          "(def inner2 <(Map Keyword String)> {:y \"hello\"})\n"
          "(def m {:a inner1 :b inner2})\n"
          "(infer (map-get (map-get m :a) :z))")))
  (define r (last-string result))
  ;; outer m : (Map K Open); (map-get m :a) : Open; (map-get Open :z) : Open
  (check-equal? r "Open"
                "map-get on Open-valued outer map returns Open through chain"))

;; ========================================
;; C3. Runtime: map-get on non-Map values returns none
;; ========================================

(test-case "runtime: map-get on non-Map value returns none"
  ;; map-get on a concrete non-Map value (like Int) should return none
  ;; instead of a stuck term
  (define result
    (run (string-append
          "(def m {:name \"Alice\" :age 43 :address {:street \"Main\"}})\n"
          "(eval (map-get (map-get m :age) :street))")))
  (define r (last-string result))
  (check-true (string-contains? r "none")
              "map-get on Int should return none at runtime"))

(test-case "runtime: chained map-get on nested map evaluates correctly"
  (define result
    (run (string-append
          "(def m {:name \"Alice\" :age 43 :address {:street \"Main\"}})\n"
          "(eval (map-get (map-get m :address) :street))")))
  (define r (last-string result))
  (check-true (string-contains? r "Main")
              "chained map-get should evaluate to the nested value"))

;; ========================================
;; D. Backward compatibility
;; ========================================

(test-case "backward-compat: homogeneous Nat map via check"
  ;; Use angle-bracket syntax for check type
  (define result (run "(check {:x zero :y (suc zero)} <(Map Keyword Nat)>)"))
  (define r (last-string result))
  (check-equal? r "OK"))

(test-case "backward-compat: map-get on unannotated homogeneous map returns Open"
  ;; Post-T-2: unannotated literals are Open regardless of homogeneity.
  ;; To get narrow type "Nat" back, annotate the def: `def m : (Map K Nat) := ...`.
  (define result
    (run (string-append
          "(def m {:x zero :y (suc zero)})\n"
          "(infer (map-get m :x))")))
  (define r (last-string result))
  (check-equal? r "Open" "unannotated homogeneous map-get returns Open"))

(test-case "backward-compat: map-get on annotated (Map K Nat) returns Nat"
  ;; Annotated maps preserve precise value types.
  (define result
    (run (string-append
          "(def m <(Map Keyword Nat)> {:x zero :y (suc zero)})\n"
          "(infer (map-get m :x))")))
  (define r (last-string result))
  (check-equal? r "Nat" "annotated (Map K Nat) preserves Nat through map-get"))

;; ========================================
;; E. Namespace mode tests
;; ========================================

(test-case "ns: mixed map infers (Map Keyword Open)"
  ;; Post-T-2: unannotated heterogeneous map is Open by design (α-semantic).
  (define result
    (run-ns (string-append
             "(ns test.mixed-map :no-prelude)\n"
             "(infer {:name \"Alice\" :active true})")))
  (define r (last-string result))
  (check-true (string-contains? r "Map") "should produce a Map type")
  (check-true (string-contains? r "Open") "value type should be Open"))

(test-case "ns: map with three value types still infers Open"
  ;; Still Open regardless of value-count/heterogeneity — Open by design default.
  (define result
    (run-ns (string-append
             "(ns test.tri-map :no-prelude)\n"
             "(infer {:name \"Alice\" :age zero :active true})")))
  (define r (last-string result))
  (check-true (string-contains? r "Map"))
  (check-true (string-contains? r "Open")
              "unannotated 3-value map is Open (no enumerated union)"))
