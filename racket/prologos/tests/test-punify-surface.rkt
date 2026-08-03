#lang racket/base

;;; test-punify-surface.rkt — the PUnify surface gaps that are no longer gaps.
;;;
;;; DEFERRED's "Relational/Unification — PUnify Surface Gaps" listed seven
;;; items, all sourced from an acceptance file's section notes. Re-probed
;;; 2026-08-02: FIVE no longer describe the compiler.
;;;
;;; They are pinned here for the reason the nested-constructor-pattern case
;;; taught: a DEFERRED entry saying "X is broken" suppresses the test that
;;; would catch X regressing. Five entries meant five behaviours nobody was
;;; guarding.
;;;
;;; One of the five (parameterized types in data constructor arguments) was
;;; never a compiler limitation at all — the entry's example
;;; `data Box A := box [List A]` is not Prologos syntax, so it was a syntax
;;; error filed as a type-system gap.

(require rackunit
         racket/string
         "test-support.rkt"
         "../errors.rkt")

(define edge "defr edge [?a ?b]\n  || 1 2\n")

(test-case "punify/a module-path call works inside an `is` goal"
  ;; Entry: "`str::concat` unbound inside `defr` clause bodies in `is` goals —
  ;; `::` lookup doesn't resolve in relational elaboration context."
  (define r (run-ns-ws-last
             (string-append "ns pu\n" edge
                            "defr cat [?x ?s]\n  &> (edge x z) (is s [str::append \"a\" \"b\"])\n"
                            "solve (cat x s)\n")))
  (check-false (prologos-error? r) (format "got: ~v" r))
  (check-true (string-contains? (format "~a" r) "\"ab\"") (format "got: ~v" r)))

(test-case "punify/a prelude constructor works in an `=` goal"
  ;; Entry: "Prelude constructors (some/none) in `=` goals inside `defr` fail."
  (define r (run-ns-ws-last
             (string-append "ns pu2\n" edge
                            "defr opt [?x ?o]\n  &> (edge x z) (= o [some 1])\n"
                            "solve (opt x o)\n")))
  (check-false (prologos-error? r) (format "got: ~v" r))
  (check-true (string-contains? (format "~a" r) "some") (format "got: ~v" r)))

(test-case "punify/solve-one in a defn body infers its row type"
  ;; Entry: "`solve-one` in `defn` body returns `_` type; `solve` works in same
  ;; position." Both work, and both give a row type.
  (define r (run-ns-ws-last
             (string-append "ns pu3\n" edge
                            "defn one-sol [u]\n  solve-one (edge a b)\n"
                            "one-sol unit\n")))
  (check-false (prologos-error? r) (format "got: ~v" r))
  (define text (format "~a" r))
  (check-true (string-contains? text ":a 1") (format "got: ~v" r))
  (check-true (string-contains? text ":a Int") (format "the row type is not derived: ~v" r)))

(test-case "punify/a parameterized type works as a data constructor argument"
  ;; Entry: "`data Box A := box [List A]` fails with not-a-type-error."
  ;; That is not Prologos syntax — a syntax error filed as a type-system gap.
  ;; Written correctly it works, and the constructor gets its Pi type.
  (define r (run-ns-ws-last
             (string-append "ns pu4\n"
                            "data Box {A : Type}\n  | box [List A]\n"
                            "def b := box '[1 2 3]\nb\n")))
  (check-false (prologos-error? r) (format "got: ~v" r))
  (check-true (string-contains? (format "~a" r) "Box Int") (format "got: ~v" r)))

(test-case "punify/eq? is callable from prelude scope"
  ;; Entry: "`Eq` trait's `eq?` not directly callable from prelude. Workaround:
  ;; concrete equality functions (`int-eq`, `str-eq`)."
  (check-true (string-contains? (format "~a" (run-ns-ws-last "ns pu5\n[eq? 1 1]\n")) "true"))
  (check-true (string-contains? (format "~a" (run-ns-ws-last "ns pu6\n[eq? \"a\" \"a\"]\n")) "true")))
