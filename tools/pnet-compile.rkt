#lang racket/base

;; pnet-compile.rkt — End-to-end compiler driver via the .pnet pipeline.
;;
;; Pipeline:
;;   .prologos source
;;       → process-file (Racket) — populates the global env with typed AST
;;       → typed-ast-to-low-pnet — emits a Low-PNet IR for main
;;       → serialize-program-state — writes a 'program-mode .pnet file
;;       → deserialize-program-state — reads it back as Low-PNet
;;       → lower-low-pnet-to-llvm — emits LLVM IR
;;       → clang + libprologos-runtime.o — links to a native binary
;;       → run + capture exit code
;;
;; This is the SH-series demonstration that .pnet → binary works
;; end-to-end without waiting for PPN Track 4. The supported program
;; subset is intentionally narrow:
;;
;;   def main : Int := <int-literal>     ✓ (works today)
;;   def main : Bool := <bool-literal>   ✓ (works today)
;;   anything else                       → unsupported error
;;
;; The narrowness is deliberate: this commit closes the .pnet → binary
;; loop for the simplest possible Prologos program. Subsequent work
;; (typed-ast → propagator network, propagator-decl lowering in
;; Phase 2.D, fire-fn .o emission) extends the supported subset.
;;
;; Usage:
;;   racket tools/pnet-compile.rkt FILE.prologos
;;     → writes /tmp/<name>.pnet, /tmp/<name>.ll, /tmp/<name>; runs binary
;;
;;   racket tools/pnet-compile.rkt --emit-pnet FILE.prologos
;;     → writes only the .pnet, prints path
;;
;;   racket tools/pnet-compile.rkt --emit-only FILE.prologos
;;     → writes only the .ll, prints to stdout
;;
;;   racket tools/pnet-compile.rkt -o BINARY FILE.prologos
;;     → links the binary to BINARY
;;
;; Env:
;;   PROLOGOS_RUNTIME_OBJ : path to runtime/prologos-runtime.o
;;                          (default: runtime/prologos-runtime.o)
;;   PROLOGOS_CLANG       : clang binary (default: clang)

(require racket/cmdline
         racket/system
         racket/file
         racket/path
         racket/match
         "../racket/prologos/driver.rkt"
         "../racket/prologos/global-env.rkt"
         "../racket/prologos/syntax.rkt"
         "../racket/prologos/low-pnet-ir.rkt"
         "../racket/prologos/low-pnet-to-llvm.rkt"
         "../racket/prologos/pnet-deploy.rkt"
         "../racket/prologos/ast-to-low-pnet.rkt"
         "../racket/prologos/propagator.rkt")

