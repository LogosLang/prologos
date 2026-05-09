#lang racket/base

;; test-pnet-deploy.rkt — SH Track 1 deployment-mode tests.
;;
;; Covers:
;;   - serialize-program-state writes a wrapped 'program-mode .pnet
;;   - deserialize-program-state reads it back as a Low-PNet structure
;;   - assert-no-untagged refuses 'untagged propagators
;;   - mode mismatch (file written as 'module) returns #f from deserialize
;;
;; Does NOT cover (deferred to integration tests):
;;   - what the runtime kernel does when loading a 'program .pnet
;;   - process-file integration

(require rackunit
         racket/file
         "../propagator.rkt"
         "../low-pnet-ir.rkt"
         "../pnet-deploy.rkt"
         (only-in "../pnet-serialize.rkt" pnet-wrap PNET_MAGIC))

(define (last-write-wins _old new) new)

(define (build-tagged-network)
  (define net (make-prop-network))
  (define-values (net1 a-cid) (net-new-cell net 0 last-write-wins))
  (define-values (net2 b-cid) (net-new-cell net1 0 last-write-wins))
  (define-values (net3 c-cid) (net-new-cell net2 0 last-write-wins))
  (define-values (net4 _pid)
    (net-add-propagator net3 (list a-cid b-cid) (list c-cid)
                        (lambda (n) n)
                        #:fire-fn-tag 'rt-test-add))
  (values net4 (cell-id-n c-cid)))

(define (build-untagged-network)
  (define net (make-prop-network))
  (define-values (net1 cid) (net-new-cell net 0 last-write-wins))
  (define-values (net2 _pid)
    (net-add-propagator net1 (list cid) '() (lambda (n) n)))
  ;; ↑ no fire-fn-tag → defaults to 'untagged
  (values net2 (cell-id-n cid)))

;; ============================================================
;; serialize → deserialize round-trip
;; ============================================================

(test-case "serialize-program-state + deserialize-program-state round-trip"
  (define-values (net main-cid) (build-tagged-network))
  (define tmp (make-temporary-file "test-program-~a.pnet"))
  (dynamic-wind
   void
   (lambda ()
     (serialize-program-state net main-cid tmp)
     (define lp (deserialize-program-state tmp))
     (check-true (low-pnet? lp) "deserialize returns a low-pnet")
     (check-true (validate-low-pnet lp) "deserialized low-pnet validates")
     ;; entry-decl points at our main cell
     (define entry
       (for/first ([n (in-list (low-pnet-nodes lp))] #:when (entry-decl? n)) n))
     (check-equal? (entry-decl-main-cell-id entry) main-cid)
     ;; our tagged propagator survived
     (check-true (for/or ([n (in-list (low-pnet-nodes lp))]
                          #:when (propagator-decl? n))
                   (eq? (propagator-decl-fire-fn-tag n) 'rt-test-add))))
   (lambda () (delete-file tmp))))

(test-case "serialize-program-state writes magic + 'program mode header"
  (define-values (net main-cid) (build-tagged-network))
  (define tmp (make-temporary-file "test-mode-~a.pnet"))
  (dynamic-wind
   void
   (lambda ()
     (serialize-program-state net main-cid tmp)
     (define raw (call-with-input-file tmp read))
     (check-true (list? raw))
     (check-equal? (car raw) PNET_MAGIC)
     (check-equal? (caddr raw) 'program "mode flag is 'program"))
   (lambda () (delete-file tmp))))

;; ============================================================
;; assert-no-untagged
;; ============================================================

(test-case "assert-no-untagged: passes for fully-tagged Low-PNet"
  (define lp
    (parse-low-pnet
     '(low-pnet
       (domain-decl 0 int merge-int 0 never)
       (cell-decl 0 0 0)
       (cell-decl 1 0 0)
       (propagator-decl 0 (0) (1) rt-some-tag 0)
       (entry-decl 1))))
  (check-not-exn (lambda () (assert-no-untagged lp))))

(test-case "assert-no-untagged: raises on 'untagged propagator-decl"
  (define lp
    (parse-low-pnet
     '(low-pnet
       (domain-decl 0 int merge-int 0 never)
       (cell-decl 0 0 0)
       (cell-decl 1 0 0)
       (propagator-decl 0 (0) (1) untagged 0)
       (entry-decl 1))))
  (check-exn untagged-propagator-error?
    (lambda () (assert-no-untagged lp))))

(test-case "serialize-program-state: rejects untagged network"
  (define-values (net main-cid) (build-untagged-network))
  (define tmp (make-temporary-file "test-untag-~a.pnet"))
  (dynamic-wind
   void
   (lambda ()
     (check-exn untagged-propagator-error?
       (lambda () (serialize-program-state net main-cid tmp))))
   (lambda () (when (file-exists? tmp) (delete-file tmp)))))

;; ============================================================
;; deserialize-program-state: rejects 'module-mode files
;; ============================================================

(test-case "deserialize-program-state returns #f on 'module-mode file"
  ;; Manually write a 'module-mode wrapper around an arbitrary payload.
  (define tmp (make-temporary-file "test-mod-mode-~a.pnet"))
  (dynamic-wind
   void
   (lambda ()
     (define wrapped (pnet-wrap '(1 "src.prologos" stuff) 'module))
     (with-output-to-file tmp #:exists 'replace
       (lambda () (write wrapped)))
     (check-false (deserialize-program-state tmp)))
   (lambda () (delete-file tmp))))

(test-case "deserialize-program-state returns #f on garbage file"
  (define tmp (make-temporary-file "test-garbage-~a.pnet"))
  (dynamic-wind
   void
   (lambda ()
     (with-output-to-file tmp #:exists 'replace
       (lambda () (display "not-a-pnet")))
     (check-false (deserialize-program-state tmp)))
   (lambda () (delete-file tmp))))
