#lang racket/base

;;;
;;; tools/pnet-dump.rkt — the human-readable reader for `.pnet` caches
;;; (DEFERRED 151 fix b: since PNET_VERSION 12 the body is fasl, binary).
;;;
;;; Pinned here, on synthetic files (the real writer's file is checked in
;;; test-pnet-header.rkt):
;;;   - both layouts read: v12 (fasl body) and v11 (text body), same data;
;;;   - `--text` output reads back (comments skipped) to the file's data;
;;;   - the summary names every slot from PNET-BODY-SLOTS, in order;
;;;   - slot selection by name and by number, and its bounds;
;;;   - refusals: missing file, v10 single-datum file, truncated fasl body,
;;;     header with no body — each a user error, never a crash;
;;;   - module-name <-> cache-path resolution;
;;;   - exit codes of the command line: 0, 1 (a file failed), 64 (usage).
;;;

(require rackunit
         racket/file
         racket/list
         racket/string
         racket/runtime-path
         (only-in racket/fasl s-exp->fasl)
         "../tools/pnet-dump.rkt"
         (only-in "../pnet-serialize.rkt"
                  PNET_VERSION PNET-BODY-SLOTS pnet-path-for-module))

(define-runtime-path tool-path "../tools/pnet-dump.rkt")
(define-runtime-path serialize-path "../pnet-serialize.rkt")

