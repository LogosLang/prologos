#lang racket/base

;;;
;;; reader-forms.rkt — THE reader-form-head registry.
;;;
;;; CIU T6 D4.P1b-iii (owner ruling on the P1b-iii mini-audit, wf_18992d66-b81).
;;;
;;; WHAT A READER-FORM HEAD IS: a symbol that, when a brace group is ADJACENT to
;;; it, means "the brace body belongs to that form" rather than "select from the
;;; thing on the left". `racket{(+ 1 2)}` is a foreign code block, not a
;;; selection off a variable named `racket`.
;;;
;;; WHY THIS MODULE EXISTS AT ALL — the layering problem the audit surfaced:
;;;   * head recognition lives at PREPARSE (macros.rkt's combine-foreign-blocks),
;;;   * head PRECEDENCE must be decided at GROUPING (parse-reader.rkt), because
;;;     adjacency is destroyed at the datum layer,
;;;   * and there is NO MODULE EDGE between them: parse-reader.rkt requires only
;;;     rrb / propagator / parse-lattice, and macros.rkt does not require
;;;     parse-reader.rkt.
;;; So neither could see the other's list. Before this module the set was
;;; hard-coded in macros.rkt and nowhere else the grouper could reach.
;;;
;;; THIS MODULE REQUIRES NOTHING PROJECT-LOCAL — deliberately. That is what lets
;;; both parse-reader.rkt (grouping) and macros.rkt (preparse) require it with no
;;; cycle. Keep it that way: adding a project require here would re-create the
;;; problem it exists to solve.
;;;
;;; ⚠ THE F1b.7g ANTI-DRIFT RULE APPLIES: this is the ONE list. Do not inline a
;;; second copy anywhere. That drift class is exactly how `recognize-keyword`
;;; diverged from `ident-continue?` for eight characters, and how
;;; `fused-type-annot?` diverged from its own recognizer (Q_N4, same phase).
;;;
;;; KNOWN RESIDUAL DIVERGENCE, accepted and named (P1b-iii audit): the Emacs
;;; tooling hard-codes the literal adjacent string "racket{" in TWO places —
;;; editors/emacs/prologos-mode.el and editors/emacs/prologos-font-lock.el. A
;;; Racket-side registry cannot reach `.el`, so those stay hand-maintained. They
;;; already require adjacency while the compiler's preparse did not, so
;;; P1b-iii CLOSES that divergence rather than opening one — but if a head is
;;; ever added here, the two `.el` sites need it too.
;;;

(provide reader-form-heads
         reader-form-head?)

;; The complete set. One entry today; the point is that it is ONE entry in ONE
;; place rather than an unfindable literal.
(define reader-form-heads '(racket))

;; Is `x` a reader-form head? Accepts the raw symbol; callers holding syntax
;; should unwrap first (grouping works on token lexemes, preparse on datums).
(define (reader-form-head? x)
  (and (symbol? x) (memq x reader-form-heads) #t))
