#lang racket/base
;;; kernel-rules-seed.rkt — PReduce Track 2 Phase 1: the arithmetic seed
;;; (design §3; D.2 ~12-20 head-specific tier-1 ops; ledger iter 20).
;;;
;;; All DECLARATIVE (serializable — what 0.3 hands the LLVM collaborator): LHS in
;;; the v1 pattern language, RHS templates with (compute OP ...) nodes interpreted
;;; against rule-dispatch's whitelisted pure-op table. Division/mod by zero abort
;;; instantiation (the rule does not fire — no error). Nat folds operate on the
;;; NUMERIC literal form per the design §6 Q2 resolution (suc-chains fold at the
;;; rule boundary; sub-positions are not interned under lazy ingestion).
(require "rule-registry.rkt")

(provide arithmetic-seed-rules
         register-arithmetic-seed!
         pour-arithmetic-seed!)

(define (fold-rule name head op #:arity [arity 2])
  (make-preduce-rule
   #:name name
   #:rule-id (string->symbol (format "kernel::seed::~a" name))
   #:interface-keys (list head)
   #:tier 'declarative
   #:lhs-pattern (if (= arity 2)
                     `(,head (lit (capture a)) (lit (capture b)))
                     `(,head (lit (capture a))))
   #:rhs-template (if (= arity 2)
                      `(lit (compute ,op (ref a) (ref b)))
                      `(lit (compute ,op (ref a))))
   #:directionality 'forward
   #:cost 1
   #:confluence-class 'literal-fold
   #:write-target 'best+alts
   #:stratum 's0))

(define arithmetic-seed-rules
  (list
   ;; integer arithmetic (5)
   (fold-rule 'int-add-fold 'int+ '+)
   (fold-rule 'int-sub-fold 'int- '-)
   (fold-rule 'int-mul-fold 'int* '*)
   (fold-rule 'int-div-fold 'int/ '/)          ;; div-by-zero aborts, never fires
   (fold-rule 'int-mod-fold 'int-mod 'mod)
   ;; integer comparisons (5)
   (fold-rule 'int-lt-fold 'int-lt '<)
   (fold-rule 'int-le-fold 'int-le '<=)
   (fold-rule 'int-gt-fold 'int-gt '>)
   (fold-rule 'int-ge-fold 'int-ge '>=)
   (fold-rule 'int-eq-fold 'int-eq '=)
   ;; booleans (3)
   (fold-rule 'bool-and-fold 'bool-and 'and)
   (fold-rule 'bool-or-fold  'bool-or  'or)
   (fold-rule 'bool-not-fold 'bool-not 'not #:arity 1)
   ;; nat structural folds on numeric literal form (2) — design §6 Q2
   (fold-rule 'nat-suc-fold 'suc 'add1 #:arity 1)
   (fold-rule 'nat-pred-fold 'nat-pred 'sub1 #:arity 1)
   ;; δ (Phase 2, iter 24): tier-2 METADATA entry (the ctor-desc
   ;; absorbed-in-metadata-only pattern) — the realization is reduction.rkt's
   ;; preduce-ingest-delta hook; this entry documents it in the registry
   (make-preduce-rule #:name 'delta-unfold
                      #:rule-id 'kernel::seed::delta-unfold
                      #:interface-keys '(fvar)
                      #:tier 'closure-resident
                      #:confluence-class 'delta
                      #:stratum 's0)))

;; → net' (idempotent under dedup-or-error; same path as the kernel pour)
(define (register-arithmetic-seed! net registry-cid)
  (for/fold ([n net]) ([r (in-list arithmetic-seed-rules)])
    (register-rule n registry-cid 'kernel r)))

;; driver-init wrapper (same shape as pour-kernel-rule-seed!)
(define (pour-arithmetic-seed! prn-box)
  (define cid (current-rule-registry-cell-id))
  (when (and prn-box cid)
    (set-box! prn-box (register-arithmetic-seed! (unbox prn-box) cid))))
