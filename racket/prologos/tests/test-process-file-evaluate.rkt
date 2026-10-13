#lang racket/base

;;;
;;; test-process-file-evaluate.rkt — `process-file #:evaluate? #f` (CHECK-ONLY).
;;;
;;; WHY THIS FILE EXISTS (2026-10-12):
;;;
;;; The LSP publishes diagnostics by running `process-file` on every open/save,
;;; and its message loop is sequential. `process-file` used to EVALUATE every
;;; top-level expression (`nf` in process-command's 'eval arm). On
;;; lib/examples/foray.prologos that was 231 s of a 234 s run (PHASE-TIMINGS
;;; reduce_ms), every REPL request queued behind it, and the values were then
;;; thrown away — the server keeps only the errors. Diagnostics now pass
;;; `#:evaluate? #f`: an `eval` form is processed as its STATIC projection,
;;; `infer` (type + trait resolution, no `nf`).
;;;
;;; THE CONTRACT PINNED HERE:
;;;   (1) Default (`#t`) is unchanged — the file is evaluated.
;;;   (2) Check-only prints the TYPE of each eval form, never a value, and a
;;;       runtime-only failure (panic) does not occur — proof `nf` did not run.
;;;   (3) PARITY: every STATIC error is reported identically in both modes —
;;;       including `solve: Unknown relation`, which is raised before evaluation.
;;;       Check-only may only DROP runtime errors, never static ones.
;;;   (4) Every non-eval result (defs, defr) is identical in both modes, and the
;;;       check-only type of each eval form equals the type half of the
;;;       evaluating result.
;;;
;;; Level 3 (a real .prologos FILE through process-file) because the flag is a
;;; process-file keyword — there is no string-level path for it.
;;;

(require rackunit
         racket/file
         racket/list
         racket/string
         "test-support.rkt"
         "../errors.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../macros.rkt")

;; ---- Shared prelude fixture (once per file; the test-def-seam pattern) ----
(define-values (pre-global-env pre-ns-context pre-module-reg
                pre-trait-reg pre-impl-reg pre-param-impl-reg)
  (parameterize ([current-file-module-network-ref (make-module-network)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry])
    (install-module-loader!)
    (process-string "(ns evaluate-flag-pre)")
    (values (global-env-snapshot) (current-ns-context) (current-module-registry)
            (current-trait-registry) (current-impl-registry)
            (current-param-impl-registry))))

(define (run-file-ws s #:evaluate? evaluate?)
  (define tmp (make-temporary-file "prologos-evalflag-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display s out)))
  (define result
    (parameterize ([current-file-module-network-ref
                    (module-network-add-import (make-module-network)
                                               (module-network-from-snapshot pre-global-env))]
                   [current-ns-context pre-ns-context]
                   [current-module-registry pre-module-reg]
                   [current-trait-registry pre-trait-reg]
                   [current-impl-registry pre-impl-reg]
                   [current-param-impl-registry pre-param-impl-reg])
      (process-file (path->string tmp) #:evaluate? evaluate?)))
  (delete-file tmp)
  result)

;; One program, run in both modes. Result indices (ns is consumed):
;;   0 def        1 eval (value)     2 eval (runtime panic)   3 eval (static error)
;;   4 spec+defn  5 eval (recursion) 6 eval (static solve error)
;;   7 defr       8 eval (solve query)
(define program
  (string-join
   '("ns evalflag"
     "def k : Int := 3"
     "[int+ k 1]"
     "(the Int (panic \"boom\"))"
     "(the Int \"x\")"
     "spec slow Int -> Int"
     "defn slow [n]"
     "  match [int-le n 0]"
     "    | true  -> 0"
     "    | false -> [int+ 1 [slow [int- n 1]]]"
     "slow 5"
     "(loves-nobody 1)"
     "defr likes [?a ?b]"
     "  || \"ann\" \"bob\""
     "(likes \"ann\" who)")
   "\n"))

(define EVAL-IDXS '(1 2 3 5 6 8))
(define RUNTIME-ONLY-IDXS '(2))   ; the panic — only `nf` can produce it

(define evaluated (run-file-ws program #:evaluate? #t))
(define checked   (run-file-ws program #:evaluate? #f))

(define (show r) (if (prologos-error? r) (format "ERROR: ~a" (prologos-error-message r)) r))

(define (error-key r)
  (define loc (prologos-error-srcloc r))
  (list (prologos-error-message r)
        (and (srcloc? loc) (srcloc-line loc))
        (and (srcloc? loc) (srcloc-column loc))))

(test-case "evaluate-flag/1 default mode evaluates (unchanged baseline)"
  (check-equal? (length evaluated) 9 (format "~v" (map show evaluated)))
  (check-equal? (list-ref evaluated 1) "4 : Int")
  (check-equal? (list-ref evaluated 5) "5 : Int")
  (check-true (prologos-error? (list-ref evaluated 2)))
  (check-regexp-match #rx"panic: boom" (prologos-error-message (list-ref evaluated 2)))
  (check-regexp-match #rx"\"bob\"" (list-ref evaluated 8)))

(test-case "evaluate-flag/2 check-only prints types, never values, and runs nothing"
  (check-equal? (length checked) 9 (format "~v" (map show checked)))
  (check-equal? (list-ref checked 1) "Int")
  (check-equal? (list-ref checked 5) "Int")
  ;; THE nf-did-not-run witness: a panic exists only at evaluation time.
  (check-equal? (list-ref checked 2) "Int")
  (check-equal? (list-ref checked 8) "[PVec {:who String}]"))

(test-case "evaluate-flag/3 static errors are identical in both modes"
  (for ([i (in-range (length evaluated))]
        #:unless (memv i RUNTIME-ONLY-IDXS))
    (define e (list-ref evaluated i))
    (define c (list-ref checked i))
    (check-equal? (prologos-error? c) (prologos-error? e)
                  (format "index ~a: error-ness must agree: eval=~v check=~v" i (show e) (show c)))
    (when (prologos-error? e)
      ;; message + line/column, NOT the whole struct: each mode runs its own
      ;; temp file, so srcloc-source legitimately differs.
      (check-equal? (error-key c) (error-key e)
                    (format "index ~a: the static error must be identical" i))))
  ;; and the two static error kinds in the program are actually present
  (check-regexp-match #rx"Could not infer type" (prologos-error-message (list-ref checked 3)))
  (check-regexp-match #rx"Unknown relation: loves-nobody"
                      (prologos-error-message (list-ref checked 6))))

(test-case "evaluate-flag/4 non-eval results identical; eval types match the evaluated type"
  (for ([i (in-range (length evaluated))]
        #:unless (memv i EVAL-IDXS))
    (check-equal? (list-ref checked i) (list-ref evaluated i) (format "index ~a" i)))
  (for ([i (in-list EVAL-IDXS)]
        #:unless (prologos-error? (list-ref evaluated i)))
    (define e (list-ref evaluated i))
    ;; "VALUE : TYPE" — the type is everything after the LAST " : "
    (define type-half (last (regexp-split #rx" : " e)))
    (check-equal? (list-ref checked i) type-half (format "index ~a: ~v" i e))))
