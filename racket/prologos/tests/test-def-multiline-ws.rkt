#lang racket/base

;;;
;;; Regression tests for multi-line `def NAME : TYPE := BODY` forms in WS mode.
;;;
;;; Background — the eigentrust pitfalls doc (2026-04-23) #15 reported that a
;;; `def` with a type annotation split across two lines like
;;;
;;;     def c-asym-3 : [List [List Rat]]
;;;       := '['[rz 1/2 1/2] '[rz rz ro] '[ro rz rz]]
;;;
;;; would silently misparse: the indented continuation `:= BODY` was wrapped
;;; by the WS reader as a sub-list `(:= BODY)`, leaving the def datum as
;;;
;;;     (def c : (List ...) (:= ($list-literal ...)))
;;;
;;; instead of the one-line equivalent
;;;
;;;     (def c : (List ...) := ($list-literal ...))
;;;
;;; `expand-def-assign` only scans the TOP LEVEL of the def body for `:=`
;;; (via `memq`), so the buried `:=` was invisible. The 4-element fallback
;;; in `parse-def` then treated `(:= ($list-literal ...))` as the BODY of
;;; `def`, which on elaboration tried to apply `:=` to `($list-literal ...)`
;;; and reported `Unbound variable: $list-literal`. Worse, downstream
;;; references to the (never-bound) `c` produced spurious unbound-variable
;;; errors and benchmarks measuring `reduce_ms` reported 0 because the
;;; intended computation never ran.
;;;
;;; Fix shape (a in the eigentrust pitfalls doc): `parse-reader.rkt` recognises
;;; `def`/`def-` form nodes in `tree-node->stx-elements` and SPLICES any
;;; indent-grouped continuation line whose first token is `:=` directly
;;; into the parent token stream. All other continuations (bare bodies,
;;; bracketed application chains) remain wrapped, preserving today's
;;; semantics for forms like `(def c\n  + 1 2)` → `(def c (+ 1 2))`.
;;;

(require rackunit
         racket/list
         "../parse-reader.rkt"
         "test-support.rkt")

;; ========================================
;; Helpers
;; ========================================

;; Read a single WS datum.
(define (ws-read s)
  (define in (open-input-string s))
  (prologos-read in))

