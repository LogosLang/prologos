#lang racket/base

;;;
;;; Tripwire for the dual-spine merge key (`loc->line`, driver.rkt).
;;;
;;; ═══════════════════════════════════════════════════════════════════════════
;;; WHAT THIS PINS, AND WHY IT IS A TRIPWIRE RATHER THAN A FEATURE TEST
;;;
;;; `merge-preparse-and-tree-parser` merges two parser spines keyed by SOURCE
;;; LINE, and its last arm is `[else tree-surf]` — "tree parser wins for user
;;; forms". MEASURED 2026-08-02 over the 163-file corpus (5,171 forms): the tree
;;; spine wins **0 forms**. It never has, in the whole life of that code, because
;;; the key was broken three ways at once.
;;;
;;; Correcting the key is NOT the fix. Measured: with a correct key the tree
;;; spine wins ~694 forms and the corpus REGRESSES — errors 359 -> 724 across 35
;;; files with not one improvement, two clean files lost to whole-file aborts,
;;; and 32 test files fail. The legacy `parse-*-tree` family went stale precisely
;;; BECAUSE it never ran; classification found 14 distinct defects across 4
;;; layers, two of which cannot be repaired inside tree-parser.rkt at all.
;;; So the merge is deliberately kept preparse-authoritative.
;;;
;;; ⚠ WHAT THIS FILE CATCHES, AND WHAT IT DELIBERATELY DOES NOT.
;;;
;;; The defusal lives at the ADMISSION GATE — `tree-spine-admitted?` in
;;; driver.rkt's `merge-preparse-and-tree-parser`. These assertions fail if that
;;; gate is opened without first repairing the tree spine's arms. Each construct
;;; below is one the tree spine parses DIFFERENTLY, so admitting it flips them.
;;; If this file starts failing, someone opened the gate — read
;;; docs/tracking/2026-08-02_LOC_TO_LINE_MERGE_DEFECT.md before "fixing" it.
;;;
;;; It does NOT trip on making `item-srcloc` (tree-parser.rkt) emit a real
;;; 1-based `srcloc` struct — and that is the POINT, not a gap. That change is
;;; independently correct (`format-srcloc` RAISES on the bare list a tree surf
;;; carries today; the LSP's `srcloc->range` degrades every diagnostic to 0:0;
;;; `register-definition-location!`'s values are .pnet-serialized where only the
;;; struct shape is registered). An earlier version of this fix guarded at the
;;; merge KEY, where that correct change silently re-armed 694 form-swaps; the
;;; gate was moved precisely so a guard is not defeated by someone else doing the
;;; right thing.
;;;
;;; BOTH DIRECTIONS VERIFIED (2026-08-02):
;;;  · `item-srcloc` struct conversion applied  -> this file PASSES (guard holds)
;;;  · `tree-spine-admitted?` flipped to #t     -> this file FAILS, e.g.
;;;      [0] "#(struct:unbound-variable-error (0 0 25 32) Unbound variable Keyword)"
;;;      [3] "church : [[Pi [x :0 <Int>] Int]] Int -> Int defined."   <- SILENT
;;;    Note [0]'s srcloc is the raw LIST `(0 0 25 32)` — `item-srcloc`'s TOKEN
;;;    branch, which the struct conversion does not cover either. That list is
;;;    what makes `format-srcloc` raise `expected: srcloc?`.
;;; ═══════════════════════════════════════════════════════════════════════════

(require rackunit
         racket/list
         racket/file
         racket/string
         "../driver.rkt"
         "../namespace.rkt"
         "test-support.rkt")

;; process-file a fixture string under a fresh per-file mnr (isolation).
;; process-file — NOT process-string-ws — is load-bearing: only the FILE path
;; leaves `current-source-str` unset, which is what routes the tree spine through
;; the legacy `parse-*-tree` arms these constructs discriminate against.
(define (run-file-fixture str)
  (define tmp (make-temporary-file "mergekey-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display str out)))
  (define result
    (parameterize ([current-file-module-network-ref (make-module-network)]
                   [current-ns-context #f])
      (process-file (path->string tmp))))
  (delete-file tmp)
  result)

(define results
  (run-file-fixture
   (string-join
    (list "ns mergekey"
          ;; [0] `Keyword` is one of 31 atoms missing from the tree spine's
          ;;     11-entry table (parser.rkt's has 42) -> `(surf-var 'Keyword)`.
          "def kw-val : Keyword := :test"
          ;; [1] the tree spine builds `{…}` as the RETIRED surf-map-assoc chain
          ;;     over holes, never `surf-map-literal`, so CIU T6's closed-record
          ;;     seeding never runs and both hole-metas stay unsolved.
          "def m := {:name \"alice\" :age 30}"
          ;; [2] consequence of [1] — the field type is unrecoverable.
          "m.name"
          ;; [3] ⭐ THE SILENT ONE, and the reason this file asserts TYPES and not
          ;;     just error counts. `<A -> B>` hardcodes multiplicity 'm0
          ;;     (ERASED) in the tree spine; preparse passes #f -> mw. Under a
          ;;     re-armed merge this line still "defines" with ZERO errors — only
          ;;     the printed type changes, to `[[Pi [x :0 <Int>] Int]] Int -> Int`.
          ;;     An error-count gate cannot see this class at all.
          "def church := [fn [f : <Int -> Int>] [fn [x : Int] [f [f x]]]]")
    "\n")))

(define (res n) (format "~a" (list-ref results n)))

(test-case "merge-key/tree-spine-does-not-win-atom-table"
  ;; Re-armed: "ERROR: Unbound variable"
  (check-equal? (res 0) "kw-val : Keyword defined."))

(test-case "merge-key/tree-spine-does-not-win-map-literal"
  ;; Re-armed: "ERROR: Could not infer type"
  (check-equal? (res 1) "m : {:age Int :name String} defined."))

(test-case "merge-key/tree-spine-does-not-win-record-field-access"
  ;; Re-armed: "ERROR: Unbound variable"
  (check-equal? (res 2) "\"alice\" : String"))

(test-case "merge-key/tree-spine-does-not-win-arrow-multiplicity-SILENT"
  ;; Re-armed: "church : [[Pi [x :0 <Int>] Int]] Int -> Int defined." — still a
  ;; successful definition, zero errors, WRONG multiplicity. This assertion is
  ;; the one that catches the silent class.
  (check-equal? (res 3) "church : [Int -> Int] Int -> Int defined."))

(test-case "merge-key/fixture-is-otherwise-clean"
  ;; Guards against the assertions above passing for an unrelated reason (e.g.
  ;; the whole file failing to load). Re-armed: 3.
  (check-equal? (length (filter (lambda (r) (string-prefix? (format "~a" r) "ERROR"))
                                results))
                0))
