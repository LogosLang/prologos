#lang racket/base

;;;
;;; tools/dep-graph.rkt — the dependency graph is DERIVED from the files on disk
;;; (SW-24, DEFERRED 169), through a per-file content-keyed cache.
;;;
;;; Pinned here, on a synthetic tree:
;;;   - each layer derives as the old data sections were shaped (root-level source
;;;     edges filtered to root-level modules; test → source + uses-driver?; library
;;;     requires; driver tests → the library modules they name); info.rkt and
;;;     hidden files are not modules;
;;;   - compute-affected-tests over a derived graph: source edges are followed
;;;     transitively, library edges into driver tests, a changed test selects itself;
;;;   - the cache: a second derivation scans nothing; an edit of the SAME SIZE in the
;;;     SAME SECOND is re-scanned (content key, not mtime); new and deleted files
;;;     appear and disappear; a corrupt cache, or one written by another version of
;;;     dep-graph.rkt, is discarded and the graph is still right;
;;;   - all-test-files is every tests/test-*.rkt on disk.
;;; And on this checkout: the cached derivation equals a full rescan (what
;;; `update-deps.rkt --check` verifies), and all-test-files equals the disk listing.
;;;

(require rackunit
         racket/file
         racket/list
         "../tools/dep-graph.rkt")

