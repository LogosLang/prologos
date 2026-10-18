#lang racket/base
(require racket/file)
;; tmp-race.rkt <mode> <n> <dir> — make-temporary-file then write it with #:exists <mode>, N times,
;; in a temp dir shared with concurrent copies of this process. Prints the count of failures by message.
(define-values (mode n dir)
  (let ([v (current-command-line-arguments)])
    (values (string->symbol (vector-ref v 0)) (string->number (vector-ref v 1)) (vector-ref v 2))))
(define fails (make-hash))
(for ([i (in-range n)])
  (with-handlers ([exn:fail? (λ (e) (hash-update! fails (car (regexp-split #rx"\n" (exn-message e))) add1 0))])
    (define tmp (make-temporary-file "race-~a.txt" #f dir))
    (call-with-output-file tmp #:exists mode (λ (o) (display "x" o)))
    (delete-file tmp)))
(printf "~a ~a: ~a\n" mode n (if (zero? (hash-count fails)) "0 failures" (for/list ([(k v) fails]) (format "~a × ~a" v k))))
