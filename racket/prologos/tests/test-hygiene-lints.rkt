#lang racket/base

;;;
;;; test-hygiene-lints.rkt — regression tests for the custom hygiene lints
;;;
;;; The lints (tools/lint-fire-fn-capture.rkt, tools/lint-memo-hash.rkt,
;;; tools/lint-pnet-registration.rkt) are static guards for documented bug
;;; classes. These tests pin their DETECTION behavior against committed
;;; fixtures in tests/lint-fixtures/ — bug shapes flagged, corrected twins
;;; clean — so a lint refactor cannot silently lose the very case each lint
;;; exists for. (PR #81's original validation ran against session-local
;;; fixtures that were never committed; this file closes that gap.)
;;;
;;; Fixtures are READ by the lints, never compiled — they reference unbound
;;; identifiers freely. They use the .rktl extension DELIBERATELY: the suite
;;; runner's precompile-modules! walks tests/ RECURSIVELY compiling every
;;; *.rkt (bench-lib.rkt), and `raco test tests/` would try to run them —
;;; a .rkt fixture with unbound identifiers breaks both. .rktl is invisible
;;; to every \.rkt$ glob while the lints read file CONTENT, not extension.
;;;

(require rackunit
         racket/port
         racket/system
         racket/path)

(define here (path-only (path->complete-path (syntax-source #'here))))
(define tools-dir (simplify-path (build-path here 'up "tools")))
(define fixtures-dir (build-path here "lint-fixtures"))
;; exec-file can come back RELATIVE (just "racket"); system* does not search
;; PATH, so resolve it ourselves in that case.
(define racket-bin
  (let ([p (find-system-path 'exec-file)])
    (if (absolute-path? p) p (or (find-executable-path p) p))))

;; Run a lint script on fixture files; return (values exit-ok? output).
;; Without --strict the lints always exit 0, so detection is asserted via
;; the "NEW: n" count in the report line.
(define (run-lint lint-name . fixture-names)
  (define script (build-path tools-dir (string-append lint-name ".rkt")))
  (define args (for/list ([f (in-list fixture-names)])
                 (path->string (build-path fixtures-dir f))))
  (define out (open-output-string))
  (define ok?
    (parameterize ([current-output-port out]
                   [current-error-port out])
      (apply system* racket-bin (path->string script) args)))
  (values ok? (get-output-string out)))

(define (new-count output)
  (define m (regexp-match #px"NEW: (\\d+)" output))
  (and m (string->number (cadr m))))

;; ============================================================
;; lint-fire-fn-capture
;; ============================================================

(test-case "fire-fn-capture: the propagator-design.md WRONG example is flagged"
  (define-values (ok? out) (run-lint "lint-fire-fn-capture" "fire-doc-bug.rktl"))
  (check-true ok? out)
  (check-equal? (new-count out) 1 out)
  ;; the report names the captured variable
  (check-regexp-match #px"uses 'n'" out))

(test-case "fire-fn-capture: corrected twin (net param everywhere) is clean"
  (define-values (ok? out) (run-lint "lint-fire-fn-capture" "fire-clean.rktl"))
  (check-true ok? out)
  (check-equal? (new-count out) 0 out))

(test-case "fire-fn-capture: named helper passed by reference is flagged (rule c)"
  (define-values (ok? out) (run-lint "lint-fire-fn-capture" "fire-named-helper.rktl"))
  (check-true ok? out)
  (check-equal? (new-count out) 1 out))

;; ============================================================
;; lint-memo-hash
;; ============================================================

(test-case "memo-hash: (make-hash at end-of-line near memo context is flagged"
  (define-values (ok? out) (run-lint "lint-memo-hash" "memo-eol.rktl"))
  (check-true ok? out)
  (check-equal? (new-count out) 1 out))

(test-case "memo-hash: make-hasheq twin is clean"
  (define-values (ok? out) (run-lint "lint-memo-hash" "memo-clean.rktl"))
  (check-true ok? out)
  (check-equal? (new-count out) 0 out))

;; ============================================================
;; lint-pnet-registration (fixed surfaces: syntax.rkt + pnet-serialize.rkt —
;; no fixture mode; pin that it parses the real tree and stays baseline-clean)
;; ============================================================

(test-case "pnet-registration: parses the real tree, strict-clean vs baseline"
  (define script (build-path tools-dir "lint-pnet-registration.rkt"))
  (define out (open-output-string))
  (define ok?
    (parameterize ([current-output-port out]
                   [current-error-port out])
      (system* racket-bin (path->string script) "--strict")))
  (define s (get-output-string out))
  (check-true ok? s)
  ;; struct discovery actually worked (the tree has 300+ expr structs);
  ;; a parse regression that found 0 structs would otherwise pass silently
  (define m (regexp-match #px"\\((\\d+) structs in syntax.rkt\\)" s))
  (check-true (and m (> (string->number (cadr m)) 300)) s))
