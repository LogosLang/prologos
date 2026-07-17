#lang racket/base
;; ============================================================================
;; field-witness.rkt — the RUNTIME half of the schema field-type witness.
;;
;; CIU T6 F1b.5-s1 (D28). The seal's runtime tabulation (validate, s2) checks
;; each field's VALUE against its field TYPE. subtype? — the subsumption
;; relation the witness must respect (Nat⊂Int etc.) — lives above reduction
;; (subtype-predicate → type-lattice → reduction is a cycle), so it CANNOT be
;; consulted from the reduction arm. The split (Data Orientation):
;;
;;   - BAKE TIME (typing-core, has subtype?): field-type->witness-tag computes
;;     a per-field acceptance TAG as plain DATA by CONSUMING subtype? (zero
;;     drift — computed, not hand-rolled). Tags-as-data also serialize into
;;     .pnet where closures cannot (the coercion-cache lesson).
;;   - RUN TIME (here, below reduction): value-witnesses-tag? interprets the
;;     tag against a value using struct predicates + the ctor-meta registry
;;     (which reduction already reads) — zero new cross-module edges.
;;
;; TAG GRAMMAR (plain s-expressions — no struct, no serialization surface):
;;   (prim S1 S2 ...)   value's primitive tag ∈ {S1 ...} (the subtype closure)
;;   (ctor TypeName)    value's ctor-meta type-name = TypeName (short/bare)
;;   any                unwitnessable → ALWAYS accept (the D28 skip posture:
;;                      functions, type vars, unknown/higher-kinded — checked
;;                      statically at the seal boundary, not re-witnessed here)
;;   (union T1 T2 ...)  accept if ANY Ti accepts (mirrors field-type-satisfies?)
;;
;; SAFETY DIRECTION (D28 err-polarity): on ANY uncertainty the witness ACCEPTS.
;; A false REJECT (erroring on data the static seal accepted) is strictly worse
;; than a skip. Subsumption is handled at bake time (the prim set IS the
;; subtype closure), so a Nat value in an Int field witnesses correctly.
;;
;; Values passed here are assumed already NF'd (the s2 arm reduces first) — this
;; module never calls whnf (it is below reduction).
;; ============================================================================

(require racket/list
         racket/string
         "syntax.rkt"
         (only-in "macros.rkt" lookup-ctor ctor-meta-type-name))

(provide value-witnesses-tag?
         value->prim-tag
         value->ctor-type-name
         witness-tag-skip?
         witness-tag-well-formed?)

;; ---- value → primitive tag -------------------------------------------------
;; Maps a NF'd runtime value to its primitive type-name symbol, or #f if the
;; value is not a recognized primitive (a ctor value, a champ, a closure, …).
;; Mirrors the infer arms (typing-core value→type) so the witness agrees with
;; the static seal on primitive classification.
(define (value->prim-tag v)
  (cond
    [(or (expr-zero? v) (expr-nat-val? v) (expr-suc? v)) 'Nat]  ; NF'd nat forms
    [(or (expr-true? v) (expr-false? v)) 'Bool]
    [(expr-int? v)     'Int]
    [(expr-rat? v)     'Rat]
    [(expr-string? v)  'String]
    [(expr-char? v)    'Char]
    [(expr-keyword? v) 'Keyword]
    [(expr-symbol? v)  'Symbol]
    [(expr-unit? v)    'Unit]
    [(expr-nil? v)     'Nil]
    [(expr-posit8? v)  'Posit8]
    [(expr-posit16? v) 'Posit16]
    [(expr-posit32? v) 'Posit32]
    [(expr-posit64? v) 'Posit64]
    [(expr-float32? v) 'Float32]
    [(expr-float64? v) 'Float64]
    [else #f]))

;; ---- value → ctor type-name ------------------------------------------------
;; The head of an application chain, resolved through the ctor-meta registry to
;; its TYPE name (short/bare, matching how register-ctor! stores it). Handles
;; both bare (`some`) and FQN (`prologos::data::option::some`) ctor heads via a
;; short-name fallback — the reduction.rkt:823 two-step. Returns #f if the head
;; is not a registered constructor.
(define (short-name sym)
  (string->symbol (last (string-split (symbol->string sym) "::"))))

(define (expr-app-head v)
  (cond [(expr-app? v) (expr-app-head (expr-app-func v))]
        [else v]))

(define (value->ctor-type-name v)
  (define head (expr-app-head v))
  (and (expr-fvar? head)
       (let* ([name (expr-fvar-name head)]
              [meta (or (lookup-ctor name) (lookup-ctor (short-name name)))])
         (and meta (ctor-meta-type-name meta)))))

;; ---- the interpreter -------------------------------------------------------
;; value × tag → Bool. Accept on any uncertainty (never false-reject).
(define (value-witnesses-tag? v tag)
  (cond
    [(eq? tag 'any) #t]
    [(pair? tag)
     (case (car tag)
       [(prim)
        (let ([pt (value->prim-tag v)])
          (and pt (memq pt (cdr tag)) #t))]
       [(ctor)
        (let ([tn (value->ctor-type-name v)])
          (and tn (eq? tn (cadr tag)) #t))]
       [(union)
        (ormap (lambda (t) (value-witnesses-tag? v t)) (cdr tag))]
       ;; unknown tag head → accept (forward-compatible; never false-reject)
       [else #t])]
    ;; malformed / unexpected tag shape → accept
    [else #t]))

;; ---- tag introspection (for the skip-set discipline test) ------------------
;; A tag SKIPS (concedes witnessing) iff it is 'any, at top level or inside a
;; union. The D28 skip-set-discipline test asserts the RIGHT shapes skip:
;; witnessable field types must NOT skip; unwitnessable (arrows, type vars)
;; must skip — the executable re-trigger.
(define (witness-tag-skip? tag)
  (cond
    [(eq? tag 'any) #t]
    [(and (pair? tag) (eq? (car tag) 'union)) (ormap witness-tag-skip? (cdr tag))]
    [else #f]))

;; Structural well-formedness — the totality assertion: a tag is one of the
;; four grammar shapes, recursively.
(define (witness-tag-well-formed? tag)
  (cond
    [(eq? tag 'any) #t]
    [(and (pair? tag) (eq? (car tag) 'prim))
     (and (pair? (cdr tag)) (andmap symbol? (cdr tag)))]
    [(and (pair? tag) (eq? (car tag) 'ctor))
     (and (pair? (cdr tag)) (symbol? (cadr tag)) (null? (cddr tag)))]
    [(and (pair? tag) (eq? (car tag) 'union))
     (and (pair? (cdr tag)) (andmap witness-tag-well-formed? (cdr tag)))]
    [else #f]))
