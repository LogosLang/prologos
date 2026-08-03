#lang racket/base

;;; test-pnet-dep-staleness.rkt — editing a DEPENDENCY invalidates the cache.
;;;
;;; `source-hash-for-module` compares ONE file's mtime: the module's own. So a
;;; module whose dependency changed was reported fresh, and its cached env
;;; snapshot still carried the dependency's OLD contributions. Not a freshness
;;; nicety — a silent WRONG ANSWER:
;;;
;;;   base:  defn basev [x] [int+ x 1]
;;;   mid:   imports base;  defn midv [x] [basev x]
;;;   user:  imports mid;   def r := [midv 10]      => 11
;;;
;;; Edit `base` to `[int+ x 100]` and re-run the USER file only. Before the fix:
;;;   cache ON, mid.pnet present  ->  11   ← the pre-edit answer
;;;   cache OFF                   -> 110
;;;   cache ON, mid.pnet deleted  -> 110
;;;
;;; The fix mirrors the driver.zo check onto the second input class: a `.pnet`
;;; is a function of the Racket compiler AND of every `.prologos` that fed it.
;;;
;;; Why this needed a THREE-phase test rather than two. A test that only
;;; checked "edit → new answer" would also pass if the cache never hit at all,
;;; which is the easiest way to "fix" this and the worst. So phase 2 asserts a
;;; WARM run still serves the OLD answer from cache before any edit — i.e. the
;;; cache is genuinely live — and only then does phase 3 assert the edit is
;;; seen. Without phase 2 the suite would be green with caching disabled.
;;;
;;; mtimes are set explicitly rather than by sleeping: the granularity is
;;; whole seconds, so a fast test would otherwise write the edit inside the
;;; same second as the cache and see nothing.

(require rackunit
         racket/file
         racket/list
         racket/string
         "test-support.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         (only-in "../pnet-serialize.rkt"
                  reset-lib-source-staleness-cache!
                  pnet-path-for-module))

(define lib-root (make-temporary-file "prologos-pnetdep-~a" 'directory))
(define dep-dir (build-path lib-root "prologos" "pnetdep"))
(make-directory* dep-dir)

(define (write-base! n)
  (call-with-output-file (build-path dep-dir "base.prologos") #:exists 'truncate
    (lambda (o)
      (display (string-append
                "ns prologos::pnetdep::base\n\n"
                "spec basev Int -> Int\n"
                (format "defn basev [x] [int+ x ~a]\n" n))
               o))))

(call-with-output-file (build-path dep-dir "mid.prologos") #:exists 'truncate
  (lambda (o)
    (display (string-append
              "ns prologos::pnetdep::mid\n\n"
              "imports prologos::pnetdep::base\n\n"
              "spec midv Int -> Int\n"
              "defn midv [x] [basev x]\n")
             o)))

(define user-file (build-path lib-root "user.prologos"))
(call-with-output-file user-file #:exists 'truncate
  (lambda (o)
    (display (string-append
              "ns pnetdepuser\n\n"
              "imports prologos::pnetdep::mid\n\n"
              "def r := [midv 10]\n"
              "r\n")
             o)))

(write-base! 1)

(define (run-user)
  (install-module-loader!)
  (reset-lib-source-staleness-cache!)
  ;; WRITES must be enabled explicitly: `batch-worker.rkt` sets
  ;; `current-pnet-write-enabled? #f` so that N concurrent workers never race on
  ;; the shared cache dir. Without this the test cannot create the cache whose
  ;; staleness it is about, and phases 1-2 fail on a missing file rather than on
  ;; the behaviour. Safe here because the two module names are unique to this
  ;; file, so the paths written are touched by nothing else.
  ;; The MODULE REGISTRY must be reset per run too, and this is not incidental:
  ;; a module already in the registry is never re-loaded from disk at all, so
  ;; with a shared registry phase 3 reports the phase-1 answer no matter what
  ;; the cache does. (Found the hard way — phase 3 failed at `11` while a
  ;; fresh-process probe of the same three files returned `110`.)
  (parameterize ([current-lib-paths (list lib-root)]
                 [current-module-registry prelude-module-registry]
                 [current-use-pnet-cache? #t]
                 [current-pnet-write-enabled? #t])
    (define rs (process-file user-file))
    (format "~a" (last rs))))

(define (mid-pnet-exists?) (file-exists? (pnet-path-for-module 'prologos::pnetdep::mid)))

;; Phase 1 — cold. Nothing cached yet; this is the baseline answer.
(define cold (run-user))

(test-case "pnet-dep/phase 1: the cold run computes 11"
  (check-true (regexp-match? #rx"^11 : Int" cold) (format "got: ~a" cold))
  (check-true (mid-pnet-exists?) "the load should have WRITTEN a .pnet for mid"))

;; Phase 2 — warm, nothing edited. The cache must actually be SERVING, or
;; phase 3 proves nothing.
(define warm (run-user))

(test-case "pnet-dep/phase 2: the warm run is served from cache (still 11)"
  (check-equal? warm cold "a warm run must agree with the cold one")
  (check-true (mid-pnet-exists?) "the .pnet must still be there to be served"))

;; Phase 3 — edit the DEPENDENCY only, and push its mtime past the cache's.
;; `mid.prologos` is untouched, so its own mtime is unchanged: this is exactly
;; the case `source-hash-for-module` cannot see.
(write-base! 100)
(let* ([pnet (pnet-path-for-module 'prologos::pnetdep::mid)]
       [t (+ 2 (max (file-or-directory-modify-seconds pnet)
                    (file-or-directory-modify-seconds
                     (build-path dep-dir "base.prologos"))))])
  (file-or-directory-modify-seconds (build-path dep-dir "base.prologos") t))

(define after-edit (run-user))

(test-case "pnet-dep/phase 3: editing the DEPENDENCY is seen (110, not 11)"
  (check-true (regexp-match? #rx"^110 : Int" after-edit)
              (format "stale cache served the pre-edit answer: ~a" after-edit)))

;; Cleanup — the .pnet files land in the shared cache dir, not the temp lib.
(for ([m (in-list '(prologos::pnetdep::base prologos::pnetdep::mid))])
  (define p (pnet-path-for-module m))
  (when (file-exists? p) (delete-file p)))
(delete-directory/files lib-root #:must-exist? #f)
