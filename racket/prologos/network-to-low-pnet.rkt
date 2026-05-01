#lang racket/base

;; network-to-low-pnet.rkt — SH Track 2 Phase 2.B.
;;
;; Translates an in-memory prop-network into a Low-PNet IR structure.
;; This is the second of three phases for Track 2 (per the design doc):
;;
;;   Phase 2.A — data structures + parse + pp + validate (commit f4157be)
;;   Phase 2.B — prop-network → Low-PNet (this file)
;;   Phase 2.C — Low-PNet → LLVM IR (deferred)
;;
;; Scope of Phase 2.B (this commit):
;;   - Walk prop-net cells and propagators
;;   - Emit cell-decl, propagator-decl, dep-decl, domain-decl, entry-decl
;;   - Domain decls use placeholder tag values (real merge-fn-tag, bot, etc.
;;     come from a future domain-registry-to-low-pnet pass; placeholders are
;;     enough for Phase 2.B's diagnostic value)
;;   - write-decl emission is DEFERRED — initial cell values are arbitrary
;;     Racket values that may not survive serialization. write-decl needs
;;     a value-marshal step that's part of the future deployment-mode work.
;;
;; Out of scope:
;;   - Stratum decls (deferred until stratum exposure on the network is finalized)
;;   - Initial-value emission (write-decls)
;;   - The reverse direction (Low-PNet → prop-network): not needed; the kernel
;;     loads Low-PNet directly via LLVM lowering, never reconstructs a Racket
;;     prop-network from Low-PNet.

(require racket/match
         "propagator.rkt"
         "champ.rkt"
         "low-pnet-ir.rkt")

(provide prop-network-to-low-pnet)

;; prop-network-to-low-pnet : prop-network × main-cell-id → low-pnet
;;
;; Walks the network, emits a Low-PNet structure that captures the runtime
;; topology. The result is suitable for inspection (pp-low-pnet) and for
;; downstream Phase 2.C lowering once that arrives.
;;
;; main-cell-id : exact-nonnegative-integer
;;   The id of the cell whose value the program's result reads from.
;;   Caller responsibility: this should be a real cell in the network.
(define (prop-network-to-low-pnet net main-cell-id)
  (define cells-champ (prop-network-cells net))
  (define props-champ (prop-network-propagators net))
  (define domains-champ (prop-network-cell-domains net))

  ;; -------- 1. Collect unique domains and assign sequential ids ----------
  ;; The network maps cell-id → domain-name-symbol (or no entry for cells
  ;; without an explicit domain). We collect the set of domain names that
  ;; actually appear, assign each a sequential id, and emit one domain-decl
  ;; per unique domain.
  (define domain-name->id (make-hasheq))
  (champ-fold domains-champ
              (lambda (cid dom-name acc)
                (unless (hash-has-key? domain-name->id dom-name)
                  (hash-set! domain-name->id dom-name (hash-count domain-name->id)))
                acc)
              #f)

  ;; Cells without an explicit domain entry get a default 'unknown domain.
  ;; (Most often: cells allocated via net-new-cell with a merge-fn but no
  ;; explicit domain symbol. Future Track 1 work will tighten this; for
  ;; Phase 2.B the placeholder is fine.)
  (define unknown-id
    (cond
      [(hash-ref domain-name->id 'unknown #f)
       => values]
      [else
       (define id (hash-count domain-name->id))
       (hash-set! domain-name->id 'unknown id)
       id]))

  ;; -------- 2. Walk cells -------------------------------------------------
  (define cell-decls
    (champ-fold cells-champ
                (lambda (cid cell acc)
                  (define cid-int (cell-id-n cid))
                  (define dom-name
                    (or (lookup-cell-domain net cid) 'unknown))
                  (define dom-id (hash-ref domain-name->id dom-name unknown-id))
                  ;; Phase 2.B: don't try to serialize the live cell value as
                  ;; init-value — it may be a complex Racket struct that won't
                  ;; survive Low-PNet → sexp roundtrip. Use a sentinel.
                  (cons (cell-decl cid-int dom-id 'phase-2b-placeholder) acc))
                '()))

  ;; -------- 3. Walk propagators -------------------------------------------
  (define props-acc
    (champ-fold props-champ
                (lambda (pid prop acc)
                  (match-define (list pds dds) acc)
                  (define pid-int (prop-id-n pid))
                  (define ins (map cell-id-n (propagator-inputs prop)))
                  (define outs (map cell-id-n (propagator-outputs prop)))
                  (define tag (propagator-fire-fn-tag prop))
                  (define flags (propagator-flags prop))
                  (define new-prop (propagator-decl pid-int ins outs tag flags))
                  ;; One dep-decl per input cell. Phase 2.B uses 'all paths;
                  ;; component-paths refinement is future work (see SH Master
                  ;; Track 4 / compound cells).
                  (define new-deps
                    (map (lambda (cid) (dep-decl pid-int cid 'all)) ins))
                  (list (cons new-prop pds)
                        (append (reverse new-deps) dds)))
                (list '() '())))
  (define prop-decls (car props-acc))
  (define dep-decls (cadr props-acc))

  ;; -------- 4. Emit domain-decls in id order ------------------------------
  (define domain-decls
    (let ([by-id (make-hasheq)])
      (for ([(name id) (in-hash domain-name->id)])
        (hash-set! by-id id name))
      (for/list ([id (in-range (hash-count by-id))])
        (define name (hash-ref by-id id))
        ;; Placeholder merge-fn-tag, bot, contradiction-pred-tag.
        ;; Real values come from the future domain registry pass.
        (domain-decl id name
                     (string->symbol (format "kernel-merge-~a" name))
                     'phase-2b-placeholder
                     'never))))

  ;; -------- 5. Assemble the Low-PNet -------------------------------------
  ;; Order matters per the V10 validation rule: domains first, then cells,
  ;; then propagators, then dep-decls, then entry-decl.
  (define nodes
    (append domain-decls
            (sort cell-decls < #:key cell-decl-id)
            (sort prop-decls < #:key propagator-decl-id)
            (sort dep-decls < #:key (lambda (d) (dep-decl-prop-id d)))
            (list (entry-decl main-cell-id))))

  (low-pnet LOW_PNET_FORMAT_VERSION nodes))
