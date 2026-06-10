#lang racket/base

;;;
;;; test-forward-ref-01.rkt — PPN 4C Addendum Phase 4B.3-b (§18.21.22)
;;;
;;; The ACTIVE flip: forward bare-ref residuation. `def x := a` where `a` is a
;;; not-yet-defined SAME-FILE def-head installs a δ residuation propagator on
;;; NET-1 (the per-file mnr) + defers the commit; the file-end drive fires the δ
;;; when `a` grounds; the DQ5 post-drive sweep finalizes the result.
;;;
;;; Residuation is process-file-GATED (DQ4 — only process-file runs the drive +
;;; the finalize sweep), so these MUST run via process-file (NOT process-string-ws,
;;; where a forward ref errors immediately, status quo).
;;;
;;; Boundary (DEF vs USE): the slice residuates DEF BODIES. A top-level EXPRESSION
;;; that USES a forward-def before the file-end drive sees it pending → errors;
;;; that is the 4C all-at-once / general-body (4B.5) territory the design deferred.
;;;

(require rackunit
         racket/list
         racket/file
         "../driver.rkt"
         "../namespace.rkt"
         "../errors.rkt")

;; process-file a fixture string under a fresh per-file mnr (isolation). The
;; simple Nat-literal fixtures need no prelude (5N is a built-in literal).
(define (run-file-fixture str)
  (define tmp (make-temporary-file "fwdref-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display str out)))
  (define result
    (parameterize ([current-file-module-network-ref (make-module-network)]
                   [current-ns-context #f])
      (process-file (path->string tmp))))
  (delete-file tmp)
  result)

;; does the results list contain an unbound-variable-error for `name`?
(define (unbound-for? results name)
  (for/or ([r (in-list results)])
    (and (unbound-variable-error? r)
         (eq? (unbound-variable-error-name r) name))))

(define (has? results s) (and (member s results) #t))

;; ① forward DEF — the slice's deliverable: `def x := a` resolves at file-end.
(test-case "4B.3-b: forward def resolves (def x := a; def a := 5N)"
  (define rs (run-file-fixture "ns tf1\ndef x := a\ndef a := 5N"))
  (check-true (has? rs "x : Nat defined."))
  (check-true (has? rs "a : Nat defined.")))

;; ② forward DEF-CHAIN — a residuates → x's δ → y's δ, all at the one drive.
(test-case "4B.3-b: forward def-chain resolves (def y := x; def x := a; def a := 5N)"
  (define rs (run-file-fixture "ns tf2\ndef y := x\ndef x := a\ndef a := 5N"))
  (check-true (has? rs "y : Nat defined."))
  (check-true (has? rs "x : Nat defined."))
  (check-true (has? rs "a : Nat defined.")))

;; backward control — x is ground before its use, so the use works (parity).
(test-case "4B.3-b: backward control (def a := 5N; def x := a; x ⇒ 5N)"
  (define rs (run-file-fixture "ns tf3\ndef a := 5N\ndef x := a\nx"))
  (check-true (has? rs "a : Nat defined."))
  (check-true (has? rs "x : Nat defined."))
  (check-true (has? rs "5N : Nat")))

;; DQ5 file-end shift — a is a def-head (seeded, pending) but its def FAILS, so
;; x's δ never fires → the post-drive sweep emits x's unbound error at file-end.
(test-case "4B.3-b: never-grounded forward def → file-end unbound (DQ5)"
  (define rs (run-file-fixture "ns tf4\ndef x := a\ndef a := badref"))
  (check-true (unbound-for? rs 'x))        ;; residuated, never grounded → file-end
  (check-true (unbound-for? rs 'badref)))  ;; absent typo → immediate

;; typo — `nonexistent` is never a def-head (Pass 1.5 never seeds it → absent,
;; not pending), so it is NOT residuated and errors immediately at the ref site.
(test-case "4B.3-b: typo (absent, never a def-head) → immediate unbound"
  (define rs (run-file-fixture "ns tf5\ndef x := nonexistent"))
  (check-true (unbound-for? rs 'nonexistent)))

;; ③ the DEF-vs-USE boundary — AMENDED at 4B.5.a (§18.21.25.3, user-ratified):
;; a top-level USE now resolves against everything defined-or-deferred SO FAR
;; (the demand trigger runs the sweep fixpoint, firing x's δ, then retries).
;; The REMAINING boundary: uses depending on textually-LATER defs (4C).
(test-case "4B.5.a amendment: mid-file top-level use of a forward-def RESOLVES (demand sweep)"
  (define rs (run-file-fixture "ns tf6\ndef x := a\ndef a := 5N\nx"))
  (check-true (has? rs "x : Nat defined."))  ;; the DEF resolves
  (check-true (has? rs "5N : Nat"))           ;; the USE now resolves too
  (check-false (unbound-for? rs 'x)))

;;; ============================================================
;;; PPN 4C Addendum Phase 4B.4.a (§18.21.24) — fwd-annot: the ANNOTATED path
;;; residuates too. The δ RE-SUPPLIES the captured zonked annotation T
;;; (def-entry-merge's :type is new-wins — the referent's type would clobber T);
;;; the TC-(a) finalize-time check runs the deferred type-obligation (a ⊨ T).
;;; ============================================================

;; ④ forward ANNOTATED def — probe g, the 4B.4 deliverable.
(test-case "4B.4.a: forward annotated def resolves (def x : Nat := a; def a := 5N)"
  (define rs (run-file-fixture "ns tf7\ndef x : Nat := a\ndef a := 5N"))
  (check-true (has? rs "x : Nat defined."))
  (check-true (has? rs "a : Nat defined.")))

;; ⑤ annotated def-chain — all three at the one drive.
(test-case "4B.4.a: annotated forward def-chain resolves"
  (define rs (run-file-fixture "ns tf8\ndef y : Nat := x\ndef x : Nat := a\ndef a := 5N"))
  (check-true (has? rs "y : Nat defined."))
  (check-true (has? rs "x : Nat defined."))
  (check-true (has? rs "a : Nat defined.")))

;; ⑥ (annotated x, annotated a) — pins the moot open-item (§18.21.24.1): a
;; FORWARD referent is always still def-bot/'pending at the referrer's
;; processing time (a's own pre-register runs only inside a's later process-def).
(test-case "4B.4.a: annotated x referencing annotated a resolves (both annotated)"
  (define rs (run-file-fixture "ns tf9\ndef x : Nat := a\ndef a : Nat := 5N"))
  (check-true (has? rs "x : Nat defined."))
  (check-true (has? rs "a : Nat defined.")))

;; ⑦ backward annotated control — referent ground → 'pending fails → falls
;; through to the annotated [else] → status-quo synchronous path.
(test-case "4B.4.a: backward annotated control (def a := 5N; def x : Nat := a)"
  (define rs (run-file-fixture "ns tf10\ndef a := 5N\ndef x : Nat := a"))
  (check-true (has? rs "a : Nat defined."))
  (check-true (has? rs "x : Nat defined.")))

;; ⑧ T-PRESERVATION discriminator — the annotation is WIDER than the referent's
;; type. The cell must hold T (the union), NOT the referent's Int: had the δ
;; transplanted the referent's type (the clobber, D-4B4a-1), this would print
;; "x : Int defined." The TC check passes (Int ⊨ Int | String).
(test-case "4B.4.a: annotation T preserved in the cell (union annotation, Int referent)"
  (define rs (run-file-fixture "ns tf11\ndef x : <Int | String> := a\ndef a := 5"))
  (check-true (has? rs "x : Int | String defined."))
  (check-true (has? rs "a : Int defined.")))

;; ⑨ type-mismatch annotated forward → file-end TYPE error (TC-(a)), NOT
;; Unbound (the pre-4B.4.a behavior was unbound-variable-error for x).
;; The referent's own def still succeeds; x's failed def is removed (parity
;; with the immediate annotated path's remove-failed-definition!).
(test-case "4B.4.a: type-mismatch annotated forward → file-end type error (not unbound)"
  (define rs (run-file-fixture "ns tf12\ndef x : String := a\ndef a := 5N"))
  (check-true (for/or ([r (in-list rs)]) (type-mismatch-error? r)))
  (check-false (unbound-for? rs 'x))
  (check-true (has? rs "a : Nat defined.")))

;; ⑩ the OPAQUE data-type exclusion — `Wrap` is a registered data-type, so the
;; annotated redefinition routes through the [else]'s opaque branch (type-only,
;; body IGNORED — value never grounds); a δ here would wait forever
;; (§18.21.24.3 reject case 1, NAME-keyed). Behavior-preserved vs 4B.3-b:
;; 0 errors, Wrap stays type-only, the ignored bare-var body residuates nothing.
(test-case "4B.4.a: opaque data-type exclusion (annotated redefinition of a data-type name)"
  (define rs (run-file-fixture "ns tf13\ndata Wrap := MkWrap\ndef Wrap : Type := later\ndef later := Nat"))
  (check-false (for/or ([r (in-list rs)]) (prologos-error? r)))
  (check-true (has? rs "later : [Type 0] defined.")))

;; ⑪ malformed annotation — is-type fails in the helper → 'reject → the [else]
;; re-elaborates + reports (error-path parity; D-4B4a-6). Still an immediate
;; not-a-type error, never residuated.
(test-case "4B.4.a: malformed annotation falls through to the [else] (parity)"
  (define rs (run-file-fixture "ns tf14\ndef x : 5N := a\ndef a := 5N"))
  (check-true (for/or ([r (in-list rs)]) (prologos-error? r)))
  (check-false (unbound-for? rs 'a))
  (check-true (has? rs "a : Nat defined.")))
