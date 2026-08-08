#lang racket/base
;; DEFERRED 59 (member 4) — the `def name := rel …` clause-srcloc collapse.
;;
;; WHY THIS TEST IS AT THE SRCLOC LEVEL AND NOT END-TO-END. The defect is a
;; SILENT clause mis-grouping, and it is unobservable from output: `pp-expr`'s
;; expr-rel arm elides the clauses, and a def-bound `rel` VALUE cannot be
;; queried. Measured — the mis-grouped spelling and a shape-identical control
;; print byte-identically (`(rel [1] ...) : _`, 0 errors). The existing
;; end-to-end guard in test-rel-t1-pol.rkt is VACUOUS for exactly that reason:
;; both sides collapse the same way, so `check-equal?` passes over a live bug.
;; So this pins the mechanism directly, which is the only honest option.
;;
;; THE DEFECT: `expand-def-assign` MINTS a new `(rel …)` list to wrap a spliced
;; multi-token RHS. That minted node is datum-equal to nothing in the original,
;; so `rebuild-preserving-locs` stamps it with the changed-middle anchor — the
;; `:=` token — and the `$clause-sep` group inherits `:=`'s line and column.
;; A NONZERO column means POL.8's degradation marker `(zero? sent-col)` never
;; fires, `parse-degraded` is skipped, and the layout walk sees one line and
;; therefore one goal.
;;
;; ⚠ It only fires when a preparse REWRITE sits inside the rel. Without one the
;; `$clause-sep` group is datum-unchanged, so DEFERRED 58's origin index returns
;; the original wholesale and the srclocs are right. That is why the no-rewrite
;; control below is the correct oracle: it is the SAME spelling, differing only
;; in whether a rewrite is present.
(require rackunit
         (only-in "../parse-reader.rkt" prologos-read-syntax-all)
         (only-in "../macros.rkt" preparse-expand-all))

;; Find the `$clause-sep` SENTINEL anywhere in a preparsed form; return
;; (cons line column), or #f.
;;
;; ⚠ It appears in TWO shapes, and a helper that knows only one silently returns
;; #f for the other. Indent-grouped sources (the unparenthesized spellings) give
;; a GROUP headed by `$clause-sep`; inside explicit parens the reader SUSPENDS
;; indent grouping, so the sentinel arrives as a BARE SYMBOL among flat elements.
;; Both are "the sentinel's position" as `parse-clause-content` reads it.
(define (clause-sep-loc src)
  (define stxs (prologos-read-syntax-all "<probe>" (open-input-string src)))
  (define out (preparse-expand-all stxs))
  (let/ec return
    (for ([s (in-list out)])
      (when (syntax? s)
        (let walk ([x s])
          (when (syntax? x)
            (define d (syntax->datum x))
            (when (or (eq? d '$clause-sep)
                      (and (pair? d) (eq? (car d) '$clause-sep)))
              (return (cons (syntax-line x) (syntax-column x))))
            (define e (syntax-e x))
            (when (pair? e)
              (for ([kid (in-list (if (list? e) e (list (car e))))])
                (walk kid)))))))
    #f))

;; line 1 `ns`, line 2 `def …`, line 3 `&> …`, line 4 the second goal.
;; The `&>` sentinel is at column 2 on line 3 in BOTH sources.
(define SRC-REWRITE
  (string-append "ns m4s\n"
                 "def k1 := rel [?f]\n"
                 "  &> fruit-color f mm.k\n"
                 "     fruit-color f \"yellow\"\n"))
(define SRC-CONTROL
  (string-append "ns m4s\n"
                 "def k2 := rel [?f]\n"
                 "  &> fruit-color f \"blue\"\n"
                 "     fruit-color f \"yellow\"\n"))
(define SRC-PAREN
  (string-append "ns m4s\n"
                 "def k3 := (rel [?f]\n"
                 "  &> fruit-color f mm.k\n"
                 "     fruit-color f \"yellow\")\n"))

(test-case "DEFERRED 59: the no-rewrite control keeps the sentinel's real position"
  ;; Establishes the oracle: this spelling is capable of correct srclocs.
  (check-equal? (clause-sep-loc SRC-CONTROL) (cons 3 2)))

(test-case "DEFERRED 59: the PAREN spelling keeps it too, even with a rewrite"
  ;; The known-correct sibling — isolates the defect to the UNPARENTHESIZED form.
  (check-equal? (clause-sep-loc SRC-PAREN) (cons 3 2)))

(test-case "DEFERRED 59 ⭐ member 4: an unparen `def := rel` with a REWRITE keeps it as well"
  ;; The defect proper. Before the fix this was (2 . 7) — line 2, the column of
  ;; the `:=` token — nonzero, so the POL.8 guard stayed blind and the two goals
  ;; collapsed into one 3-argument goal.
  (check-equal? (clause-sep-loc SRC-REWRITE) (cons 3 2)))
