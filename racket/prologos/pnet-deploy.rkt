#lang racket/base

;; pnet-deploy.rkt — SH Track 1 deployment-mode serializer.
;;
;; Today's pnet-serialize.rkt writes .pnet files in mode='module
;; (compile-time module cache: env, registries, foreign-procs).
;; This module adds the 'program mode path: a deployment artifact that
;; carries the program's runtime-relevant topology (cells + propagators
;; + dep-graph + fire-fn-tags + entry-cell).
;;
;; Why a separate module rather than extending pnet-serialize.rkt:
;; the two modes have very different content shapes. Module mode is the
;; existing 10-registry payload. Program mode is a Low-PNet IR structure
;; (per Phase 2.B). Keeping them separate clarifies the contract; both
;; share pnet-wrap / pnet-unwrap to compose with the format-2 header.
;;
;; Per Track 1 audit (commit 82eba16): 'program mode REQUIRES every
;; propagator to have an explicit fire-fn-tag. 'untagged propagators are
;; rejected with a clear error pointing the caller at the audit doc.
;;
;; Today's scope (B):
;;   - serialize-program-state    : prop-network × main-cell-id × out-path → void
;;   - deserialize-program-state  : in-path → low-pnet | #f
;;   - assert-no-untagged         : low-pnet → void (raises on violation)
;;
;; Out of scope (left for C / Track 4):
;;   - integration with process-file (deciding when to emit program.pnet)
;;   - actually loading a 'program .pnet into a kernel runtime
;;   - cell value marshaling beyond the placeholder phase 2.B uses

(require racket/file
         "low-pnet-ir.rkt"
         "network-to-low-pnet.rkt"
         (only-in "pnet-serialize.rkt"
                  pnet-wrap pnet-unwrap
                  PNET_MAGIC PNET_FORMAT_VERSION))

(provide serialize-program-state
         deserialize-program-state
         assert-no-untagged
         (struct-out untagged-propagator-error))

;; ============================================================
;; Untagged-propagator detection
;; ============================================================
;;
;; Per the audit doc § 3, 'program mode artifacts cannot serialize
;; 'untagged propagators because the runtime kernel has no way to look
;; up the corresponding native fire-fn. Refuse early with a clear error.

(struct untagged-propagator-error exn:fail (prop-decl) #:transparent)

(define (assert-no-untagged lp)
  (for ([n (in-list (low-pnet-nodes lp))])
    (when (propagator-decl? n)
      (when (eq? (propagator-decl-fire-fn-tag n) 'untagged)
        (raise (untagged-propagator-error
                (format
                 "cannot serialize program-mode .pnet: propagator-decl id=~a has fire-fn-tag = 'untagged. \
See docs/tracking/2026-05-02_FIRE_FN_TAG_AUDIT_TRACK1.md § 3 for tagging guidance."
                 (propagator-decl-id n))
                (current-continuation-marks)
                n))))))

;; ============================================================
;; Serialize
;; ============================================================
;;
;; Pipeline:
;;   prop-network → prop-network-to-low-pnet → assert-no-untagged
;;   → pp-low-pnet → pnet-wrap (mode='program) → write to disk

(define (serialize-program-state net main-cell-id out-path)
  (define lp (prop-network-to-low-pnet net main-cell-id))
  (assert-no-untagged lp)
  (define payload (pp-low-pnet lp))
  (define wrapped (pnet-wrap payload 'program))
  (with-output-to-file out-path #:exists 'replace
    (lambda () (write wrapped))))

;; ============================================================
;; Deserialize
;; ============================================================
;;
;; Returns a Low-PNet structure (which Phase 2.C will lower to LLVM IR
;; or the Zig kernel will load directly via libpnet bindings — neither
;; consumer exists yet, so this is currently a diagnostic round-trip).
;; Returns #f if the file isn't valid 'program-mode.

(define (deserialize-program-state in-path)
  (define raw (with-handlers ([exn? (lambda (_) #f)])
                (call-with-input-file in-path read)))
  (cond
    [(not raw) #f]
    [else
     (define unwrap (with-handlers ([exn? (lambda (_) #f)])
                      (call-with-values (lambda () (pnet-unwrap raw)) list)))
     (cond
       [(or (not unwrap) (not (= (length unwrap) 3))) #f]
       [else
        (define mode (car unwrap))
        (define payload (caddr unwrap))
        (cond
          [(not (eq? mode 'program)) #f]
          [else
           (with-handlers ([exn? (lambda (_) #f)])
             (parse-low-pnet payload))])])]))
