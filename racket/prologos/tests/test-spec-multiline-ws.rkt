#lang racket/base

;;;
;;; Regression tests for multi-line `spec` forms in WS mode.
;;;
;;; Background — the eigentrust pitfalls doc (2026-04-23) #6 reported that
;;; a multi-line spec like
;;;
;;;     spec eigentrust-step
;;;          [List [List Rat]]   ;; matrix C
;;;          [List Rat]          ;; pre-trust p
;;;          Rat                 ;; damping
;;;          [List Rat]          ;; current t
;;;          -> [List Rat]       ;; next t
;;;     defn eigentrust-step [c p alpha t] ...
;;;
;;; failed with
;;;
;;;     spec: spec type for eigentrust-step has no arrow but defn has 4 params
;;;
;;; Root cause — the WS reader wraps each indent-grouped continuation line
;;; with multiple tokens as a sub-list (via wrap-stx-list). When the user
;;; placed `-> [List Rat]` on its own continuation line, that line wrapped
;;; to `(-> [List Rat])`, hiding the arrow inside a sub-list where
;;; split-on-arrow-datum (which only scans the top level of the spec body
;;; tokens) couldn't see it. Line comments are a red herring — they're
;;; stripped by the tokenizer; the bug is purely about indent wrapping of
;;; multi-token continuation lines in spec form bodies.
;;;

(require rackunit
         "../parse-reader.rkt")

;; Read a single WS datum
(define (ws-read s)
  (define in (open-input-string s))
  (prologos-read in))

