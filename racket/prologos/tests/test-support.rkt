#lang racket/base

;;;
;;; Shared test support: pre-loaded prelude for fast test execution.
;;;
;;; Instead of each test case reloading ~84 prelude modules from .prologos
;;; source (~3s per call), this module loads the prelude ONCE at require
;;; time and exports cached registries. Test cases reuse the module cache
;;; while maintaining full isolation via fresh global-env/ns-context/meta-store.
;;;
;;; Usage in test files:
;;;   (require "test-support.rkt")
;;;   ;; Then use run-ns-last, run-ns-all, or the prelude-* values directly.
;;;

(require racket/list
         racket/file
         racket/os
         racket/path
         racket/port
         racket/string
         rackunit
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         (only-in "../reduction.rkt" current-reduction-fuel-budget)
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../warnings.rkt"           ;; Track 7 Phase 6d: init-warning-cells!
         "../global-constraints.rkt"  ;; Track 7 Phase 6d: init-narrow-cells!
         (only-in "../propagator.rkt" with-forked-network) ;; Track 10 Phase 3c: network fork
         ;; Rel T1: the relation store is a parameter, and `pipeline.md`
         ;; § "New Racket Parameter" names THIS FILE and batch-worker.rkt as
         ;; items 2 and 3 of the checklist. It was in neither, so `solve` in a
         ;; `run-ns*` context saw a store that was not the ambient one — typing
         ;; as untyped where production types, silently. Instance #7 of that
         ;; class.
         (only-in "../relations.rkt" current-relation-store))

(provide ;; G2/B — preparse failures are VALUES now, not raises
         yields-prologos-error?
         ;; Pre-loaded prelude registries
         prelude-module-registry
         prelude-trait-registry
         prelude-impl-registry
         prelude-param-impl-registry
         prelude-preparse-registry
         prelude-capability-registry
         prelude-persistent-registry-net-box  ;; Track 7 Phase 6d
         prelude-lib-dir
         ;; Convenience helpers
         run-ns-last
         run-ns-all
         ;; WS-mode helpers (primary design target)
         run-ns-ws-last
         run-ns-ws-all
         ;; GDE-4: Structured error testing helpers
         check-error-has-provenance
         check-error-diagnosis-count
         extract-provenance-json
         run-simple-capture-stderr
         ;; Rich failure diagnostics: custom check with provenance
         check-prologos
         error-provenance-summary
         ;; Collision-free scratch files for WS-mode (process-file) tests
         make-prologos-temp-file)

;; ========================================
;; Temp files for WS-mode tests
;; ========================================
;;
;; 23 test files drive `process-file` through a scratch `.prologos` file, and
;; every one of them used the SAME `make-temporary-file` template. That is
;; safe within a process -- Racket disambiguates with a counter -- but the
;; counter is per-process, and the suite runs four batch workers. Two workers
;; landing in the same millisecond generate the same name, and the loser dies
;; with
;;
;;     open-output-file: file exists
;;       path: /var/tmp/prologos-test-17852384651785238465047.prologos
;;
;; then fails somewhere unrelated -- the observed symptom was
;; "Unbound variable: <" in a mixfix test, because the file it went on to read
;; was not the one it meant to write.
;;
;; It is load-dependent and rare, so it presents as a test that "passes
;; individually, fails in batch, sometimes" -- which is also the signature of
;; two genuine architectural bugs in this project (the collection-path trap and
;; parameter leakage), and it cost a wrong diagnosis before being read
;; properly. Two sightings: test-mixfix-01 on CI (2026-07-27) and
;; test-mixfix-02 locally (2026-07-28).
;;
;; The PID makes the name unique across workers; the counter keeps it unique
;; within one.
(define (make-prologos-temp-file)
  (make-temporary-file (format "prologos-test-~a-~~a.prologos" (getpid))))

