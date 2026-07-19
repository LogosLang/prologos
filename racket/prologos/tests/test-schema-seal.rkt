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

;; ========================================
;; 7. F1b.4c: :check minimal-repair — panic exemption + seal-scoped def-forcing
;; ========================================

(define CHECKED
  (string-append
   "ns t :no-prelude\n"
   ;; F1b.5-s3 (D29): a :check-schema ctor door delegates :check to validate,
   ;; which needs result + reason in scope in a :no-prelude file.
   "require [prologos::data::result :refer [Result ok err ok? err?]]\n"
   "require [prologos::data::reason :refer [Reason missing-required check-failed type-mismatch unexpected-field]]\n"
   "schema Person\n"
   "  :name String\n"
   "  :age Int :check (> _ 0)\n"))

(test-case "violating :check def errors AT COMMIT (was: silent 'defined.')"
  (define results
    (run-file-string
     (string-append
      CHECKED
      "def bad := [Person {:name \"dave\" :age 0}]\n")))
  (check-true (prologos-error? (last-result results))
              "seal-scoped def-forcing: tabulation forces; the panic converts at the def boundary")
  (check-true (regexp-match? #rx"panic" (prologos-error-message (last-result results)))
              "the error must carry the :check panic message"))

(test-case "violating :check ANNOTATED def errors at commit too"
  (define results
    (run-file-string
     (string-append
      CHECKED
      "def bad2 : Person := [Person {:name \"gil\" :age 0}]\n")))
  (check-true (prologos-error? (last-result results))
              "both def commit paths force seal bodies"))

(test-case "passing :check def commits and projects"
  (define results
    (run-file-string
     (string-append
      CHECKED
      "def good := [Person {:name \"fred\" :age 5}]\n"
      "good.age\n")))
  (check-true (ok? (last-result results)) "a satisfying seal defines and projects"))

(test-case "projection over a violating seal does NOT swallow to none (panic exemption)"
  (define results
    (run-file-string
     (string-append
      CHECKED
      "[map-get [Person {:name \"eve\" :age 0}] :name]\n")))
  (define r (last-result results))
  (define shown (format "~a" r))
  (check-false (regexp-match? #rx"^none" shown)
               "pre-4c this displayed `none : String` — the swallow class (PROBES §P4)")
  (check-true (regexp-match? #rx"panic" shown)
              "the stuck panic must remain visible in the projection result"))

(test-case "non-seal def bodies stay LAZY (forcing is shape-gated)"
  ;; A panic INSIDE a lambda body (checkable — panic inhabits any type in
  ;; check mode) defines silently: the body is not seal-shaped, so the 4c
  ;; forcing never fires and the panic waits for application, as ever.
  ;; (A BARE panic body was never definable — infer can't synthesize it.)
  (define results
    (run-file-string
     (string-append
      "ns t :no-prelude\n"
      "def d : <Int -> String> := [fn [x : Int] [panic \"boom\"]]\n")))
  (check-true (ok? (last-result results))
              "a panic-bearing lambda def still defines silently — laziness untouched outside seals"))

;; ========================================
;; 8. F1b.4e: the fill-or-error flip (D22.3) — the residual is live
;; ========================================

(define DEFAULTED
  (string-append
   "ns t :no-prelude\n"
   "schema Config\n"
   "  :host String :default \"localhost\"\n"
   "  :port Int :default 8080\n"))

(test-case "THE aspirational payoff: def c : Config := {} fills all defaults"
  ;; punify-p3-acceptance :264 has wanted this since March (commented out).
  (define results
    (run-file-string
     (string-append
      DEFAULTED
      "def c : Config := {}\n"
      "c.host\n")))
  (define r (last-result results))
  (check-true (ok? r) "an empty literal against an all-defaulted schema seals")
  (check-true (regexp-match? #rx"localhost" (format "~a" r))
              "the default must be MATERIALIZED in the runtime value (preparse fill)"))

(test-case "missing-REQUIRED on the annotation route ERRORS with the named field"
  (define results
    (run-file-string
     (string-append
      PERSON
      "def p : Person := {:age 30}\n")))
  (define r (last-result results))
  (check-true (prologos-error? r) "the D22.3 flip: silent width-partial acceptance is dead")
  (check-true (regexp-match? #rx"missing required field :name" (prologos-error-message r))
              "the residual hint names the missing field"))

(test-case "annotation-route missing-DEFAULTED field fills"
  (define results
    (run-file-string
     (string-append
      "ns t :no-prelude\n"
      "schema P2\n"
      "  :name String\n"
      "  :age Int :default 30\n"
      "def p2 : P2 := {:name \"carol\"}\n"
      "p2.age\n")))
  (define r (last-result results))
  (check-true (ok? r))
  (check-true (regexp-match? #rx"30" (format "~a" r)) "the default fills on the def route"))

(test-case "the-route literal fills too"
  (define results
    (run-file-string
     (string-append
      DEFAULTED
      "[the Config {:port 9090}].host\n")))
  (check-true (regexp-match? #rx"localhost" (format "~a" (last-result results)))
              "direct `the Schema {…}` gets defaults (was: bypass, P5(d))"))

(test-case "dyn-row non-literal: missing-required ABSORBED (gradual, D16 posture)"
  (define results
    (run-file-string
     (string-append
      PERSON
      "def m := [map-assoc {} :name \"dave\"]\n"
      "the Person m\n")))
  (check-true (ok? (last-result results))
              "a dyn row's remainder may provide :age at runtime — the tail absorbs"))

(test-case "closed-row non-literal: missing-required ERRORS"
  (define results
    (run-file-string
     (string-append
      PERSON
      "def cr := {:age 5}\n"
      "the Person cr\n")))
  (check-true (prologos-error? (last-result results))
              "a closed row DEFINITELY lacks :name — exact knowledge, hard error"))

(test-case ":closed schema REFUSES a dyn-row actual (the closedness scan)"
  (define results
    (run-file-string
     (string-append
      "ns t :no-prelude\n"
      "schema Locked :closed\n"
      "  :a Int\n"
      "def d := [map-assoc {} :a 1]\n"
      "the Locked d\n")))
  (check-true (prologos-error? (last-result results))
              "cannot verify the ABSENCE of extras on an open remainder"))

(test-case "selections stay CONSTRUCTION-PARTIAL: an empty selection-typed def passes"
  ;; Empirically decisive during 4e (test-selection-paths nameaddr-name-gated):
  ;; `:requires` is a READ-CAPABILITY declaration, not a value-completeness
  ;; contract — selection-typed values are partial VIEWS by design, and
  ;; completeness is the PARENT schema seal's business. The selection residual
  ;; is closedness-only.
  (define results
    (run-file-string
     (string-append
      PERSON
      "selection NameOnly from Person :requires [:name]\n"
      "def u : NameOnly := {}\n")))
  (check-true (ok? (last-result results))
              "no completeness residual on selection construction (partial views)"))

(test-case "empty literal vs a schema with a REQUIRED field errors (map-empty base retired)"
  (define results
    (run-file-string
     (string-append
      PERSON
      "def p : Person := {}\n")))
  (check-true (prologos-error? (last-result results))
              "the blanket-#t recursion base is gone — this WAS the width-partial hole"))

(test-case "F1b.7e: bare map-ops on a schema value up-shift to its row (were inference-failed)"
  ;; map-keys/assoc/dissoc/etc on a schema-typed value project the schema to its
  ;; row (schema->row) and behave like the anon row — ROW results (map-assoc
  ;; grows a row, not Person). Pre-7e these fell through to inference-failed.
  (define results
    (run-file-string
     (string-append
      PERSON
      "def p : Person := {:name \"alice\" :age 30}\n"
      "[map-keys p]\n"
      "[map-vals p]\n"
      "[map-assoc p :age 31]\n"
      "[map-dissoc p :age]\n"
      "[map-has-key? p :name]\n")))
  (define last5 (list-tail results (- (length results) 5)))
  (check-true (andmap ok? last5)
              "map-keys/vals/assoc/dissoc/has-key? on a schema value succeed (project to the row)"))

(test-case "F1b.7g: ?/!-suffixed keyword keys read whole (schema fields + map keys)"
  ;; recognize-keyword now delegates to ident-continue? (was an inline charset
  ;; omitting ?/!), so :active?/:reset! read as ONE keyword — the predicate /
  ;; mutation naming conventions work as field names AND map keys. Pre-7g the
  ;; schema `:active? Int` errored ("expected a keyword field name") and a map
  ;; `{:ok? 7 :n 8}` errored (odd element count from the stray split `?`).
  (define results
    (run-file-string
     (string-append
      "ns t :no-prelude\n"
      "schema S\n"
      "  :active? Int\n"
      "  :reset! Int\n"
      "def s : S := {:active? 1 :reset! 2}\n"
      "s.active?\n"
      "s.reset!\n"
      "def m := {:ok? 7 :n 8}\n"
      "m.ok?\n")))
  (check-true (andmap ok? results)
              "?/!-suffixed keyword field names + map keys parse whole and project"))

(define (err-msg r) (and (prologos-error? r) (prologos-error-message r)))

(test-case "F1b.7f: targeted schema-mistake diagnostics (was generic 'Could not infer type')"
  (define P2
    (string-append
     "ns t :no-prelude\n"
     "schema Person\n  :name String\n  :age Int\n"
     "schema Employee\n  :id Int\n  :dept String\n"))
  ;; (a) wrong-typed field — infer/`the` door (constructor)
  (define ra (last-result (run-file-string (string-append P2 "def pa := [Person {:name \"a\" :age \"x\"}]\n"))))
  (check-true (and (regexp-match? #rx"Could not infer" (or (err-msg ra) ""))
                   (regexp-match? #rx"field :age expected Int" (or (err-msg ra) "")))
              "wrong-typed field: prefix preserved + names :age + expected type (infer door)")
  ;; (a) wrong-typed field — CHECK / annotation door (Q3 parity)
  (define rc (last-result (run-file-string (string-append P2 "def pc : Person := {:name \"a\" :age \"x\"}\n"))))
  (check-true (regexp-match? #rx"field :age expected Int" (or (err-msg rc) ""))
              "wrong-typed field names :age on the annotation door too (Q3 shared helper)")
  ;; (c) cross-schema `the`
  (define rx (last-result (run-file-string (string-append P2 "def q : Person := {:name \"a\" :age 1}\nthe Employee q\n"))))
  (check-true (regexp-match? #rx"does not satisfy schema" (or (err-msg rx) ""))
              "cross-schema `the` names the schema mismatch")
  ;; (b) schema value into a Map-typed parameter (narrowly-scoped app-domain)
  (define rb (last-result (run-file-string
                           (string-append P2 "def q : Person := {:name \"a\" :age 1}\n"
                                          "spec getage (Map Keyword Int) -> Int\n"
                                          "defn getage [m] [map-get m :age]\n[getage q]\n"))))
  (check-true (regexp-match? #rx"expected parameter type" (or (err-msg rb) ""))
              "schema value into a Map param names the parameter type")
  ;; (d) validate on a non-map subject
  (define rd (last-result (run-file-string
                           (string-append
                            "ns t :no-prelude\n"
                            "require [prologos::data::result :refer [Result ok err ok? err?]]\n"
                            "require [prologos::data::reason :refer [Reason missing-required check-failed type-mismatch unexpected-field errors-to-list]]\n"
                            "schema Person\n  :name String\n  :age Int\n"
                            "[validate Person 42]\n"))))
  (check-true (regexp-match? #rx"validate expects a map-like subject" (or (err-msg rd) ""))
              "validate on a non-map subject names the expectation"))

(test-case "F1b.7d: non-literal ctor door materializes :default (option A; was dropped → <error>)"
  ;; [Cfg m] on a :default-bearing (no-:check) schema now routes through validate
  ;; (wrap-seal-validate #:also-defaults? #t) so the default fills — was bare
  ;; (the Cfg m) type-only → b.port projected the <error> sentinel.
  (define CFG
    (string-append
     "ns t :no-prelude\n"
     "require [prologos::data::result :refer [Result ok err ok? err?]]\n"
     "require [prologos::data::reason :refer [Reason missing-required check-failed type-mismatch unexpected-field errors-to-list]]\n"
     "schema Cfg\n  :host String\n  :port Int :default 8080\n"))
  ;; the fill (the 7d payoff)
  (define bport (last-result (run-file-string
                              (string-append CFG "def m := [map-assoc {} :host \"h\"]\n"
                                             "def b := [Cfg m]\nb.port\n"))))
  (check-true (and (string? bport) (regexp-match? #rx"8080" bport))
              (format "[Cfg m].port materializes the default 8080; got: ~v" bport))
  (check-false (and (string? bport) (regexp-match? #rx"<error>" bport))
               "the default is filled, not the <error> sentinel")
  ;; the orthogonal strengthening (option A, consistent with the s3 :check door):
  ;; a DYN subject missing a required NON-defaulted field errors at commit.
  (define rs (last-result (run-file-string
                           (string-append
                            "ns t :no-prelude\n"
                            "require [prologos::data::result :refer [Result ok err ok? err?]]\n"
                            "require [prologos::data::reason :refer [Reason missing-required check-failed type-mismatch unexpected-field errors-to-list]]\n"
                            "schema DCfg\n  :name String\n  :port Int :default 80\n"
                            "def dyn := [map-assoc {} :port 9]\n"
                            "def bad := [DCfg dyn]\n"))))
  (check-true (prologos-error? rs)
              "dyn subject missing a required non-defaulted field errors at commit (the A strengthening)"))

(test-case "F1b.7c: `def x : S :=` COMMITMENT door discharges :check + non-literal :default; `the` stays a view"
  (define P7C
    (string-append
     "ns t :no-prelude\n"
     "require [prologos::data::result :refer [Result ok err ok? err?]]\n"
     "require [prologos::data::reason :refer [Reason missing-required check-failed type-mismatch unexpected-field errors-to-list]]\n"
     "schema Checked\n  :name String\n  :age Int :check (> _ 0)\n"))
  ;; (a) LITERAL def-annotation on a :check-violating value ERRORS at commit (was silent)
  (check-true (prologos-error?
               (last-result (run-file-string
                             (string-append P7C "def c : Checked := {:name \"d\" :age 0}\n"))))
              "def c : Checked := {…:age 0} errors at commit (the 7c gap closed)")
  ;; (b) NON-LITERAL (def-bound symbol) on a violating value ERRORS at commit
  (check-true (prologos-error?
               (last-result (run-file-string
                             (string-append P7C
                                            "def m := [map-assoc [map-assoc {} :name \"e\"] :age 0]\n"
                                            "def c : Checked := m\n"))))
              "def c : Checked := m (violating) errors at commit")
  ;; (c) a satisfying :check def commits and its field reads back
  (define cage (last-result (run-file-string
                             (string-append P7C "def c : Checked := {:name \"f\" :age 5}\nc.age\n"))))
  (check-true (and (string? cage) (regexp-match? #rx"5" cage))
              (format "a satisfying :check def commits and reads; got: ~v" cage))
  ;; (d) NON-LITERAL def-annotation :default fill (the pre-7d annotation-door drop, closed)
  (define chost (last-result (run-file-string
                              (string-append
                               "ns t :no-prelude\n"
                               "require [prologos::data::result :refer [Result ok err ok? err?]]\n"
                               "require [prologos::data::reason :refer [Reason missing-required check-failed type-mismatch unexpected-field errors-to-list]]\n"
                               "schema Cfg\n  :host String :default \"localhost\"\n"
                               "def m := {}\ndef c : Cfg := m\nc.host\n"))))
  (check-true (and (string? chost) (regexp-match? #rx"localhost" chost))
              (format "def c : Cfg := m fills the :default (annotation-door drop closed); got: ~v" chost))
  ;; (e) `the S {violating}` STAYS a gradual view — Q3: no :check discharge, no error
  (check-false (prologos-error?
                (last-result (run-file-string
                              (string-append P7C "the Checked {:name \"g\" :age 0}\n"))))
               "the Checked {…:age 0} stays a view (no :check discharge) — Q3")
  ;; (f) ctor-RHS `def x : S := [S {…}]` still SELF-DISCHARGES (not double-wrapped)
  (check-true (prologos-error?
               (last-result (run-file-string
                             (string-append P7C "def c : Checked := [Checked {:name \"h\" :age 0}]\n"))))
              "def c : Checked := [Checked {…:age 0}] errors via the ctor RHS (no double-wrap)"))
