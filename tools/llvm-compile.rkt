#lang racket/base

;; llvm-compile.rkt — CLI: .prologos -> .ll -> (clang) -> native binary
;;
;; Usage:
;;   racket tools/llvm-compile.rkt FILE.prologos
;;     Lower FILE to ./out.ll, link via clang to ./out, run, print exit code.
;;
;;   racket tools/llvm-compile.rkt --emit-only FILE.prologos
;;     Lower to stdout (or to -o PATH if given). Skip clang and execution.
;;
;;   racket tools/llvm-compile.rkt -o BINARY FILE.prologos
;;     Lower + link to BINARY. Skip execution.
;;
;;   racket tools/llvm-compile.rkt --run FILE.prologos
;;     Default: lower + link + run + print exit code (synonym for no flag).
;;
;; Tier-controlled by PROLOGOS_LLVM_TIER (default 0).

(require racket/cmdline
         racket/system
         "../racket/prologos/driver.rkt"
         "../racket/prologos/llvm-lower.rkt")

(define emit-only? (make-parameter #f))
(define out-path (make-parameter "out"))
(define run? (make-parameter #t))

(define input-path
  (command-line
   #:program "llvm-compile"
   #:once-each
   [("--emit-only") "Emit LLVM IR only; do not link or run."
                    (emit-only? #t)
                    (run? #f)]
   [("-o") path "Output path (binary, or .ll if --emit-only)."
           (out-path path)]
   [("--run") "Lower, link, and run (default)."
              (run? #t)]
   [("--no-run") "Lower, link, but do not run (use this when the caller will run the binary)."
                 (run? #f)]
   #:args (file)
   file))

(define tier
  (let ([s (getenv "PROLOGOS_LLVM_TIER")])
    (if s (string->number s) 0)))

(current-llvm-tier tier)

;; 1. Run the elaboration pipeline. process-file populates the global env.
(define result (process-file input-path))
(when (string? result)
  ;; process-file returns a status string per def. Print for visibility.
  (displayln result))

;; 2. Lower main from the global env.
;; Tier 0–1 use the main-only entry; Tier 2 walks dependencies.
(define ir
  (case tier
    [(0 1) (lower-program/from-global-env)]
    [else  (lower-program/from-global-env-multi)]))

(cond
  [(emit-only?)
   (cond
     [(equal? (out-path) "out")
      ;; No -o given: emit to stdout
      (display ir)]
     [else
      (with-output-to-file (out-path) #:exists 'replace
        (lambda () (display ir)))
      (printf "Wrote IR to ~a~n" (out-path))])]
  [else
   ;; 3. Write IR to a temp .ll file, link with clang to (out-path),
   ;;    optionally run, print exit code.
   (define ll-path (string-append (out-path) ".ll"))
   (with-output-to-file ll-path #:exists 'replace
     (lambda () (display ir)))
   (define clang (or (getenv "PROLOGOS_CLANG") "clang"))
   (printf "Linking ~a -> ~a~n" ll-path (out-path))
   (define link-ok?
     (system* (find-executable-path clang) ll-path "-o" (out-path)))
   (unless link-ok?
     (error 'llvm-compile "clang link failed"))
   (when (run?)
     (define abs-out (path->complete-path (out-path)))
     (printf "Running ~a~n" abs-out)
     (define exit-code (system*/exit-code abs-out))
     (printf "exit=~a~n" exit-code)
     (exit exit-code))])
