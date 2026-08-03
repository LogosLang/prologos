#lang racket/base

;;;
;;; Tests for the spine-census comparator (tools/spine-census.rkt).
;;;
;;; ═══════════════════════════════════════════════════════════════════════════
;;; WHY A DIAGNOSTIC TOOL GETS TESTS
;;;
;;; This tool exists to find silent wrong answers between two parser spines. Its
;;; first two drafts each CONTAINED one — the same class it was built to catch —
;;; and both produced confident, plausible, wrong numbers:
;;;
;;;   1. MASKING BY POSITION. Of 377 surf structs, `srcloc` is the last field in
;;;      376 and at index 3 of 5 in `surf-narrow` (lhs rhs vars srcloc
;;;      constraint-map). "Drop the last field" would have compared its SRCLOC as
;;;      data and skipped its CONSTRAINT-MAP entirely. A regex census over
;;;      single-line struct forms reported 292/292 clean and would have shipped it.
;;;
;;;   2. RECURSING ONLY INTO surf-* STRUCTS. surf nodes are reached through
;;;      NON-surf carriers — `binder-info` holds a surf-type holds a srcloc — so
;;;      `equal?` on the carrier compared srclocs as data. That manufactured
;;;      ~500 FALSE divergences out of 1,039 on the first corpus run.
;;;
;;; A number from an unverified instrument is worse than no number, because it
;;; gets acted on. These tests pin both, plus a POSITIVE CONTROL: a comparator
;;; that always answered "equivalent" would satisfy every masking test, so one
;;; case asserts a real difference IS caught.
;;; ═══════════════════════════════════════════════════════════════════════════

(require rackunit
         "../surface-syntax.rkt"
         "../source-location.rkt"
         "../tools/spine-census.rkt")

(define (loc n) (srcloc "f.prologos" n 0 0))
(define other  (srcloc "OTHER.prologos" 999 7 3))

;; ────────────────────────────────────────────────────────────────────────────
;; The mask table
;; ────────────────────────────────────────────────────────────────────────────

(test-case "census/mask-table-covers-every-surf-struct"
  ;; The table is derived by READING surface-syntax.rkt, so it cannot go stale —
  ;; but it can be EMPTY if the reader silently fails. Guard the floor.
  (check-true (> (hash-count srcloc-index) 300)
              "mask table looks empty/partial — did surface-syntax.rkt parsing fail?")
  ;; every entry must have located a srcloc field (none may be #f)
  (check-equal? (for/list ([(k v) (in-hash srcloc-index)] #:when (not v)) k)
                '()
                "some surf struct has no srcloc/loc field — masking would be undefined"))

(test-case "census/surf-narrow-is-the-non-final-srcloc-and-is-known"
  ;; ⭐ THE TRAP. If this ever becomes 4, someone reordered surf-narrow's fields
  ;; and a positional comparator would silently start comparing srclocs as data.
  (check-equal? (mask-index-for 'surf-narrow) 3
                "surf-narrow's srcloc moved — re-check every positional assumption")
  ;; and the overwhelming majority ARE last, which is what makes the exception
  ;; dangerous rather than obvious
  (check-equal? (mask-index-for 'surf-var) 1)
  (check-equal? (mask-index-for 'surf-pi) 2))

(test-case "census/unknown-struct-fails-LOUDLY-rather-than-guessing"
  (check-exn exn:fail?
             (lambda () (mask-index-for 'surf-does-not-exist-anywhere))
             "an unknown struct must raise, never return a silent default"))

;; ────────────────────────────────────────────────────────────────────────────
;; The comparator
;; ────────────────────────────────────────────────────────────────────────────

(test-case "census/srcloc-differences-are-masked-on-a-plain-surf"
  (check-false (diff (surf-var 'x (loc 1)) (surf-var 'x other))))

(test-case "census/srcloc-masked-THROUGH-a-non-surf-carrier"
  ;; REGRESSION for instrument bug 2: binder-info is NOT a surf struct, so a
  ;; comparator that only recursed into surf-* would `equal?` the whole carrier
  ;; and report the nested srcloc as a divergence.
  (define a (surf-pi (binder-info 'x #f (surf-int-type (loc 1))) (surf-var 'x (loc 1)) (loc 1)))
  (define b (surf-pi (binder-info 'x #f (surf-int-type other))   (surf-var 'x other)   other))
  (check-false (diff a b) "srcloc reached through binder-info was not masked"))

(test-case "census/srcloc-masked-at-surf-narrow's-NON-FINAL-slot"
  ;; REGRESSION for instrument bug 1, both directions in one case:
  ;;   · the srcloc at index 3 must be IGNORED
  ;;   · the constraint-map at index 4 must still be COMPARED
  (define (mk l cm) (surf-narrow (surf-var 'a (loc 1)) (surf-var 'b (loc 1)) '(a b) l cm))
  (check-false (diff (mk (loc 1) 'same) (mk other 'same))
               "surf-narrow's srcloc (index 3) was not masked")
  (check-true (and (diff (mk (loc 1) 'one) (mk (loc 1) 'two)) #t)
              "surf-narrow's constraint-map (index 4) was SKIPPED — the positional bug"))

;; ⭐ POSITIVE CONTROLS — without these, a comparator hardwired to #f passes everything.

(test-case "census/real-value-difference-IS-caught"
  (define d (diff (surf-var 'x (loc 1)) (surf-var 'DIFFERENT (loc 1))))
  (check-true (and d #t) "a differing field was not reported")
  (check-equal? (cadr d) "value"))

(test-case "census/real-node-kind-difference-IS-caught"
  (define d (diff (surf-var 'x (loc 1)) (surf-int-type (loc 1))))
  (check-true (and d #t))
  (check-equal? (cadr d) "node-kind"))

(test-case "census/difference-NESTED-under-a-carrier-IS-caught"
  ;; the masking test above must not be passing merely because recursion stops
  (define a (surf-pi (binder-info 'x #f (surf-int-type (loc 1))) (surf-var 'x (loc 1)) (loc 1)))
  (define b (surf-pi (binder-info 'y #f (surf-int-type (loc 1))) (surf-var 'x (loc 1)) (loc 1)))
  (define d (diff a b))
  (check-true (and d #t) "a differing binder NAME under binder-info was not reported"))

(test-case "census/reported-values-never-leak-a-srcloc"
  ;; The tell that instrument bug 2 was live: `struct:srcloc` appearing inside a
  ;; reported divergence. Whatever diverges, the REPORT must be srcloc-free.
  (define d (diff (surf-pi (binder-info 'x #f (surf-int-type (loc 1))) (surf-var 'x (loc 1)) (loc 1))
                  (surf-pi (binder-info 'y #f (surf-int-type other))   (surf-var 'x other)   other)))
  (check-true (and d #t))
  (check-false (regexp-match? #rx"struct:srcloc" (format "~a ~a" (caddr d) (cadddr d)))
               "a srcloc leaked into the divergence report"))
