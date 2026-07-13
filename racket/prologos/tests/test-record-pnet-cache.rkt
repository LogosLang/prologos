#lang racket/base

;;;
;;; CIU Track 6 F1a-s3 — cross-module .pnet canary (D.3 coverage gap).
;;;
;;; The F2 lesson: an unregistered node in a CACHED library body does not error
;;; at cache read — the reader's unknown-tag fallback returns a raw VECTOR
;;; impostor that detonates at the first cached USE, arbitrarily far away.
;;; The single-file :no-prelude acceptance file structurally cannot reach this
;;; surface. This test commits the two-run repro shape: a lib module whose defs
;;; carry expr-Record types (+ record-field structs inside them) is loaded by a
;;; consumer TWICE — run 1 elaborates from source and WRITES the .pnet; run 2
;;; (fresh module context) READS the cache and the consumer PROJECTS the
;;; record-typed defs. If Record deserialization were broken, run 2 would crash
;;; or mis-type; both runs must agree.
;;;

(require rackunit
         racket/file
         racket/list
         racket/string
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../reduction.rkt"
         "../namespace.rkt"
         "../trait-resolution.rkt"
         "../parse-reader.rkt"
         (only-in "../pnet-serialize.rkt" pnet-path-for-module))

;; Unique ns so no other test's cache entry collides.
(define lib-ns 'reclib-f1s3-canary)

;; ---- Fixture: a temp lib dir with a record-carrying module ----
(define temp-lib-dir (make-temporary-file "prologos-reclib-~a" 'directory))
(define lib-file (build-path temp-lib-dir "reclib-f1s3-canary.prologos"))
(call-with-output-file lib-file #:exists 'replace
  (lambda (out)
    (display (string-append
              "ns reclib-f1s3-canary :no-prelude\n"
              "def rq := {:a 1 :b \"x\"}\n"
              "def nested := {:o {:i 7}}\n")
             out)))

(define consumer-src
  (string-append
   "ns pnet-consumer :no-prelude\n"
   "require [reclib-f1s3-canary :refer [rq nested]]\n"
   "rq.a\n"
   "nested.o.i\n"
   "map-keys rq\n"))

;; One full, isolated processing context per run (fresh registries + network;
;; SAME lib dir + cache dir, so run 2 is a cache HIT).
(define (run-consumer!)
  (define tmp (make-temporary-file "prologos-pnetc-~a.prologos"))
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
  results)

(define (result-strings results)
  (for/list ([r (in-list results)])
    (cond [(prologos-error? r) (format "ERROR: ~a" (prologos-error-message r))]
          [(string? r) r]
          [else (format "~a" r)])))

;; Start from a cold cache for OUR module (previous test runs may have left one).
(define cache-path (pnet-path-for-module lib-ns))
(when (file-exists? cache-path) (delete-file cache-path))

;; ---- Run 1: elaborate from source, write the cache ----
(define run1 (result-strings (run-consumer!)))

(test-case "run 1 (source elaboration): consumer projects record-typed lib defs"
  (check-false (ormap (lambda (s) (string-contains? s "ERROR")) run1)
               (format "run 1 had errors: ~a" run1))
  (check-true (ormap (lambda (s) (string-contains? s "1 : Int")) run1) (format "~a" run1))
  (check-true (ormap (lambda (s) (string-contains? s "7 : Int")) run1) (format "~a" run1))
  (check-true (ormap (lambda (s) (string-contains? s "List Keyword")) run1) (format "~a" run1)))

(test-case "run 1 wrote the module's .pnet cache"
  (check-true (file-exists? cache-path)
              (format "expected cache at ~a" cache-path)))

;; ---- Run 2: fresh context — module loads FROM the cache; consumer USES it ----
(define run2 (result-strings (run-consumer!)))

(test-case "run 2 (cache read): record types survive deserialization + first USE"
  (check-false (ormap (lambda (s) (string-contains? s "ERROR")) run2)
               (format "run 2 had errors: ~a" run2))
  ;; identical observable behavior across the cache boundary
  (check-equal? run2 run1))
