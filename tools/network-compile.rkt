#lang racket/base

;; network-compile.rkt — CLI: .prologos -> network skeleton -> LLVM IR -> linked binary.
;;
;; Pipeline:
;;   1. process-file (driver.rkt) — populates the global env with typed AST
;;   2. emit-program/from-global-env (network-emit.rkt) — typed AST -> skeleton
;;   3. lower-skeleton (network-lower.rkt) -> LLVM IR text
;;   4. clang IR + prologos-runtime.o -> native binary
;;
;; Usage:
;;   racket tools/network-compile.rkt FILE.prologos
;;     Lower + link to ./out, run, print exit code.
;;
;;   racket tools/network-compile.rkt --emit-only FILE.prologos
;;     Lower to stdout (or to -o PATH if given). Skip clang and execution.
;;
;;   racket tools/network-compile.rkt -o BINARY FILE.prologos
;;     Lower + link to BINARY. Run unless --no-run.
;;
;; Tier-controlled by PROLOGOS_NETWORK_TIER (default 0).
;; Runtime object path: PROLOGOS_RUNTIME_OBJ (default: runtime/prologos-runtime.o).

(require racket/cmdline
         racket/system
         "../racket/prologos/driver.rkt"
         "../racket/prologos/network-emit.rkt"
         "../racket/prologos/network-lower.rkt")

(define emit-only? (make-parameter #f))
(define out-path (make-parameter "out"))
(define run? (make-parameter #t))

(define input-path
  (command-line
   #:program "network-compile"
   #:once-each
   [("--emit-only") "Emit LLVM IR only; do not link or run."
                    (emit-only? #t)
                    (run? #f)]
   [("-o") path "Output path (binary, or .ll if --emit-only)."
           (out-path path)]
   [("--run") "Lower, link, and run (default)."
              (run? #t)]
   [("--no-run") "Lower, link, but do not run."
                 (run? #f)]
   #:args (file)
   file))

(define tier
  (let ([s (getenv "PROLOGOS_NETWORK_TIER")])
    (if s (string->number s) 0)))

(current-network-tier tier)

;; 1. Run the elaboration pipeline. Populates the global env.
(define result (process-file input-path))
(when (string? result)
  (displayln result))

;; 2. Emit the network skeleton.
(define skeleton (emit-program/from-global-env))

;; 3. Lower to LLVM IR text.
(define ir (lower-skeleton skeleton))

(cond
  [(emit-only?)
   (cond
     [(equal? (out-path) "out") (display ir)]
     [else
      (with-output-to-file (out-path) #:exists 'replace
        (lambda () (display ir)))
      (printf "Wrote IR to ~a~n" (out-path))])]
  [else
   ;; 4. Write IR to .ll, link with the runtime kernel via clang.
   (define ll-path (string-append (out-path) ".ll"))
   (with-output-to-file ll-path #:exists 'replace
     (lambda () (display ir)))
   (define clang (or (getenv "PROLOGOS_CLANG") "clang"))
   (define runtime-obj
     (or (getenv "PROLOGOS_RUNTIME_OBJ") "runtime/prologos-runtime.o"))
   (printf "Linking ~a + ~a -> ~a~n" ll-path runtime-obj (out-path))
   (define link-ok?
     (system* (find-executable-path clang)
              ll-path runtime-obj "-o" (out-path)))
   (unless link-ok?
     (error 'network-compile "clang link failed"))
   (when (run?)
     (define abs-out (path->complete-path (out-path)))
     (printf "Running ~a~n" abs-out)
     (define exit-code (system*/exit-code abs-out))
     (printf "exit=~a~n" exit-code)
     (exit exit-code))])
