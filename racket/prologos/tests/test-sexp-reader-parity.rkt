#lang racket/base

;;;
;;; PROLOGOS SEXP READER PARITY TESTS
;;; Verifies that the sexp-mode reader produces identical datums to the WS reader
;;; for all operator/sentinel forms. See docs/tracking/2026-02-18_UNIFORM_SYNTAX_AUDIT.md
;;; for the full audit.
;;;
;;; Tests added 2026-02-19 as part of Phase I: Reader Parity.
;;;

(require rackunit
         racket/list
         racket/port
         racket/string
         racket/file
         racket/path
         "test-support.rkt"
         "../sexp-readtable.rkt"
         "../parse-reader.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../reduction.rkt"
         "../namespace.rkt"
         "../trait-resolution.rkt")

;; ========================================
;; Helpers
;; ========================================

;; Run sexp-mode code
(define (run s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-bundle-registry (current-bundle-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string s)))

(define (run-last s) (last (run s)))

;; Run WS-mode code via temp .prologos file
(define (run-ws s)
  (define tmp (make-temporary-file "prologos-test-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display s out)))
  (define result
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-ns-context #f]
                   [current-module-registry prelude-module-registry]
                   [current-lib-paths (list prelude-lib-dir)]
                   [current-preparse-registry prelude-preparse-registry]
                   [current-trait-registry prelude-trait-registry]
                   [current-impl-registry prelude-impl-registry]
                   [current-param-impl-registry prelude-param-impl-registry]
                   [current-bundle-registry (current-bundle-registry)]
                   [current-spec-store (hasheq)])
      (install-module-loader!)
      (process-file tmp)))
  (delete-file tmp)
  result)

(define (run-ws-last s) (last (run-ws s)))

;; ========================================
;; A. Sexp readtable datum-level tests
;; ========================================

;; --- |> pipe operator ---

