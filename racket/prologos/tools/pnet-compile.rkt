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

(case (mode)
  [(clean)
   (when (directory-exists? cache-dir)
     (delete-directory/files cache-dir)
     (printf "Deleted ~a\n" cache-dir))]

  [(check)
   (printf "Checking .pnet cache in ~a ...\n" cache-dir)
   (if (directory-exists? cache-dir)
       (let ([files (directory-list cache-dir)])
         (printf "~a .pnet files present\n" (length files)))
       (printf "No cache directory exists\n"))]

  [(generate)
   (printf "Generating .pnet cache ...\n")
   (make-directory* cache-dir)
   (current-use-pnet-cache? #t)
   (current-pnet-write-enabled? #t)
   (install-module-loader!)
   ;; Loading the prelude triggers module loading, which auto-writes .pnet files
   (process-string "(ns pnet-gen)")
   (define count (length (directory-list cache-dir)))
   (printf "Generated ~a .pnet files in ~a\n" count cache-dir)])
