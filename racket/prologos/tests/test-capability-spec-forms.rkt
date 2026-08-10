#lang racket/base

;;; test-capability-spec-forms.rkt — a capability in a spec is a TYPE, not a
;;; type variable; and the scope check matches it regardless of qualification.
;;;
;;; Two independent defects, found chasing "prologos::core::csv cannot be
;;; imported" (DEFERRED.md § IO Library). csv was hit by both, which is why it
;;; had been unimportable while two E2E test files over it stayed green.
;;;
;;; 1. `known-type-name?` did not consult the capability registry, so the Phase
;;;    1b auto-detect generalized every capability name in a spec into a fresh
;;;    `{X : Type}` binder:
;;;
;;;      spec rd ReadCap -0> String -> String
;;;      ⇒ rd : [Pi [x :0 <[Type 0]>] [Pi [y :0 <x>] String -> String]]
;;;
;;;    `ReadCap` became a type VARIABLE, so the binder never registered as a
;;;    capability and the capability scope stayed empty. The resulting error
;;;    pointed at the CALL SITE ("E2001: Required capability ReadCap not
;;;    available in scope") while the damage was done in the spec — which is
;;;    why chasing it from the error is a dead end.
;;;
;;; 2. The scope search compared functor names with `eq?`. The requirement
;;;    comes from a foreign decl's `:requires (ReadCap)` — bare — while the
;;;    binder's type, under an explicit `require`, elaborates to the FQN
;;;    `prologos::core::capabilities::ReadCap`. So a `:no-prelude` module had
;;;    the capability in scope and was told it did not.

(require rackunit
         racket/list
         racket/string
         racket/file
         "test-support.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         (only-in "../macros.rkt" current-capability-registry))

(define (run-file-results src)
  (define tmp (make-temporary-file "prologos-capform-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace (lambda (o) (display src o)))
  ;; ⚠ `current-capability-registry` must be supplied explicitly, and that is
  ;; the SAME phenomenon this file is about. Starting from a pre-built
  ;; `prelude-module-registry` means the prelude's `capabilities` import is
  ;; served as already-loaded, so its registrations never re-run in this
  ;; context — leaving the registry empty, `capability-type?` false, and the
  ;; first test failing for the very reason it exists to pin. Through
  ;; `run-file.rkt` (a cold process) the prelude loads for real and no
  ;; parameterize is needed. `test-io-main-01.rkt` carries the same line.
  (define rs (parameterize ([current-lib-paths (list prelude-lib-dir)]
                            [current-module-registry prelude-module-registry]
                            [current-capability-registry prelude-capability-registry])
               (install-module-loader!)
               (process-file (path->string tmp))))
  (delete-file tmp)
  (map (lambda (r) (format "~a" r)) rs))

(test-case "capform/a capability in a spec is a TYPE, not an auto-generalized variable"
  ;; The positional and brace spellings must produce the SAME type. Before the
  ;; fix the positional one produced a two-binder Pi over a fresh type var.
  (define rs (run-file-results
              (string-append "ns capform-a\n\n"
                             "spec rd0 ReadCap -0> String -> String\n"
                             "defn rd0 [_cap path] path\n"
                             "spec rd1 {cap :0 ReadCap} String -> String\n"
                             "defn rd1 [path] path\n")))
  (check-regexp-match #rx"Pi \\[x :0 <.*ReadCap>\\]" (first rs)
                      (format "positional form: ~a" (first rs)))
  (check-false (regexp-match? #rx"Type 0" (first rs))
               (format "ReadCap was auto-generalized into a type variable: ~a" (first rs)))
  ;; and the two spellings agree
  (check-equal? (regexp-replace #rx"^rd0" (first rs) "X")
                (regexp-replace #rx"^rd1" (second rs) "X")))

;; The two tests that lived here — a `:no-prelude` module calling a
;; capability-annotated foreign fn, and `prologos::core::csv` importing —
;; belong to DEFECT 2, which is NOT fixed. See DEFERRED.md § IO Library: the
;; scope comparison is a one-line change that makes both pass, and it also
;; loosens a SECURITY check and surfaces a multiplicity violation in csv's
;; `read-csv` (the resolved capability is threaded into `read-file` as a
;; runtime argument while its binder is `:0`). Not shipped on that basis.

(test-case "capform/IO with NO capability in scope still ERRORS"
  ;; The security direction, guarded here as well as in test-io-main-01 —
  ;; because the fix to defect 2 makes the scope comparison LOOSER, and a
  ;; looser capability check is exactly the change that must not be allowed to
  ;; pass silently. An empty scope must still refuse.
  (define rs (run-file-results
              (string-append "ns capform-d\n\n"
                             "imports [prologos::core::io :refer [read-file]]\n\n"
                             "def notmain := [fn [x : Unit] [read-file \"/tmp/nope\"]]\n")))
  (check-true (ormap (lambda (r) (regexp-match? #rx"E2001" r)) rs)
              (format "a capability-free context must be refused: ~v" rs)))