;; ========================================
;; Compute lib-dir from this file's location
;; ========================================
(define here (path->string (path-only (syntax-source #'here))))
(define prelude-lib-dir (simplify-path (build-path here ".." "lib")))

;; ========================================
;; Load prelude once and capture registries
;; ========================================
;; This runs at module load time (once per test subprocess).
;; Captures the module registry (parsed/elaborated module ASTs),
;; trait/impl registries, and preparse registry.

(define-values (prelude-module-registry
                prelude-trait-registry
                prelude-impl-registry
                prelude-param-impl-registry
                prelude-preparse-registry
                prelude-capability-registry
                prelude-persistent-registry-net-box)  ;; Track 7 Phase 6d
  (parameterize ([current-file-module-network-ref (make-module-network)]  ;; PPN 4C Addendum Phase 4A.b: fresh per-file mnr
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-capability-registry (current-capability-registry)]
                 ;; SH step 4: the per-command reduction-fuel BUDGET. Reset per
                 ;; test so a file that raises it for a server loop cannot leak
                 ;; the raised value into the next file's commands, where a
                 ;; divergent term would spin instead of erroring.
                 [current-reduction-fuel-budget (current-reduction-fuel-budget)]
                 ;; CIU T6 F1b.5-s1d: the five registry params added to the
                 ;; macros snapshot (pipeline.md New-Parameter checklist parity)
                 [current-schema-registry (current-schema-registry)]
                 [current-selection-registry (current-selection-registry)]
                 [current-session-registry (current-session-registry)]
                 [current-strategy-registry (current-strategy-registry)]
                 [current-process-registry (current-process-registry)]
                 ;; Track 6 Phase 7a: network isolation (fresh network per call)
                 [current-prop-net-box              #f]
                 [current-persistent-registry-net-box #f]  ;; #f during prelude load; created below
                 [current-ns-prop-net-box           #f]
                 [current-module-registry-cell-id   #f]
                 [current-ns-context-cell-id        #f]
                 )
    (install-module-loader!)
    (process-string "(ns prelude-cache)\n")
    ;; Track 7 Phase 6d: Initialize persistent registry network from post-prelude params.
    ;; This captures all prelude registrations (traits, impls, ctors, etc.) into
    ;; persistent cells, so test fixtures can use cell-primary reads without fallback.
    (init-persistent-registry-network!)
    (define prn-box (current-persistent-registry-net-box))
    (when prn-box
      (init-macros-cells! prn-box)
      (init-warning-cells! prn-box)
      (init-narrow-cells! prn-box))
    (values (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-preparse-registry)
            (current-capability-registry)
            (current-persistent-registry-net-box))))

;; ========================================
;; Fast test helpers using cached prelude
;; ========================================

;; Process a string in a fresh namespace using cached prelude modules.
;; Returns the LAST result (like the common run-ns-last pattern).
;; Each call gets a fresh global-env, ns-context, and meta-store for isolation.
(define (run-ns-last s)
  ;; Track 10 Phase 3c: Network isolation via fork.
  ;; Network-related params replaced by with-forked-network (8 params → 1 fork).
  ;; Registry params remain until Phase 6 migrates them to cells.
  (parameterize ([current-file-module-network-ref (make-module-network)]  ;; PPN 4C Addendum Phase 4A.b: fresh per-file mnr
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 ;; Track 10 Phase 3c: fork replaces 8 network params
                 [current-persistent-registry-net-box prelude-persistent-registry-net-box]  ;; Track 7 Phase 6d
                 ;; Immutable hasheq, so binding the current value is a full
                 ;; per-call isolation: a `defr` inside the call rebinds a NEW
                 ;; store and cannot escape.
                 [current-relation-store (current-relation-store)]
                 [current-module-registry-cell-id   #f]
                 [current-ns-context-cell-id        #f]
                 )
    (with-forked-network current-prop-net-box
     ;; …and the PERSISTENT REGISTRY network too. Forking only the prop net
     ;; left the cell-backed registries (spec store, preparse registry, schema
     ;; registry) on ONE shared network for the life of the batch-worker
     ;; process, and `spec-store-lookup` reads the CELL FIRST
     ;; (macros.rkt:496) — so a `spec` registered by one test FILE was still
     ;; there for the next. The per-file snapshot the worker takes restores
     ;; the `current-spec-store` PARAMETER, which the cell read never
     ;; consults; the dual-write is what hid it.
     ;;
     ;; Forking from the prelude box keeps everything the prelude registered
     ;; and discards what this call writes.
     (with-forked-network current-persistent-registry-net-box
        (install-module-loader!)
        (last (process-string s))))))

;; Process a string and return ALL results (list).
(define (run-ns-all s)
  (parameterize ([current-file-module-network-ref (make-module-network)]  ;; PPN 4C Addendum Phase 4A.b: fresh per-file mnr
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 ;; Track 10 Phase 3c: fork replaces 8 network params
                 [current-persistent-registry-net-box prelude-persistent-registry-net-box]  ;; Track 7 Phase 6d
                 ;; Immutable hasheq, so binding the current value is a full
                 ;; per-call isolation: a `defr` inside the call rebinds a NEW
                 ;; store and cannot escape.
                 [current-relation-store (current-relation-store)]
                 [current-module-registry-cell-id   #f]
                 [current-ns-context-cell-id        #f]
                 )
    (with-forked-network current-prop-net-box
     ;; …and the PERSISTENT REGISTRY network too. Forking only the prop net
     ;; left the cell-backed registries (spec store, preparse registry, schema
     ;; registry) on ONE shared network for the life of the batch-worker
     ;; process, and `spec-store-lookup` reads the CELL FIRST
     ;; (macros.rkt:496) — so a `spec` registered by one test FILE was still
     ;; there for the next. The per-file snapshot the worker takes restores
     ;; the `current-spec-store` PARAMETER, which the cell read never
     ;; consults; the dual-write is what hid it.
     ;;
     ;; Forking from the prelude box keeps everything the prelude registered
     ;; and discards what this call writes.
     (with-forked-network current-persistent-registry-net-box
        (install-module-loader!)
        (process-string s)))))

;; ========================================
;; WS-mode helpers (primary design target)
;; ========================================
;; Like run-ns-last/run-ns-all but using the WS reader (indentation-sensitive).
;; This is the path that .prologos files use.

(define (run-ns-ws-last s)
  (parameterize ([current-file-module-network-ref (make-module-network)]  ;; PPN 4C Addendum Phase 4A.b: fresh per-file mnr
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 ;; Track 10 Phase 3c: fork replaces 8 network params
                 [current-persistent-registry-net-box prelude-persistent-registry-net-box]  ;; Track 7 Phase 6d
                 ;; Immutable hasheq, so binding the current value is a full
                 ;; per-call isolation: a `defr` inside the call rebinds a NEW
                 ;; store and cannot escape.
                 [current-relation-store (current-relation-store)]
                 [current-module-registry-cell-id   #f]
                 [current-ns-context-cell-id        #f]
                 )
    (with-forked-network current-prop-net-box
     ;; …and the PERSISTENT REGISTRY network too. Forking only the prop net
     ;; left the cell-backed registries (spec store, preparse registry, schema
     ;; registry) on ONE shared network for the life of the batch-worker
     ;; process, and `spec-store-lookup` reads the CELL FIRST
     ;; (macros.rkt:496) — so a `spec` registered by one test FILE was still
     ;; there for the next. The per-file snapshot the worker takes restores
     ;; the `current-spec-store` PARAMETER, which the cell read never
     ;; consults; the dual-write is what hid it.
     ;;
     ;; Forking from the prelude box keeps everything the prelude registered
     ;; and discards what this call writes.
     (with-forked-network current-persistent-registry-net-box
        (install-module-loader!)
        (last (process-string-ws s))))))

(define (run-ns-ws-all s)
  (parameterize ([current-file-module-network-ref (make-module-network)]  ;; PPN 4C Addendum Phase 4A.b: fresh per-file mnr
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 ;; Track 10 Phase 3c: fork replaces 8 network params
                 [current-persistent-registry-net-box prelude-persistent-registry-net-box]  ;; Track 7 Phase 6d
                 ;; Immutable hasheq, so binding the current value is a full
                 ;; per-call isolation: a `defr` inside the call rebinds a NEW
                 ;; store and cannot escape.
                 [current-relation-store (current-relation-store)]
                 [current-module-registry-cell-id   #f]
                 [current-ns-context-cell-id        #f]
                 )
    (with-forked-network current-prop-net-box
     ;; …and the PERSISTENT REGISTRY network too. Forking only the prop net
     ;; left the cell-backed registries (spec store, preparse registry, schema
     ;; registry) on ONE shared network for the life of the batch-worker
     ;; process, and `spec-store-lookup` reads the CELL FIRST
     ;; (macros.rkt:496) — so a `spec` registered by one test FILE was still
     ;; there for the next. The per-file snapshot the worker takes restores
     ;; the `current-spec-store` PARAMETER, which the cell read never
     ;; consults; the dual-write is what hid it.
     ;;
     ;; Forking from the prelude box keeps everything the prelude registered
     ;; and discards what this call writes.
     (with-forked-network current-persistent-registry-net-box
        (install-module-loader!)
        (process-string-ws s)))))

;; ========================================
;; GDE-4: Structured error testing helpers
;; ========================================

;; Run without prelude, capture stderr. Returns (cons results stderr-string).
(define (run-simple-capture-stderr s)
  (define stderr-out (open-output-string))
  (define results
    (parameterize ([current-file-module-network-ref (make-module-network)]  ;; PPN 4C Addendum Phase 4A.b: fresh per-file mnr
                   [current-error-port stderr-out]
                   ;; Track 10 Phase 3c: fork replaces 8 network params
                   [current-persistent-registry-net-box prelude-persistent-registry-net-box]  ;; Track 7 Phase 6d
                 ;; Immutable hasheq, so binding the current value is a full
                 ;; per-call isolation: a `defr` inside the call rebinds a NEW
                 ;; store and cannot escape.
                 [current-relation-store (current-relation-store)]
                   [current-module-registry-cell-id   #f]
                   [current-ns-context-cell-id        #f]
                   )
      (with-forked-network current-prop-net-box
     ;; …and the PERSISTENT REGISTRY network too. Forking only the prop net
     ;; left the cell-backed registries (spec store, preparse registry, schema
     ;; registry) on ONE shared network for the life of the batch-worker
     ;; process, and `spec-store-lookup` reads the CELL FIRST
     ;; (macros.rkt:496) — so a `spec` registered by one test FILE was still
     ;; there for the next. The per-file snapshot the worker takes restores
     ;; the `current-spec-store` PARAMETER, which the cell read never
     ;; consults; the dual-write is what hid it.
     ;;
     ;; Forking from the prelude box keeps everything the prelude registered
     ;; and discards what this call writes.
     (with-forked-network current-persistent-registry-net-box
          (process-string s)))))
  (cons results (get-output-string stderr-out)))

;; Assert that an error has a non-empty provenance field.
;; Works for type-mismatch-error (provenance field) and union-exhaustion-error (derivation-chain).
;; Returns #t if provenance is non-empty, #f otherwise.
(define (check-error-has-provenance err)
  (cond
    [(type-mismatch-error? err)
     (define prov (type-mismatch-error-provenance err))
     (and (list? prov) (pair? prov))]
    [(union-exhaustion-error? err)
     (define chain (union-exhaustion-error-derivation-chain err))
     (and (list? chain) (ormap pair? chain))]
    [else #f]))

;; Count the number of diagnosis entries in an error's provenance.
;; Diagnosis lines start with "[diagnosis]".
(define (check-error-diagnosis-count err)
  (define provenance
    (cond
      [(type-mismatch-error? err) (type-mismatch-error-provenance err)]
      [(union-exhaustion-error? err)
       (apply append (union-exhaustion-error-derivation-chain err))]
      [else '()]))
  (length (filter (lambda (s) (and (string? s) (string-prefix? s "[diagnosis]")))
                  provenance)))

;; Extract PROVENANCE-STATS JSON from stderr string.
;; Returns a hash of key→value (string keys, number values) or #f if not found.
;; When multiple PROVENANCE-STATS lines exist (one per command), returns the LAST one.
(define (extract-provenance-json stderr)
  ;; Find all PROVENANCE-STATS lines and use the last one
  (define all-matches
    (regexp-match* #rx"PROVENANCE-STATS:\\{([^}]+)\\}" stderr #:match-select cadr))
  (cond
    [(null? all-matches) #f]
    [else
     (define json-body (last all-matches))
     ;; Extract "key":number pairs
     (define pair-matches
       (regexp-match* #rx"\"([^\"]+)\":([0-9]+)" json-body #:match-select cdr))
     (for/hash ([pair (in-list pair-matches)])
       (values (car pair) (string->number (cadr pair))))]))

;; ========================================
;; Rich failure diagnostics: custom check
;; ========================================

;; Summarize provenance information from a prologos-error.
;; Returns a human-readable string with derivation chain details.
(define (error-provenance-summary err)
  (cond
    [(type-mismatch-error? err)
     (define prov (type-mismatch-error-provenance err))
     (if (and (list? prov) (pair? prov))
         (string-join prov "\n")
         "(no provenance)")]
    [(union-exhaustion-error? err)
     (define chain (union-exhaustion-error-derivation-chain err))
     (if (and (list? chain) (ormap pair? chain))
         (string-join
          (for/list ([branch-chain (in-list chain)]
                     [i (in-naturals 1)])
            (if (pair? branch-chain)
                (format "branch ~a:\n  ~a" i (string-join branch-chain "\n  "))
                (format "branch ~a: (no chain)" i)))
          "\n")
         "(no derivation chain)")]
    [else "(no provenance for this error type)"]))

;; Custom check: drop-in replacement for check-equal? that enriches
;; failure output with formatted prologos errors and provenance chains.
;;
;; When actual is a prologos-error and expected is a string (common pattern),
;; the failure message shows the formatted error with "because:" chains
;; instead of just the opaque struct representation.
;;
;; Usage: (check-prologos (run-last "(def x : Nat 0N)") "x : Nat defined.")
(define-check (check-prologos actual expected)
  (unless (equal? actual expected)
    (with-check-info*
      (append
        (list (make-check-info 'expected expected)
              (make-check-info 'actual actual))
        (if (prologos-error? actual)
            (list (make-check-info 'formatted-error (format-error actual))
                  (make-check-info 'provenance (error-provenance-summary actual)))
            '())
        (if (prologos-error? expected)
            (list (make-check-info 'expected-formatted (format-error expected)))
            '()))
      (lambda () (fail-check "prologos result mismatch")))))


;; ---------------------------------------------------------------------------
;; CIU T6 D4.P4c-4c / G2 (option B, owner ruling 2026-08-05) — THE ASSERTION FOR
;; A PREPARSE SYNTAX FAILURE.
;;
;; Preparse used to RAISE on a malformed declaration, which escaped `process-file`
;; and took the whole file with it — `pipeline.md` § "A Raise on the Parse/
;; Expansion Path Is a WHOLE-FILE Abort", five instances in the CIU T6 track. The
;; seam is now guarded: a raise becomes a `($preparse-error msg)` marker and the
;; parser converts it to a per-command error VALUE, so the file continues.
;;
;; Consequence for tests: every `(check-exn exn:fail? (lambda () (run …)))` that
;; pinned one of those raises now sees a RESULT, not an exception. The proposition
;; those pins assert — "this malformed declaration is REFUSED, not silently
;; accepted" — is unchanged, so they are re-expressed through this helper rather
;; than deleted. 20 assertions across 9 files at the conversion.
;;
;; Accepts whatever the caller's own runner returns — a list of results, a single
;; result, or a thunk producing either — because the test files disagree about
;; that and a helper that only handles one shape would just move the problem.
;; ⚠ A raise still counts as a refusal: some malformed shapes fail BEFORE the
;; guarded seam (in the reader), and this helper must not turn "still aborts" into
;; a green pin by accident — it reports the truth for both channels.
(define (yields-prologos-error? v)
  (define (scan x)
    (cond [(prologos-error? x) #t]
          [(list? x) (ormap scan x)]
          [else #f]))
  (cond
    [(procedure? v)
     (with-handlers ([exn:fail? (lambda (_) #t)])   ; a surviving raise IS a refusal
       (scan (v)))]
    [else (scan v)]))