(define root (make-temporary-file "prologos-depgraph-~a" 'directory))
(define (put! rel text)
  (define p (build-path root rel))
  (make-directory* (let-values ([(dir name must-dir?) (split-path p)]) dir))
  (call-with-output-file p #:exists 'truncate (lambda (o) (display text o))))
(define cache (build-path root "data" "cache" "dep-graph.rktd"))

(put! "a.rkt" "#lang racket/base\n(require \"b.rkt\" racket/list)\n")
(put! "b.rkt" "#lang racket/base\n(require racket/string)\n")
(put! "c.rkt" "#lang racket/base\n(provide c)\n(define c 1)\n")
(put! "info.rkt" "#lang info\n(define collection \"x\")\n")
(put! ".#lock.rkt" "#lang racket/base\n(require \"a.rkt\")\n")
(put! "tests/test-a.rkt" "#lang racket/base\n(require rackunit \"../a.rkt\")\n")
(put! "tests/test-c.rkt" "#lang racket/base\n(require \"../c.rkt\")\n;; run-ns \"ns t\\nrequire [prologos::data::foo]\"\n")
(put! "tests/helper.rkt" "#lang racket/base\n(require \"../b.rkt\")\n")
(put! "lib/prologos/data/foo.prologos" "ns prologos::data::foo\nrequire [prologos::data::bar :refer [x]]\n")
(put! "lib/prologos/data/bar.prologos" "ns prologos::data::bar\n")
(put! "lib/prologos/data/.#foo.prologos" "ns lock\nrequire [prologos::data::foo]\n")

(define (derive #:scanned [box #f])
  (derive-dep-graph root #:cache-path cache
                    #:on-scan (lambda (rel) (when box (set-box! box (cons rel (unbox box)))))))

(define g (derive))

(test-case "layers derive in the old data sections' shape; info.rkt and hidden files are not modules"
  (check-equal? (dep-graph-source-deps g) (hasheq 'a.rkt '(b.rkt) 'b.rkt '() 'c.rkt '()))
  (check-equal? (dep-graph-test-deps g)
                (hasheq 'test-a.rkt (test-dep '(a.rkt) #f) 'test-c.rkt (test-dep '(c.rkt) #t)))
  (check-equal? (dep-graph-prologos-lib-deps g)
                (hasheq 'prologos::data::foo '(prologos::data::bar) 'prologos::data::bar '()))
  (check-equal? (dep-graph-test-prologos-deps g) (hasheq 'test-c.rkt '(prologos::data::foo))))

(define (affected . changes) (compute-affected-tests changes #:graph g))

(test-case "affected tests follow the derived edges"
  (check-equal? (affected (changed-source 'b.rkt)) '(test-a.rkt) "b <- a <- test-a, transitively")
  (check-equal? (affected (changed-source 'c.rkt)) '(test-c.rkt))
  (check-equal? (affected (changed-prologos 'prologos::data::bar)) '(test-c.rkt) "bar <- foo, named by test-c")
  (check-equal? (affected (changed-test 'test-a.rkt)) '(test-a.rkt))
  ;; a changed module the graph does not know can only be a deleted file: reported, no edges
  (define err (open-output-string))
  (check-equal? (parameterize ([current-error-port err])
                  (compute-affected-tests (list (changed-source 'gone.rkt)) #:graph g #:project-root root))
                '())
  (check-regexp-match #rx"gone[.]rkt" (get-output-string err)))

(test-case "cache: a second derivation scans nothing and gives the same graph"
  (define scanned (box '()))
  (check-equal? (derive #:scanned scanned) g)
  (check-equal? (unbox scanned) '()))

(test-case "cache: an edit of the same size in the same second is re-scanned (content key, not mtime)"
  (define p (build-path root "a.rkt"))
  (define t0 (file-or-directory-modify-seconds p))
  (define before (file-size p))
  (put! "a.rkt" "#lang racket/base\n(require \"c.rkt\" racket/list)\n")   ; b -> c: same length
  (file-or-directory-modify-seconds p t0)
  (check-equal? (file-size p) before "the edit keeps the size")
  (define scanned (box '()))
  (define g2 (derive #:scanned scanned))
  (check-equal? (unbox scanned) '("a.rkt") "exactly the edited file")
  (check-equal? (hash-ref (dep-graph-source-deps g2) 'a.rkt) '(c.rkt))
  (put! "a.rkt" "#lang racket/base\n(require \"b.rkt\" racket/list)\n"))

(test-case "cache: new files appear, deleted files disappear"
  (put! "tests/test-new.rkt" "#lang racket/base\n(require \"../b.rkt\")\n")
  (define scanned (box '()))
  (define g2 (derive #:scanned scanned))
  (check-equal? (sort (unbox scanned) string<?) '("a.rkt" "tests/test-new.rkt") "a.rkt was restored by the last case")
  (check-equal? (hash-ref (dep-graph-test-deps g2) 'test-new.rkt) (test-dep '(b.rkt) #f))
  (check-not-false (member 'test-new.rkt (all-test-files root)))
  (delete-file (build-path root "tests" "test-new.rkt"))
  (define g3 (derive))
  (check-false (hash-ref (dep-graph-test-deps g3) 'test-new.rkt #f))
  (check-false (member 'test-new.rkt (all-test-files root)))
  (check-equal? g3 g))

(test-case "cache: a corrupt cache, or one from another version of dep-graph.rkt, is discarded"
  (call-with-output-file cache #:exists 'truncate (lambda (o) (display "(dep-graph-cache #\"x\" #hash((" o)))
  (define scanned (box '()))
  (check-equal? (derive #:scanned scanned) g)
  (check-equal? (length (unbox scanned)) 7 "every module re-scanned")
  (define d (call-with-input-file cache read))
  (check-equal? (car d) 'dep-graph-cache "rewritten whole")
  ;; same entries, another version's self key: none of them may be trusted
  (define stale-key (list 'dep-graph-cache #"another-version" (caddr d)))
  (call-with-output-file cache #:exists 'truncate (lambda (o) (write stale-key o)))
  (define scanned2 (box '()))
  (check-equal? (derive #:scanned scanned2) g)
  (check-equal? (length (unbox scanned2)) 7))

(test-case "all-test-files: every tests/test-*.rkt on disk, nothing else"
  (check-equal? (all-test-files root) '(test-a.rkt test-c.rkt)))

(test-case "this checkout: the cached derivation equals a full rescan; all-test-files is the disk listing"
  (define cached (derive-dep-graph))
  (define scanned (derive-dep-graph #:cache-path #f))
  (check-equal? cached scanned)
  (define on-disk
    (sort (for/list ([f (directory-list (build-path default-project-root "tests"))]
                     #:when (regexp-match? #rx"^test-.*[.]rkt$" (path->string f)))
            (string->symbol (path->string f)))
          symbol<?))
  (check-equal? (all-test-files) on-disk)
  (check-equal? (sort (hash-keys (dep-graph-test-deps scanned)) symbol<?) on-disk))

(delete-directory/files root #:must-exist? #f)
