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

(define (closed-row-miss-hint ctx e names)
  (with-handlers ([(lambda (_) #t) (lambda (_) #f)])
    (let search ([x e])
      (and (expr? x)
           (or (let ([mk (projection-parts x)])
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
;; Infer with error reporting
;; ========================================
;; Returns (or/c Expr? prologos-error?)
;; Sprint 9: optional `names` for de Bruijn recovery in error messages
(define (infer/err ctx e [loc srcloc-unknown] [names '()])
  (let ([result (infer ctx e)])
    (if (expr-error? result)
        (inference-failed-error loc
                                (or (seal-residual-hint ctx e names)    ;; F1b.4e: most specific first
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
                               [_ #f])])
              (type-mismatch-error
               loc
               (or seal-msg "Type mismatch")
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