;; Read all WS datums until eof
(define (ws-read-all s)
  (define in (open-input-string s))
  (let loop ([acc '()])
    (define d (prologos-read in))
    (if (eof-object? d) (reverse acc) (loop (cons d acc)))))

;; ========================================
;; Multi-line spec body tokens stay flat
;; ========================================

(test-case "multi-line spec: arrow on its own continuation line is at top level"
  (define d (ws-read "spec foo\n     A\n     B\n     -> C"))
  ;; Body tokens: (A B -> C). The `->` MUST be at the top level (not buried
  ;; inside a sub-list) for split-on-arrow-datum to find it.
  (check-equal? d '(spec foo A B -> C))
  (check-not-false (memq '-> (cddr d))
                   "arrow must appear at top level of spec body tokens"))

(test-case "multi-line spec: bracket-grouped types preserved as sub-lists"
  (define d (ws-read "spec eigentrust-step\n     [List [List Rat]]\n     [List Rat]\n     Rat\n     [List Rat]\n     -> [List Rat]"))
  ;; Each [...]-grouped type stays a sub-list (came from explicit brackets,
  ;; not from indent grouping). The arrow line `-> [List Rat]` is spliced
  ;; so that `->` is at top level.
  (check-equal? d
                '(spec eigentrust-step
                       (List (List Rat))
                       (List Rat)
                       Rat
                       (List Rat)
                       -> (List Rat)))
  (check-not-false (memq '-> (cddr d))
                   "arrow must appear at top level of spec body tokens"))

(test-case "multi-line spec: line comments between tokens do not break it"
  ;; The eigentrust pitfalls doc #6 reproducer — with trailing line
  ;; comments on every continuation line.
  (define src
    (string-append
     "spec eigentrust-step\n"
     "     [List [List Rat]]   ;; matrix C\n"
     "     [List Rat]          ;; pre-trust p\n"
     "     Rat                 ;; damping\n"
     "     [List Rat]          ;; current t\n"
     "     -> [List Rat]       ;; next t\n"))
  (define d (ws-read src))
  (check-equal? d
                '(spec eigentrust-step
                       (List (List Rat))
                       (List Rat)
                       Rat
                       (List Rat)
                       -> (List Rat))))

(test-case "multi-line spec: still works when `defn` follows on a sibling line"
  (define src
    (string-append
     "spec eigentrust-step\n"
     "     [List [List Rat]]\n"
     "     [List Rat]\n"
     "     Rat\n"
     "     [List Rat]\n"
     "     -> [List Rat]\n"
     "defn eigentrust-step [c p alpha t]\n"
     "  c\n"))
  (define forms (ws-read-all src))
  (check-equal? (length forms) 2 "spec and defn are two separate top-level forms")
  (check-equal? (car forms)
                '(spec eigentrust-step
                       (List (List Rat))
                       (List Rat)
                       Rat
                       (List Rat)
                       -> (List Rat)))
  (check-equal? (caar (cdr forms)) 'defn))

;; ========================================
;; Single-line spec is unchanged
;; ========================================

(test-case "single-line spec: unchanged behavior"
  (define d (ws-read "spec foo Nat -> Bool"))
  (check-equal? d '(spec foo Nat -> Bool)))

(test-case "single-line spec with bracket function-type param: unchanged"
  ;; [-> Nat Bool] is a legitimate prefix-arrow function type — the
  ;; sub-list (-> Nat Bool) MUST be preserved (it's bracket-grouped, not
  ;; indent-grouped).
  (define d (ws-read "spec all? [-> Nat Bool] -> [List Nat] -> Bool"))
  (check-equal? d '(spec all? (-> Nat Bool) -> (List Nat) -> Bool)))

;; ========================================
;; Metadata continuations stay wrapped
;; ========================================

(test-case "spec with :doc continuation: keyword line stays wrapped as sub-list"
  ;; The process-spec metadata loop expects (:doc "value") as a sub-list,
  ;; so metadata-style continuation lines must NOT be spliced.
  (define d (ws-read "spec sum [Add A] -> [List A] -> A\n  :doc \"Sum a list\""))
  (check-equal? d '(spec sum (Add A) -> (List A) -> A (:doc "Sum a list"))))

(test-case "spec with type continuations AND :doc continuation: type lines spliced, :doc kept wrapped"
  (define src
    (string-append
     "spec foo\n"
     "     A\n"
     "     -> B\n"
     "     :doc \"description\"\n"))
  (define d (ws-read src))
  (check-equal? d '(spec foo A -> B (:doc "description"))))

(test-case "spec with forall (brace-params) + where + :doc, all multi-line"
  ;; Cover the dependent-type / trait-constraint / docstring keywords
  ;; together. The forall-style brace binder `{A : Type}` rides along on
  ;; the spec name's line, type tokens splice across continuation lines,
  ;; the bare `where` keyword splices flat (along with its trait
  ;; constraints), and the keyword-like `:doc` continuation is wrapped
  ;; per the metadata path.
  (define src
    (string-append
     "spec compare {A : Type}\n"
     "     A\n"
     "     A\n"
     "     -> Ord\n"
     "     where (Eq A)\n"
     "     :doc \"compare two values\"\n"))
  (define d (ws-read src))
  (check-equal? d '(spec compare ($brace-params A : Type)
                         A A -> Ord
                         where (Eq A)
                         (:doc "compare two values"))))

(test-case "spec multi-line forall+where+:doc matches one-line shape (modulo :doc wrap)"
  ;; Same content on a single line produces the same flat token stream up
  ;; to the `:doc` continuation — single-line `:doc` is bare, multi-line
  ;; `:doc` becomes `(:doc ...)` wrapped. Both shapes are accepted by
  ;; `process-spec`'s metadata loop.
  (define one-line
    "spec compare {A : Type} A A -> Ord where (Eq A) :doc \"compare two values\"")
  (check-equal? (ws-read one-line)
                '(spec compare ($brace-params A : Type)
                       A A -> Ord
                       where (Eq A)
                       :doc "compare two values")))

;; ========================================
;; Other forms are unaffected (defn, def, match, etc. still wrap
;; multi-token indent-grouped continuations as sub-lists)
;; ========================================

(test-case "defn body with multi-token continuation line: still wrapped"
  (define d (ws-read "defn foo [x]\n  do-thing x"))
  (check-equal? d '(defn foo (x) (do-thing x))))

(test-case "private spec- form: same multi-line treatment"
  (define d (ws-read "spec- foo\n     A\n     -> B"))
  (check-equal? d '(spec- foo A -> B)))
