#lang racket/base

;;;
;;; Schema-seal gate (CIU T6 F1b.4 / D22)
;;;
;;; F1b.4a — the schema→row up-shift + the row-vs-schema/selection discharge:
;;;   (1) `the Person m` on a def-bound ROW (closed or dyn) seals — per-field
;;;       CHECK-strength on knowns via record-<:-schema? (was: inference error;
;;;       no Record-vs-fvar arm existed — the F1b.4 mini-audit C8 corollary);
;;;   (2) wrong-typed row fields REJECT;
;;;   (3) the free up-shift: a schema-typed value satisfies a (Map K V)
;;;       annotation via schema->row + the existing record→Map α;
;;;   (4) field-type-satisfies? closes the PRE-EXISTING union-V gap (a row
;;;       vs (Map K <A|B>) refused although every field fit a branch);
;;;   (5) closed? consultation: open schemas accept unknown row fields,
;;;       :closed schemas reject them (mirrors the map-assoc arm);
;;;   (6) selections: field TYPES validate against the PARENT schema; extra
;;;       parent fields are ACCEPTED (a selection is a read-side VIEW over
;;;       fuller data — probe-corrected); D22's "subset" scopes the 4e
;;;       residual (what a selection seal REQUIRES), and selection identity
;;;       survives the recursion so 4e can enumerate it.
;;;
;;; F1b.4b — the constructor form generalizes: [SchemaName e] seals
;;;   non-literals TYPE-ONLY via the `the` boundary (fill/checks for
;;;   non-literals = validate's tabulation, F1b.5 — the runtime-conditional
;;;   wrap was probe-REFUTED: type-directed fill needs types, preparse has
;;;   none); the literal route keeps static defaults + :check wrapping.
;;;
;;; Missing-field residual (fill-or-error) is F1b.4e — nothing here pins
;;; width-partial acceptance as PERMANENT; those flips land with the census.
;;;

