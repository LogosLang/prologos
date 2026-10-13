#lang racket/base

;;; test-annotate-invalid-timings.rkt — tools/annotate-invalid-timings.rkt
;;; (DEFERRED 164 open 3): polluted timings records are ANNOTATED, not dropped.

(require rackunit
         json
         racket/file
         racket/list
         racket/string
         "../tools/annotate-invalid-timings.rkt")

(define (rec fc n #:extra [extra (hasheq)])
  (jsexpr->string
   (for/fold ([h (hasheq 'file_count fc 'all_pass #t
                         'results (for/list ([i n]) (hasheq 'file (format "f~a.rkt" i) 'wall_ms i)))])
             ([(k v) (in-hash extra)])
     (hash-set h k v))))

(define valid (rec 3 3))
(define partial (rec 300 2))
(define already (rec 300 0 #:extra (hasheq 'invalid "annotated earlier")))
(define junk "{not json")

(test-case "annotate: only partial records gain \"invalid\"; every other line is byte-identical"
  (define-values (out n-new n-already) (annotate-lines (list valid partial already junk "")))
  (check-equal? n-new 1)
  (check-equal? n-already 1)
  (check-equal? (list-ref out 0) valid)
  (check-equal? (list-ref out 2) already)
  (check-equal? (list-ref out 3) junk)
  (check-equal? (list-ref out 4) "")
  (define annotated (string->jsexpr (list-ref out 1)))
  (check-equal? (hash-ref annotated 'invalid) "results 2 < file_count 300 (DEFERRED 164)")
  ;; the rest of the record is untouched: same bytes after the inserted key
  (check-true (string-suffix? (list-ref out 1) (substring partial 1)))
  (check-equal? (hash-remove annotated 'invalid) (string->jsexpr partial)))

(test-case "annotate: idempotent — a second pass changes nothing"
  (define-values (once n1 _a1) (annotate-lines (list valid partial already junk)))
  (define-values (twice n2 a2) (annotate-lines once))
  (check-equal? n1 1)
  (check-equal? n2 0)
  (check-equal? a2 2)
  (check-equal? twice once))

(test-case "annotate: the file round trip, and the counts it reports"
  (define dir (make-temporary-directory "annotate-test-~a"))
  (define f (build-path dir "timings.jsonl"))
  (with-output-to-file f (lambda () (for-each displayln (list valid partial already junk))))
  (define lock (build-path dir "suite.lock"))
  (define r1 (annotate-file! f #:lock-path lock))
  (check-equal? (hash-ref r1 'newly_annotated) 1)
  (check-equal? (hash-ref r1 'already_annotated) 1)
  (check-equal? (hash-ref r1 'records) 3 "the junk line is not a record")
  (define bytes1 (file->bytes f))
  (define r2 (annotate-file! f #:lock-path lock))
  (check-equal? (hash-ref r2 'newly_annotated) 0)
  (check-equal? (file->bytes f) bytes1 "byte-identical after the second pass")
  (define r3 (annotate-file! f #:lock-path lock #:dry-run? #t))
  (check-equal? (hash-ref r3 'newly_annotated) 0)
  ;; dry run on an unannotated copy reports without writing
  (define g (build-path dir "copy.jsonl"))
  (with-output-to-file g (lambda () (for-each displayln (list valid partial))))
  (define before (file->bytes g))
  (check-equal? (hash-ref (annotate-file! g #:lock-path lock #:dry-run? #t) 'newly_annotated) 1)
  (check-equal? (file->bytes g) before "--dry-run writes nothing"))
