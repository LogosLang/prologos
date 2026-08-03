#lang racket/base

;;; test-reader-robustness.rkt — a reader failure must not cost the whole file.
;;;
;;; Everything the reader does happens BEFORE any command runs: `read-all-syntax-ws`
;;; tokenizes and groups the entire file up front. So a raise anywhere in it is
;;; a whole-file abort by construction — no results, no per-command error count,
;;; and (when it is a raw Racket contract violation) no source location either.
;;;
;;; That is the silence class the loud-tier work exists to prevent, sitting in
;;; the one place that runs first.

(require rackunit
         racket/list
         racket/file
         racket/string
         "test-support.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../macros.rkt"
         "../errors.rkt")

(define (run-file-lines src)
  (define f (make-prologos-temp-file))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file f #:exists 'truncate (lambda (o) (display src o)))
      (parameterize ([current-module-registry prelude-module-registry]
                     [current-lib-paths (list prelude-lib-dir)]
                     [current-preparse-registry prelude-preparse-registry]
                     [current-trait-registry prelude-trait-registry]
                     [current-impl-registry prelude-impl-registry]
                     [current-param-impl-registry prelude-param-impl-registry])
        (install-module-loader!)
        (process-file (path->string f))))
    (lambda () (with-handlers ([void void]) (delete-file f)))))

(test-case "reader/a bare top-level [] does not take the file with it"
  ;; It used to die inside the reader with
  ;;   >: contract violation  expected: real?  given: #f
  ;; and nothing else — every command in the file lost, including the ones
  ;; before it. The chain: a `'()` element gets a syntax object with line 0,
  ;; `make-stx` maps 0 to #f, and re-wrapping that element read the #f back and
  ;; compared it with `>`.
  ;;
  ;; What this pins is the FILE surviving. `[]` alone is not meaningful and is
  ;; entitled to be an error -- it just has to be one error, in one command.
  (define results (run-file-lines "ns rr\ndef a := 1\na\n[]\ndef b := 2\nb\n"))
  (check-true (list? results))
  (define text (string-join (map (lambda (r) (format "~a" r)) results) "\n"))
  (check-true (string-contains? text "a")
              (format "commands BEFORE the bad form were lost: ~v" results))
  (check-true (string-contains? text "b")
              (format "commands AFTER the bad form were lost: ~v" results)))

(test-case "reader/an empty bracket in a value position still means the empty list"
  ;; The fix must not have made `[]` unreadable where it was already fine.
  (define results (run-file-lines "ns rr2\ndef x := []\nx\n"))
  (check-true (list? results))
  (check-false (ormap prologos-error? results)
               (format "expected no errors, got: ~v" results)))

(test-case "reader/[] alone in a file is a per-command error, not an abort"
  (define results (run-file-lines "ns rr3\n[]\n"))
  (check-true (list? results))
  (check-true (>= (length results) 1)
              "an aborted file returns nothing at all"))