;; Read all WS datums until eof.
(define (ws-read-all s)
  (define in (open-input-string s))
  (let loop ([acc '()])
    (define d (prologos-read in))
    (if (eof-object? d) (reverse acc) (loop (cons d acc)))))

;; ========================================
;; Datum-level checks: one-line and two-line forms produce identical surf
;; ========================================

(test-case "two-line def with `:= BODY` on continuation matches one-line"
  (define one-line (ws-read "def c : T := 42"))
  (define two-line (ws-read "def c : T\n  := 42"))
  (check-equal? two-line one-line)
  (check-equal? two-line '(def c : T := 42))
  ;; The `:=` MUST appear at the top level so `expand-def-assign`'s
  ;; `(memq ':= datum)` test fires. memq returns a non-#f tail (truthy)
  ;; when `:=` is a top-level element of the form.
  (check-true (and (memq ':= two-line) #t)
              "`:=` must be at the top level, not buried in a sub-list"))

(test-case "two-line def with `:=` on its own line (body on third line)"
  ;; Rare but valid: split the assignment marker AND the body.
  (define d (ws-read "def c : T\n  :=\n    42"))
  (check-equal? d '(def c : T := 42))
  (check-true (and (memq ':= d) #t)))

(test-case "two-line def with multi-token list-literal body"
  ;; Reproducer matching the eigentrust pitfalls doc's primary example.
  ;; Slash-containing rationals carry the `$rat-literal` sentinel from
  ;; the WS reader's number tokenizer (see eigentrust pitfalls doc #3).
  (define d (ws-read "def c : [List Rat]\n  := '[1/2 1/2 1/2]"))
  (check-equal?
   d
   '(def c : (List Rat) := ($list-literal ($rat-literal 1/2)
                                          ($rat-literal 1/2)
                                          ($rat-literal 1/2))))
  (check-true (and (memq ':= d) #t)))

(test-case "two-line def with bracketed multi-line body after `:=`"
  ;; The body itself spans lines as a bracketed group — must remain a
  ;; single sub-list and the `:=` must remain spliced.
  (define d (ws-read "def c : T\n  := [+\n      1\n      2]"))
  (check-equal? d '(def c : T := (+ 1 2))))

(test-case "one-line def is unchanged by the splice rule"
  (check-equal? (ws-read "def c : T := 42") '(def c : T := 42))
  (check-equal? (ws-read "def c := 42") '(def c := 42))
  (check-equal? (ws-read "def c 42") '(def c 42)))

(test-case "def with bare body on continuation (no `:=`) is still wrapped"
  ;; Without `:=`, the continuation line is a body expression. It must
  ;; remain grouped (otherwise `(def c\n  + 1 2)` would become
  ;; `(def c + 1 2)` — a 4-arg def parse error rather than `(def c (+ 1 2))`).
  (check-equal? (ws-read "def c\n  42") '(def c 42))
  (check-equal? (ws-read "def c\n  + 1 2") '(def c (+ 1 2)))
  (check-equal? (ws-read "def c\n  [+ 1 2]") '(def c (+ 1 2)))
  ;; Multi-line bracketed body — also stays grouped.
  (check-equal? (ws-read "def c\n  [+\n   1\n   2]") '(def c (+ 1 2))))

(test-case "private def- gets the same splice treatment"
  (define one-line (ws-read "def- c : T := 42"))
  (define two-line (ws-read "def- c : T\n  := 42"))
  (check-equal? two-line one-line)
  (check-equal? two-line '(def- c : T := 42)))

;; Non-regression: confirm the splice rule does NOT touch other forms.
(test-case "non-def forms are unaffected by the def splice rule"
  ;; `defn` body: continuation MUST stay wrapped — defn relies on the
  ;; sub-list grouping to recover its body shape.
  (define defn-d (ws-read "defn foo [x]\n  + x 1"))
  (check-equal? defn-d '(defn foo (x) (+ x 1)))
  ;; A plain top-level expression with a continuation also stays wrapped.
  (define expr-d (ws-read "let x := 5\n  + x 1"))
  ;; (Just check the form parses without error and `:=` is at top level
  ;;  exactly where the user wrote it — the splice rule is def-only.)
  (check-equal? (car expr-d) 'let))

;; ========================================
;; End-to-end: two-line def actually evaluates downstream expressions
;; ========================================

;; The eigentrust pitfalls doc's headline failure is silent suppression: with the bug,
;; the def's body never runs, and any expression referencing the bound name
;; reports "Unbound variable". With the fix, the bound name evaluates as
;; expected.

;; Note: every E2E program needs `ns NAME` so the prelude (List, Rat,
;; numeric traits, ...) loads — `run-ns-ws-last` starts with an empty
;; prelude env per the standard test fixture pattern.

(define two-line-program
  (string-append
   "ns test-def-multiline-two\n"
   "def d : [List Rat]\n"
   "  := '[1/2 1/2 1/2]\n"
   "d\n"))

(define one-line-program
  (string-append
   "ns test-def-multiline-one\n"
   "def d : [List Rat] := '[1/2 1/2 1/2]\n"
   "d\n"))

(test-case "two-line def: bound name evaluates (not 'Unbound variable d')"
  (define result (run-ns-ws-last two-line-program))
  ;; result should be a string describing the value+type, NOT a prologos-error
  (check-true (string? result)
              (format "expected evaluation result string, got: ~v" result))
  ;; The value should print as the list literal we bound.
  (check-true (regexp-match? #rx"1/2 1/2 1/2" result)
              (format "expected bound value to print, got: ~v" result)))

(test-case "two-line def: result matches one-line def"
  (define r-two (run-ns-ws-last two-line-program))
  (define r-one (run-ns-ws-last one-line-program))
  (check-equal? r-two r-one
                "two-line and one-line def must produce identical results"))

(test-case "two-line def: mid-program references resolve"
  ;; Variant exercising several defs with a downstream expression that
  ;; depends on every one of them.
  (define program
    (string-append
     "ns test-def-multiline-mid\n"
     "def x : Int\n"
     "  := 10\n"
     "def y : Int\n"
     "  := 20\n"
     "+ x y\n"))
  (define result (run-ns-ws-last program))
  (check-true (string? result)
              (format "expected `+ x y` to evaluate, got: ~v" result))
  (check-true (regexp-match? #rx"30" result)
              (format "expected `30` in result, got: ~v" result)))

;; ========================================
;; Regression: the silently-suppressed evaluation case
;; ========================================
;;
;; Pre-fix behaviour (verified manually before applying the fix):
;;   Results count: 4
;;     [0] => "c : [List Rat] defined."
;;     [1] => (unbound-variable-error ... "Unbound variable" '$list-literal)
;;     [2] => "'[1/2 1/2 1/2] : [List Rat]"            ; c (one-line) ok
;;     [3] => (unbound-variable-error ... "Unbound variable" 'd)
;;
;; This test pins the post-fix behaviour: ALL four results are non-error,
;; and the two def forms produce equivalent value strings.

(test-case "downstream expressions after two-line def all evaluate cleanly"
  (define program
    (string-append
     "ns test-def-multiline-mixed\n"
     "def c : [List Rat] := '[1/2 1/2 1/2]\n"   ;; one-line baseline
     "def d : [List Rat]\n"
     "  := '[1/2 1/2 1/2]\n"                     ;; two-line
     "c\n"
     "d\n"))
  (define results (run-ns-ws-all program))
  (check-equal? (length results) 4
                (format "expected 4 results, got: ~a (~v)" (length results) results))
  (for ([r (in-list results)] [i (in-naturals)])
    (check-true (string? r)
                (format "result [~a] expected string, got: ~v" i r)))
  ;; The two def status strings should match (modulo whitespace/name).
  (define c-result (list-ref results 2))
  (define d-result (list-ref results 3))
  (check-equal? c-result d-result
                "c (one-line) and d (two-line) must evaluate to the same value"))
