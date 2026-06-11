#lang racket/base
;;; pnet-sections.rkt — PReduce Track 5 Phase 1: the .pnet/2 tagged-section
;;; container's FIRST realization (the 0.3 freeze was a SPEC — design §6 Q3;
;;; ledger iter 36).
;;;
;;; v1 SITING (3-columned at implementation): sections live in a SIBLING file
;;; (<module>.pnetx), not appended to the legacy .pnet tuple — zero
;;; legacy-reader risk (in-file appending would gamble on `read` tolerating
;;; trailing data); the in-file unification arrives when pnet-serialize
;;; migrates to /2 wholesale (named). Old toolchains simply have no .pnetx:
;;; degraded (no warm-start), never divergent.
;;;
;;; Format (s-expression, `write`-emitted, versioned):
;;;   (pnet2 1 (section TAG DATUM) ...)
;;; Consumers LOOK UP the tags they know; unknown tags are skipped by
;;; construction (the container spec's forward-compatibility).
(require racket/list)

(provide PNET2-VERSION
         pnet2-write-sections
         pnet2-read-sections
         pnet2-section-ref)

(define PNET2-VERSION 1)

(define (pnet2-write-sections path sections)
  ;; sections: (listof (cons tag-symbol datum)) — datums must be write/read-able
  (call-with-output-file path #:exists 'replace
    (lambda (out)
      (write (cons 'pnet2 (cons PNET2-VERSION
                                (for/list ([s (in-list sections)])
                                  (list 'section (car s) (cdr s)))))
             out))))

;; → (listof (cons tag datum)) | #f on missing/malformed (degraded, not fatal)
(define (pnet2-read-sections path)
  (and (file-exists? path)
       (with-handlers ([exn:fail? (lambda (_e) #f)])
         (define datum (call-with-input-file path read))
         (and (pair? datum) (eq? (car datum) 'pnet2)
              (pair? (cdr datum)) (exact-integer? (cadr datum))
              (for/list ([s (in-list (cddr datum))]
                         #:when (and (list? s) (= (length s) 3)
                                     (eq? (car s) 'section)))
                (cons (cadr s) (caddr s)))))))

(define (pnet2-section-ref sections tag)
  (and sections
       (for/or ([s (in-list sections)])
         (and (eq? (car s) tag) (cdr s)))))
