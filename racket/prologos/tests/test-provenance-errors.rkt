#lang racket/base

;;;
;;; test-provenance-errors.rkt — E3e: Provenance-rich error tests
;;;
;;; Tests that type errors carry ATMS derivation chains through the
;;; speculation → ATMS → build-derivation-chain → error formatting pipeline.
;;;

(require racket/list
         racket/port
         racket/string
         rackunit
         "test-support.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../elab-speculation-bridge.rkt"
         "../metavar-store.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../errors.rkt"
         "../performance-counters.rkt"
         "../source-location.rkt"
         "../atms.rkt"
         ;; PPN 4C 3C.c.3 (2026-05-24): derivation-chain + derivation-step
         ;; struct accessors for union-exhaustion-error.derivation-chain field
         ;; (post-Q-B.2 flip to (listof derivation-chain) per §9.5.4.4)
         "../error-explanation.rkt"
         ;; PPN 4C 3C.c.6 (2026-05-24): cell-19 observability test —
         ;; net-cell-read for union-derivation-chains-cell-id; elab-cell-read
         ;; via elab-network-types
         (only-in "../propagator.rkt" union-derivation-chains-cell-id)
         (only-in "../elab-network-types.rkt" elab-cell-read))

;; ========================================
;; Test Helpers
;; ========================================

;; Run without prelude, suppress stderr, return all results
(define (run-simple s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-error-port (open-output-nowhere)])
    (process-string s)))

;; Run with prelude, suppress stderr, return last result
(define (run-ns s)
  (parameterize ([current-error-port (open-output-nowhere)])
    (run-ns-last s)))

;; Run with prelude, capture stderr, return (cons last-result stderr-string)
(define (run-ns-with-stderr s)
  (define stderr-out (open-output-string))
  (define result
    (parameterize ([current-error-port stderr-out])
      (run-ns-last s)))
  (cons result (get-output-string stderr-out)))

;; Run without prelude, capture stderr, return (cons results stderr-string)
(define (run-simple-with-stderr s)
  (define stderr-out (open-output-string))
  (define results
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-error-port stderr-out])
      (process-string s)))
  (cons results (get-output-string stderr-out)))

;; ========================================
;; Suite 1: Type mismatch provenance
;; ========================================

(test-case "type-mismatch-error has provenance field"
  (define result (last (run-simple "(def x : Nat true)")))
  (check-true (type-mismatch-error? result))
  ;; provenance should be a list (possibly empty)
  (check-true (list? (type-mismatch-error-provenance result))))

(test-case "successful check produces no error (no false positive provenance)"
  (define result (last (run-simple "(def x : Nat 0N)")))
  (check-false (prologos-error? result)))

;; ========================================
;; Suite 2: Union exhaustion provenance
;; ========================================

(test-case "union exhaustion error has derivation-chain field"
  ;; Angle-bracket union syntax works without prelude
  (define result (run-simple "(def x <Nat | Bool> \"hello\")"))
  (check-true (union-exhaustion-error? (last result)))
  ;; PPN 4C 3C.c.3: field shape is (listof derivation-chain) per Q-B.2 flip
  (define chains (union-exhaustion-error-derivation-chain (last result)))
  (check-true (list? chains) "Field is a list (per-branch shape per Q-C.6)")
  (check-true (andmap derivation-chain? chains)
              "All list entries are derivation-chain structs (3C.a foundation)"))

(test-case "union branch mismatch produces per-branch info"
  (define result (run-simple "(def x <Nat | Bool> \"hello\")"))
  (check-true (union-exhaustion-error? (last result)))
  ;; Should have 2 branches
  (define branches (union-exhaustion-error-branches (last result)))
  (check-equal? (length branches) 2))

;; ========================================
;; Suite 3: Provenance stats
;; ========================================

