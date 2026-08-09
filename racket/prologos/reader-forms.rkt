#lang racket/base

(require racket/string)  ;; LET P4: string-split in split-glued-name-datum

;;;
;;; reader-forms.rkt — THE reader-form-head registry.
;;;
;;; CIU T6 D4.P1b-iii (owner ruling on the P1b-iii mini-audit, wf_18992d66-b81).
;;;
;;; WHAT A READER-FORM HEAD IS: a symbol that, when a brace group is ADJACENT to
;;; it, means "the brace body belongs to that form" rather than "select from the
;;; thing on the left". `racket{(+ 1 2)}` is a foreign code block, not a
;;; selection off a variable named `racket`.
;;;
;;; WHY THIS MODULE EXISTS AT ALL — the layering problem the audit surfaced:
;;;   * head recognition lives at PREPARSE (macros.rkt's combine-foreign-blocks),
;;;   * head PRECEDENCE must be decided at GROUPING (parse-reader.rkt), because
;;;     adjacency is destroyed at the datum layer,
;;;   * and there is NO MODULE EDGE between them: parse-reader.rkt requires only
;;;     rrb / propagator / parse-lattice, and macros.rkt does not require
;;;     parse-reader.rkt.
;;; So neither could see the other's list. Before this module the set was
;;; hard-coded in macros.rkt and nowhere else the grouper could reach.
;;;
;;; THIS MODULE REQUIRES NOTHING PROJECT-LOCAL — deliberately. That is what lets
;;; both parse-reader.rkt (grouping) and macros.rkt (preparse) require it with no
;;; cycle. Keep it that way: adding a project require here would re-create the
;;; problem it exists to solve.
;;;
;;; ⚠ THE F1b.7g ANTI-DRIFT RULE APPLIES: this is the ONE list. Do not inline a
;;; second copy anywhere. That drift class is exactly how `recognize-keyword`
;;; diverged from `ident-continue?` for eight characters, and how
;;; `fused-type-annot?` diverged from its own recognizer (Q_N4, same phase).
;;;
;;; KNOWN RESIDUAL DIVERGENCE, accepted and named (P1b-iii audit): the Emacs
;;; tooling hard-codes the literal adjacent string "racket{" in TWO places —
;;; editors/emacs/prologos-mode.el and editors/emacs/prologos-font-lock.el. A
;;; Racket-side registry cannot reach `.el`, so those stay hand-maintained. They
;;; already require adjacency while the compiler's preparse did not, so
;;; P1b-iii CLOSES that divergence rather than opening one — but if a head is
;;; ever added here, the two `.el` sites need it too.
;;;

(provide reader-form-heads
         reader-form-head?
         ;; LET P4 (2026-07-31): the fused-annotation primitives MOVED HERE
         ;; from parser.rkt. macros.rkt (expand-let, the merge helpers) needs
         ;; them at the DATUM level, and parser.rkt requires macros.rkt — so
         ;; parser.rkt can never export TO macros. This leaf is the one module
         ;; both already require. parser.rkt re-imports these names (its own
         ;; definitions deleted) — ONE definition, per the fused-primitives
         ;; discipline recorded at their original site (Rel T1 C.b.2 + POL.6).
         colon-symbol?
         digit-headed-colon-symbol?
         fused-type-annot?
         fused-annot->type-symbol
         split-glued-name-datum
         ;; CIU T6 D4.P4c-2 condition (c): MOVED HERE from macros.rkt for the
         ;; same reason as the fused primitives above. The reader post-pass
         ;; binder unwrap must recognize `defn-` as a `defn`, and it runs at
         ;; READER time — strictly before preparse, where macros.rkt did the
         ;; normalization. parse-reader.rkt cannot require macros.rkt, so a
         ;; second copy was the only alternative, and a second copy of a
         ;; recognizer is precisely the drift this module exists to forbid.
         private-form-base
         ;; CIU T6 D4.P4d slice 7: the access-sentinel head sets. Same reason as
         ;; every move above — TWO consumers at DIFFERENT layers. macros.rkt's
         ;; `access-sentinel?` (the preparse FUSION GATE) and parse-reader.rkt's
         ;; command-position goal-subject mint (READER time, strictly earlier)
         ;; must agree on what a postfix access sentinel IS. parse-reader.rkt
         ;; cannot require macros.rkt, so the alternative was a second copy of
         ;; the list — the exact drift this module exists to forbid.
         arity2-access-sentinel-heads
         brace-access-sentinel-heads
         subject-preserving-access-heads
         subject-preserving-access-head?)

;; The complete set. One entry today; the point is that it is ONE entry in ONE
;; place rather than an unfindable literal.
(define reader-form-heads '(racket))

;; ============================================================
;; Private-suffix forms — the ONE normalization
;; ============================================================
;; `defn-` / `def-` / … are the private (non-auto-exported) spellings of the
;; ordinary binding heads. Returns the BASE head symbol, or #f if `head` is not
;; a suffixed form.
;;
;; ⚠ TWO CONSUMERS AT DIFFERENT LAYERS, which is why this is here and not in
;; macros.rkt where it was born: macros.rkt normalizes at PREPARSE (auto-export
;; + head dispatch), and parse-reader.rkt's binder unwrap needs the same answer
;; at READER time — strictly earlier. When the unwrap could not see through the
;; suffix, `defn- f [x:Int] x` LEAKED its fused annotation into the param group
;; and became a 2-arity function; measured as a live regression against a
;; pinned pre-mint baseline (CIU T6 D4.P4c-2).
(define (private-form-base head)
  (case head
    [(defn-)     'defn]
    [(def-)      'def]
    [(data-)     'data]
    [(deftype-)  'deftype]
    [(defmacro-) 'defmacro]
    [(spec-)     'spec]
    [(trait-)    'trait]
    [(impl-)     'impl]
    [(bundle-)   'bundle]
    [(property-) 'property]
    [(functor-)  'functor]
    [else #f]))

;; Is `x` a reader-form head? Accepts the raw symbol; callers holding syntax
;; should unwrap first (grouping works on token lexemes, preparse on datums).
(define (reader-form-head? x)
  (and (symbol? x) (memq x reader-form-heads) #t))

;; ============================================================
;; Fused type annotations — the ONE set of primitives (moved from parser.rkt
;; at LET P4; original discipline comment: Rel T1 C.b.2 + POL.6 — "a second
;; copy is how the two paths would drift").
;; ============================================================

;; A colon-prefixed symbol like `:Int`. The WS reader renders a fused type
;; annotation's `:Type` as a SEPARATE colon-prefixed SYMBOL (not a Racket
;; keyword); sexp glues it into the preceding symbol.
(define (colon-symbol? x)
  (and (symbol? x)
       (let ([s (symbol->string x)])
         (and (> (string-length s) 0) (char=? (string-ref s 0) #\:)))))

;; No type name starts with a digit, so a digit-headed colon symbol is NEVER a
;; type annotation — it is a multiplicity (`:0`/`:1`/`:7`/`:10` …). STRUCTURAL,
;; not a list (the Q_N4 ruling; see the history at the original parser.rkt
;; site: the four-lexeme list silently ate `:7` as a type name).
(define (digit-headed-colon-symbol? d)
  (and (colon-symbol? d)
       (let ([s (symbol->string d)])
         (and (> (string-length s) 1) (char-numeric? (string-ref s 1))))))

;; WS shape: a colon-symbol that is a TYPE annotation, not a multiplicity.
;; `:w`/`:m` stay multiplicities — the named cost: a type literally named
;; `w`/`m` cannot be fused in WS; use the spaced form.
;;
;; ⚠ LET P4 hardening, found by an INFINITE LOOP: a fused annotation must
;; CARRY A TYPE. The bare `:` (the spaced-annotation marker, length 1) and
;; `:=` (the binding marker) are colon-symbols and are neither multiplicity-
;; shaped nor digit-headed, so the predicate accepted BOTH — and a consumer
;; that rewrites `name :T …` → `name : T …` then re-parses would see the
;; emitted bare `:` as another fused annotation, forever (caught live in
;; parse-assign-bindings; the pre-P4 defn consumer never met a bare `:` in
;; param position, so the hole was latent there, not absent).
(define (fused-type-annot? d)
  (and (colon-symbol? d)
       (not (eq? d ':))                     ;; the spaced-annotation marker
       (not (eq? d ':=))                    ;; the binding marker
       (> (string-length (symbol->string d)) 1)
       (not (memq d '(:w :m)))
       (not (digit-headed-colon-symbol? d))))

;; `:Int` → the bare type symbol `Int` (datum level — parser-side callers wrap
;; it through parse-datum to build the surf; preparse-side callers emit it as a
;; type ATOM for parse-assign-bindings).
(define (fused-annot->type-symbol annot-datum)
  (string->symbol (substring (symbol->string annot-datum) 1)))

;; sexp shape: split a possibly-glued `name:Type` symbol AT THE DATUM LEVEL.
;; Returns (values name type-sym err-msg):
;;   `x:Int`   → x, Int, #f
;;   `x:A:B`   → #f #f "chained…" (reserve for UCS — mirrors the WS reject)
;;   `x` / `str::length` (module paths produce EMPTY segments) → x/#f/#f
;;                                                              (no split)
(define (split-glued-name-datum sym)
  (define segs (string-split (symbol->string sym) ":"))
  (define nonempty? (andmap (lambda (s) (> (string-length s) 0)) segs))
  (cond
    [(and nonempty? (> (length segs) 2))
     (values #f #f (format "chained type annotation in ~a not supported (reserve for UCS)" sym))]
    [(and nonempty? (= (length segs) 2))
     (values (string->symbol (car segs)) (string->symbol (cadr segs)) #f)]
    [else (values sym #f #f)]))

;; ============================================================
;; Access-sentinel heads — the ONE set (CIU T6 D4.P4d slice 7)
;; ============================================================
;; The reader mints a postfix access as a SIBLING of its subject (`xs:name` →
;; `xs ($bcast-step |:name|)`); preparse's `rewrite-dot-access` fold is what
;; joins them. Two layers therefore need to recognize these heads, and they sit
;; on opposite sides of a module boundary that cannot be crossed directly.
;;
;; Split by ARITY because the two families differ and always have: the brace
;; family carries an arbitrary-length body, its siblings are exactly arity 2.
;; This split reproduces `access-sentinel?`'s existing shape EXACTLY — it is a
;; faithful re-homing of that predicate's data, not a redefinition.
(define arity2-access-sentinel-heads
  '($dot-access $dot-key $nil-dot-access $nil-dot-key
    $postfix-index $broadcast-access $bcast-step))

(define brace-access-sentinel-heads
  '($dot-brace $select-brace))

;; The SUBJECT-PRESERVING subset: sentinels whose fold arm NESTS the base as the
;; new node's subject (`($select-path TARGET step)`, `(get TARGET k)`, …).
;;
;; ⚠ THE COMPLEMENT IS NOT AN OVERSIGHT. The excluded heads DESTROY their base:
;; `$dot-key` / `$nil-dot-key` / `$broadcast-access` are the RETIRED family and
;; fold to `($retired-selection kind detail)`, and `$dot-brace` folds to
;; `($retired-selection select-block #f)` — in every case the subject is dropped
;; rather than wrapped. There is no subject left to carry a goal, so marking one
;; would be dead weight, and those spellings keep their existing guided refusal.
;; Verified by measurement at b6f773a8: `(g …).{c}` → `($retired-selection
;; select-block #f)`, `(g …).:name` → `($retired-selection dot-key :name)`.
(define subject-preserving-access-heads
  '($dot-access $nil-dot-access $postfix-index $bcast-step $select-brace))

(define (subject-preserving-access-head? x)
  (and (symbol? x) (memq x subject-preserving-access-heads) #t))
