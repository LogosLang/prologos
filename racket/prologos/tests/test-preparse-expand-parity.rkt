#lang racket/base

;;;
;;; `preparse-expand-single` must not stop short of `preparse-expand-all`.
;;;
;;; ═══════════════════════════════════════════════════════════════════════════
;;; THE INVARIANT, AND WHY IT IS EASY TO BREAK SILENTLY
;;;
;;; There are two preparse entry points and they are used by DIFFERENT SPINES:
;;;   · `preparse-expand-all`    — whole-file, used by the PREPARSE spine
;;;   · `preparse-expand-single` — per-form, used by the TREE spine's datum path
;;;     (tree-parser.rkt) and by the form-cell pipeline (form-cells.rkt)
;;;
;;; They must agree, because driver.rkt's merge compares their outputs. When they
;;; disagree the merge sees a "divergence" that is not a parser difference at all
;;; — it is one expander doing a pass the other skipped.
;;;
;;; ⚠ THIS WAS LIVE, and it was invisible. `-all` runs, in order:
;;;      spec injection -> **where-clause injection** -> preparse-expand-form
;;; while `-single`'s defn arm ran:
;;;      spec injection ->                              preparse-expand-form
;;; so a `spec f … where (Add A)` + `defn f` pair came out of `-single` with the
;;; `where` clause STILL ATTACHED and un-discharged, instead of the implicit
;;; dictionary parameter `$Add-A` that `-all` produces. MEASURED across the
;;; 163-file corpus, that single missing pass accounted for 12 of the 26
;;; remaining tree/preparse divergences (98% -> 99% agreement once added).
;;;
;;; It was invisible because the tree spine's output is not admitted by the merge
;;; (`tree-spine-admitted?`, driver.rkt), so nothing downstream ever saw the
;;; wrong expansion. It would have detonated the moment the spine was
;;; commissioned — as a "parser bug" in the wrong subsystem entirely.
;;;
;;; ⭐ I FIRST DIAGNOSED THIS WRONG, twice, and the correction is the lesson: the
;;; dict binders looked like generated-name noise, then like a STRUCTURAL ceiling
;;; ("per-form expansion cannot see cross-form spec context, so 98% is the
;;; realistic maximum"). Both were reasoning. Running the two expanders back to
;;; back on the same datum — with registries populated, exactly as the tree spine
;;; sees them — showed `-single` produced the spec injection FINE and simply left
;;; `where (-> A (-> A A))` sitting in the output. Not missing information. A
;;; missing pass.
;;; ═══════════════════════════════════════════════════════════════════════════

(require rackunit
         racket/list
         racket/string
         "../parse-reader.rkt"
         "../surface-rewrite.rkt"
         "../macros.rkt")

(register-default-token-patterns!)

;; `:no-prelude` + a locally-declared trait keeps this self-contained: the
;; where-clause discharge needs `Add` in the trait registry, and relying on the
;; prelude here would make the test depend on prelude load order.
(define src
  (string-join
   (list "ns expandparity :no-prelude"
         ""
         "trait Add {A}"
         "  add : A A -> A"
         ""
         "spec plus {A} A A -> A where (Add A)"
         "defn plus [x y]"
         "  [add x y]")
   "\n"))

(define stxs
  (let* ([pt (read-to-tree src)]
         [refined (refine-tag (parse-tree-root pt))])
    (read-all-forms-from-tree (struct-copy parse-tree pt [root refined]) src "<parity>")))

(define defn-datum
  (for/first ([s (in-list stxs)]
              #:when (let ([d (syntax->datum s)]) (and (pair? d) (eq? (car d) 'defn))))
    (syntax->datum s)))

;; Whole-file pass FIRST — this is what populates the trait/spec registries, and
;; it is the state the tree spine actually runs in (the merge computes the
;; preparse surfs before invoking the tree spine at all).
(define all-out (map (lambda (d) (if (syntax? d) (syntax->datum d) d))
                     (preparse-expand-all stxs)))

(define all-defn
  (for/first ([d (in-list all-out)] #:when (and (pair? d) (eq? (car d) 'defn))) d))

(define single-defn (preparse-expand-single defn-datum))

(test-case "expand-parity/fixture-is-well-formed"
  ;; guards against the test passing because the fixture silently failed to parse
  (check-true (and defn-datum #t) "no defn in the fixture")
  (check-true (and all-defn #t) "preparse-expand-all produced no defn"))

(test-case "expand-parity/single-discharges-the-where-clause"
  ;; ⭐ THE REGRESSION. Before the fix this held a literal `where` and no dict.
  (check-false (memq 'where single-defn)
               (format "`where` survived preparse-expand-single un-discharged: ~s" single-defn)))

(test-case "expand-parity/single-inserts-the-implicit-dict-binder"
  (define (mentions-dict? d)
    (regexp-match? #rx"[$]Add-A" (format "~s" d)))
  (check-true (mentions-dict? all-defn)
              "preparse-expand-all did not insert $Add-A — fixture no longer exercises the path")
  (check-true (mentions-dict? single-defn)
              (format "preparse-expand-single lost the implicit dict binder: ~s" single-defn)))

(test-case "expand-parity/the-two-expanders-AGREE-on-this-defn"
  ;; The invariant itself, stated directly. This is what the merge relies on.
  (check-equal? single-defn all-defn))
