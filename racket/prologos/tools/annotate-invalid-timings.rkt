#lang racket/base

;;; annotate-invalid-timings.rkt — mark polluted timings.jsonl records, in place.
;;;
;;; Usage:  racket tools/annotate-invalid-timings.rkt [--dry-run] <path/to/timings.jsonl>
;;;
;;; DEFERRED 164 open(3). Before fd2986cc a run that lost its workers could be
;;; recorded as a full suite with `all_pass: true` and fewer results than files
;;; (13 of 971 full-suite records in main's file). The records are ANNOTATED,
;;; not dropped (owner decision): each gains `"invalid": "<reason>"` as its
;;; FIRST key and every other byte of the line is kept, so the history stays
;;; readable as it was written and every reader can skip on one key
;;; (suite-plan.rkt record-invalid-reason, which historical-medians uses).
;;;
;;; Idempotent: a record that already carries "invalid" is left alone, so a
;;; second pass changes no byte. Lines that do not parse are kept verbatim.
;;; The rewrite is atomic (temp file + rename) and runs under the machine-wide
;;; suite lock taken EXCLUSIVELY, so no participating runner appends a record
;;; mid-rewrite (an older checkout's runner does not take the lock: run it when
;;; that checkout is idle).

(require json
         racket/cmdline
         racket/file
         racket/list
         racket/path
         racket/string
         "suite-plan.rkt"
         "suite-lock.rkt")

(provide annotate-lines
         annotate-file!)

;; The threshold DEFERRED 164 counted "full-suite" records with.
(define FULL-SUITE-FILE-COUNT 300)

(define (parse line)
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (and (regexp-match? #rx"^[ \t]*[{]" line) (string->jsexpr line))))

;; Insert "invalid" as the first key, textually: the original bytes after the
;; opening brace are kept exactly.
(define (insert-invalid line reason)
  (define m (regexp-match-positions #rx"^[ \t]*[{]" line))
  (define after (cdar m))
  (define rest (substring line after))
  (string-append (substring line 0 after)
                 "\"invalid\":" (jsexpr->string reason)
                 (if (regexp-match? #rx"^[ \t]*[}]" rest) "" ",")
                 rest))

;; annotate-lines : (listof string) -> (values (listof string) n-new n-already)
(define (annotate-lines lines)
  (for/fold ([out '()] [n-new 0] [n-already 0]
             #:result (values (reverse out) n-new n-already))
            ([line (in-list lines)])
    (define rec (parse line))
    (cond
      [(not (hash? rec)) (values (cons line out) n-new n-already)]
      [(hash-ref rec 'invalid #f) (values (cons line out) n-new (add1 n-already))]
      [(record-invalid-reason rec)
       => (lambda (why) (values (cons (insert-invalid line why) out) (add1 n-new) n-already))]
      [else (values (cons line out) n-new n-already)])))

(define (count-records lines pred)
  (for/sum ([l (in-list lines)])
    (define r (parse l))
    (if (and (hash? r) (pred r)) 1 0)))

;; annotate-file! : path -> report-hash
(define (annotate-file! path
                        #:dry-run? [dry-run? #f]
                        #:lock-path [lock-path (suite-lock-path)])
  (call-with-suite-lock
   'exclusive
   (lambda ()
     (define lines (file->lines path))
     (define-values (out n-new n-already) (annotate-lines lines))
     (define (full? r) (>= (hash-ref r 'file_count 0) FULL-SUITE-FILE-COUNT))
     (define newly
       (for/list ([before (in-list lines)] [after (in-list out)]
                  #:unless (eq? before after))
         (parse after)))
     (unless (or dry-run? (zero? n-new))
       (define dir (path-only (path->complete-path path)))
       (define tmp (make-temporary-file "timings-~a.tmp" #f dir))
       (with-output-to-file tmp #:exists 'truncate
         (lambda () (for ([l (in-list out)]) (write-string l) (newline))))
       (rename-file-or-directory tmp path #t))
     (hasheq 'records (count-records lines (lambda (r) #t))
             'full_suite_records (count-records lines full?)
             'newly_annotated n-new
             'already_annotated n-already
             'newly_annotated_full_suite_all_pass
             (for/sum ([r (in-list newly)])
               (if (and (full? r) (eq? (hash-ref r 'all_pass #f) #t)) 1 0))
             'newly_annotated_reasons
             (for/list ([r (in-list newly)])
               (format "~a ~a ~a" (hash-ref r 'timestamp "?") (hash-ref r 'commit "?")
                       (hash-ref r 'invalid)))
             'written (and (not dry-run?) (> n-new 0))))
   #:path lock-path
   #:command "annotate-invalid-timings"
   #:on-wait (make-wait-reporter 'exclusive lock-path)))

(module+ main
  (define dry-run? (make-parameter #f))
  (define path
    (command-line
     #:program "annotate-invalid-timings"
     #:once-each
     ["--dry-run" "Report what would be annotated; write nothing" (dry-run? #t)]
     #:args (timings-path) timings-path))
  (define r (annotate-file! path #:dry-run? (dry-run?)))
  (printf "~a: ~a records (~a full-suite, file_count >= ~a)\n"
          path (hash-ref r 'records) (hash-ref r 'full_suite_records) FULL-SUITE-FILE-COUNT)
  (printf "  already annotated: ~a\n" (hash-ref r 'already_annotated))
  (printf "  newly annotated:   ~a (~a of them full-suite with all_pass true)~a\n"
          (hash-ref r 'newly_annotated) (hash-ref r 'newly_annotated_full_suite_all_pass)
          (if (dry-run?) " — DRY RUN, nothing written" ""))
  (for ([why (in-list (hash-ref r 'newly_annotated_reasons))])
    (printf "    ~a\n" why)))
