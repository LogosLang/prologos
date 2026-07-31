#lang racket/base

;;;
;;; PROLOGOS TYPING-ERRORS
;;; Error-accumulating wrappers around the core type checker.
;;; The core kernel functions (infer, check, etc.) are preserved unchanged
;;; for Maude cross-validation. These wrappers add structured error reporting.
;;;
;;; Sprint 9: Added optional `names` parameter for de Bruijn → user name recovery.
;;;

(require racket/list
         racket/match
         racket/string
         "prelude.rkt"
         "performance-counters.rkt"
         "syntax.rkt"
         "reduction.rkt"
         "typing-core.rkt"
         "qtt.rkt"
         "source-location.rkt"
         "errors.rkt"
         "pretty-print.rkt"
         "global-env.rkt"
         "elab-speculation-bridge.rkt"
         "atms.rkt"
         ;; PPN 4C 3C.c.3 (2026-05-24): translator + struct constructor for
         ;; union-exhaustion-error.derivation-chain field shape flip per
         ;; §9.5.4.4 Q-B.2 + Q-C.6 lock (per-branch list of derivation-chain).
         "error-explanation.rkt"
         ;; PPN 4C 3C.c.3 (2026-05-24): cell-19 write per §9.5.4.4 Q-C.1 (f)
         ;; multi-writer scaffolding (sexp check/err is the SECOND writer to
         ;; cell-19 alongside on-network 3C.b handler; retires at Track 4D).
         ;; Direct net-cell-write per user direction (NOT propagator wrapper).
         "propagator.rkt"
         "elab-network-types.rkt"
         ;; current-prop-net-box defined in metavar-store.rkt; (only-in)
         ;; pattern follows typing-propagators.rkt:28 precedent.
         (only-in "metavar-store.rkt" current-prop-net-box))

(provide infer/err
         check/err
         is-type/err
         checkQ-top/err)

;; ========================================
;; Issue #70 diagnostic (N6e-C stopgap).
;; ========================================
;; A "Could not infer type" whose expr contains a HOLE-domain lambda (an
;; unannotated `fn` / `_`-section) wrapping a generic numeric op (+ - * / < …)
;; is almost always the #70 gap: the op's numeric type can't be inferred while
;; its operand (the lambda param) is still an unsolved element meta — map/filter
;; type the fn arg before the container that would solve it. Detect that shape
;; and append an actionable hint. Best-effort structural walk, runs ONLY on the
;; already-failing error path; purely additive text (no soundness effect). The
;; real fix (container-before-fn ordering; option B) is scheduled for N6e-E5 —
;; see issue #70 + design doc §12 / §9d E5.
(define (generic-op-node? x)
  (or (expr-generic-add? x) (expr-generic-sub? x) (expr-generic-mul? x)
      (expr-generic-div? x) (expr-generic-mod? x)
      (expr-generic-lt? x) (expr-generic-le? x) (expr-generic-gt? x)
      (expr-generic-ge? x) (expr-generic-eq? x)
      (expr-generic-negate? x) (expr-generic-abs? x)
      ;; N6e-E4: the cross-width float conversions are the same #70 class —
      ;; their rules INFER-and-test the operand (float-type?), so they can't
      ;; solve a hole-lambda's meta either (unlike check-mode rules like int*).
      (expr-float-finite? x) (expr-float-to-rat? x)
      (expr-float-to-int? x) (expr-float-to-float32? x)))