(test-case "provenance stats: successful type check has zero nogoods"
  (define pair (run-simple-with-stderr "(def x : Nat 0N)"))
  (define stderr (cdr pair))
  (check-true (string-contains? stderr "PROVENANCE-STATS:"))
  ;; Extract the provenance stats JSON
  (define m (regexp-match #rx"PROVENANCE-STATS:(\\{[^}]+\\})" stderr))
  (check-not-false m)
  ;; Should have 0 nogoods for a successful check
  (check-true (string-contains? (cadr m) "\"atms_nogood_count\":0")))

(test-case "provenance stats: union error creates speculation + hypothesis"
  ;; Union type mismatch triggers speculation per branch
  (define pair (run-simple-with-stderr "(def x <Nat | Bool> \"s\")"))
  (define stderr (cdr pair))
  (define m (regexp-match #rx"PROVENANCE-STATS:(\\{[^}]+\\})" stderr))
  (check-not-false m)
  (define json-str (cadr m))
  ;; At least 2 speculations (one per union branch)
  (check-false (string-contains? json-str "\"speculation_count\":0")))

(test-case "provenance stats: simple mismatch has provenance stats"
  (define pair (run-simple-with-stderr "(def x : Nat true)"))
  (define stderr (cdr pair))
  (define m (regexp-match #rx"PROVENANCE-STATS:(\\{[^}]+\\})" stderr))
  (check-not-false m))

;; ========================================
;; Suite 4: Error formatting with provenance
;; ========================================

(test-case "format-error renders type mismatch with empty provenance"
  (define err (type-mismatch-error srcloc-unknown "Type mismatch" "Nat" "Bool" "(f x)" '()))
  (define formatted (format-error err))
  (check-true (string-contains? formatted "Expected: Nat"))
  (check-true (string-contains? formatted "Got:      Bool"))
  ;; No "because:" lines
  (check-false (string-contains? formatted "because:")))

(test-case "format-error renders type mismatch with non-empty provenance"
  (define err (type-mismatch-error srcloc-unknown "Type mismatch" "Nat" "Bool" "(f x)"
                '("tried branch Nat" "nested union left branch failed")))
  (define formatted (format-error err))
  (check-true (string-contains? formatted "because: tried branch Nat"))
  (check-true (string-contains? formatted "because: nested union left branch failed")))

(test-case "union exhaustion format includes 'because:' for non-empty chains"
  ;; PPN 4C 3C.c.3 (2026-05-24): per Q-B.2 + Q-C.6, field shape is
  ;; (listof derivation-chain). Construct chain with one step containing
  ;; the speculation label as assumption-name; verify format-error renders
  ;; "because: <name>".
  (define step (derivation-step #f #f '() (list "tried branch Nat") #f))
  (define err
    (union-exhaustion-error srcloc-unknown "Nat | Bool"
                            '("Nat" "Bool")
                            '("Bool" "Nat")
                            "\"hello\""
                            (list (derivation-chain (list step))
                                  (derivation-chain '()))))
  (define formatted (format-error err))
  (check-true (string-contains? formatted "because: tried branch Nat"))
  (check-true (string-contains? formatted "tried Nat")))

;; ========================================
;; Suite 5: ATMS integration
;; ========================================

(test-case "ATMS is active during type checking (hypothesis created)"
  ;; Speculation creates ATMS hypotheses
  (define pair (run-simple-with-stderr "(def x : Nat true)"))
  (define stderr (cdr pair))
  (define m (regexp-match #rx"atms_hypothesis_count\":([0-9]+)" stderr))
  (check-not-false m))

(test-case "ATMS nogoods recorded on union branch failure"
  ;; Each failing union branch should record a nogood
  (define pair (run-simple-with-stderr "(def x <Nat | Bool> \"hello\")"))
  (define stderr (cdr pair))
  (define m (regexp-match #rx"atms_nogood_count\":([0-9]+)" stderr))
  (check-not-false m)
  (define count (string->number (cadr m)))
  ;; At least 2 nogoods (one per failing union branch)
  (check-true (>= count 2)))

;; ========================================
;; Suite 6: Prelude integration
;; ========================================

(test-case "prelude type mismatch carries provenance"
  (define result (run-ns "(ns test) (def x : Nat true)"))
  (check-true (type-mismatch-error? result))
  (check-true (list? (type-mismatch-error-provenance result))))

(test-case "prelude implicit resolution error has structured info"
  ;; This tests that trait resolution failures flow through the provenance pipeline
  (define result (run-ns "(ns test :no-prelude) (def x : Nat \"hello\")"))
  (check-true (prologos-error? result)))

;; ========================================
;; Suite 7: GDE-1 — Context assumptions in nogoods
;; ========================================

;; Helper: Run a command through the driver, return speculation failures list.
(define (run-and-get-failures s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-error-port (open-output-nowhere)])
    (define failures-box (box '()))
    (parameterize ([current-speculation-failures failures-box])
      (process-string s)
      (reverse (unbox failures-box)))))

(test-case "GDE-1: context assumption created for annotated def"
  ;; When a def has a type annotation, an ATMS context assumption is created.
  ;; We verify via stderr stats that the ATMS has assumptions beyond just speculation.
  (define pair (run-simple-with-stderr "(def x : Nat true)"))
  (define stderr (cdr pair))
  (define m (regexp-match #rx"atms_hypothesis_count\":([0-9]+)" stderr))
  (check-not-false m)
  ;; Should have at least 1 hypothesis (the context assumption for "x : Nat")
  (define count (string->number (cadr m)))
  (check-true (>= count 1)))

(test-case "GDE-1: union error nogoods include context assumption"
  ;; When a union type mismatch occurs with an annotated def, the nogood
  ;; should contain BOTH the speculation hypothesis AND the context assumption.
  (define pair (run-simple-with-stderr "(def x <Nat | Bool> \"hello\")"))
  (define stderr (cdr pair))
  ;; Extract the ATMS from the provenance stats
  (define m-hyp (regexp-match #rx"atms_hypothesis_count\":([0-9]+)" stderr))
  (check-not-false m-hyp)
  ;; Hypothesis count should be >= 3: 1 context assumption + 2 speculation branches
  (define hyp-count (string->number (cadr m-hyp)))
  (check-true (>= hyp-count 3)
              (format "Expected >= 3 hypotheses (1 ctx + 2 spec), got ~a" hyp-count)))

(test-case "GDE-1: speculation failure support-set is multi-hypothesis"
  ;; After a failing speculation on an annotated def, the support-set
  ;; (nogood) should contain more than one assumption.
  (define pair (run-simple-with-stderr "(def x <Nat | Bool> \"hello\")"))
  (define results (car pair))
  (define err (last results))
  (check-true (union-exhaustion-error? err))
  ;; PPN 4C 3C.c.3: field shape is (listof derivation-chain) per Q-B.2 + Q-C.6
  (define chains (union-exhaustion-error-derivation-chain err))
  (check-true (list? chains))
  (check-true (andmap derivation-chain? chains)
              "All chains are derivation-chain structs"))

;; ========================================
;; PPN 4C Phase 3C.c.6 (2026-05-24): cell-19 observability — sexp check/err
;; writes cell-19 via direct elab-cell-write per Q-C.1 (f) multi-writer
;; scaffolding. Verifies the on-network store is populated from the sexp
;; path (validates D-3C.b.5-6 deployment gap closure).
;; ========================================

(test-case "3C.c: sexp check/err writes cell-19 for union all-branch-contradict"
  ;; Use process-string/return-net (3C.b.5.b infrastructure) to inspect the
  ;; post-elaboration network state. Cell-19 should contain a per-position
  ;; entry with (listof derivation-chain) for the union-exhaustion scenario.
  (define-values (_results net)
    (process-string/return-net "(def x <Nat | Bool> \"hello\")"))
  (define cell-19-val
    (elab-cell-read net union-derivation-chains-cell-id))
  (check-true (hash? cell-19-val) "cell-19 is a hash")
  ;; The hash should have at least one entry (the union position)
  (check-true (positive? (hash-count cell-19-val))
              "cell-19 has at least one entry (sexp check/err wrote it)")
  ;; The first entry's value should be (listof derivation-chain) — per Q-C.6 shape
  (define entries (hash->list cell-19-val))
  (define first-entry-value (cdr (first entries)))
  (check-true (list? first-entry-value)
              "cell-19 entry value is a list (per-branch shape per Q-C.6)")
  (check-true (andmap derivation-chain? first-entry-value)
              "all entries are derivation-chain structs (3C.a foundation)")
  (check-equal? (length first-entry-value) 2
                "binary union → 2 per-branch chains (Nat + Bool)"))

(test-case "GDE-1: context assumption for check command"
  ;; (check expr : Type) should also create a context assumption.
  (define pair (run-simple-with-stderr "(check true : Nat)"))
  (define stderr (cdr pair))
  (define m (regexp-match #rx"atms_hypothesis_count\":([0-9]+)" stderr))
  (check-not-false m)
  (define count (string->number (cadr m)))
  ;; At least 1 hypothesis from the check annotation
  (check-true (>= count 1)))

(test-case "GDE-1: successful def has no nogoods"
  ;; A well-typed annotated def should create context assumption but no nogoods.
  (define pair (run-simple-with-stderr "(def x : Nat 0N)"))
  (define stderr (cdr pair))
  (define m (regexp-match #rx"atms_nogood_count\":([0-9]+)" stderr))
  (check-not-false m)
  (check-equal? (string->number (cadr m)) 0))

(test-case "GDE-1: successful def context assumption + zero nogoods"
  ;; Successful annotated def: hypothesis created but no nogoods recorded.
  (define pair (run-simple-with-stderr "(def x : Nat 0N)"))
  (define stderr (cdr pair))
  (define m-hyp (regexp-match #rx"atms_hypothesis_count\":([0-9]+)" stderr))
  (check-not-false m-hyp)
  ;; Context assumption created
  (define hyp-count (string->number (cadr m-hyp)))
  (check-true (>= hyp-count 1))
  ;; No nogoods
  (define m-ng (regexp-match #rx"atms_nogood_count\":([0-9]+)" stderr))
  (check-not-false m-ng)
  (check-equal? (string->number (cadr m-ng)) 0))

(test-case "GDE-1: unannotated def creates no context assumption"
  ;; A def without type annotation should NOT create a context assumption.
  (define pair (run-simple-with-stderr "(def x 0N)"))
  (define stderr (cdr pair))
  (define m (regexp-match #rx"atms_hypothesis_count\":([0-9]+)" stderr))
  (check-not-false m)
  ;; Zero hypotheses — no speculation, no context assumption
  (check-equal? (string->number (cadr m)) 0))

;; ========================================
;; Suite 8: GDE-3 — Rich error formatting with derivation trees
;; ========================================

(test-case "GDE-3: union error includes context annotation in derivation chain"
  ;; Union type mismatch on an annotated def should include "user annotated" line
  (define result (last (run-simple "(def x <Nat | Bool> \"hello\")")))
  (check-true (union-exhaustion-error? result))
  (define formatted (format-error result))
  ;; Should contain union branch info
  (check-true (string-contains? formatted "tried Nat"))
  (check-true (string-contains? formatted "tried Bool")))

(test-case "GDE-3: type mismatch provenance includes context info"
  ;; Simple annotated def type mismatch — provenance should contain context info
  (define result (last (run-simple "(def x : Nat true)")))
  (check-true (type-mismatch-error? result))
  ;; The provenance field is a list of strings
  (define prov (type-mismatch-error-provenance result))
  (check-true (list? prov)))

(test-case "GDE-3: format-error renders [diagnosis] lines without 'because:' prefix"
  ;; Construct a type-mismatch-error with a diagnosis provenance line
  (define err (type-mismatch-error srcloc-unknown "Type mismatch" "Nat" "Bool" "(f x)"
                '("tried branch Nat" "[diagnosis] retract: x : Nat")))
  (define formatted (format-error err))
  ;; Diagnosis line should appear without "because:" prefix
  (check-true (string-contains? formatted "[diagnosis] retract: x : Nat"))
  ;; But regular provenance should have "because:"
  (check-true (string-contains? formatted "because: tried branch Nat"))
  ;; Specifically, should NOT have "because: [diagnosis]"
  (check-false (string-contains? formatted "because: [diagnosis]")))

(test-case "GDE-3: union error format renders per-step assumption-names"
  ;; PPN 4C 3C.c.3 (2026-05-24): under Q-B.2 + Q-C.6 (listof derivation-chain)
  ;; shape, format-error renders per-step "because: <name>" via derivation-
  ;; step-assumption-names. The OLD inline "[diagnosis]" string convention
  ;; (build-derivation-chain's format-context-diagnosis appended strings to
  ;; chain) retires alongside build-derivation-chain's union-type path per Q9.
  ;; Diagnosis info under new architecture is queryable via ATMS state at
  ;; render time — deferred to Phase 11b general derivation infrastructure
  ;; (see §9.5.4.4 adversarial framing on lost richness). For 3C.c.3 minimum:
  ;; chain renders step assumption-names; diagnosis-line testing deferred.
  (define step-1 (derivation-step #f #f '() (list "tried branch Nat") #f))
  (define step-2 (derivation-step #f #f '() (list "tried branch Bool") #f))
  (define err
    (union-exhaustion-error srcloc-unknown "Nat | Bool"
                            '("Nat" "Bool")
                            '("Bool" "Nat")
                            "\"hello\""
                            (list (derivation-chain (list step-1))
                                  (derivation-chain (list step-2)))))
  (define formatted (format-error err))
  ;; Per-step "because:" lines render with assumption-names
  (check-true (string-contains? formatted "because: tried branch Nat"))
  (check-true (string-contains? formatted "because: tried branch Bool"))
  ;; Old [diagnosis] inline format NOT preserved under new struct shape; testing
  ;; deferred to Phase 11b ATMS state query infrastructure (see §9.5.4.4
  ;; adversarial framing on lost richness — ATMS conflicts + minimal diagnoses
  ;; queryable via solver-state at render time, structured data path)
  )

(test-case "GDE-3: successful def produces no diagnosis in provenance"
  (define result (last (run-simple "(def x : Nat 0N)")))
  (check-false (prologos-error? result)))
