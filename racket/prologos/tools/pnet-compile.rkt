#lang racket/base

;; pnet-compile.rkt — Pre-generate .pnet files for all prelude modules.
;;
;; Analogous to `raco make` for bytecode: loads the prelude once,
;; serializes each module's state to a .pnet file. Subsequent runs
;; (with `current-use-pnet-cache? #t`) load from .pnet instead of
;; re-elaborating from source.
;;
;; Usage:
;;   racket tools/pnet-compile.rkt            # generate all .pnet files
;;   racket tools/pnet-compile.rkt --clean    # delete all .pnet files
;;   racket tools/pnet-compile.rkt --check    # report stale/missing .pnet files
;;
;; The test runner calls this automatically before running tests
;; (unless --no-pnet-cache is specified).

(require racket/cmdline
         racket/path
         racket/file
         "../driver.rkt")

(define mode (make-parameter 'generate))

(command-line
 #:program "pnet-compile"
 #:once-any
 ["--clean" "Delete all .pnet files"
  (mode 'clean)]
 ["--check" "Report stale/missing .pnet files"
  (mode 'check)])

;; Track 10B: resolve cache dir from script location, not CWD.
;; This matches pnet-serialize.rkt's path resolution.
(define script-dir (path-only (syntax-source #'here)))
(define cache-dir
  (simplify-path (build-path script-dir ".." "data" "cache" "pnet")))

;; The prelude module caches live under the prologos/ subdirectory
;; (pnet-path-for-module maps prologos::core::list → prologos/core/list.pnet).
;; Counting must be recursive and scoped there — top-level strays (test
;; artifacts) are not prelude caches (incident: commit c6c3ef3a).
(define prelude-cache-dir (build-path cache-dir "prologos"))

(define (count-prelude-pnets)
  (if (directory-exists? prelude-cache-dir)
      (for/sum ([f (in-directory prelude-cache-dir)]
                #:when (regexp-match? #rx"\\.pnet$" (path->string f)))
        1)
      0))

;; Generation stamp: written only AFTER a complete generation. The test
;; runner's readiness check requires it and compares its mtime against
;; driver_rkt.zo, so an interrupted generation (no stamp) or a compiler
;; rebuild (newer driver_rkt.zo) triggers regeneration.
(define stamp-path (build-path cache-dir ".pnet-stamp"))
(define driver-zo-path
  (simplify-path (build-path script-dir ".." "compiled" "driver_rkt.zo")))

(case (mode)
  [(clean)
   (when (directory-exists? cache-dir)
     (delete-directory/files cache-dir)
     (printf "Deleted ~a\n" cache-dir))]

  [(check)
   (printf "Checking .pnet cache in ~a ...\n" cache-dir)
   (define count (count-prelude-pnets))
   (printf "~a prelude module caches present\n" count)
   (cond
     [(not (file-exists? stamp-path))
      (printf "No generation stamp — cache incomplete or pre-stamp; runner will regenerate\n")]
     [(and (file-exists? driver-zo-path)
           (< (file-or-directory-modify-seconds stamp-path)
              (file-or-directory-modify-seconds driver-zo-path)))
      (printf "STALE: driver_rkt.zo is newer than the generation stamp; runner will regenerate\n")]
     [else
      (printf "Stamp present and fresh vs driver_rkt.zo\n")])]

  [(generate)
   (printf "Generating .pnet cache ...\n")
   (make-directory* cache-dir)
   ;; Remove any prior stamp first: if this run is interrupted, no stamp
   ;; survives to present a partial cache as ready.
   (when (file-exists? stamp-path)
     (delete-file stamp-path))
   (current-use-pnet-cache? #t)
   (current-pnet-write-enabled? #t)
   (install-module-loader!)
   ;; Loading the prelude triggers module loading, which auto-writes .pnet files
   (process-string "(ns pnet-gen)")
   (define count (count-prelude-pnets))
   (call-with-output-file stamp-path
     (lambda (out)
       (fprintf out "~a ~a\n" (current-seconds) count))
     #:exists 'replace)
   (printf "Generated: ~a prelude module caches in ~a\n" count cache-dir)])
