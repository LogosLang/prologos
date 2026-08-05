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
;;; ⚠ WHAT THIS FILE CATCHES — AND THE MECHANISM IT GUARDS HAS CHANGED ONCE.
;;;
;;; HISTORY, because the file's name and its assertions now outlive two different
;;; guards, and knowing which one you are looking at matters:
;;;   1. originally the defusal was at the merge KEY (`loc->line`) — WRONG PLACE:
;;;      giving the tree spine real `srcloc` structs is an independently correct
;;;      change (`format-srcloc` RAISES on the bare list a tree surf carries; the
;;;      LSP's `srcloc->range` degrades every diagnostic to 0:0;
;;;      `register-definition-location!`'s values are .pnet-serialized where only
;;;      the struct shape is registered) and it silently re-armed 694 form-swaps.
;;;      A guard defeated by someone else doing the right thing is the wrong guard.
;;;   2. then at an ADMISSION GATE (`tree-spine-admitted?`), which survived that.
;;;   3. NOW: there is no gate, because **there is no tree leg to gate**. PPN
;;;      Track 3 Phase 7's second half removed it — `tree-surfs`, `tree-by-line`
;;;      and `merge-form` are gone from driver.rkt; the merge is the preparse
;;;      pass-through plus the `consumed-form-residue?` filter, and it keeps the
;;;      form-cell block (Track 3's deliverable, and the intended replacement).
;;;
;;; SO WHAT THIS PINS NOW: that these four constructs are parsed by PREPARSE.
;;; Each was chosen because the legacy `parse-*-tree` arms parse it DIFFERENTLY,
;;; so the assertions flip the moment any tree-spine output is admitted again —
;;; whether by a new merge, by wiring the form cells to produce surfs, or by
;;; reviving `extract-surfs-from-form-cells` (which still calls `parse-form-tree`
;;; and today has ZERO production callers). If this file starts failing, someone
;;; re-admitted the tree spine — read
;;; docs/tracking/2026-08-02_LOC_TO_LINE_MERGE_DEFECT.md before "fixing" it.
;;;
;;; VERIFIED WHEN THE GATE STILL EXISTED (2026-08-02) — kept because it is the
;;; evidence that these four assertions actually discriminate:
;;;  · `item-srcloc` struct conversion applied  -> this file PASSES
;;;  · `tree-spine-admitted?` flipped to #t     -> this file FAILS, e.g.
;;;      [0] "#(struct:unbound-variable-error (0 0 25 32) Unbound variable Keyword)"
;;;      [3] "church : [[Pi [x :0 <Int>] Int]] Int -> Int defined."   <- SILENT
;;;    Note [0]'s srcloc is the raw LIST `(0 0 25 32)` — `item-srcloc`'s TOKEN
;;;    branch. That list is what makes `format-srcloc` raise `expected: srcloc?`.
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
;; leaves `current-source-str` unset, which is what routed the tree spine through
;; the legacy `parse-*-tree` arms these constructs discriminate against. (That
;; fork still exists in `parse-form-tree`; the merge simply no longer reaches it.
;; Keep using process-file so a revival is caught on the path it would revive on.)
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
