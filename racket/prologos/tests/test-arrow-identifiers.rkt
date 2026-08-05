#lang racket/base

;;;
;;; ARROW T1 P1 — `->` glued between identifier chars is part of the name.
;;;
;;; These assert the TOKEN STREAM directly, not just end-to-end behaviour.
;;; That matters here: the defect was a mis-lex, and its most damaging symptom
;;; was remote — the stray `rangle` popped a bracket frame, so `[int->str x]`
;;; lost its `[` and errors surfaced far from the cause. An end-to-end-only
;;; test would pin the symptom and miss the mechanism.
;;;
;;; THE RULE: `->` continues an identifier iff flanked by identifier characters
;;; on BOTH sides. NOT "no surrounding whitespace" — 275 live corpus sites glue
;;; `->` to an opening bracket (`[-> [List A] [Option A]]`), and those must
;;; keep lexing as the standalone arrow.
;;;
;;; Half of these are REGRESSION ANCHORS (behaviour that must not change)
;;; rather than discriminators for the new rule; each is labelled, per the
;;; "a pin that turns only one red is thin" note in the dailies.
;;;

(require rackunit
         racket/list
         "../parse-reader.rkt")

;; (type . value) for the real tokens — drops the leading newline and the eof
;; sentinel the tokenizer brackets every string with.
(define (toks s)
  (for/list ([t (in-list (tokenize-string s))]
             #:unless (memq (compat-token-type t) '(newline eof)))
    (cons (compat-token-type t) (compat-token-value t))))

;; ========================================
;; The new rule — discriminators
;; ========================================

(test-case "glued -> is absorbed into the identifier"
  (check-equal? (toks "c->f")     '((symbol . c->f)))
  (check-equal? (toks "int->str") '((symbol . int->str)))
  ;; the reported case
  (check-equal? (toks "centigrade->fahrenheit") '((symbol . centigrade->fahrenheit))))

(test-case "chained arrows, and composition with the :: module path"
  (check-equal? (toks "a->b->c")  '((symbol . a->b->c)))
  (check-equal? (toks "x::y->z")  '((symbol . x::y->z))))

(test-case "keywords take the same rule (owner ruling R1)"
  ;; recognize-keyword must not lag recognize-symbol — that divergence IS the
  ;; F1b.7g drift class this codebase has already paid for once.
  (check-equal? (toks ":a->b") '((keyword . :a->b))))

;; ========================================
;; Regression anchors — must NOT change
;; ========================================

(test-case "ANCHOR: spaced arrows are untouched"
  ;; Every arrow consumer reads this token: spec signatures, defn/match arms,
  ;; angle-group Pi types, and binder-region-terminators.
  (check-equal? (toks "a -> b")  '((symbol . a) (symbol . ->) (symbol . b)))
  ;; right-glued only — still the arrow, because the rule needs BOTH sides
  (check-equal? (toks "a ->b")   '((symbol . a) (symbol . ->) (symbol . b))))

(test-case "ANCHOR: prefix arrow-type form keeps its standalone arrow"
  ;; `[-> [List A] [Option A]]` — 275 such sites in lib/ + examples/. This is
  ;; why the rule is NOT "no surrounding whitespace".
  (check-equal? (toks "[-> A B]")
                '((lbracket . |[|) (symbol . ->) (symbol . A) (symbol . B) (rbracket . |]|))))

(test-case "ANCHOR: angle groups still close"
  ;; `>` must never join ident-continue?: 1,416 of 1,444 ident-glued `>` chars
  ;; in the corpus close an angle group. The rule's `-`-before-`>` requirement
  ;; is what keeps `Bool>` intact.
  (check-equal? (toks "<Int -> Bool>")
                '((langle . <) (symbol . Int) (symbol . ->) (symbol . Bool) (rangle . >)))
  ;; glued inside a group: the arrow is absorbed (owner ruling R3 — accepted),
  ;; but the closing rangle SURVIVES, which is the load-bearing half.
  (check-equal? (toks "<Int->Bool>")
                '((langle . <) (symbol . Int->Bool) (rangle . >))))

(test-case "ANCHOR: bare > is still glue-insensitive"
  ;; `a>b` and `a > b` tokenized identically before this change and still do.
  (check-equal? (toks "a>b") '((symbol . a) (rangle . >) (symbol . b))))

;; ========================================
;; Documented edges (pins, not aspirations)
;; ========================================

(test-case "leading ->foo stays two tokens (both-sides rule)"
  ;; A known WS/sexp divergence: sexp reads `->foo` as one symbol. The
  ;; both-sides rule deliberately does not close that gap; pinned so a future
  ;; change to it is a conscious decision. See the design doc §8.5.
  (check-equal? (toks "->foo") '((symbol . ->) (symbol . foo))))

(test-case "a-->b is absorbed whole"
  ;; The second `-` is the flanking ident char, so the trailing `->b` is taken.
  ;; Zero code-region instances corpus-wide (all 19 `-->` are comments), so this
  ;; is latent rather than load-bearing — pinned so it is not a surprise later.
  (check-equal? (toks "a-->b") '((symbol . a-->b))))

(test-case "HALF-GLUED still truncates — P1b (owner ruling R2) target"
  ;; `a-> b` and `foo->` are NOT identifiers under the both-sides rule, and are
  ;; not yet a guided error either: they still lex as `a-` + rangle, exactly as
  ;; before this change. Pinned as the CURRENT state so P1b's guided error has
  ;; a failing baseline to move.
  (check-equal? (toks "a-> b") '((symbol . a-) (rangle . >) (symbol . b)))
  (check-equal? (toks "foo->") '((symbol . foo-) (rangle . >))))