(test-case "reader/a reader raise becomes a reported error, with a position"
  ;; `~3` (approximate literals, removed) used to escape as a raw Racket
  ;; message plus a `context...:` dump: exit 1, zero result lines, no error
  ;; COUNT, and no indication of WHERE. The loudest possible failure presented
  ;; as the quietest.
  ;;
  ;; Tokenization finishes before any command runs, so the commands really are
  ;; unrecoverable here — what is recoverable is saying so properly.
  (define results (run-file-lines "ns rt\ndef a := 1\na\ndef b := ~3\nb\n"))
  (check-true (list? results) "the file aborted instead of reporting")
  (define text (string-join (map (lambda (r) (format "~a" r)) results) "\n"))
  (check-true (string-contains? text "approximate literals were removed")
              (format "got: ~v" results))
  (check-true (regexp-match? #rx"line 4" text)
              (format "the diagnostic does not say WHERE: ~v" results)))

(test-case "reader/the tokenizer-validation raises are not the live path"
  ;; The validation loop in `tokenize-string` raises on a negative Nat literal
  ;; and on a stray `&`. Both now report line and column — but neither is
  ;; REACHABLE for the obvious input, because a per-command check gets there
  ;; first with a real srcloc.
  ;;
  ;; Pinned as a negative on purpose. Those raises read like they own these
  ;; cases; they do not, and the next person to "fix" one should find that out
  ;; here rather than by editing dead code. The live whole-file raiser is the
  ;; tilde TOKEN PATTERN (above), which fires during tokenization proper.
  (define bad-nat (run-file-lines "ns rt2\ndef a := 1\ndef b := -3N\n"))
  (check-true (list? bad-nat))
  (check-true (string-contains? (format "~a" bad-nat)
                                "N suffix requires a non-negative integer")
              (format "got: ~v" bad-nat))
  (check-true (string-contains? (format "~a" bad-nat) "a : Int defined.")
              (format "the earlier command was lost: ~v" bad-nat))

  (define stray-amp (run-file-lines "ns rt3\ndef a := 1\n&\n"))
  (check-true (list? stray-amp))
  (check-true (string-contains? (format "~a" stray-amp) "Unbound variable")
              (format "got: ~v" stray-amp))
  (check-true (string-contains? (format "~a" stray-amp) "a : Int defined.")
              (format "the earlier command was lost: ~v" stray-amp)))

;; ----------------------------------------------------------------
;; `.( )` mixfix failures are per-command
;; ----------------------------------------------------------------
;;
;; These raised out of `preparse-expand-all` and cost the whole file: no
;; results, no error count, a raw Racket `context...:` dump. Unlike the reader
;; raises above, this one IS recoverable per-command — expansion is per-form, so
;; the failing form can collapse to a marker datum and the rest of the file runs.
;;
;; Same channel as LET P1's `$let-error`, deliberately: one mechanism for
;; "a preparse expander failed", not a second one alongside it.

(test-case "reader/an incomparable-precedence mixfix errors, and only there"
  (define results (run-file-lines "ns mx\ndef a := 1\n.( 1 :: '[2 3] ++ '[4] )\ndef b := 2\n"))
  (check-true (list? results))
  (define text (string-join (map (lambda (r) (format "~a" r)) results) "\n"))
  (check-true (string-contains? text "no defined precedence relationship")
              (format "got: ~v" results))
  (check-true (string-contains? text "a :") (format "the command BEFORE was lost: ~v" results))
  (check-true (string-contains? text "b :") (format "the command AFTER was lost: ~v" results)))

(test-case "reader/an empty .( ) errors, and only there"
  (define results (run-file-lines "ns mx2\ndef a := 1\n.( )\ndef b := 2\n"))
  (check-true (list? results))
  (define text (string-join (map (lambda (r) (format "~a" r)) results) "\n"))
  (check-true (string-contains? text "Empty .( ) mixfix expression") (format "got: ~v" results))
  (check-true (string-contains? text "a :") (format "the command BEFORE was lost: ~v" results))
  (check-true (string-contains? text "b :") (format "the command AFTER was lost: ~v" results)))

(test-case "reader/a WELL-FORMED mixfix still evaluates"
  ;; The conversion must not have turned working mixfix into an error channel.
  (define results (run-file-lines "ns mx3\ndef a := 1\n.( 1 + 2 )\ndef b := 2\n"))
  (check-true (list? results))
  (check-false (ormap prologos-error? results) (format "expected no errors: ~v" results))
  (check-true (string-contains? (format "~a" results) "3") (format "got: ~v" results)))

;; ----------------------------------------------------------------
;; `def X :=` with a layout map body
;; ----------------------------------------------------------------

(test-case "layout/a multi-key layout body means the same with := as without"
  ;; `def r :=` followed by keyword-headed lines used to build an APPLICATION
  ;; -- `((:eu …) (:us …))` -- and fail with "Could not infer type", naming
  ;; typing for what is a layout seam. The byte-identical body WITHOUT `:=`
  ;; worked, because it reached `rewrite-implicit-map` with its keyword tail
  ;; intact.
  ;;
  ;; The A/B is the test: the two spellings have to agree, and asserting on
  ;; only one of them would have passed throughout the divergence.
  (define with-assign
    (run-file-lines "ns ly\ndef r1 :=\n  :eu {:host \"e\" :port 443}\n  :us {:host \"u\" :port 443}\n"))
  (define without-assign
    (run-file-lines "ns ly2\ndef r2\n  :eu {:host \"e\" :port 443}\n  :us {:host \"u\" :port 443}\n"))
  (check-false (ormap prologos-error? with-assign)
               (format "the := spelling failed: ~v" with-assign))
  (check-false (ormap prologos-error? without-assign)
               (format "the no-:= spelling failed: ~v" without-assign))
  ;; Same inferred type, modulo the name.
  (define (type-of results name)
    (regexp-replace (regexp (string-append "^" name " : ")) (format "~a" (car results)) ""))
  (check-equal? (type-of with-assign "r1") (type-of without-assign "r2")))

(test-case "layout/a multi-token RHS is still an application"
  ;; The narrow part. Only an all-keyword-headed RHS is a map body; anything
  ;; else keeps the application default, which is what `def x := some 42N`
  ;; depends on.
  (define rs (run-file-lines "ns ly3\ndef x := some 42N\nx\n"))
  (check-false (ormap prologos-error? rs) (format "expected success, got: ~v" rs))
  (check-true (string-contains? (format "~a" rs) "Option") (format "got: ~v" rs)))

(test-case "layout/a single-key layout body still works"
  (define rs (run-file-lines "ns ly4\ndef r3 :=\n  :eu 1\nr3\n"))
  (check-false (ormap prologos-error? rs) (format "expected success, got: ~v" rs))
  (check-true (string-contains? (format "~a" rs) ":eu") (format "got: ~v" rs)))
