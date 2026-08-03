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

;; ------------------------------------------------------------------
;; Phase 4 — the SCHEMA carrier, which is the shape the DEFERRED entry
;; ("CIU T6: the cross-module schema channel", gap 1) actually names.
;;
;; Worth its own phase rather than trusting phases 1-3 to cover it. A schema
;; does not reach a dependent the way `basev` does: GitHub #78 P2 serializes the
;; schema registry into the `.pnet` (v4, indices 24-30) and re-registers it on a
;; cache HIT, and the dependent bakes the schema's `:default` chain into its own
;; AST at elaboration. So the stale value can be carried by two different
;; mechanisms here, and "the contents are correct on a hit" (which #78 fixed) is
;; a separate question from "the hit was legitimate" (which this fixes). The
;; entry drew exactly that line and left the second half open.
;;
;; ⚠ THE MIDDLE MODULE IS NOT DECORATION, and the first draft of this phase
;; omitted it and PASSED WITH THE FIX DISABLED. If the user file imports the
;; schema module directly, that module's OWN mtime changed, so
;; `source-hash-for-module` invalidates its `.pnet` unaided and the phase proves
;; nothing about dependency staleness. The bake has to happen one module in:
;; `schmid` imports the schema and commits `:default` into its own AST, so
;; `schmid.prologos` is untouched by the edit — which is precisely the case the
;; own-mtime check cannot see. Same three-level shape as phases 1-3, and for the
;; same reason.
;; ------------------------------------------------------------------

(define sch-dir (build-path lib-root "prologos" "pnetdep"))

(define (write-schema! port-default)
  (call-with-output-file (build-path sch-dir "sch.prologos") #:exists 'truncate
    (lambda (o)
      (display (string-append
                "ns prologos::pnetdep::sch\n\n"
                "schema Cfg\n"
                "  :host String\n"
                (format "  :port Int :default ~a\n" port-default))
               o))))

;; The middle module — this is where the schema's `:default` gets BAKED.
(call-with-output-file (build-path sch-dir "schmid.prologos") #:exists 'truncate
  (lambda (o)
    (display (string-append
              "ns prologos::pnetdep::schmid\n\n"
              "imports prologos::pnetdep::sch\n\n"
              "def baked-port : Int := [map-get (the Cfg {:host \"h\"}) :port]\n")
             o)))

(define sch-user (build-path lib-root "schuser.prologos"))
(call-with-output-file sch-user #:exists 'truncate
  (lambda (o)
    (display (string-append
              "ns pnetdepschuser\n\n"
              "imports prologos::pnetdep::schmid\n\n"
              "baked-port\n")
             o)))

(write-schema! 80)

(define (run-sch-user)
  (install-module-loader!)
  (reset-lib-source-staleness-cache!)
  (parameterize ([current-lib-paths (list lib-root)]
                 [current-module-registry prelude-module-registry]
                 [current-use-pnet-cache? #t]
                 [current-pnet-write-enabled? #t])
    (format "~a" (last (process-file sch-user)))))

(define sch-cold (run-sch-user))
(define sch-warm (run-sch-user))

(test-case "pnet-dep/phase 4: the schema's :default arrives, and the cache serves it"
  (check-true (regexp-match? #rx"^80 : Int" sch-cold) (format "got: ~a" sch-cold))
  (check-equal? sch-warm sch-cold "a warm run must agree — the cache must be live")
  (check-true (file-exists? (pnet-path-for-module 'prologos::pnetdep::schmid))
              "the load should have WRITTEN a .pnet for the BAKING module"))

(write-schema! 8080)
(let* ([pnet (pnet-path-for-module 'prologos::pnetdep::schmid)]
       [src (build-path sch-dir "sch.prologos")]
       [t (+ 2 (max (file-or-directory-modify-seconds pnet)
                    (file-or-directory-modify-seconds src)))])
  (file-or-directory-modify-seconds src t))

(test-case "pnet-dep/phase 4: editing the DEFINING module's schema is seen (8080)"
  (define r (run-sch-user))
  (check-true (regexp-match? #rx"^8080 : Int" r)
              (format "a stale cache served the pre-edit :default: ~a" r)))

;; Cleanup — the .pnet files land in the shared cache dir, not the temp lib.
(for ([m (in-list '(prologos::pnetdep::base prologos::pnetdep::mid
                    prologos::pnetdep::sch prologos::pnetdep::schmid))])
  (define p (pnet-path-for-module m))
  (when (file-exists? p) (delete-file p)))
(delete-directory/files lib-root #:must-exist? #f)
