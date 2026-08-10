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
  ;; a CONFIRMED data type (registered ctors). The HEAD check is what this arm
  ;; has always done; since 2026-08-03 it also carries the per-constructor,
  ;; per-field tags (tier-2 element recursion) when they can be computed.
  (parameterize ([current-type-meta (hasheq 'Color '(red green)
                                             'Option '(none some))])
    ;; `Color`'s ctors have no registered ctor-meta here (this fixture sets
    ;; type-meta only), so `data-witness-tag` DECLINES and the old tag stands.
    ;; That fallback is the safety story — where the refinement cannot be
    ;; computed, behaviour is unchanged rather than guessed.
    (check-equal? (tag-of 'Color) '(ctor Color))
    ;; `Option`'s ctors ARE registered (the prelude), so the applied form
    ;; refines: `(Option Int)` now knows `some`'s field is an Int.
    ;; This assertion USED to read '(ctor Option) — the pin on the old,
    ;; element-blind behaviour, which is exactly what item 2 set out to change.
    (check-equal? (field-type->witness-tag (schema-field-type->expr '(Option Int)))
                  '(data Option 1 (none) (some (prim Nat Int))))))

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

;; ============================================================================
;; SUB-SCHEMA / nested-row descent (the deep-walker charter's item 3, 2026-08-03)
;;
;; Before this, a field typed by another schema fell to the 'any skip, so
;; `[validate Config bad]` returned `ok` on data whose nested field held the
;; wrong type — while the STATIC seal caught the identical mistake in a
;; literal. The asymmetry ran the wrong way round for the demo's headline flow
;; (external data → validate → Result).
;; ============================================================================

(require (only-in "../macros.rkt" register-schema! schema-entry schema-field)
         (only-in "../champ.rkt" champ-empty champ-insert))

(define (mk-champ . kvs)
  (let loop ([kvs kvs] [c champ-empty])
    (if (null? kvs)
        (expr-champ c)
        (let ([k (expr-keyword (car kvs))])
          (loop (cddr kvs)
                (champ-insert c (equal-hash-code k) k (cadr kvs)))))))

(test-case "witness/row-tag from a NAMED sub-schema"
  (register-schema! 'WInner
                    (schema-entry 'WInner (list (schema-field 'c 'Int #f #f)) #f #f))
  (check-equal? (tag-of 'WInner) '(row (c prim Nat Int))
                "a schema NAME must tag as a row, not skip to 'any")
  (check-false (witness-tag-skip? (tag-of 'WInner))
               "a row with a witnessable field is witnessable")
  (check-true (witness-tag-well-formed? (tag-of 'WInner))))

(test-case "witness/row descends into a nested value"
  (register-schema! 'WInner2
                    (schema-entry 'WInner2 (list (schema-field 'c 'Int #f #f)) #f #f))
  (define tag (tag-of 'WInner2))
  (check-true  (value-witnesses-tag? (mk-champ 'c (expr-int 1)) tag)  "a good inner value passes")
  (check-false (value-witnesses-tag? (mk-champ 'c (expr-string "z")) tag)
               "THE BUG: a String in an Int slot used to pass"))

(test-case "witness/row ACCEPTS on the two deliberate uncertainties"
  ;; Both are err-polarity, not oversight, and each has a different owner.
  (register-schema! 'WInner3
                    (schema-entry 'WInner3 (list (schema-field 'c 'Int #f #f)) #f #f))
  (define tag (tag-of 'WInner3))
  (check-true (value-witnesses-tag? (mk-champ) tag)
              "a MISSING key is the plan's business (it has required?), not the witness's")
  (check-true (value-witnesses-tag? (expr-int 5) tag)
              "a non-map value: the witness must not assert a type error it cannot substantiate"))

(test-case "witness/a RECURSIVE schema terminates by degrading to 'any"
  ;; The seen-set is not speculative: a schema field's type is a bare name
  ;; resolved through the same registry, so this shape is expressible TODAY.
  ;; Verified by removing the guard — the probe hung rather than erroring.
  (register-schema! 'WNode
                    (schema-entry 'WNode
                                  (list (schema-field 'label 'String #f #f)
                                        (schema-field 'next 'WNode #f #f))
                                  #f #f))
  (define tag (tag-of 'WNode))
  (check-equal? tag '(row (label prim String) (next . any))
                "the cycle degrades to 'any — accept, never loop or false-reject")
  (check-true (witness-tag-well-formed? tag))
  ;; and the non-recursive field still witnesses through it
  (check-false (value-witnesses-tag? (mk-champ 'label (expr-int 1)) tag)))

(test-case "witness/got-string names the failing path, not just \"Map\""
  ;; `type-mismatch \"Server\" \"Map\"` is true and useless — the value IS a map;
  ;; which of its fields is wrong is the whole question.
  (register-schema! 'WDeepIn
                    (schema-entry 'WDeepIn (list (schema-field 'c 'Int #f #f)) #f #f))
  (register-schema! 'WDeepOut
                    (schema-entry 'WDeepOut (list (schema-field 'b 'WDeepIn #f #f)) #f #f))
  (define tag (tag-of 'WDeepOut))
  (check-equal? (witness-got-string
                 (mk-champ 'b (mk-champ 'c (expr-string "z"))) tag)
                "Map (:b.:c is String)")
  ;; a non-row tag is untouched — this must not change any existing payload
  (check-equal? (witness-got-string (expr-string "z") (tag-of 'Int)) "String"))

;; ============================================================================
;; TIER-2 ELEMENT RECURSION (the deep-walker charter's item 2, 2026-08-03)
;;
;; `(ctor Name)` asserted only that the value's constructor belonged to the
;; type — nothing about its ARGUMENTS. So a `(List String)` field accepted
;; `[cons 1 nil]` and an `(Option Int)` field accepted `[some "z"]`.
;; ============================================================================

(define (mk-some ty v)
  (expr-app (expr-app (expr-fvar 'prologos::data::option::some) ty) v))
(define (mk-nil ty) (expr-app (expr-fvar 'prologos::data::list::nil) ty))
(define (mk-cons ty h t)
  (expr-app (expr-app (expr-app (expr-fvar 'prologos::data::list::cons) ty) h) t))

(test-case "witness/data tag knows the ELEMENT type"
  (define t (field-type->witness-tag (schema-field-type->expr '(Option Int))))
  (check-equal? t '(data Option 1 (none) (some (prim Nat Int))))
  (check-true  (value-witnesses-tag? (mk-some (expr-Int) (expr-int 1)) t))
  (check-false (value-witnesses-tag? (mk-some (expr-Int) (expr-string "z")) t)
               "THE BUG: [some \"z\"] used to satisfy an (Option Int) field"))

(test-case "witness/`self` makes a list check EVERY element, not just the head"
  ;; The load-bearing case, and the reason `self` exists at all: an
  ;; implementation that only checked the head passes a bad element at
  ;; position 0 and fails at position 2. (Same shape as the vindex
  ;; position-2 lesson — a rule that fires once is not a rule that recurses.)
  (define t (field-type->witness-tag (schema-field-type->expr '(List String))))
  (define (lst . vs)
    (foldr (lambda (v acc) (mk-cons (expr-String) v acc)) (mk-nil (expr-String)) vs))
  (check-true (value-witnesses-tag?
               (lst (expr-string "a") (expr-string "b") (expr-string "c")) t))
  (check-false (value-witnesses-tag?
                (lst (expr-int 1) (expr-string "b") (expr-string "c")) t)
               "bad element at position 0")
  (check-false (value-witnesses-tag?
                (lst (expr-string "a") (expr-string "b") (expr-int 1)) t)
               "bad element at POSITION 2 — this is the one `self` is for")
  (check-true (value-witnesses-tag? (mk-nil (expr-String)) t) "the empty list passes"))

(test-case "witness/data ACCEPTS on arity uncertainty, rejects only a real miss"
  (define t (field-type->witness-tag (schema-field-type->expr '(Option Int))))
  ;; a PARTIAL application: the args do not line up with the field tags, so no
  ;; comparison is meaningful and the witness must not invent one.
  (check-true (value-witnesses-tag? (expr-app (expr-fvar 'prologos::data::option::some)
                                              (expr-Int))
                                    t)
              "a partially-applied ctor must accept, not reject")
  ;; the HEAD check is unchanged from (ctor …): a value of a different type
  ;; still rejects, exactly as before.
  (check-false (value-witnesses-tag? (expr-int 1) t)))

(test-case "witness/data DECLINES to a (ctor …) tag when it cannot compute"
  ;; No ctor-meta registered for these names, so the refinement is not
  ;; computable and the pre-existing tag must stand — unchanged behaviour is
  ;; the fallback, never a guess.
  (parameterize ([current-type-meta (hasheq 'MysteryT '(mystery-a mystery-b))])
    (check-equal? (tag-of 'MysteryT) '(ctor MysteryT))))

(test-case "witness/data got-string composes through both levels"
  (define t (field-type->witness-tag
             (schema-field-type->expr '(List (Option Int)))))
  (define bad (mk-cons (expr-Int) (mk-some (expr-Int) (expr-string "z"))
                       (mk-nil (expr-Int))))
  (check-equal? (witness-got-string bad t)
                "List (cons field 0 is Option (some field 0 is String))"))

(test-case "witness/data tags are well-formed and never skip"
  (for ([d (in-list '((Option Int) (List String) (List (Option Int))))])
    (define t (field-type->witness-tag (schema-field-type->expr d)))
    (check-true (witness-tag-well-formed? t) (format "~a → ~a" d t))
    (check-false (witness-tag-skip? t) (format "~a must stay witnessable" d))))

;; ============================================================================
;; The NON-CTOR CARRIERS: PVec / Set / Map (2026-08-03, with the tier-2 work).
;;
;; These three never reach the `data` arm — their values are an rrb, an hset and
;; a champ, not constructor applications — so they sat at 'any and a
;; `(PVec Int)` field accepted `@[1 "z"]`.
;; ============================================================================

(require (only-in "../rrb.rkt" rrb-from-list))

(test-case "witness/PVec checks its elements"
  (define t (field-type->witness-tag (schema-field-type->expr '(PVec Int))))
  (check-equal? t '(pvec (prim Nat Int)))
  (check-true  (value-witnesses-tag?
                (expr-rrb (rrb-from-list (list (expr-int 1) (expr-int 2)))) t))
  (check-false (value-witnesses-tag?
                (expr-rrb (rrb-from-list (list (expr-int 1) (expr-string "z")))) t)
               "THE BUG: @[1 \"z\"] used to satisfy a (PVec Int) field")
  (check-true (value-witnesses-tag? (expr-rrb (rrb-from-list '())) t)
              "an empty PVec has no elements to disagree"))

(test-case "witness/Map checks BOTH keys and values"
  (define t (field-type->witness-tag
             (schema-field-type->expr '(Map Keyword String))))
  (check-equal? t '(hmap (prim Keyword) (prim String)))
  (check-true  (value-witnesses-tag? (mk-champ 'a (expr-string "x")) t))
  (check-false (value-witnesses-tag? (mk-champ 'a (expr-int 1)) t)
               "a wrong VALUE type must reject"))

(test-case "witness/a carrier accepts a value of the WRONG carrier kind"
  ;; Same call as the `row` arm: the carrier mismatch is the static seal's to
  ;; make, and a witness that cannot read the value has nothing to say about
  ;; its elements.
  (define t (field-type->witness-tag (schema-field-type->expr '(PVec Int))))
  (check-true (value-witnesses-tag? (expr-string "not a pvec") t)))

(test-case "witness/a carrier SKIPS honestly when its element type is unwitnessable"
  ;; `(PVec <Int -> Int>)` can reject nothing, and must say so — otherwise the
  ;; discipline test reads it as coverage it does not have.
  (check-true (witness-tag-skip?
               (field-type->witness-tag
                (schema-field-type->expr '(PVec ($arrow Int Int)))))
              "an unwitnessable element type makes the carrier a skip")
  (check-false (witness-tag-skip?
                (field-type->witness-tag (schema-field-type->expr '(PVec Int)))))) 

(test-case "witness/carrier got-strings name the offending element"
  (check-equal? (witness-got-string
                 (expr-rrb (rrb-from-list (list (expr-int 1) (expr-string "z"))))
                 (field-type->witness-tag (schema-field-type->expr '(PVec Int))))
                "PVec (element 1 is String)")
  (check-equal? (witness-got-string
                 (mk-champ 'a (expr-int 1))
                 (field-type->witness-tag
                  (schema-field-type->expr '(Map Keyword String))))
                "Map (the value at :a is Int)"))
