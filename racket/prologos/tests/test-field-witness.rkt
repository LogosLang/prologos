#lang racket/base
;; ============================================================================
;; CIU T6 F1b.5-s1 (D28) — the field-type witness: polarity table + interpreter
;; + the SKIP-SET DISCIPLINE test (the executable re-trigger for the skip
;; posture). Pure-Racket unit tests (test-subtyping.rkt convention: direct
;; requires, network-free). subtype? is consumed at bake time, so the tags'
;; primitive acceptance sets ARE the subtype closure — the polarity table is
;; test-LOCKED here BEFORE s2 writes the typing rule against it.
;; ============================================================================

(require rackunit
         (only-in "../typing-core.rkt" field-type->witness-tag schema-field-type->expr)
         "../field-witness.rkt"
         "../syntax.rkt"
         (only-in "../macros.rkt"
                  ctor-meta current-type-meta current-ctor-registry))

(define (tag-of datum) (field-type->witness-tag (schema-field-type->expr datum)))

;; ---- the polarity table: primitive acceptance sets = the subtype closure ---

(test-case "witness/prim-closure-numeric-tower"
  ;; Nat⊂Int⊂Rat and the posit/float towers — the err-polarity invariant: a
  ;; field accepts exactly its subtypes (so a Nat value in an Int field passes).
  (check-equal? (tag-of 'Nat)     '(prim Nat))
  (check-equal? (tag-of 'Int)     '(prim Nat Int))
  (check-equal? (tag-of 'Rat)     '(prim Nat Int Rat))
  (check-equal? (tag-of 'Posit8)  '(prim Posit8))
  (check-equal? (tag-of 'Posit64) '(prim Posit8 Posit16 Posit32 Posit64))
  (check-equal? (tag-of 'Float32) '(prim Float32))
  (check-equal? (tag-of 'Float64) '(prim Float32 Float64)))

(test-case "witness/prim-closure-singletons"
  ;; non-numeric primitives have no subtype edges → acceptance set = {self}
  (check-equal? (tag-of 'Bool)    '(prim Bool))
  (check-equal? (tag-of 'String)  '(prim String))
  (check-equal? (tag-of 'Char)    '(prim Char))
  (check-equal? (tag-of 'Keyword) '(prim Keyword))
  (check-equal? (tag-of 'Unit)    '(prim Unit)))

(test-case "witness/union-is-branchwise"
  ;; ⋃ of branch tags — mirrors field-type-satisfies? some-branch
  (check-equal? (field-type->witness-tag (schema-field-type->expr '($union Int String)))
                '(union (prim Nat Int) (prim String)))
  (check-equal? (field-type->witness-tag (schema-field-type->expr '($union Bool Char Nat)))
                '(union (prim Bool) (prim Char) (prim Nat))))

(test-case "witness/refined-erases-to-base"
  ;; PosInt values are base Int at runtime; refined→base edges are
  ;; one-directional, so a naive closure would be empty — erase to base.
  (check-equal? (tag-of 'PosInt) '(prim Nat Int))
  (check-equal? (tag-of 'PosRat) '(prim Nat Int Rat)))

(test-case "witness/unwitnessable-skips"
  ;; arrows, unknown/abstract heads → 'any (the D28 skip posture, err-safe)
  (check-equal? (field-type->witness-tag (schema-field-type->expr '($arrow Int Int))) 'any)
  (check-equal? (tag-of 'TotallyUnknownAbstractType) 'any))

(test-case "witness/data-type-head-ctor-route"
  ;; a CONFIRMED data type (registered ctors) → (ctor Name); the tier-2 HEAD
  ;; route. Element args are NOT recursed (deferred to the walker charter).
  (parameterize ([current-type-meta (hasheq 'Color '(red green)
                                             'Option '(none some))])
    (check-equal? (tag-of 'Color) '(ctor Color))
    ;; applied container head: (Option Int) → head-only (ctor Option)
    (check-equal? (field-type->witness-tag (schema-field-type->expr '(Option Int)))
                  '(ctor Option))))

;; ---- the interpreter (runtime, value × tag → Bool) -------------------------

(test-case "witness/interp-prim-subsumption"
  ;; a Nat value witnesses an Int field's tag (the whole point of the closure)
  (check-true  (value-witnesses-tag? (expr-nat-val 3) '(prim Nat Int)))
  (check-true  (value-witnesses-tag? (expr-zero)      '(prim Nat Int)))
  (check-true  (value-witnesses-tag? (expr-int 5)     '(prim Nat Int)))
  ;; an Int value does NOT witness a Nat-only field (Int ⊄ Nat) — genuine reject
  (check-false (value-witnesses-tag? (expr-int 5)     '(prim Nat)))
  ;; a String value does NOT witness a numeric field
  (check-false (value-witnesses-tag? (expr-string "x") '(prim Nat Int))))

(test-case "witness/interp-any-and-union"
  (check-true (value-witnesses-tag? (expr-string "x") 'any))
  (check-true (value-witnesses-tag? (expr-lam 'x #f (expr-int 1)) 'any))
  ;; union: accept if any branch accepts
  (check-true  (value-witnesses-tag? (expr-string "x") '(union (prim Nat Int) (prim String))))
  (check-true  (value-witnesses-tag? (expr-int 3)      '(union (prim Nat Int) (prim String))))
  (check-false (value-witnesses-tag? (expr-true)       '(union (prim Nat Int) (prim String)))))

(test-case "witness/interp-ctor-route"
  (parameterize ([current-ctor-registry (hasheq 'red   (ctor-meta 'Color '() '() #f 0)
                                                 'green (ctor-meta 'Color '() '() #f 1))])
    (check-true  (value-witnesses-tag? (expr-fvar 'red) '(ctor Color)))
    ;; FQN ctor head normalizes via short-name
    (check-true  (value-witnesses-tag? (expr-fvar 'my::ns::green) '(ctor Color)))
    (check-false (value-witnesses-tag? (expr-fvar 'red) '(ctor Option)))
    ;; a non-ctor value against a ctor tag → reject (genuine mismatch)
    (check-false (value-witnesses-tag? (expr-int 3) '(ctor Color)))))

;; ---- the SKIP-SET DISCIPLINE (the D28 executable re-trigger) ----------------
;; NOT "zero skips globally" (arrows legitimately skip) — the RIGHT shapes must
;; skip and the right shapes must NOT. Fires if a witnessable shape regresses to
;; 'any (a coverage loss) or an unwitnessable shape stops skipping. Corpus
;; extension (a newly-expressible shape) is a documented obligation, not
;; auto-detected (there is no field-type grammar-reflection surface).

(define SHOULD-WITNESS-DATUMS
  ;; every expressible field-type shape we CLAIM to check must produce a
  ;; non-skip tag
  '(Nat Int Rat Bool String Char Keyword Symbol Unit
    Posit8 Posit64 Float32 Float64
    PosInt PosRat
    ($union Int String) ($union Bool Nat Char)
    (List Int) (Map Keyword String)))

(define SHOULD-SKIP-DATUMS
  ;; unwitnessable shapes must skip honestly
  '(($arrow Int Int) ($arrow String Bool)
    TotallyUnknownAbstractType SomeTypeVar))

(test-case "witness/skip-discipline-witnessable-never-skip"
  ;; (List Int)/(Map …) need registered container ctors to route via (ctor …);
  ;; register them so they count as witnessable-head, not skip.
  (parameterize ([current-type-meta (hasheq 'List '(nil cons) 'Map '(map-lit))])
    (for ([d (in-list SHOULD-WITNESS-DATUMS)])
      (define tag (tag-of d))
      (check-true (witness-tag-well-formed? tag) (format "~a → malformed tag ~a" d tag))
      (check-false (witness-tag-skip? tag)
                   (format "~a REGRESSED to a skip tag ~a (D28 re-trigger)" d tag)))))

(test-case "witness/skip-discipline-unwitnessable-skip"
  (for ([d (in-list SHOULD-SKIP-DATUMS)])
    (define tag (tag-of d))
    (check-true (witness-tag-well-formed? tag) (format "~a → malformed tag ~a" d tag))
    (check-true (witness-tag-skip? tag)
                (format "~a should skip (unwitnessable) but produced ~a" d tag))))

(test-case "witness/tag-assignment-is-total"
  ;; totality: never errors, always well-formed — over both corpora + edge shapes
  (for ([d (in-list (append SHOULD-WITNESS-DATUMS SHOULD-SKIP-DATUMS
                            '(Nil Posit16 Posit32)))])
    (check-true (witness-tag-well-formed? (tag-of d))
                (format "~a produced a non-well-formed tag" d))))