(require rackunit
         racket/list
         racket/path
         racket/file
         "test-support.rkt"
         "../driver.rkt"
         "../errors.rkt"
         "../namespace.rkt"
         "../relations.rkt"
         "../global-env.rkt"
         "../macros.rkt")

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Level-3: run a :no-prelude .prologos string through the full pipeline
;; (process-file — the route-soundness precedent: no forked-network fixture,
;; so re-routed imperative paths may speculate safely).
(define (run-file-string content)
  (define tmp (make-temporary-file "schema-seal-~a.prologos"))
  (call-with-output-file tmp
    (lambda (out) (display content out))
    #:exists 'truncate)
  (define results
    (parameterize ([current-ns-context #f]
                   [current-module-registry (hasheq)]
                   [current-lib-paths (list lib-dir)]
                   [current-relation-store (make-relation-store)]
                   [current-preparse-registry (current-preparse-registry)]
                   [current-schema-registry (hasheq)]
                   [current-selection-registry (hasheq)]
                   [current-defn-param-names (hasheq)])
      (install-module-loader!)
      (process-file (path->string tmp))))
  (delete-file tmp)
  results)

(define (last-result results) (last results))
(define (ok? r) (not (prologos-error? r)))

(define PERSON
  (string-append
   "ns t :no-prelude\n"
   "schema Person\n"
   "  :name String\n"
   "  :age Int\n"))

;; ========================================
;; 1. The 4a payoff: def-bound rows seal via `the`
;; ========================================

(test-case "def-bound DYN row seals against an open schema"
  (define results
    (run-file-string
     (string-append
      PERSON
      "def m := [map-assoc [map-assoc {} :name \"alice\"] :age 30]\n"
      "the Person m\n")))
  (check-true (ok? (last-result results))
              "the Person m on a conformant dyn row must seal (was: inference error)"))

(test-case "def-bound row with a WRONG-typed field rejects"
  (define results
    (run-file-string
     (string-append
      PERSON
      "def bad := [map-assoc [map-assoc {} :name \"bob\"] :age \"x\"]\n"
      "the Person bad\n")))
  (check-true (prologos-error? (last-result results))
              ":age String vs Int must reject through the row-vs-schema discharge"))

;; ========================================
;; 2. The free up-shift: schema-typed value where Map expected
;; ========================================

(test-case "schema-typed value satisfies a union-V Map annotation (up-shift)"
  (define results
    (run-file-string
     (string-append
      PERSON
      "def p : Person := {:name \"carol\" :age 25}\n"
      "def mv : (Map Keyword <Int | String>) := p\n")))
  (check-true (ok? (last-result results))
              "Person → (Map Keyword <Int|String>) must pass via schema->row + the α"))

(test-case "schema-typed value REJECTS a too-narrow Map annotation"
  (define results
    (run-file-string
     (string-append
      PERSON
      "def p : Person := {:name \"carol\" :age 25}\n"
      "def mv : (Map Keyword Int) := p\n")))
  (check-true (prologos-error? (last-result results))
              "String field cannot satisfy V=Int — the projection must not over-accept"))

;; ========================================
;; 3. field-type-satisfies?: the pre-existing union-V gap (no schema involved)
;; ========================================

(test-case "row satisfies a union-V Map annotation (pre-existing gap closed)"
  (define results
    (run-file-string
     (string-append
      "ns t :no-prelude\n"
      "def m := [map-assoc [map-assoc {} :name \"alice\"] :age 30]\n"
      "def mv : (Map Keyword <Int | String>) := m\n")))
  (check-true (ok? (last-result results))
              "every field fits a union branch — must pass (refused pre-4a)"))

;; ========================================
;; 4. closed? consultation in the discharge
;; ========================================

(test-case "OPEN schema accepts an unknown row field; :closed rejects it"
  (define results
    (run-file-string
     (string-append
      "ns t :no-prelude\n"
      "schema Open1\n"
      "  :a Int\n"
      "schema Locked :closed\n"
      "  :a Int\n"
      "def wide := [map-assoc [map-assoc {} :a 1] :zzz 9]\n"
      "the Open1 wide\n"
      "the Locked wide\n")))
  (define open-r (list-ref results (- (length results) 2)))
  (define closed-r (last-result results))
  (check-true (ok? open-r) "open schema + extra field must pass")
  (check-true (prologos-error? closed-r) ":closed schema + extra field must reject"))

;; ========================================
;; 5. Selections discharge against their SUBSET (D22)
;; ========================================

(test-case "selection-typed literal with an ALLOWED subset field passes"
  (define results
    (run-file-string
     (string-append
      PERSON
      "selection NameOnly from Person :requires [:name]\n"
      "def u : NameOnly := {:name \"alice\"}\n")))
  (check-true (ok? (last-result results))
              "the by-design width-partial selection idiom must keep working"))

(test-case "selection-typed literal MAY carry parent fields outside the view (read-side gating)"
  ;; A selection is a VIEW over fuller data: construction accepts any
  ;; PARENT-schema fields (types validated against the parent); reads gate to
  ;; the view (test-selection-typing pins that side). The 4e residual will
  ;; REQUIRE only the selection's subset — that is where "delegate against
  ;; their SUBSET" (D22) bites, not here.
  (define results
    (run-file-string
     (string-append
      PERSON
      "selection NameOnly from Person :requires [:name]\n"
      "def u : NameOnly := {:name \"alice\" :age 30}\n")))
  (check-true (ok? (last-result results))
              ":age is a parent field — construction accepts; the view gates reads only"))

(test-case "selection-typed literal with a WRONG-typed parent field rejects"
  (define results
    (run-file-string
     (string-append
      PERSON
      "selection NameOnly from Person :requires [:name]\n"
      "def u : NameOnly := {:name \"alice\" :age \"x\"}\n")))
  (check-true (prologos-error? (last-result results))
              "field types still validate against the parent schema"))

;; ========================================
;; 6. F1b.4b: the constructor form generalizes to non-literals
;; ========================================

(test-case "non-literal constructor [Person m] seals (was: inference error)"
  (define results
    (run-file-string
     (string-append
      PERSON
      "def m := [map-assoc [map-assoc {} :name \"alice\"] :age 30]\n"
      "[Person m]\n")))
  (check-true (ok? (last-result results))
              "[SchemaName e] generalizes: the preparse rewrite emits (the Person m)"))

(test-case "non-literal constructor with a WRONG-typed field rejects"
  (define results
    (run-file-string
     (string-append
      PERSON
      "def bad := [map-assoc [map-assoc {} :name \"bob\"] :age \"x\"]\n"
      "[Person bad]\n")))
  (check-true (prologos-error? (last-result results))
              "the seal's per-field discharge must reject through the constructor door too"))

(test-case "non-row constructor argument rejects"
  (define results
    (run-file-string
     (string-append
      PERSON
      "[Person 42]\n")))
  (check-true (prologos-error? (last-result results))
              "Int has no row to discharge — natural rejection at the ann boundary"))

(test-case "literal route unchanged: defaults still inject"
  (define results
    (run-file-string
     (string-append
      "ns t :no-prelude\n"
      "schema Config\n"
      "  :host String\n"
      "  :port Int :default 8080\n"
      "[Config {:host \"h\"}]\n")))
  (define r (last-result results))
  (check-true (ok? r) "the literal constructor route must keep static default injection")
  (check-true (regexp-match? #rx"8080" (format "~a" r))
              "the defaulted field must be materialized in the value"))

(test-case "sealed non-literal def projects through the schema"
  (define results
    (run-file-string
     (string-append
      PERSON
      "def m := [map-assoc [map-assoc {} :name \"alice\"] :age 30]\n"
      "def p := [Person m]\n"
      "p.name\n")))
  (check-true (ok? (last-result results))
              "p : Person defined via the non-literal door must project :name"))