(define dir (make-temporary-file "prologos-pnet-dump-~a" 'directory))
(define (in-dir name) (build-path dir name))

;; A body with one value per slot, covering what real bodies hold: hasheq with
;; symbol keys and with PAIR keys (the subtype registry's shape), struct
;; vectors, strings, nested lists.
(define body
  (for/list ([name (in-list PNET-BODY-SLOTS)] [i (in-naturals 2)])
    (case name
      [(namespace) "test::dump"]
      [(exports) '(one two three)]
      [(env-snapshot) (hasheq 'one (list #(struct:expr-Int) #(struct:expr-int 1))
                              'two (list #(struct:expr-Int) #(struct:expr-int 2)))]
      [(subtype-registry) (hasheq (cons 'NegInt 'Int) #t (cons 'Int 'Rat) #t)]
      [else (if (even? i) (hasheq) (hasheq (string->symbol (format "k~a" i)) (list i "s" 1.5)))])))
(define header (list 'pnet-header PNET_VERSION "/nowhere/test-dump.prologos:1"))

(define (write-v12! path hdr b)
  (call-with-output-file path #:exists 'truncate
    (lambda (out) (write hdr out) (newline out) (s-exp->fasl b out))))
(define (write-v11! path hdr b)
  (call-with-output-file path #:exists 'truncate
    (lambda (out) (write hdr out) (newline out) (write b out) (newline out))))
(define (write-raw! path s)
  (call-with-output-file path #:exists 'truncate (lambda (out) (display s out))))

;; `equal?` cannot compare two separately-read hasheqs with pair keys (eq? key
;; lookup misses), so data is compared through the tool's canonical form.
(define canon pnet-canonical)

(test-case "pnet-canonical: equal for the same data read twice, even with pair keys; still tells data apart"
  (define (twice v) (read (open-input-string (format "~s" v))))
  (define pk (hasheq (cons 'a 'b) #t))
  (check-false (equal? (twice pk) (twice pk)) "the reason it exists")
  (check-equal? (canon (twice pk)) (canon (twice pk)))
  (check-not-equal? (canon (hasheq (cons 'a 'b) #t)) (canon (hasheq (cons 'a 'c) #t)))
  (check-not-equal? (canon (hasheq 'a 1)) (canon (hash 'a 1)) "hash kind is kept"))

(define v12 (in-dir "dump-v12.pnet"))
(define v11 (in-dir "dump-v11.pnet"))
(write-v12! v12 header body)
(write-v11! v11 (list 'pnet-header 11 "/nowhere/test-dump.prologos:1") body)

(test-case "a v12 file (fasl body) reads back to the data written"
  (define pf (read-pnet-file v12))
  (check-equal? (pnet-file-layout pf) 'fasl)
  (check-equal? (pnet-file-header pf) header)
  (check-equal? (canon (pnet-file-body pf)) (canon body)))

(test-case "a v11 file (text body) reads back to the same data"
  (define pf (read-pnet-file v11))
  (check-equal? (pnet-file-layout pf) 'text)
  (check-equal? (cadr (pnet-file-header pf)) 11)
  (check-equal? (canon (pnet-file-body pf)) (canon body)))

(define (text-of pf)
  (define o (open-output-string))
  (write-pnet-text pf o #:width 60)
  (get-output-string o))

(test-case "--text: comments, then the header datum, then the body datum; reading it back gives the data"
  (for ([path (list v12 v11)])
    (define pf (read-pnet-file path))
    (define s (text-of pf))
    (check-true (string-prefix? s ";; ") "starts with a comment")
    (check-true (string-contains? s "30 user-precedence-groups") "lists the slot names")
    (define in (open-input-string s))
    (check-equal? (read in) (pnet-file-header pf))
    (check-equal? (canon (read in)) (canon body))
    (check-true (eof-object? (read in)) "nothing after the body")))

(test-case "summary: layout, version, a verdict, and one row per slot named from PNET-BODY-SLOTS"
  (define lines (pnet-summary-lines (read-pnet-file v12) #f))
  (check-true (string-contains? (list-ref lines 1) "fasl body"))
  (check-true (string-contains? (list-ref lines 2) (format "~a" PNET_VERSION)))
  (check-true (string-contains? (list-ref lines 4) "n/a") "outside the cache dir: no loader verdict")
  (define rows (drop lines 7))
  (check-equal? (length rows) (length PNET-BODY-SLOTS))
  (for ([row rows] [name PNET-BODY-SLOTS] [i (in-naturals 2)])
    (check-true (regexp-match? (pregexp (format "^ +~a  ~a " i name)) row) row))
  (check-true (string-contains? (list-ref rows 4) "\"test::dump\"") "a string slot shows its value")
  (check-true (string-contains? (list-ref rows 9) " 2 ") "subtype-registry: 2 entries"))

(test-case "summary: a body whose length differs from PNET-BODY-SLOTS is flagged, not mislabeled silently"
  (define short-path (in-dir "dump-short.pnet"))
  (write-v12! short-path header (take body 5))
  (check-true (string-contains? (last (pnet-summary-lines (read-pnet-file short-path) #f))
                                "the body has 5 slots")))

(test-case "slot-index: names and numbers 2..30, nothing else"
  (check-equal? (slot-index "env-snapshot") 0)
  (check-equal? (slot-index "trait-registry") 12)
  (check-equal? (slot-index "14") 12)
  (check-equal? (slot-index "2") 0)
  (check-equal? (slot-index (number->string (+ 1 (length PNET-BODY-SLOTS)))) (sub1 (length PNET-BODY-SLOTS)))
  (for ([bad (list "1" "0" "31" "-3" "2.0" "nope" "")])
    (check-false (slot-index bad) bad)))

(test-case "refusals are user errors, never crashes"
  (define (refused path rx)
    (check-exn (lambda (e) (and (exn:fail:user? e) (regexp-match? rx (exn-message e))))
               (lambda () (read-pnet-file path))
               (format "~a" path)))
  (refused (in-dir "absent.pnet") #rx"no such file")
  (define p (in-dir "dump-bad.pnet"))
  (write-raw! p (format "~s\n" (list* 10 "/nowhere/x:1" body)))           ; v10: one datum
  (refused p #rx"not a v11[+]")
  (write-raw! p "")
  (refused p #rx"not a v11[+]")
  (write-v12! p header body)                                               ; truncated fasl
  (write-raw! p (bytes->string/latin-1 (subbytes (file->bytes v12) 0 (- (file-size v12) 40))))
  (refused p #rx"unreadable fasl body")
  (write-raw! p (format "~s\n" header))                                    ; header, no body
  (refused p #rx"not a list of slots"))

(test-case "module names resolve to this checkout's cache path, and back"
  (define-values (path ns) (resolve-pnet-arg "prologos::core::collections"))
  (check-equal? path (pnet-path-for-module 'prologos::core::collections))
  (check-equal? ns 'prologos::core::collections)
  (define-values (path2 ns2) (resolve-pnet-arg (path->string path)))
  (check-equal? ns2 'prologos::core::collections "a path inside the cache dir recovers the module")
  (define-values (path3 ns3) (resolve-pnet-arg (path->string v12)))
  (check-false ns3 "a path elsewhere has no module"))

;; The command line, run in-process: a fresh namespace per run (pnet-serialize
;; and its dependencies attached, so only the tool re-instantiates), output
;; captured, `exit` captured as the result.
(define (run-cli . args)
  (define out (open-output-string))
  (define err (open-output-string))
  (define ns (make-base-namespace))
  (namespace-attach-module (current-namespace) serialize-path ns)
  (define code
    (let/ec k
      (parameterize ([current-namespace ns]
                     [current-command-line-arguments (list->vector args)]
                     [exit-handler (lambda (c) (k c))]
                     [current-output-port out]
                     [current-error-port err])
        (dynamic-require `(submod ,tool-path main) #f)
        'returned-without-exit)))
  (list code (get-output-string out) (get-output-string err)))

(test-case "command line: exit 0 with output; 1 when a file fails (the others still print); 64 on usage"
  (define ok (run-cli (path->string v12)))
  (check-equal? (car ok) 0)
  (check-true (string-contains? (cadr ok) "env-snapshot"))
  (define slot (run-cli "--slot" "exports" "--slot" "6" (path->string v12)))
  (check-equal? (car slot) 0)
  (check-true (string-contains? (cadr slot) "(one two three)"))
  (check-true (string-contains? (cadr slot) "\"test::dump\""))
  (define mixed (run-cli (path->string (in-dir "absent.pnet")) (path->string v11)))
  (check-equal? (car mixed) 1)
  (check-true (string-contains? (caddr mixed) "no such file"))
  (check-true (string-contains? (cadr mixed) "text body (v11)") "the readable file still printed")
  (for ([args (list '() (list "--slot" "nope" (path->string v12)) (list "--bogus" (path->string v12))
                    (list "--width" "0" (path->string v12)))])
    (check-equal? (car (apply run-cli args)) 64 (format "~s" args))))

(delete-directory/files dir #:must-exist? #f)
