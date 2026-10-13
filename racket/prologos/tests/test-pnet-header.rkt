#lang racket/base

;;;
;;; DEFERRED 151 fix (a) — the `.pnet` header is a SEPARATE first datum.
;;;
;;; Before: a .pnet file was ONE datum `(VERSION SOURCE-HASH env specs …)`, so
;;; `pnet-stale?` `read` the whole file (~0.4–1 MB per module) to compare two
;;; elements, and `deserialize-module-state` read it all again — 2.6 s of every
;;; process start (DEFERRED 151). Now (PNET_VERSION 11) the file is two data:
;;;     (pnet-header VERSION SOURCE-HASH)
;;;     (env specs locs exports ns-string registries…)   ; the old slots 2–30
;;; `pnet-stale?` reads ONLY the header; the loader reads header + body once.
;;;
;;; Pinned here:
;;;   - the on-disk layout (the header prefix is what `pnet-stale?` peeks for);
;;;   - fresh / stale-by-source / wrong-version / not-a-header detection;
;;;   - `pnet-stale?` never parses the body (a valid header over an unreadable
;;;     body is judged by the header alone);
;;;   - an OLD single-datum file (v10 layout, even with the current source key)
;;;     is stale and never a crash, and a load over it regenerates a v11 file;
;;;   - round trip: the cache-hit run's results equal the source run's, and the
;;;     deserialized body is the body that was written.
;;;

(require rackunit
         racket/file
         racket/list
         racket/string
         "../macros.rkt"
         "../errors.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         (only-in "../pnet-serialize.rkt"
                  pnet-path-for-module pnet-stale? deserialize-module-state
                  PNET_VERSION read-pnet-header))

