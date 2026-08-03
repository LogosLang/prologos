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
;;   (row (K . T) ...)  a keyword-domain ROW (a nested schema, or an inline row
;;                      type): the value must be a map, and every listed key it
;;                      ACTUALLY HAS must witness that key's tag. See the arm.
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
         (only-in "champ.rkt" champ-lookup)
         (only-in "macros.rkt" lookup-ctor ctor-meta-type-name))

(provide value-witnesses-tag?
         witness-got-string
         value->prim-tag
         value->ctor-type-name
         value-kind-string
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
       ;; ---- SUB-SCHEMA / nested-row descent ------------------------------
       ;; The gap this closes: a field typed by another schema got tag 'any
       ;; (`field-type->witness-tag`'s unwitnessable fallback), so `[validate
       ;; Config bad]` where `bad.server.port` was a String in an Int slot came
       ;; back `ok` — the demo's headline flow (external data → validate →
       ;; Result) silently accepting wrong data. The STATIC seal descends into a
       ;; nested literal; runtime validate did not. That asymmetry was the bug.
       ;;
       ;; Two deliberate ACCEPTS keep the D28 err-polarity (never false-reject),
       ;; and they are why this is a witness rather than a second validator:
       ;;   - a non-map value accepts. The field type says "row", but a value
       ;;     that is not a champ may be an un-reduced term or a shape the
       ;;     static seal already owns. Rejecting here would be the witness
       ;;     asserting a type error it cannot substantiate.
       ;;   - a MISSING key accepts. Absence is the PLAN's business — it has
       ;;     `required?` and emits `missing-required` against the right key. A
       ;;     nested miss reported from here would surface as a type-mismatch on
       ;;     the PARENT field, naming the wrong thing.
       ;; So this rejects on exactly one condition: a key that is PRESENT and
       ;; whose value definitively fails its own tag. That is the case the
       ;; static seal catches for literals, and it is now caught for data.
       [(row)
        (cond
          [(not (expr-champ? v)) #t]
          [else
           (let ([c (expr-champ-racket-champ v)])
             (for/and ([kt (in-list (cdr tag))])
               (let* ([kexpr (expr-keyword (car kt))]
                      [found (champ-lookup c (equal-hash-code kexpr) kexpr)])
                 (or (eq? found 'none)
                     (value-witnesses-tag? found (cdr kt))))))])]
       ;; ---- TIER-2 ELEMENT RECURSION -------------------------------------
       ;; `(data Name NSKIP (Ctor FieldTag …) …)` — the refinement of `(ctor
       ;; Name)`, which asserted only that the value's constructor belonged to
       ;; the type and said nothing about its ARGUMENTS. So a `(List String)`
       ;; field accepted `[cons 1 nil]` and an `(Option Int)` field accepted
       ;; `[some "z"]`.
       ;;
       ;; The head check is IDENTICAL to `(ctor …)`'s — same predicate, same
       ;; rejection — so this can only ever reject a strict superset of what
       ;; the old tag rejected, and only on a field argument.
       ;;
       ;; NSKIP steps over the erased type params a constructor value carries
       ;; (`[some 1]` reduces to `(some Int 1)`). `self` re-enters the whole
       ;; tag, which is what makes a list check every element rather than its
       ;; head only.
       ;;
       ;; Three ACCEPTS, all uncertainty (D28), and each names a real shape:
       ;;   - a constructor absent from the tag's entries: the type's ctor set
       ;;     changed under us, or the value came from a different module's
       ;;     registration. Not our call to reject.
       ;;   - a spine whose field count differs from the tag's: a PARTIAL
       ;;     application, or extra implicit arguments we did not model. The
       ;;     arguments do not line up with the tags, so no comparison is
       ;;     meaningful.
       ;;   - anything the head check already accepted (that path is unchanged).
       [(data)
        (let* ([tname (cadr tag)]
               [nskip (caddr tag)]
               [entries (cdddr tag)]
               [tn (value->ctor-type-name v)])
          (cond
            ;; the (ctor …) check, verbatim — head must belong to this type
            [(not (and tn (eq? tn tname))) #f]
            [else
             (let* ([spine (let collect ([e v] [acc '()])
                             (if (expr-app? e)
                                 (collect (expr-app-func e) (cons (expr-app-arg e) acc))
                                 acc))]
                    [head (let peel ([e v]) (if (expr-app? e) (peel (expr-app-func e)) e))]
                    [cname (and (expr-fvar? head) (short-name (expr-fvar-name head)))]
                    [entry (and cname (assq cname entries))])
               (cond
                 [(not entry) #t]                              ; unknown ctor → accept
                 [(< (length spine) nskip) #t]                 ; malformed spine → accept
                 [else
                  (let ([fields (list-tail spine nskip)]
                        [ftags (cdr entry)])
                    (cond
                      [(not (= (length fields) (length ftags))) #t]  ; partial app → accept
                      [else
                       (for/and ([fv (in-list fields)] [ft (in-list ftags)])
                         (value-witnesses-tag? fv (if (eq? ft 'self) tag ft)))]))]))]))]
       ;; unknown tag head → accept (forward-compatible; never false-reject)
       [else #t])]
    ;; malformed / unexpected tag shape → accept
    [else #t]))

;; ---- value kind rendering (for Reason type-mismatch "got" payloads) --------
;; A short display name for what the value IS — from the same classifiers the
;; witness uses, so the error message and the witness verdict cannot drift.
;; (No pretty-print dependency: reduction-land stays below the pp module.)
(define (value-kind-string v)
  (cond
    [(value->prim-tag v) => symbol->string]
    [(value->ctor-type-name v) => symbol->string]
    [(expr-champ? v) "Map"]
    [(expr-lam? v) "function"]
    [else "value"]))

;; ---- the "got" payload -----------------------------------------------------
;; What to put in a `type-mismatch` Reason's second slot. For every tag kind but
;; `row` this is just the value's kind, exactly as before.
;;
;; For a row it must do better, and the reason is concrete: the tag sits on the
;; PARENT field, so a nested failure reported as plain `"Map"` says
;; `type-mismatch "Server" "Map"` — true, useless, and actively misleading,
;; since the value IS a map and the reader is left to guess which of its fields
;; is wrong. This walks to the first key that actually failed and names it with
;; its path, so the same failure reads `"Map (:port is String)"`, or
;; `"Map (:b.:c is Nat)"` when the miss is deeper.
;;
;; FIRST failing key, not all of them: the Reason payload is one string, and the
;; champ-fold order is deterministic. Collecting every miss is a Reason-shape
;; question (the err champ is keyed by the PARENT field here), not a string one.
(define (witness-got-string v tag)
  (define data-detail
    (and (pair? tag) (eq? (car tag) 'data)
         (let descend ([v v] [tag tag])
           (let* ([nskip (caddr tag)]
                  [entries (cdddr tag)]
                  [spine (let collect ([e v] [acc '()])
                           (if (expr-app? e)
                               (collect (expr-app-func e) (cons (expr-app-arg e) acc))
                               acc))]
                  [head (expr-app-head v)]
                  [cname (and (expr-fvar? head) (short-name (expr-fvar-name head)))]
                  [entry (and cname (assq cname entries))])
             (and entry (>= (length spine) nskip)
                  (let ([fields (list-tail spine nskip)]
                        [ftags (cdr entry)])
                    (and (= (length fields) (length ftags))
                         (for/or ([fv (in-list fields)]
                                  [ft (in-list ftags)]
                                  [i (in-naturals)])
                           (let ([ft* (if (eq? ft 'self) tag ft)])
                             (cond
                               [(value-witnesses-tag? fv ft*) #f]
                               ;; keep descending a `self` field so the report
                               ;; names the element that is actually wrong,
                               ;; rather than the outermost cons
                               [(eq? ft 'self) (or (descend fv tag)
                                                   (format "~a field ~a is ~a"
                                                           cname i (value-kind-string fv)))]
                               ;; compose, so a bad Option inside a List reads
                               ;; "cons field 0 is Option (some field 0 is String)"
                               ;; rather than stopping at "is Option"
                               [else (format "~a field ~a is ~a"
                                             cname i (witness-got-string fv ft*))]))))))))))
  (define row-detail
    (and (pair? tag) (eq? (car tag) 'row) (expr-champ? v)
         (let descend ([v v] [tag tag] [path '()])
           (and (expr-champ? v)
                (let ([c (expr-champ-racket-champ v)])
                  (for/or ([kt (in-list (cdr tag))])
                    (let* ([kexpr (expr-keyword (car kt))]
                           [found (champ-lookup c (equal-hash-code kexpr) kexpr)]
                           [p (cons (car kt) path)])
                      (cond
                        [(eq? found 'none) #f]
                        [(value-witnesses-tag? found (cdr kt)) #f]
                        ;; a nested row miss: keep descending so the path is
                        ;; the full one rather than stopping at the outermost
                        ;; field that "is a Map".
                        [(and (pair? (cdr kt)) (eq? (car (cdr kt)) 'row))
                         (or (descend found (cdr kt) p)
                             (format "~a is ~a"
                                     (path->string* p) (value-kind-string found)))]
                        ;; anything else: compose with this same function, so a
                        ;; row field holding a bad LIST reports both levels —
                        ;; ":tags is List (cons field 0 is Int)".
                        [else (format "~a is ~a"
                                      (path->string* p)
                                      (witness-got-string found (cdr kt)))]))))))))
  (define detail (or data-detail row-detail))
  (if detail
      (string-append (value-kind-string v) " (" detail ")")
      (value-kind-string v)))

(define (path->string* rev-path)
  (string-join (for/list ([k (in-list (reverse rev-path))])
                 (string-append ":" (symbol->string k)))
               "."))

;; ---- tag introspection (for the skip-set discipline test) ------------------
;; A tag SKIPS (concedes witnessing) iff it is 'any, at top level or inside a
;; union. The D28 skip-set-discipline test asserts the RIGHT shapes skip:
;; witnessable field types must NOT skip; unwitnessable (arrows, type vars)
;; must skip — the executable re-trigger.
(define (witness-tag-skip? tag)
  (cond
    [(eq? tag 'any) #t]
    [(and (pair? tag) (eq? (car tag) 'union)) (ormap witness-tag-skip? (cdr tag))]
    ;; A row concedes exactly when it can reject nothing — no fields, or every
    ;; field's own tag skips. Any witnessable field makes the row witnessable,
    ;; which is what the discipline test needs to see for a nested schema.
    [(and (pair? tag) (eq? (car tag) 'row))
     (andmap (lambda (kt) (witness-tag-skip? (cdr kt))) (cdr tag))]
    ;; a `data` tag never skips: its head check alone can reject, exactly as
    ;; `(ctor …)` could.
    [(and (pair? tag) (eq? (car tag) 'data)) #f]
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
    ;; `(row (K . T) ...)` — an EMPTY row is well-formed (an empty schema is a
    ;; legal, if useless, declaration), unlike union/prim/ctor which all carry a
    ;; non-empty payload by construction.
    [(and (pair? tag) (eq? (car tag) 'row))
     (andmap (lambda (kt) (and (pair? kt) (symbol? (car kt))
                               (witness-tag-well-formed? (cdr kt))))
             (cdr tag))]
    ;; (data Name NSKIP (Ctor FieldTag ...) ...) — `self` is well-formed only
    ;; inside a data tag, which is why it is checked here and not at top level.
    [(and (pair? tag) (eq? (car tag) 'data))
     (and (>= (length tag) 3) (symbol? (cadr tag))
          (exact-nonnegative-integer? (caddr tag))
          (andmap (lambda (e)
                    (and (pair? e) (symbol? (car e))
                         (andmap (lambda (ft)
                                   (or (eq? ft 'self) (witness-tag-well-formed? ft)))
                                 (cdr e))))
                  (cdddr tag)))]
    [else #f]))
