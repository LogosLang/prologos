#lang racket/base

;;;
;;; tests/test-t3-equality-audit.rkt — T-3 'equality merge audit (PPN 4C S2.c-i)
;;;
;;; PURPOSE: empirically verify the T-3 'equality gap audit finding (D.3
;;; §7.5.13.4). The audit conjectures that unify-core's path for ground
;;; incompat atoms goes through `conv-nf` (returns #f directly), NOT
;;; through the SRE 'equality merge. If that's correct, T-3's set-union
;;; semantics for `type-lattice-merge` does NOT silently break unify-core.
;;;
;;; If these tests PASS, the audit conclusion is confirmed:
;;;   - unify-core uses conv-nf for ground atom mismatches
;;;   - The SRE 'equality merge is never reached for these cases
;;;   - Post-T-3 set-union semantics is structurally invisible to unify-core
;;;
;;; If these tests FAIL, an active bug exists and the original 3a proposal
;;; (change 'equality to type-unify-or-top) would be the correct fix.
;;;
;;; Status: 1 expected outcome — all PASS.
;;;
;;; This is also a permanent regression guard against future changes that
;;; might silently break unify-core's failure detection on incompat atoms.
;;;

(require rackunit
         "../syntax.rkt"
         "../unify.rkt"
         "test-support.rkt")

;; ========================================
;; T-3 audit: unify-core for ground atom failures
;; ========================================

(test-case "unify-core fails on ground incompat atoms (Int vs String)"
  ;; Per audit (D.3 §7.5.13.4): classify-whnf-problem returns '(conv) for
  ;; Int vs String → dispatch-unify-whnf calls conv-nf → returns #f.
  ;; Never touches SRE 'equality merge. T-3 set-union doesn't affect this.
  (check-false (unify-ok? (unify '() (expr-Int) (expr-String)))))

(test-case "unify-core fails on ground incompat atoms (Int vs Bool)"
  (check-false (unify-ok? (unify '() (expr-Int) (expr-Bool)))))

(test-case "unify-core fails on Pi vs Sigma compound mismatch"
  ;; Different compound tags → 'conv path → conv-nf returns #f.
  (check-false (unify-ok?
                (unify '()
                       (expr-Pi 'mw (expr-Int) (expr-Bool))
                       (expr-Sigma (expr-Int) (expr-Bool))))))

(test-case "unify-core succeeds for structurally-equal types"
  ;; Sanity: classify returns '(ok) for equal terms. Not the focus of the
  ;; audit, but provides positive control.
  (check-not-false (unify-ok? (unify '() (expr-Int) (expr-Int))))
  (check-not-false (unify-ok? (unify '() (expr-Pi 'mw (expr-Int) (expr-Bool))
                                        (expr-Pi 'mw (expr-Int) (expr-Bool))))))

(test-case "unify-core fails on Pi domain mismatch"
  ;; Same compound tag, different sub-component → recursive unify-core
  ;; on sub-components hits the conv-nf path.
  (check-false (unify-ok?
                (unify '()
                       (expr-Pi 'mw (expr-Int) (expr-Bool))
                       (expr-Pi 'mw (expr-String) (expr-Bool))))))