;; Unique ns so no other test's cache entry collides.
(define lib-ns 'pnet151a-hdr)

(define temp-lib-dir (make-temporary-file "prologos-pnet151a-~a" 'directory))
(define lib-file (build-path temp-lib-dir "pnet151a-hdr.prologos"))
(call-with-output-file lib-file #:exists 'replace
  (lambda (out)
    (display (string-append
              "ns pnet151a-hdr :no-prelude\n"
              "def one := 1\n"
              "def rq := {:a 1 :b \"x\"}\n")
             out)))

(define consumer-src
  (string-append
   "ns pnet151a-consumer :no-prelude\n"
   "require [pnet151a-hdr :refer [one rq]]\n"
   "one\n"
   "rq.b\n"))

;; One full, isolated processing context per run (fresh registries + network;
;; SAME lib dir + cache dir, so a second run is a cache HIT).
(define (run-consumer!)
  (define tmp (make-temporary-file "prologos-pnet151c-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display consumer-src out)))
  (define results
    (parameterize ([current-file-module-network-ref (make-module-network)]
                   [current-ns-context #f]
                   [current-module-registry (hasheq)]
                   [current-lib-paths (list temp-lib-dir)]
                   [current-preparse-registry (current-preparse-registry)]
                   [current-trait-registry (current-trait-registry)]
                   [current-impl-registry (current-impl-registry)]
                   [current-param-impl-registry (current-param-impl-registry)]
                   [current-bundle-registry (current-bundle-registry)]
                   [current-use-pnet-cache? #t]
                   [current-pnet-write-enabled? #t])
      (install-module-loader!)
      (process-file tmp)))
  (delete-file tmp)
  (for/list ([r (in-list results)])
    (cond [(prologos-error? r) (format "ERROR: ~a" (prologos-error-message r))]
          [(string? r) r]
          [else (format "~a" r)])))

(define cache-path (pnet-path-for-module lib-ns))
(define (read-all-data path)
  (call-with-input-file path
    (lambda (in) (let loop ([acc '()])
                   (define d (read in))
                   (if (eof-object? d) (reverse acc) (loop (cons d acc)))))))
(define (write-pnet-file! . data)
  (call-with-output-file cache-path #:exists 'truncate
    (lambda (out) (for ([d (in-list data)]) (write d out) (newline out)))))
(define (write-pnet-text! s)
  (call-with-output-file cache-path #:exists 'truncate (lambda (out) (display s out))))

;; Start from a cold cache for OUR module (previous runs may have left one).
(when (file-exists? cache-path) (delete-file cache-path))

;; ---- Run 1: elaborate from source, write the cache ----
(define run1 (run-consumer!))
(define written (and (file-exists? cache-path) (file->bytes cache-path)))
(define written-data (and written (read-all-data cache-path)))
(define source-key (and written-data (caddr (car written-data))))

(test-case "run 1 elaborates from source and writes the cache"
  (check-false (ormap (lambda (s) (string-contains? s "ERROR")) run1) (format "~a" run1))
  (check-true (ormap (lambda (s) (string-contains? s "1 : Int")) run1) (format "~a" run1))
  (check-true (bytes? written) (format "expected cache at ~a" cache-path)))

(test-case "layout: header datum (pnet-header VERSION KEY), then ONE body datum"
  (check-equal? PNET_VERSION 11)
  (check-true (regexp-match? #rx#"^[(]pnet-header " written) "file must start with the header prefix")
  (check-equal? (length written-data) 2 "header + body, nothing else")
  (define hdr (car written-data))
  (check-equal? (length hdr) 3)
  (check-equal? (car hdr) 'pnet-header)
  (check-equal? (cadr hdr) PNET_VERSION)
  (check-true (string? source-key))
  (check-true (string-prefix? source-key (path->string lib-file)) source-key)
  ;; body = the old slots 2-30 (env specs locs exports ns-string + 24 registries)
  (define body (cadr written-data))
  (check-equal? (length body) 29)
  (check-equal? (list-ref body 4) "pnet151a-hdr"))

(test-case "fresh: pnet-stale? is #f right after the write"
  (check-false (pnet-stale? lib-ns lib-file)))

;; ---- Run 2: fresh context — the module loads FROM the cache ----
(define run2 (run-consumer!))

(test-case "round trip: the cache-hit run equals the source run, and the file was not rewritten"
  (check-false (ormap (lambda (s) (string-contains? s "ERROR")) run2) (format "~a" run2))
  (check-equal? run2 run1)
  (check-equal? (file->bytes cache-path) written "a hit must not regenerate"))

(test-case "round trip: deserialize-module-state returns the written body, decoded"
  (define d (deserialize-module-state lib-ns lib-file))
  (check-true (list? d))
  (check-equal? (length d) 28)
  ;; exports (returned slot 3) are stored verbatim in body slot 3
  (check-equal? (list-ref d 3) (list-ref (cadr written-data) 3))
  (check-true (hash? (list-ref d 0)) "env snapshot decodes to a hash"))

(test-case "pnet-stale? reads only the header: a valid header over an unreadable body is not stale"
  (write-pnet-text! (format "~s\n(this body is never closed" (car written-data)))
  (check-false (pnet-stale? lib-ns lib-file))
  ;; …and the loader, which must read the body, rejects it without raising
  (check-false (deserialize-module-state lib-ns lib-file)))

(test-case "stale by source: a changed source key makes both readers refuse; restoring it makes the file fresh again"
  (apply write-pnet-file! written-data)
  (define t0 (file-or-directory-modify-seconds lib-file))
  (file-or-directory-modify-seconds lib-file (+ t0 7))
  (check-true (pnet-stale? lib-ns lib-file))
  (check-false (deserialize-module-state lib-ns lib-file))
  (file-or-directory-modify-seconds lib-file t0)
  (check-false (pnet-stale? lib-ns lib-file))
  (check-true (list? (deserialize-module-state lib-ns lib-file))))

(test-case "version gate is exact equality: older, newer and non-numeric versions are stale, never a crash"
  (for ([v (list (sub1 PNET_VERSION) (add1 PNET_VERSION) "11" 'eleven)])
    (write-pnet-file! (list 'pnet-header v source-key) (cadr written-data))
    (check-true (pnet-stale? lib-ns lib-file) (format "version ~s" v))
    (check-false (deserialize-module-state lib-ns lib-file) (format "version ~s" v))))

(test-case "old single-datum layout (v10, CURRENT source key) is stale and never a crash"
  ;; exactly what the v10 writer produced: (write (list* 10 key body))
  (write-pnet-file! (list* 10 source-key (cadr written-data)))
  (check-true (pnet-stale? lib-ns lib-file))
  (check-false (deserialize-module-state lib-ns lib-file))
  ;; an old-layout file is classified by its first bytes, without parsing it
  (write-pnet-text! (format "(10 ~s (this old body is never closed" source-key))
  (check-true (pnet-stale? lib-ns lib-file))
  (check-false (deserialize-module-state lib-ns lib-file)))

(test-case "degenerate files are stale, never a crash"
  (for ([s (list "" "(pnet-header" "(pnet-header 11)" "(pnet-header 11 \"k\" extra)" "#<garbage>"
                 "pnet-header 11 \"k\"")])
    (write-pnet-text! s)
    (check-true (pnet-stale? lib-ns lib-file) (format "~s" s))
    (check-false (deserialize-module-state lib-ns lib-file) (format "~s" s))))

(test-case "read-pnet-header rejects a non-header file from its first bytes, consuming nothing"
  ;; An old single-datum file is one huge list: `read` would parse all of it.
  ;; The prefix peek must refuse it without reading a single datum.
  (define in (open-input-string "(10 \"key\" (an old body that is never closed"))
  (check-false (read-pnet-header in))
  (check-equal? (file-position in) 0)
  ;; and on a v11 file it consumes exactly the header, leaving the body unread
  (define in2 (open-input-string "(pnet-header 11 \"k\")\n(body never closed"))
  (check-equal? (read-pnet-header in2) '(pnet-header 11 "k"))
  (check-equal? (file-position in2) (string-length "(pnet-header 11 \"k\")")))

(test-case "a load over an old-layout file falls back to source and regenerates a v11 file"
  (write-pnet-file! (list* 10 source-key (cadr written-data)))
  (define run3 (run-consumer!))
  (check-equal? run3 run1)
  (check-true (regexp-match? #rx#"^[(]pnet-header " (file->bytes cache-path)))
  (check-false (pnet-stale? lib-ns lib-file)))

;; ---- Cleanup: remove our TOP-LEVEL cache file (the runner's pregen
;; heuristic counts top-level *.pnet files; see test-record-pnet-cache.rkt).
(when (file-exists? cache-path) (delete-file cache-path))
(delete-directory/files temp-lib-dir #:must-exist? #f)
