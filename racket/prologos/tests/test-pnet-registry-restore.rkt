#lang racket/base

;;;
;;; PM Track 10 — `.pnet` cache-hit registry restore (GitHub issue #78)
;;;
;;; The cache-hit restore path writes deserialized registries to Racket
;;; PARAMETERS only, while all 24 registry readers are CELL-primary. Because an
;;; empty hasheq is truthy, the parameter fallback is unreachable once the cells
;;; exist — so every entry restored from a cache hit is invisible to every
;;; reader, silently.
;;;
;;; Design: docs/tracking/2026-07-27_PM_T10_PNET_REGISTRY_RESTORE_DEFECT_DESIGN.md
;;;
;;; ── WHY THIS TEST IS SHAPED THE WAY IT IS ──────────────────────────────────
;;; Three verified masking mechanisms make the naive test PASS while the bug is
;;; fully live. Each anti-masking measure below is load-bearing; do not
;;; "simplify" one away without re-confirming the test still fails at the
;;; pre-fix commit.
;;;
;;;  M1. The cache-MISS elaboration of run 1 DUAL-WRITES the lib's entries into
;;;      the live cells (macros.rkt register-ctor!), so by run 2 the cells
;;;      already know the module and the param-only restore is invisible-but-
;;;      harmless.  ⇒ we reset the cells between runs.
;;;  M2. `init-macros-cells!` RE-SEEDS the cells from the PARAMETERS, and the
;;;      buggy restore has already polluted those parameters. Resetting the
;;;      cells alone therefore restores the very entries we are trying to
;;;      remove.  ⇒ we reset under CLEAN parameter snapshots captured before
;;;      any lib load.
;;;  M3. If the cells do NOT exist at all, `macros-cell-read-safe` returns #f
;;;      and the parameter fallback is LIVE — which is what masks the defect.
;;;      A `process-string`-only test, or a fresh subprocess, is therefore
;;;      MAXIMALLY masked, not minimally.  ⇒ the cells must EXIST and be
;;;      IGNORANT. The `cells-ignorant?` assertion below is the gate that
;;;      proves we reached that state; it is part of the test, not setup.
;;;
;;; Plus: run 2 must actually be a cache HIT (a MISS produces the CORRECT
;;; answer, so the test would pass while proving nothing) — asserted directly
;;; via `pnet-stale?`.
;;;

(require rackunit
         racket/list
         racket/file
         racket/path
         racket/string
         "test-support.rkt"
         "../macros.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../warnings.rkt"
         "../global-constraints.rkt"
         "../typing-propagators.rkt"
         (only-in "../pnet-serialize.rkt" pnet-path-for-module pnet-stale?))

;; ========================================
;; Fixture: a temp lib with a `data` + multi-arity `defn`
;; ========================================
;; The NON-FIRST arm is the whole point: when ctor lookup misses,
;; `normalize-pattern` silently keeps `t1`/`t2` as catch-all VARIABLES, so the
;; FIRST arm swallows everything. A first-arm assertion passes even when fully
;; degraded — only a non-first arm detects it.

(define temp-lib-dir (make-temporary-file "prologos-pnet78-~a" 'directory))
(define dep-ns 'pnet78dep)
(define use-ns 'pnet78use)

(call-with-output-file (build-path temp-lib-dir "pnet78dep.prologos") #:exists 'replace
  (lambda (out)
    (display (string-append
              "ns pnet78dep\n"
              "\n"
              "data Tag\n"
              "  t1\n"
              "  t2\n"
              "\n"
              "spec tag-name Tag -> String\n"
              "defn tag-name\n"
              "  | t1 -> \"one\"\n"
              "  | t2 -> \"two\"\n")
             out)))

;; A dependent module that is elaborated FRESH while its dependency comes from
;; the cache — the severity-2 (silent wrong answer) shape.
(call-with-output-file (build-path temp-lib-dir "pnet78use.prologos") #:exists 'replace
  (lambda (out)
    (display (string-append
              "ns pnet78use\n"
              "\n"
              "imports (pnet78dep :refer-all)\n"
              "\n"
              "spec use-name Tag -> String\n"
              "defn use-name\n"
              "  | t1 -> \"one\"\n"
              "  | t2 -> \"two\"\n")
             out)))

;; ---- Severity 3 fixture: a schema module + a module that SEALS against it ----
;; `schema-registry` is one of the registries never serialized into .pnet at all
;; (P2). The record/schema seal is implemented as `#:when (lookup-schema-by-name
;; sname)`-guarded arms in qtt.rkt — with the registry empty the guard fails, the
;; arm never fires, and the annotation falls through to a generic mismatch, so
;; the whole dependent module fails to LOAD.
(define sch-ns 'pnet78sch)
(define seal-ns 'pnet78seal)

(call-with-output-file (build-path temp-lib-dir "pnet78sch.prologos") #:exists 'replace
  (lambda (out)
    (display (string-append
              "ns pnet78sch\n"
              "\n"
              "schema Person\n"
              "  :name String\n"
              "  :age Int\n")
             out)))

(call-with-output-file (build-path temp-lib-dir "pnet78seal.prologos") #:exists 'replace
  (lambda (out)
    (display (string-append
              "ns pnet78seal\n"
              "\n"
              "imports (pnet78sch :refer-all)\n"
              "\n"
              "def sealed : Person := {:name \"x\" :age 1}\n")
             out)))

(define (write-driver! name body)
  (define p (build-path temp-lib-dir (string-append name ".prologos")))
  (call-with-output-file p #:exists 'replace (lambda (o) (display body o)))
  p)

(define (result-strings results)
  (for/list ([r (in-list results)])
    (if (prologos-error? r)
        (format "ERROR: ~a" (prologos-error-message r))
        (format "~a" r))))

;; ---- CLEAN parameter snapshots, captured BEFORE any lib load (defeats M2) ----
;; EVERY registry the fixture can populate must be listed. `reset-registry-cells!`
;; re-seeds ALL 24 cells from their CURRENT parameters, so a registry left off
;; this list keeps its polluted parameter, the reseeded cell inherits it, and the
;; corresponding case silently PASSES while its bug is live. (Observed while
;; writing this file: omitting `current-schema-registry` made the severity-3 case
;; pass at a commit where severity 3 was verifiably still broken.)
(define clean-ctor      (current-ctor-registry))
(define clean-tmeta     (current-type-meta))
(define clean-preparse  (current-preparse-registry))
(define clean-schema    (current-schema-registry))
(define clean-selection (current-selection-registry))

;; Is the ctor cell genuinely ignorant of the lib's constructors?
(define (cells-ignorant?)
  (not (hash-ref (read-ctor-registry) 't1 #f)))

;; Reset the registry cells so they are seeded from the CLEAN parameters.
;; Cell-ids are restored by the caller via save/restore-macros-cell-ids!.
(define (reset-registry-cells!)
  (current-persistent-registry-net-box #f)
  (init-persistent-registry-network!)
  (define b (current-persistent-registry-net-box))
  (when b
    ;; All FOUR cell families — omitting any one aborts later with
    ;; `net-cell-reset: unknown cell`.
    (init-macros-cells! b)
    (init-warning-cells! b)
    (init-narrow-cells! b)
    (init-attribute-map-cell! b)))

(define (with-common-params thunk)
  (parameterize ([current-lib-paths (list temp-lib-dir)]
                 [current-module-registry (hasheq)]
                 [current-ns-context #f]
                 [current-file-module-network-ref (make-module-network)]
                 ;; The batch worker forces write-enabled #f process-wide; a test
                 ;; that omits this re-parameterize can never PRIME the cache and
                 ;; would pass standalone while proving nothing in the suite.
                 [current-use-pnet-cache? #t]
                 [current-pnet-write-enabled? #t])
    (install-module-loader!)
    (thunk)))

;; Run a consumer with cells RESET under CLEAN params (defeats M1 + M2 while
;; keeping the cells in existence, which M3 requires).
(define (run-with-ignorant-cells thunk)
  (define saved-ids (save-macros-cell-ids))
  (define saved-box (current-persistent-registry-net-box))
  (begin0
    (parameterize ([current-ctor-registry clean-ctor]
                   [current-type-meta clean-tmeta]
                   [current-preparse-registry clean-preparse]
                   [current-schema-registry clean-schema]
                   [current-selection-registry clean-selection])
      (reset-registry-cells!)
      (with-common-params thunk))
    ;; Restore, so later tests in this file are unaffected.
    (restore-macros-cell-ids! saved-ids)
    (current-persistent-registry-net-box saved-box)))

;; ---- Prime the cache (run 1) ----
(define dep-cache-path (pnet-path-for-module dep-ns))
(define use-cache-path (pnet-path-for-module use-ns))
(when (file-exists? dep-cache-path) (delete-file dep-cache-path))
(when (file-exists? use-cache-path) (delete-file use-cache-path))

(define prime-driver (write-driver! "pnet78-prime" "ns p78prime\n\nimports (pnet78dep :refer-all)\n\n[tag-name t2]\n"))
(define prime-out (result-strings (with-common-params (lambda () (process-file prime-driver)))))

(test-case "#78 setup: run 1 elaborates from source and writes the dependency's .pnet"
  (check-false (ormap (lambda (s) (string-contains? s "ERROR")) prime-out)
               (format "priming run had errors: ~a" prime-out))
  (check-true (ormap (lambda (s) (string-contains? s "\"two\"")) prime-out)
              (format "expected the non-first arm to answer \"two\": ~a" prime-out))
  (check-true (file-exists? dep-cache-path)
              (format "expected a cache at ~a" dep-cache-path)))

;; ========================================
;; Severity 1 — a cache hit must not yield a STUCK term
;; ========================================

(test-case "#78 severity 1: cached module's constructors reduce (no stuck [reduce ...])"
  (define out
    (run-with-ignorant-cells
     (lambda ()
       ;; The anti-masking gate: cells exist, but know nothing of the lib.
       (check-true (cells-ignorant?)
                   "anti-masking FAILED: the ctor cell already knows t1, so this test cannot detect #78")
       (check-false (pnet-stale? dep-ns (build-path temp-lib-dir "pnet78dep.prologos"))
                    "run 2 must be a cache HIT; a MISS produces the correct answer and proves nothing")
       (result-strings
        (process-string "(ns p78s1)(imports (pnet78dep :refer-all))(eval (tag-name t2))")))))
  (check-false (ormap (lambda (s) (string-contains? s "reduce")) out)
               (format "STUCK TERM (#78 severity 1) — constructor invisible after cache-hit restore: ~a" out))
  (check-true (ormap (lambda (s) (string-contains? s "\"two\"")) out)
              (format "expected \"two\": ~a" out)))

;; ========================================
;; Severity 2 — a fresh dependent over a cached dependency must not be
;; silently mis-elaborated (patterns degrading to catch-all variables)
;; ========================================

(test-case "#78 severity 2: fresh dependent over a cached dependency keeps its non-first arm"
  (when (file-exists? use-cache-path) (delete-file use-cache-path))
  (define drv (write-driver! "pnet78-sev2" "ns p78s2\n\nimports (pnet78use :refer-all)\n\n[use-name t2]\n"))
  (define out
    (run-with-ignorant-cells
     (lambda ()
       (check-true (cells-ignorant?)
                   "anti-masking FAILED: the ctor cell already knows t1")
       (check-false (pnet-stale? dep-ns (build-path temp-lib-dir "pnet78dep.prologos"))
                    "the DEPENDENCY must be a cache HIT for this case to mean anything")
       (result-strings (process-file drv)))))
  ;; The degraded form answers "one" for BOTH constructors — the first arm
  ;; swallows everything because t1/t2 became catch-all variables.
  (check-false (ormap (lambda (s) (string-contains? s "\"one\"")) out)
               (format "SILENT WRONG ANSWER (#78 severity 2) — first arm swallowed t2: ~a" out))
  (check-true (ormap (lambda (s) (string-contains? s "\"two\"")) out)
              (format "expected \"two\": ~a" out)))

;; ========================================
;; Durable poisoning — the corrupted dependent is itself serialized, so the
;; wrong answer survives into a later, otherwise-clean load.
;; ========================================

(test-case "#78 durable poisoning: a dependent elaborated under the defect is not left cached"
  (define drv (write-driver! "pnet78-poison" "ns p78s3\n\nimports (pnet78use :refer-all)\n\n[use-name t2]\n"))
  ;; A normal (non-reset) load — cells are healthy here. If the previous case
  ;; wrote a poisoned pnet78use.pnet, this load consumes it and still answers
  ;; wrongly, with nothing in THIS run to blame.
  (define out (result-strings (with-common-params (lambda () (process-file drv)))))
  (check-false (ormap (lambda (s) (string-contains? s "\"one\"")) out)
               (format "DURABLE POISONING (#78) — a degraded elaboration was cached and reused: ~a" out))
  (check-true (ormap (lambda (s) (string-contains? s "\"two\"")) out)
              (format "expected \"two\": ~a" out)))

;; ========================================
;; Severity 3 — a cache hit must not turn a schema SEAL into a hard load failure
;; ========================================
;; This is the issue's third severity, which the design first deleted and then
;; retracted: it is real, and it is NOT fixed by the restore repair (P1),
;; because `schema-registry` is never serialized into the .pnet at all. The
;; seal is `#:when (lookup-schema-by-name sname)`-guarded (qtt.rkt); with the
;; registry empty the guard fails, the arm never fires, and the annotation
;; falls through to a generic mismatch that fails the whole module load.

(define sch-cache-path  (pnet-path-for-module sch-ns))
(define seal-cache-path (pnet-path-for-module seal-ns))
(when (file-exists? sch-cache-path) (delete-file sch-cache-path))
(when (file-exists? seal-cache-path) (delete-file seal-cache-path))

(define sch-prime-driver
  (write-driver! "pnet78-schprime" "ns p78schp\n\nimports (pnet78sch :refer-all)\n\ndef warm : Person := {:name \"a\" :age 2}\n"))
(define sch-prime-out
  (result-strings (with-common-params (lambda () (process-file sch-prime-driver)))))

(test-case "#78 setup: the schema module elaborates from source and writes its .pnet"
  (check-false (ormap (lambda (s) (string-contains? s "ERROR")) sch-prime-out)
               (format "schema priming had errors: ~a" sch-prime-out))
  (check-true (file-exists? sch-cache-path)
              (format "expected a cache at ~a" sch-cache-path)))

(test-case "#78 severity 3: a schema seal still works when the schema module comes from cache"
  (when (file-exists? seal-cache-path) (delete-file seal-cache-path))
  (define drv (write-driver! "pnet78-sev3" "ns p78s3seal\n\nimports (pnet78seal :refer-all)\n\nsealed\n"))
  (define out
    (run-with-ignorant-cells
     (lambda ()
       (check-true (cells-ignorant?)
                   "anti-masking FAILED: the ctor cell already knows the fixture lib")
       (check-false (pnet-stale? sch-ns (build-path temp-lib-dir "pnet78sch.prologos"))
                    "the SCHEMA module must be a cache HIT; a MISS re-elaborates it and proves nothing")
       ;; A failed module load RAISES out of process-file; capture it so the
       ;; assertions below report the diagnosis instead of an opaque exception.
       (with-handlers ([exn:fail? (lambda (e) (list (format "ERROR: ~a" (exn-message e))))])
         (result-strings (process-file drv))))))
  (check-false (ormap (lambda (s) (string-contains? s "Type mismatch")) out)
               (format "HARD LOAD FAILURE (#78 severity 3) — schema registry absent after cache hit: ~a" out))
  (check-false (ormap (lambda (s) (string-contains? s "ERROR")) out)
               (format "expected a clean load: ~a" out)))

;; ---- Cleanup ----
(for ([p (in-list (list dep-cache-path use-cache-path sch-cache-path seal-cache-path))])
  (when (file-exists? p) (delete-file p)))
(delete-directory/files temp-lib-dir #:must-exist? #f)
