#lang racket/base

;;;
;;; preduce-hybrid-main.rkt — top-level entry point for the hybrid
;;; Racket-Zig runtime binary.
;;;
;;; Usage: prologos-hybrid PROGRAM.prologos
;;;
;;; Reads PROGRAM.prologos via process-file (the existing Racket
;;; pipeline: parser → elaborator → typing-core), looks up the
;;; elaborated 'main definition, runs preduce-hybrid on it (which
;;; constructs a propagator network in the Zig kernel and runs to
;;; quiescence), prints the result + profile summary to stdout.
;;;
;;; Phase 9 deliverable: this is the binary the user runs after
;;; bundling via raco exe + raco distribute. Single-file invocation
;;; demonstrates the full Racket-Zig round-trip.
;;;
;;; Cross-references:
;;;   docs/tracking/2026-05-03_HYBRID_RUNTIME_DESIGN.md (Phase 9)
;;;   racket/prologos/preduce-hybrid.rkt (the hybrid reducer)
;;;   racket/prologos/runtime-bridge.rkt (the FFI layer)

(require racket/cmdline
         racket/format
         "preduce-hybrid.rkt"
         "runtime-bridge.rkt"
         "global-env.rkt"
         "driver.rkt"
         (only-in "reduction.rkt" nf))

(define show-profile? (make-parameter #f))
(define use-nf-fallback? (make-parameter #f))

(define program-file
  (command-line
   #:program "prologos-hybrid"
   #:once-each
   [("-p" "--profile") "Print kernel + callback profile after run"
                        (show-profile? #t)]
   [("--nf-fallback") "If preduce-hybrid encounters an unsupported node, fall back to nf"
                       (use-nf-fallback? #t)]
   #:args (file)
   file))

(unless (hybrid-runtime-available?)
  (eprintf "ERROR: libprologos-runtime-hybrid.so not loaded.~n")
  (eprintf "Build via: cd runtime && zig build-lib -dynamic prologos-runtime-hybrid.zig -O ReleaseFast~n")
  (exit 2))

;; Process the file (parser → elaborator → typing-core).
(printf "Loading ~a ...~n" program-file)
(process-file program-file)

;; Look up main.
(define main-body (global-env-lookup-value 'main))
(unless main-body
  (eprintf "ERROR: no 'main definition found in ~a~n" program-file)
  (exit 1))

;; Reduce via the hybrid runtime (with optional nf fallback).
(when (show-profile?)
  (prologos_set_profile_per_tag 1)
  (prologos_reset_stats))

(define result
  (cond
    [(use-nf-fallback?)
     (with-handlers ([exn:fail? (lambda (e)
                                   (eprintf "preduce-hybrid failed: ~a; falling back to nf~n"
                                            (exn-message e))
                                   (nf main-body))])
       (preduce-hybrid main-body))]
    [else (preduce-hybrid main-body)]))

(printf "Result: ~v~n" result)

(when (show-profile?)
  (printf "~n=== Profile ===~n")
  (prologos_print_stats)
  (prologos_print_callback_summary))
