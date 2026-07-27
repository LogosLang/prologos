#lang racket/base

;;;
;;; Rel Track 1 — Aspect B (typed solution rows), B1.
;;;
;;; solve/solve-with/solve-one/explain/explain-with over a SCHEMA'D goal-app now
;;; carry a typed per-solution ROW instead of a bare hole:
;;;   - keys  = query-var names Κ′ (Prolog-parity; from B0's classify-goal-args)
;;;   - types = the relation schema's field types α (positional bridge)
;;;   - wrap  = List<row> (solve/solve-with/explain*), bare row (solve-one)
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
         "../relations.rkt")

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Run a .prologos string through the full pipeline (Level 3); return result strings.
(define (run-prologos-string content)
  (define tmp (make-temporary-file "rel-t1-rows-~a.prologos"))
  (call-with-output-file tmp
    (lambda (out) (display content out))
    #:exists 'truncate)
  (define results
    (parameterize ([current-ns-context #f]
                   [current-module-registry (hasheq)]
                   [current-lib-paths (list lib-dir)]
                   [current-relation-store (make-relation-store)])
      (install-module-loader!)
      (process-file (path->string tmp))))
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
;; B1 — solve over a schema'd relation → List<row> (query-var keys, schema types)
;; ========================================

(test-case "B1: solve → List of a row keyed by query-vars, typed by the schema"
  (define r (last-result
             (run-prologos-string
              (string-append edge-world "solve (edge f t w)\n"))))
  (check-true (string-contains? r "List") "solve result is List-wrapped")
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
  (check-false (string-contains? r "Option") "solve-one is unwrapped (D25.4), not Option"))

(test-case "B1: partially-ground goal → only the FREE positions become typed fields"
  (define r (last-result
             (run-prologos-string
              (string-append edge-world "solve (edge \"a\" t w)\n"))))
  (check-true (string-contains? r ":t String"))
  (check-true (string-contains? r ":w Int"))
  ;; :f is ground ("a"), so it is NOT a solution key
  (check-false (string-contains? r ":f") "ground position f is not a solution field"))

(test-case "B1: explain → List row with a 'dyn tail (open) for reserved metadata keys"
  (define r (last-result
             (run-prologos-string
              (string-append edge-world "explain (edge f t w)\n"))))
  (check-true (string-contains? r "List"))
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
  (check-true (string-contains? r "List"))
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

(test-case "B2: RULE-bearing un-schema'd relation stays loose (unsound to observe; → C.1/runtime)"
  (define r (last-result
             (run-prologos-string
              (string-append
               plain-facts-world
               "defr ruler [?a ?b]\n  &> (edge a b _)\n\n"
               "solve (ruler s d)\n"))))
  (check-true (string-contains? r ": _")
              "a rule-bearing relation is NOT statically observed (its rows exceed the facts)"))