;; Immediate sub-exprs of a transparent expr struct (also recursing into list /
;; pair fields). Non-expr fields ignored; an exotic container just yields no
;; hint, never an error.
(define (expr-subfields x)
  (if (expr? x)
      (let ([v (struct->vector x)])
        (let loop ([i 1] [acc '()])
          (if (>= i (vector-length v))
              (reverse acc)
              (let ([f (vector-ref v i)])
                (loop (add1 i)
                      (cond
                        [(expr? f) (cons f acc)]
                        [(list? f) (append (reverse (filter expr? f)) acc)]
                        [(pair? f)
                         (append (reverse (filter expr? (list (car f) (cdr f)))) acc)]
                        [else acc]))))))
      '()))

;; Does e contain an expr-lam with a HOLE domain whose body-subtree contains a
;; generic op? Single pass tracking "am I inside a hole-lambda".
(define (hole-lambda-over-generic-op? e)
  (let search ([x e] [in-hole-lam? #f])
    (cond
      [(and in-hole-lam? (generic-op-node? x)) #t]
      [(expr-lam? x)
       (or (search (expr-lam-type x) #f)
           (search (expr-lam-body x)
                   (or in-hole-lam? (expr-hole? (expr-lam-type x)))))]
      [else (ormap (lambda (s) (search s in-hole-lam?)) (expr-subfields x))])))

(define i70-inference-hint
  (string-append
   "Could not infer type"
   " — hint (issue #70): a generic numeric op (+, -, *, /, <, …) over an"
   " unannotated parameter can't infer its numeric type here; annotate the"
   " parameter (e.g. [fn [x : Int] …]) or use a concrete-op section (e.g."
   " [int* _ 2] / [int+ _ 1])."))

;; ========================================
;; CIU T6 F1a-s3 (S7): closed-row-miss diagnostic.
;; ========================================
;; A failing expr containing a projection (map-get / get) of a KEYWORD-LITERAL
;; key out of a RECORD-typed sub-expr that LACKS that key gets the rich
;; "field :b is not present …" message naming the available fields. Same
;; contract as the #70 hint above: best-effort post-hoc walk, runs ONLY on the
;; already-failing error path, purely additive text. The walk re-infers the
;; map sub-expr at the CALLER's ctx — a node under a binder whose map mentions
;; bvars simply fails to infer (or isn't a Record) → no hint, never a wrong one;
;; any exception is swallowed to the plain message.

;; x is a projection node? → (m . k), else #f
(define (projection-parts x)
  (cond
    [(expr-map-get? x) (cons (expr-map-get-m x) (expr-map-get-k x))]
    [(expr-get? x) (cons (expr-get-coll x) (expr-get-key x))]
    [else #f]))

(define (format-closed-row-miss rec kw names)
  (define labels (map car (expr-Record-fields rec)))
  (define shown (if (> (length labels) 6) (take labels 6) labels))
  (define more (- (length labels) (length shown)))
  (string-append
   "Could not infer type — field :" (symbol->string kw)
   " is not present in the record " (pp-expr rec names)
   (if (null? labels)
       " (the record has no fields)"
       (string-append
        "; available fields: "
        (string-join (map (lambda (l) (string-append ":" (symbol->string l))) shown) " ")
        (if (> more 0) (format " (+~a more)" more) "")))))

;; CIU T6 D4.P2 (owner ruling Q_R5) — the ORDINAL counterpart of
;; `format-closed-row-miss`.
;;
;; P2 makes `t.9` reachable on a het tuple, and the pre-existing hint was
;; KEYWORD-GATED twice over (an `expr-keyword?` key AND a `'keyword`
;; key-domain), so a nat-domain closed row got NO hint at all and surfaced as a
;; bare "Could not infer type" — no index, no arity, no path. Het tuples are
;; exactly the carrier the acceptance corpus pins (`mixed`, `events`), so this
;; was the first thing a user would hit on the new surface. The PVec runtime
;; path was already excellent ("index 9 out of bounds for PVec of length 3");
;; this brings the STATIC tuple path up to that bar.
(define (format-closed-tuple-oob rec idx names)
  (define arity (length (expr-Record-fields rec)))
  (string-append
   "Could not infer type — index " (number->string idx)
   " is out of range for the " (number->string arity) "-tuple "
   (pp-expr rec names)
   (if (zero? arity)
       " (the tuple has no positions)"
       (format " — valid indices 0–~a" (sub1 arity)))))

;; The key of an ordinal projection, as a plain NON-NEGATIVE integer, or #f.
;; `expr-get` accepts Nat-or-Int literals, so both shapes reach here.
;;
;; ⚠ THE NON-NEGATIVE GUARD IS LOAD-BEARING — caught by adversarial verify.
;; This predicate mirrors `record-project`'s literal-nat leg
;; (typing-core.rkt:573-576), whose `#:when` is `(and (eq? kd 'nat)
;; (exact-nonnegative-integer? n))`. The first draft copied the Nat-or-Int half
;; and DROPPED the non-negative half — the `infer`/`inferQ`-twin drift shape
;; `pipeline.md` codifies, where two halves of one rule disagree.
;;
;; Because the ordinal branch sits FIRST in `closed-row-miss-hint`'s `or`, a
;; negative literal made the hint (a) assert something FALSE about a
;; sub-expression that type-checks fine — `record-project` routes a negative
;; literal to the DYNAMIC-key path, where `(get het -1)` succeeds as the union
;; of positions — and (b) SUPPRESS the correct keyword closed-row-miss hint
;; that the same expression used to get. A/B-verified against a pinned
;; baseline: it was a diagnostic REGRESSION, not merely a new gap. Reachable
;; via the paren-keyword forms `(get het -1)` / `(map-get het -1)`; the bracket
;; surface is intercepted by the `postfix-neg` marker and `.N` cannot lex a
;; sign, which is exactly why no `.N` test caught it.
(define (ordinal-key-index k)
  (cond
    [(expr-nat-val? k) (expr-nat-val-n k)]
    [(expr-int? k)
     (let ([n (expr-int-val k)])
       (and (exact-nonnegative-integer? n) n))]
    [else #f]))

(define (closed-row-miss-hint ctx e names)
  (with-handlers ([(lambda (_) #t) (lambda (_) #f)])
    (let search ([x e])
      (and (expr? x)
           (or
            ;; ---- ORDINAL branch (D4.P2, Q_R5): nat key-domain, integer key ----
            (let ([mk (projection-parts x)])
              (and mk
                   (let ([idx (ordinal-key-index (cdr mk))])
                     (and idx
                          (let ([tm (whnf (infer ctx (car mk)))])
                            ;; `closed-nat-row?` (syntax.rkt) IS this conjunction
                            ;; — Record ∧ 'nat domain ∧ 'closed tail — and is
                            ;; already the canonical guard at 5 typing-core
                            ;; sites. The first draft re-derived it inline; use
                            ;; the ONE definition (the "check for existing
                            ;; helpers" lesson). CLOSED-only for the same reason
                            ;; the keyword branch below is: a 'dyn tail means
                            ;; the position may live in the remainder.
                            (and (closed-nat-row? tm)
                                 (not (record-lookup-field tm idx))
                                 (format-closed-tuple-oob tm idx names)))))))
            (let ([mk (projection-parts x)])
                 (and mk
                      (expr-keyword? (cdr mk))
                      (let ([tm (whnf (infer ctx (car mk)))])
                        (and (expr-Record? tm)
                             (eq? (expr-Record-key-domain tm) 'keyword)
                             ;; CIU T6 F1a.2 p1a: CLOSED rows only — a miss on a
                             ;; 'dyn row is legal (D19: fresh meta; the field may
                             ;; live in the remainder), so the closed-row-miss
                             ;; hint would be misleading there.
                             (eq? (expr-Record-tail tm) 'closed)
                             (not (record-lookup-field tm (expr-keyword-name (cdr mk))))
                             (format-closed-row-miss tm (expr-keyword-name (cdr mk)) names)))))
               (ormap search (expr-subfields x)))))))

;; ========================================
;; CIU T6 D4.P3a: the select-block hint (the S7 pattern).
;; ========================================
;; Post-hoc walk on the already-failing expr, most-specific-first. It re-runs
;; the SAME `select-project` walk the infer arm used (one walk, two consumers
;; — the arm and its diagnostic cannot drift) and formats the failure with
;; BRANCH context. The three Q_T2 refusal kinds all name the 4d remedy list:
;; seal / validate / annotate.
(define (format-select-fail fail names)
  (define path (select-fail-path fail))
  ;; D4.P3c: ordinal steps put NUMBERS in the path — ~a, not symbol->string
  (define branch-str (string-join (map (lambda (p) (format "~a" p)) path) "."))
  (define label (select-fail-label fail))
  (define row (select-fail-row fail))
  ;; D4.P3a adversarial verify: "annotate its row type" was DROPPED from the
  ;; remedy list — row-literal annotations have no working spelling at HEAD
  ;; (zero in-tree uses; `def q : {:a Int} := …` refuses), so naming it was
  ;; the P1b-iii advice-that-does-not-work class. Seal and validate are both
  ;; VERIFIED working remedies now that select-project projects through
  ;; schema-typed subjects. Re-add annotate when row annotations become
  ;; writable (recorded as a Q_T2 adaptation in D4 §5.P3a).
  (define remedies
    "seal the subject against a schema (`the Schema subj`) or validate it against one")
  (case (select-fail-kind fail)
    [(miss-closed)
     (string-append
      (format-closed-row-miss row label names)
      (format "; in the select branch `~a` — bare field access (no construction) is spelled `.~a`"
              branch-str label))]
    [(miss-dyn)
     (format
      "Could not infer type — select: field :~a (branch `~a`) is not listed on the open row ~a; a select block asserts its result, so unlisted fields refuse — ~a"
      label branch-str (pp-expr row names) remedies)]
    [(unknown-presence)
     (format
      "Could not infer type — select: field :~a's presence (branch `~a`) is 'unknown on ~a; a select block asserts its result — ~a"
      label branch-str (pp-expr row names) remedies)]
    [(subject-map)
     (format
      "Could not infer type — select: the subject~a is a (Map K V), which has no per-field row; a select block needs a record subject — ~a"
      (if (null? path) "" (format " (branch `~a`)" branch-str)) remedies)]
    [(subject-tuple)
     ;; D4.P3c: ordinal selection is LIVE — the recommendation works now.
     (format
      "Could not infer type — select: the subject~a is a tuple (nat-keyed row); a keyed block selects NAMED fields — ordinal selection is `x{N M}`, single-element extraction `x.N`"
      (if (null? path) "" (format " (branch `~a`)" branch-str)))]
    [(subject-other)
     ;; P3c verify (rank 3): PVec subjects deserve the ordinal teaching —
     ;; ordinal steps/branches over vectors are LIVE; only NAMED steps
     ;; refuse here. Also surface the offending step label (`.-1` was
     ;; invisible, byte-identical to `.foo`).
     (if (expr-PVec? row)
         (format
          "Could not infer type — select: `~a`~a is not a field of a vector element position — a vector subject takes ordinal steps (`.N`) or ordinal branches (`x{N M}`)"
          (or label "the step")
          (if (null? path) "" (format " (branch `~a`)" branch-str)))
         (format
          "Could not infer type — select: the subject~a is not a record; a select block projects fields of a keyword row"
          (if (null? path) "" (format " (branch `~a`)" branch-str))))]
    ;; ---- D4.P3c: the ordinal fail kinds ----
    [(ordinal-oob)
     (string-append
      (format-closed-tuple-oob row label names)
      (format "; in the select branch `~a`" branch-str))]
    [(not-indexable)
     (format
      "Could not infer type — select: ordinal `~a` (branch `~a`) needs a tuple or vector subject; ~a — select named fields instead (`x{k}`)"
      label branch-str
      (cond
        [(and (expr-Record? row) (eq? (expr-Record-key-domain row) 'keyword))
         (format "~a is keyword-keyed" (pp-expr row names))]
        [(expr-Map? row) "a (Map K V) has no positions"]
        [else (format "~a has no positions" (pp-expr row names))]))]
    [else #f]))

(define (select-block-hint ctx e names)
  (with-handlers ([(lambda (_) #t) (lambda (_) #f)])
    (let search ([x e])
      (and (expr? x)
           (or (match x
                 [(expr-select subject branches)
                  (let ([tm (whnf (infer ctx subject))])
                    (and (not (expr-error? tm))
                         (let-values ([(row fail) (select-project ctx tm branches)])
                           (and fail (format-select-fail fail names)))))]
                 [_ #f])
               (ormap search (expr-subfields x)))))))

;; ========================================
;; CIU T6 F1b.4e (D22): seal missing-required hint (the S7 pattern)
;; ========================================
;; When an infer failure contains a seal boundary (expr-ann against a schema
;; fvar) whose EXACT knowledge lacks required (undefaulted) fields, name them.
(define (seal-residual-hint ctx e names)
  (let search ([x e])
    (and (expr? x)
         (or (match x
               [(expr-ann term (expr-fvar sname))
                (let ([schema (lookup-schema-by-name sname)])
                  (and schema
                       (let ([missing (seal-missing-required ctx term schema)])
                         (and (pair? missing)
                              (string-append
                               "schema seal: missing required field"
                               (if (null? (cdr missing)) "" "s")
                               " "
                               (string-join (map (lambda (k) (format ":~a" k)) missing) ", ")
                               " of " (symbol->string sname)
                               " (fields without :default must be provided; runtime maps discharge via validate)")))))]
               [_ #f])
             (ormap search (expr-subfields x))))))

;; ========================================
;; CIU T6 F1b.7f: targeted schema-mistake diagnostics (the stress-test edge —
;; the generic "Could not infer type" swallowed the specific error on common
;; schema mistakes). Each is the seal-residual-hint pattern: a guarded post-hoc
;; walk over the already-failing expr, re-deriving the type info the bare
;; expr-error dropped, returning a string OR #f. All PRESERVE the "Could not
;; infer type" prefix + append detail (the infer-door convention — the struct
;; has no wanted/got field; the 7 test-firstclass-ops "Could not infer" prefix
;; asserts pin this). Ordered most-specific-first in infer/err; shapes are
;; (mostly) disjoint. No qtt twin: a rejected term errors at infer/err before
;; inferQ (post-freeze) ever runs.
;; ========================================

;; (a) wrong-TYPED field in a seal (map-assoc chain against a schema fvar) —
;; seal-missing-required is presence-only, so this names the field + expected/got.
(define (seal-field-type-hint ctx e names)
  (with-handlers ([(lambda (_) #t) (lambda (_) #f)])
    (let search ([x e])
      (and (expr? x)
           (or (match x
                 [(expr-ann term (expr-fvar sname))
                  (let ([schema (lookup-schema-by-name sname)])
                    (and schema
                         (let ([mm (seal-first-field-type-mismatch ctx term schema)])
                           (and mm
                                (string-append
                                 "Could not infer type — schema " (symbol->string sname)
                                 ": field :" (symbol->string (car mm))
                                 " expected " (pp-expr (cadr mm) names)
                                 (if (caddr mm)
                                     (string-append ", got " (pp-expr (caddr mm) names))
                                     " (the provided value's type could not be inferred)"))))))]
                 [_ #f])
               (ormap search (expr-subfields x)))))))

;; (c) cross-schema `the` — a VALUE whose whole type is a DIFFERENT schema fvar
;; sealed against sname (the `the`/infer door; the def-annotation door already
;; gives a crisp type-mismatch — this closes that door asymmetry). Scoped to a
;; schema-fvar-typed term so it never fires on a map-assoc literal (that is (a)).
(define (cross-schema-seal-hint ctx e names)
  (with-handlers ([(lambda (_) #t) (lambda (_) #f)])
    (let search ([x e])
      (and (expr? x)
           (or (match x
                 [(expr-ann term (expr-fvar sname))
                  (let ([schema (lookup-schema-by-name sname)])
                    (and schema
                         (let ([tt (whnf (infer ctx term))])
                           (and (not (expr-error? tt))
                                (expr-fvar? tt)
                                (lookup-schema-by-name (expr-fvar-name tt))
                                (not (eq? (expr-fvar-name tt) sname))
                                (string-append
                                 "Could not infer type — the " (symbol->string sname)
                                 ": the value has type " (pp-expr tt names)
                                 ", which does not satisfy schema " (symbol->string sname))))))]
                 [_ #f])
               (ormap search (expr-subfields x)))))))

;; (d) validate on a NON-map subject — reuse the exact validate-subject predicate.
(define (validate-nonmap-hint ctx e names)
  (with-handlers ([(lambda (_) #t) (lambda (_) #f)])
    (let search ([x e])
      (and (expr? x)
           (or (match x
                 [(expr-validate _sname _closed? _plan subject _names)
                  (let ([tm (whnf (infer ctx subject))])
                    (and (not (expr-error? tm))
                         (not (validate-subject-map-ish? tm))
                         (string-append
                          "Could not infer type — validate expects a map-like subject"
                          " (a map, record, or schema/selection value), got "
                          (pp-expr tm names))))]
                 [_ #f])
               (ormap search (expr-subfields x)))))))

;; (b) a SCHEMA/RECORD value flowing into a function's non-matching parameter type
;; (the app-domain mismatch). NARROWED to a schema/record ARG so it stays clear of
;; the issue-#70 op-section "Could not infer" cases (whose args are numeric holes).
(define (app-domain-schema-hint ctx e names)
  (with-handlers ([(lambda (_) #t) (lambda (_) #f)])
    (let search ([x e])
      (and (expr? x)
           (or (match x
                 [(expr-app e1 e2)
                  (let ([t1 (whnf (infer ctx e1))])
                    (and (expr-Pi? t1)
                         (let ([dom (expr-Pi-domain t1)]
                               [at (whnf (infer ctx e2))])
                           (and (not (expr-error? at))
                                ;; scope gate: the argument is a schema value or a record
                                (or (and (expr-fvar? at) (lookup-schema-by-name (expr-fvar-name at)))
                                    (expr-Record? at))
                                (not (check ctx e2 dom))
                                (string-append
                                 "Could not infer type — argument of type " (pp-expr at names)
                                 " does not match the expected parameter type " (pp-expr dom names))))))]
                 [_ #f])
               (ormap search (expr-subfields x)))))))

;; ========================================
;; Infer with error reporting
;; ========================================
;; Returns (or/c Expr? prologos-error?)
;; Sprint 9: optional `names` for de Bruijn recovery in error messages
(define (infer/err ctx e [loc srcloc-unknown] [names '()])
  (let ([result (infer ctx e)])
    (if (expr-error? result)
        (inference-failed-error loc
                                (or (seal-residual-hint ctx e names)    ;; F1b.4e: most specific first
                                    (seal-field-type-hint ctx e names)  ;; F1b.7f (a) wrong-typed field
                                    (cross-schema-seal-hint ctx e names);; F1b.7f (c) cross-schema `the`
                                    (validate-nonmap-hint ctx e names)  ;; F1b.7f (d) validate non-map subj
                                    (app-domain-schema-hint ctx e names);; F1b.7f (b) schema arg vs param
                                    (select-block-hint ctx e names)     ;; D4.P3a (before S7: branch-aware)
                                    (closed-row-miss-hint ctx e names)  ;; S7
                                    (if (hole-lambda-over-generic-op? e)
                                        i70-inference-hint
                                        "Could not infer type"))
                                (pp-expr e names))
        result)))

;; ========================================
;; Check with error reporting
;; ========================================

;; Flatten nested union types into a list of branches.
;; (A | (B | C)) → (list A B C)
(define (flatten-union-local t)
  (if (expr-union? t)
      (append (flatten-union-local (expr-union-left t))
              (flatten-union-local (expr-union-right t)))
      (list t)))

;; Returns (or/c #t prologos-error?)
;; Sprint 9: optional `names` for de Bruijn recovery in error messages
;; Phase 6: union types produce enriched union-exhaustion-error (E1006)
;; Phase 7a: per-branch re-checking — each branch gets its own speculative check
;;           for branch-specific "got: ..." messages
;; Phase D3: derivation chains from sub-failures within each branch
;; PPN 4C 3C.c.3 (2026-05-24): union path REWORKED per §9.5.4 mini-design:
;;   - Per-branch chain now constructed via derivation-chain-for/union-check
;;     (3C.c.1 translator); build-derivation-chain's union-type path RETIRES
;;     per Q9 mandate (non-union path retained for type-mismatch-error /
;;     Phase 11b scope)
;;   - Cell-19 (union-derivation-chains-cell-id) WRITTEN via direct elab-cell-
;;     write on (current-prop-net-box) — multi-writer scaffolding with on-
;;     network 3C.b handler; retires at Track 4D (Q-C.1 (f) lock; D-3C.c-9
;;     honest scaffolding framing)
;;   - union-exhaustion-error.derivation-chain field shape FLIPS atomically
;;     to (listof derivation-chain) per Q-B.2 + Q-C.6 locks
(define (check/err ctx e t [loc srcloc-unknown] [names '()])
  (if (check ctx e t)
      #t
      ;; Check failed — is this a union type?
      (let ([t* (whnf t)])
        (if (expr-union? t*)
            ;; Union: produce enriched error with per-branch details
            (let* ([branches (flatten-union-local t*)]
                   [branch-strs (map (lambda (b) (pp-expr b names)) branches)]
                   ;; Phase D3+3C.c.3: collect per-branch mismatch AND structured
                   ;; derivation-chain (struct from error-explanation.rkt)
                   [branch-info
                    (for/list ([br (in-list branches)])
                      ;; Try check against this specific branch (speculatively)
                      (define ok?
                        (with-speculative-rollback
                          (lambda () (check ctx e br))
                          values  ;; identity: #t = success, #f = failure
                          (format "union-branch-~a" (pp-expr br names))))
                      (if ok?
                          ;; PPN 4C 3C.c.3: "matched" branches get empty
                          ;; derivation-chain struct (was '()). Per-branch list
                          ;; shape (Q-C.6); empty struct semantics preserved.
                          (list "matched" (derivation-chain '()))
                          ;; Per-branch failure: get sub-failures + translate
                          ;; via 3C.c.1 primitive (NOT build-derivation-chain
                          ;; — union-type path retires per Q9). Atomic case
                          ;; has empty sub-failures → empty chain (matches UX
                          ;; parity per §9.5.4.7.1); nested case populates.
                          (let* ([latest (get-latest-speculation-failure)]
                                 [sub-failures (if latest
                                                   (speculation-failure-sub-failures latest)
                                                   '())]
                                 [chain (derivation-chain-for/union-check sub-failures)]
                                 [actual (infer ctx e)])
                            (list (if (expr-error? actual)
                                      "<could not infer>"
                                      (pp-expr actual names))
                                  chain))))]
                   [branch-mismatches (map car branch-info)]
                   [branch-chains (map cadr branch-info)])
              ;; PPN 4C 3C.c.3: write cell-19 (multi-writer scaffolding per
              ;; §9.5.4.4 Q-C.1 (f) lean). Direct elab-cell-write (NOT
              ;; propagator wrapper) per user direction — pretending sexp is
              ;; a propagator would set bad precedent; honest scaffolding
              ;; preferable. Defensive on missing net-box (test contexts
              ;; without elab-network).
              (define net-box (current-prop-net-box))
              (when net-box
                (set-box! net-box
                          (elab-cell-write (unbox net-box)
                                           union-derivation-chains-cell-id
                                           (hasheq loc branch-chains))))
              (union-exhaustion-error
               loc
               (pp-expr t names)  ;; message field = full union type string (for help line)
               branch-strs
               branch-mismatches
               (pp-expr e names)
               branch-chains))
            ;; Non-union: collect provenance from speculation failures
            ;; (Phase 11b scope — build-derivation-chain's non-union path
            ;; retained until Phase 11b extends static-walk-based primitive
            ;; to non-union cases. Q9 union-only retirement.)
            (let* ([actual (infer ctx e)]
                   [latest (get-latest-speculation-failure)]
                   [sub-failures (if latest
                                     (speculation-failure-sub-failures latest)
                                     '())]
                   [provenance (build-derivation-chain sub-failures (current-command-atms))]
                   ;; CIU T6 F1b.4e: seal missing-required specificity — the
                   ;; annotation-def route fails HERE (check/err), not
                   ;; infer/err; when the expected type IS a schema fvar,
                   ;; compute the missing set directly on the checked term.
                   [seal-msg (match t*
                               [(expr-fvar sname)
                                ;; (schemas only — selections have NO
                                ;; completeness residual at construction:
                                ;; partial views by design)
                                (let ([schema (lookup-schema-by-name sname)])
                                  (and schema
                                       (let ([missing (seal-missing-required ctx e schema)])
                                         (and (pair? missing)
                                              (string-append
                                               "schema seal: missing required field"
                                               (if (null? (cdr missing)) "" "s")
                                               " "
                                               (string-join
                                                (map (lambda (k) (format ":~a" k)) missing) ", ")
                                               " of " (symbol->string sname))))))]
                               [_ #f])]
                   ;; CIU T6 F1b.7f (Q3): wrong-TYPED field on the check door too
                   ;; (the annotation-def route), sharing seal-first-field-type-
                   ;; mismatch with the infer/err hint — names the field +
                   ;; expected/got. Ordered AFTER seal-msg (missing-required wins).
                   [seal-type-msg
                    (and (not seal-msg)
                         (match t*
                           [(expr-fvar sname)
                            (let ([schema (lookup-schema-by-name sname)])
                              (and schema
                                   (let ([mm (seal-first-field-type-mismatch ctx e schema)])
                                     (and mm
                                          (string-append
                                           "schema " (symbol->string sname)
                                           ": field :" (symbol->string (car mm))
                                           " expected " (pp-expr (cadr mm) names)
                                           (if (caddr mm)
                                               (string-append ", got " (pp-expr (caddr mm) names))
                                               ""))))))]
                           [_ #f]))]
                   ;; CIU T6 (2026-07-18): a clearer message for the common
                   ;; "unannotated parameter used in a way that needs its type"
                   ;; case — the checked term is a lambda whose domain is a hole
                   ;; (unannotated param) and inference of the body gave up
                   ;; (actual = could-not-infer). e.g. `defn f [p] p.x` (field
                   ;; projection) or `defn f [x] [+ x 1]` (arithmetic): both need
                   ;; p / x to have a known type. Surgical — only fires for this
                   ;; shape, so every other check failure keeps "Type mismatch".
                   [infer-hint-msg
                    (and (not seal-msg)
                         (expr-error? actual)
                         (expr-lam? e)
                         (let ([dom (expr-lam-type e)])
                           (or (expr-hole? dom) (expr-meta? dom)))
                         (string-append
                          "cannot infer the type of an unannotated parameter — "
                          "it is used here in a way that requires a known type "
                          "(e.g. field projection `.field` or arithmetic). "
                          "Annotate the parameter (`[x : T]`) or add a `spec`."))])
              (type-mismatch-error
               loc
               (or seal-msg seal-type-msg infer-hint-msg "Type mismatch")
               (pp-expr t names)
               (if (expr-error? actual) "<could not infer>" (pp-expr actual names))
               (pp-expr e names)
               provenance))))))

;; Phase D3+E3b: Build a human-readable derivation chain from nested speculation failures.
;; Returns a list of strings, one per sub-failure, showing the speculation path.
;; When atms-box is provided (box of atms), appends ATMS conflict info to each step.
;; GDE-3: Also appends minimal diagnosis lines showing which user annotations
;; participate in the conflict, enabling messages like:
;;   "because: user annotated x : Nat"
;;   "minimal fix: retract def-type-annotation"
(define (build-derivation-chain sub-failures [atms-box #f])
  (when (pair? sub-failures)
    (perf-inc-provenance-chain!))
  (define chain
    (for/list ([sf (in-list sub-failures)])
      (define label (speculation-failure-label sf))
      (define nested (speculation-failure-sub-failures sf))
      (define base (format-speculation-label label))
      (define with-nested
        (if (pair? nested)
            (format "~a (also tried: ~a)"
                    base
                    (string-join (map (lambda (n)
                                        (format-speculation-label
                                         (speculation-failure-label n)))
                                      nested)
                                 ", "))
            base))
      ;; E3b: Append ATMS conflict info when available
      (define atms-info (format-atms-conflict atms-box (speculation-failure-hypothesis-id sf)))
      (if (string=? atms-info "")
          with-nested
          (format "~a — ~a" with-nested atms-info))))
  ;; GDE-3: Append context assumption info from nogoods
  (define context-lines (format-context-diagnosis sub-failures atms-box))
  (append chain context-lines))

;; E3b: Format ATMS conflict info for a hypothesis.
;; Returns "" if no ATMS, no hypothesis, or no nogoods for this hypothesis.
;; Otherwise returns "conflicts with: <name1>, <name2>" from the nogood set.
(define (format-atms-conflict atms-box hyp-id)
  (cond
    [(not atms-box) ""]
    [(not hyp-id) ""]
    [else
     (define a (unbox atms-box))
     (define explanations (solver-state-explain-hypothesis a hyp-id))
     (if (null? explanations)
         ""
         ;; Collect all conflicting assumption names across all nogoods
         (let* ([all-others
                 (apply append
                        (map nogood-explanation-conflicting-assumptions explanations))]
                [names
                 (for/list ([pair (in-list all-others)]
                            #:when (cdr pair))
                   (symbol->string (assumption-name (cdr pair))))]
                [unique-names (remove-duplicates names)])
           (if (null? unique-names)
               ""
               (format "conflicts with: ~a"
                       (string-join unique-names ", ")))))]))

;; GDE-3: Extract context assumption info from nogoods for diagnosis display.
;; Returns additional provenance lines showing:
;; 1. Context assumptions (user annotations) that participate in the conflict
;; 2. Minimal diagnosis from ATMS (which assumptions to retract)
;;
;; These lines are included in the provenance/derivation-chain list and rendered
;; by format-error with "because:" prefix for context lines, or as-is for diagnosis.
(define (format-context-diagnosis sub-failures atms-box)
  (cond
    [(not atms-box) '()]
    [(null? sub-failures) '()]
    [else
     (define a (unbox atms-box))
     ;; Collect all support-sets from sub-failures
     (define all-support-sets
       (for/list ([sf (in-list sub-failures)]
                  #:when (speculation-failure-support-set sf))
         (speculation-failure-support-set sf)))
     (cond
       [(null? all-support-sets) '()]
       [else
        ;; Extract context assumptions (non-speculation) from support sets
        (define context-aids
          (remove-duplicates
           (for*/list ([ss (in-list all-support-sets)]
                       [(aid _) (in-hash ss)]
                       #:when (let ([asn (hash-ref (solver-state-assumptions a) aid #f)])
                                (and asn
                                     (memq (assumption-name asn)
                                           '(def-type-annotation check-type-annotation)))))
             aid)))
        (define context-lines
          (for/list ([aid (in-list context-aids)])
            (define asn (hash-ref (solver-state-assumptions a) aid #f))
            (if asn
                (format "user annotated ~a" (assumption-datum asn))
                "")))
        ;; Minimal diagnosis: which assumptions to retract
        (define diags (solver-state-minimal-diagnoses a))
        (when (pair? diags) (perf-inc-gde-diagnosis!))
        (define diag-lines
          (cond
            [(null? diags) '()]
            [else
             (define diag (car diags))
             (define diag-datums
               (for/list ([(aid _) (in-hash diag)])
                 (define asn (hash-ref (solver-state-assumptions a) aid #f))
                 (if asn (format "~a" (assumption-datum asn))
                     (format "assumption-~a" (assumption-id-n aid)))))
             (if (null? diag-datums) '()
                 (list (string-append
                        "[diagnosis] retract: "
                        (string-join diag-datums " or "))))]))
        (append context-lines diag-lines)])]))

;; Phase D3: Convert internal speculation labels to human-readable strings.
(define (format-speculation-label label)
  (cond
    [(string-prefix? label "union-check-left")
     "nested union left branch failed"]
    [(string-prefix? label "union-checkQ-left")
     "nested QTT union left branch failed"]
    [(string-prefix? label "map-value-widening")
     "map value widening attempted"]
    [(string-prefix? label "union-map-get-component")
     "union map key check failed"]
    [(string-prefix? label "union-branch-")
     (format "tried branch ~a" (substring label 13))]
    [else label]))

;; ========================================
;; Is-type with error reporting
;; ========================================
;; Returns (or/c #t prologos-error?)
;; Sprint 9: optional `names` for de Bruijn recovery in error messages
(define (is-type/err ctx e [loc srcloc-unknown] [names '()])
  (if (is-type ctx e)
      #t
      (not-a-type-error loc
                         "Expression is not a valid type"
                         (pp-expr e names))))

;; ========================================
;; QTT multiplicity check with error reporting
;; ========================================
;; Returns (or/c #t prologos-error?)
;; Runs checkQ-top to verify that variable usage matches declared multiplicities.
;; For v1, error message is generic (checkQ-top returns boolean only).
(define (checkQ-top/err ctx e t [loc srcloc-unknown] [names '()])
  (if (checkQ-top ctx e t)
      #t
      (multiplicity-error loc
                          "Multiplicity violation"
                          (pp-expr e names)
                          "declared"
                          "actual")))