(define out-bin-arg  (make-parameter "out"))
(define emit-pnet?   (make-parameter #f))
(define emit-only?   (make-parameter #f))
(define run?         (make-parameter #t))

;; lowering-yolo M5 (2026-05-02): trailing positional arguments after
;; the .prologos file are forwarded to the lowered binary's argv.
;; Required for parameterised main (`def main : Int -> ... := ...`).
;; For closed main these are silently ignored by the binary.
(define-values (input-path-str prog-args)
  (let ([raw (command-line
              #:program "pnet-compile"
              #:once-each
              [("-o") path "Output binary path (default: out)" (out-bin-arg path)]
              [("--emit-pnet") "Emit only the .pnet file; do not lower or link" (emit-pnet? #t) (run? #f)]
              [("--emit-only") "Emit only LLVM IR (.ll) to stdout; do not link" (emit-only? #t) (run? #f)]
              [("--no-run") "Lower and link but do not run" (run? #f)]
              #:args args
              args)])
    (cond
      [(null? raw)
       (error 'pnet-compile "missing input file argument; usage: pnet-compile [options] FILE.prologos [arg1 arg2 ...]")]
      [else (values (car raw) (cdr raw))])))

(define input-path (string->path input-path-str))

;; -------- Step 1: elaborate the source -----------------------------------
;; process-file populates the global env. main's typed body is at:
;;   (global-env-lookup-value 'main).

(define _result (process-file input-path-str))
(define main-type (global-env-lookup-type 'main))
(define main-body (global-env-lookup-value 'main))

(unless main-type
  (error 'pnet-compile "no top-level definition named 'main' in ~a" input-path))

;; -------- Step 2: build a Low-PNet from the typed AST --------------------
;; Use ast-to-low-pnet (Phase 2.D) which handles literals + binary
;; arithmetic via propagator-decls. Anything beyond that range raises
;; ast-translation-error.

(define lp (ast-to-low-pnet main-type main-body (path->string input-path)))

;; -------- Step 3: write the program.pnet file --------------------------
;; pnet-deploy expects a prop-network as input but our Low-PNet was
;; synthesized without one. Use a low-level write directly.

(require (only-in "../racket/prologos/pnet-serialize.rkt" pnet-wrap))

(define (write-pnet path lp-form)
  (define wrapped (pnet-wrap (pp-low-pnet lp-form) 'program))
  (with-output-to-file path #:exists 'replace
    (lambda () (write wrapped))))

(define stem (regexp-replace #rx"\\.prologos$" (path->string (file-name-from-path input-path)) ""))
(define pnet-path (string-append "/tmp/" stem ".pnet"))
(write-pnet pnet-path lp)

(when (emit-pnet?)
  (printf "Wrote ~a~n" pnet-path)
  (exit 0))

;; -------- Step 4: lower Low-PNet → LLVM IR --------------------------
;; Round-trip through .pnet to validate the serialization works for real.

(define lp-loaded (deserialize-program-state pnet-path))
(unless lp-loaded
  (error 'pnet-compile "failed to round-trip .pnet at ~a" pnet-path))

(define ir (lower-low-pnet-to-llvm lp-loaded))

(when (emit-only?)
  (display ir)
  (exit 0))

;; -------- Step 5: link via clang ------------------------------------
(define ll-path (string-append "/tmp/" stem ".ll"))
(with-output-to-file ll-path #:exists 'replace
  (lambda () (display ir)))

(define clang (or (getenv "PROLOGOS_CLANG") "clang"))
(define runtime-obj (or (getenv "PROLOGOS_RUNTIME_OBJ") "runtime/prologos-runtime.o"))
;; Phase 2 Day 5 (2026-05-02 kernel-pocket-universes track): the
;; runtime depends on prologos-hamt.o for HAMT-rooted cell storage.
;; Link both objects.
(define hamt-obj (or (getenv "PROLOGOS_HAMT_OBJ") "runtime/prologos-hamt.o"))
(define out-bin (out-bin-arg))

(printf "Linking ~a + ~a + ~a -> ~a~n" ll-path runtime-obj hamt-obj out-bin)
(define link-ok?
  (system* (find-executable-path clang) ll-path runtime-obj hamt-obj "-o" out-bin))
(unless link-ok?
  (error 'pnet-compile "clang link failed"))

;; -------- Step 6: run --------------------------------------------------
;;
;; M5 (lowering-yolo, 2026-05-02): forward any trailing positional
;; arguments to the binary's argv. The binary itself decides whether
;; they are needed: parameterised main calls prologos_argv_i64 to read
;; them; closed main ignores them.
;;
;; The binary's stdout is intentionally inherited (not captured) so
;; the user sees the printed result interleaved with the driver's
;; bookkeeping lines. The benchmark harness (M7) wraps this differently
;; — it bypasses the driver and invokes the binary directly so it can
;; capture and validate stdout.
(when (run?)
  (define abs-out (path->complete-path out-bin))
  (printf "Running ~a~a~n"
          abs-out
          (if (null? prog-args) "" (format " with args: ~a" prog-args)))
  (define exit-code (apply system*/exit-code abs-out prog-args))
  (printf "exit=~a~n" exit-code)
  (exit exit-code))