(test-case "sexp-parity/pipe-gt: |> reads as $pipe-gt"
  (define result (prologos-sexp-read (open-input-string "|>")))
  (check-equal? result '$pipe-gt))

(test-case "sexp-parity/pipe-gt: (x |> f) reads as (x $pipe-gt f)"
  (define result (prologos-sexp-read (open-input-string "(x |> f)")))
  (check-equal? result '(x $pipe-gt f)))

(test-case "sexp-parity/pipe-gt: (x |> f |> g) reads as (x $pipe-gt f $pipe-gt g)"
  (define result (prologos-sexp-read (open-input-string "(x |> f |> g)")))
  (check-equal? result '(x $pipe-gt f $pipe-gt g)))

(test-case "sexp-parity/pipe: bare | reads as $pipe"
  (define result (prologos-sexp-read (open-input-string "|")))
  (check-equal? result '$pipe))

(test-case "sexp-parity/pipe: | inside <> still works as $pipe"
  (define result (prologos-sexp-read (open-input-string "<A | B>")))
  (check-equal? result '($angle-type A $pipe B)))

;; --- >> compose operator ---

(test-case "sexp-parity/compose: >> reads as >> symbol"
  ;; >> reads as the Racket symbol >> (not $compose) at the datum level.
  ;; The normalization >> → $compose happens in the preparse layer.
  (define result (prologos-sexp-read (open-input-string ">>")))
  (check-equal? result '>>))

(test-case "sexp-parity/compose: (f >> g) normalized to $compose by preparse"
  (define result (preparse-expand-form '(f >> g)))
  ;; Should produce a lambda (fn ($>>0 : _) (g (f $>>0)))
  (check-true (and (pair? result) (eq? (car result) 'fn))))

(test-case "sexp-parity/compose: (f >> g >> h) triple compose"
  (define result (preparse-expand-form '(f >> g >> h)))
  (check-true (and (pair? result) (eq? (car result) 'fn))))

;; --- ... varargs ---

(test-case "sexp-parity/varargs: ... reads as ... symbol"
  ;; ... reads as the Racket symbol ... at the datum level.
  ;; The normalization ... → $rest happens in desugar-rest-type.
  (define result (prologos-sexp-read (open-input-string "...")))
  (check-equal? result '...))

(test-case "sexp-parity/varargs: ...xs reads as ...xs symbol"
  (define result (prologos-sexp-read (open-input-string "...xs")))
  (check-equal? result '...xs))

(test-case "sexp-parity/varargs: spec with ... works in sexp mode"
  ;; (spec foo Nat ... -> Nat) — using bare ... instead of $rest
  (parameterize ([current-spec-store (hasheq)]
                 [current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-preparse-registry prelude-preparse-registry])
    (process-spec '(spec add-all Nat ... -> Nat))
    (define entry (lookup-spec 'add-all))
    (check-not-false entry)
    ;; rest-type should be Nat
    (check-equal? (spec-entry-rest-type entry) 'Nat)
    ;; type-datums should have (List Nat) instead of Nat ...
    (define tokens (car (spec-entry-type-datums entry)))
    (check-not-false (member '(List Nat) tokens))))

(test-case "sexp-parity/varargs: spec with ... mixed fixed+rest"
  (parameterize ([current-spec-store (hasheq)]
                 [current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-preparse-registry prelude-preparse-registry])
    (process-spec '(spec max-of Nat Nat ... -> Nat))
    (define entry (lookup-spec 'max-of))
    (check-equal? (spec-entry-rest-type entry) 'Nat)
    (define tokens (car (spec-entry-type-datums entry)))
    (check-equal? (car tokens) 'Nat)
    (check-not-false (member '(List Nat) tokens))))

(test-case "sexp-parity/varargs: spec with ... and implicit binders"
  (parameterize ([current-spec-store (hasheq)]
                 [current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-preparse-registry prelude-preparse-registry])
    (process-spec '(spec list-of ($brace-params A) A ... -> (List A)))
    (define entry (lookup-spec 'list-of))
    (check-equal? (spec-entry-rest-type entry) 'A)
    (check-not-false (spec-entry-implicit-binders entry))))

(test-case "sexp-parity/varargs: spec with ... at start is error"
  (parameterize ([current-spec-store (hasheq)]
                 [current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-preparse-registry prelude-preparse-registry])
    (check-exn exn:fail?
      (lambda () (process-spec '(spec bad ... -> Nat))))))

;; ========================================
;; B. End-to-end sexp-mode tests
;; ========================================

;; --- |> pipe end-to-end ---

(test-case "sexp-parity/e2e/pipe: x |> f using infix |>"
  ;; Using the |> symbol directly (now readable in sexp mode)
  (check-equal?
    (run-last (string-append
      "(ns sp-pipe-1)\n"
      "(eval (($pipe-gt zero (suc)) ))"))
    "1N : Nat"))

;; --- >> compose end-to-end ---

(test-case "sexp-parity/e2e/compose: (f >> g) using >> symbol"
  ;; >> now normalized to $compose in preparse
  (check-equal?
    (run-last (string-append
      "(ns sp-comp-1)\n"
      "(eval ((suc >> suc) zero))"))
    "2N : Nat"))

(test-case "sexp-parity/e2e/compose: (f >> g >> h) triple compose"
  (check-equal?
    (run-last (string-append
      "(ns sp-comp-2)\n"
      "(eval ((suc >> suc >> suc) zero))"))
    "3N : Nat"))

;; --- ... varargs end-to-end ---

(test-case "sexp-parity/e2e/varargs: basic with ... in spec"
  (define result
    (run (string-append
      "(ns sp-va-1)\n"
      "(imports [prologos::data::list :refer [List nil cons length]])\n"
      "(spec count-args Nat ... -> Nat)\n"
      "(defn count-args [xs] (length Nat xs))\n"
      "(eval (count-args 1N 2N 3N))")))
  (check-equal? (last result) "3N : Nat"))

(test-case "sexp-parity/e2e/varargs: zero args with ..."
  (define result
    (run (string-append
      "(ns sp-va-2)\n"
      "(imports [prologos::data::list :refer [List nil cons length]])\n"
      "(spec count-args Nat ... -> Nat)\n"
      "(defn count-args [xs] (length Nat xs))\n"
      "(eval (count-args))")))
  (check-equal? (last result) "0N : Nat"))

(test-case "sexp-parity/e2e/varargs: ...xs rest param in defn"
  (define result
    (run (string-append
      "(ns sp-va-3)\n"
      "(imports [prologos::data::list :refer [List nil cons length]])\n"
      "(spec count-args Nat ... -> Nat)\n"
      "(defn count-args [...xs] (length Nat xs))\n"
      "(eval (count-args 1N 2N 3N))")))
  (check-equal? (last result) "3N : Nat"))

(test-case "sexp-parity/e2e/varargs: mixed fixed + ... rest"
  (define result
    (run (string-append
      "(ns sp-va-4)\n"
      "(imports [prologos::data::list :refer [List nil cons length]])\n"
      "(spec count-rest Nat Nat ... -> Nat)\n"
      "(defn count-rest [first ...rest] (length Nat rest))\n"
      "(eval (count-rest 99N 1N 2N 3N))")))
  (check-equal? (last result) "3N : Nat"))
