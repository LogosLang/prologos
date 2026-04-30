#lang racket/base

;; llvm-lower.rkt — SH Series Track 1, Tier 0–2.
;;
;; Lowers typed AST (expr-* structs from syntax.rkt, post-elaboration and
;; post-zonking) to LLVM IR text.
;;
;; SCAFFOLDING STATEMENT (per docs/tracking/2026-04-30_LLVM_LOWERING_TIER_0_2.md
;; § 5): this is a Racket function, NOT a propagator stratum. Promotion to a
;; lowering stratum is a deferred SH-series track gated on PPN Track 4D +
;; incremental compilation requirement. The function form's API is shaped
;; (lower-program : Listof TopForm -> String) so it can be replaced by the
;; stratum form without touching callers.
;;
;; CLOSED PASS: any AST node not in the supported set raises
;; (unsupported-llvm-node node tier hint). No silent fallthroughs.

(require racket/match
         "syntax.rkt"
         "global-env.rkt")

(provide lower-program
         lower-program/from-global-env
         (struct-out unsupported-llvm-node)
         current-llvm-tier)

;; The tier currently in scope. Lowering rules dispatch on this so a Tier 1
;; node attempted under (current-llvm-tier 0) raises a clear error pointing
;; the caller at the next tier.
(define current-llvm-tier (make-parameter 0))

;; A top-form triple as it lives in the global-env after process-file:
;;   (list 'def name type body)
;; Lowering operates on a list of these, with main as the entry point.
;;
;; unsupported-llvm-node is a real exn:fail so it interoperates with
;; rackunit's check-exn and Racket's standard error formatting.
(struct unsupported-llvm-node exn:fail (node tier hint) #:transparent)

;; Fail loud: raise with the struct kind, the tier we are in, and a hint.
(define (unsupported! node hint)
  (raise
   (unsupported-llvm-node
    (format "unsupported LLVM lowering node at tier ~a: ~a (node: ~v)"
            (current-llvm-tier) hint node)
    (current-continuation-marks)
    node
    (current-llvm-tier)
    hint)))

;; ============================================================
;; Public entry points
;; ============================================================

;; lower-program : (Listof TopForm) -> String
;; Lowers a list of (list 'def name type body) into a single .ll text.
;; Tier 0: the list MUST contain exactly one form, named 'main, whose body
;; lowers to a single i64 literal returned from @main.
(define (lower-program forms)
  (case (current-llvm-tier)
    [(0) (lower-program/tier0 forms)]
    [else
     (error 'lower-program
            "tier ~a not yet implemented (Tier 0 only at this commit)"
            (current-llvm-tier))]))

;; lower-program/from-global-env : -> String
;; Convenience: pulls main's type+body out of (current-prelude-env)
;; and lowers. Caller is expected to have just run process-file.
(define (lower-program/from-global-env)
  (define type (global-env-lookup-type 'main))
  (define body (global-env-lookup-value 'main))
  (unless type
    (error 'lower-program/from-global-env
           "no top-level definition named 'main' in global env"))
  (lower-program (list (list 'def 'main type body))))

;; ============================================================
;; Tier 0 — literal Int returned by main as exit code
;; ============================================================

(define (lower-program/tier0 forms)
  (match forms
    [(list (list 'def 'main type body))
     (lower-main/tier0 type body)]
    [_
     (error 'lower-program/tier0
            "Tier 0 expects a single 'main' top-form; got ~v" forms)]))

(define (lower-main/tier0 type body)
  ;; Type must be Int (Tier 0 closes the Bool case in Tier 1).
  (unless (expr-Int? type)
    (unsupported! type "Tier 0 only supports `def main : Int`"))
  (define n (lower-int-literal/tier0 body))
  (string-append
   "; ModuleID = 'prologos-tier0'\n"
   "target triple = \"" (default-target-triple) "\"\n"
   "\n"
   "define i64 @main() {\n"
   "entry:\n"
   "  ret i64 " (number->string n) "\n"
   "}\n"))

;; In Tier 0 the body must reduce to a single integer literal.
;; We accept (expr-int n) directly. Annotated forms (expr-ann) unwrap once.
(define (lower-int-literal/tier0 e)
  (match e
    [(expr-int n)
     (unless (exact-integer? n)
       (unsupported! e "expr-int with non-integer payload"))
     n]
    [(expr-ann inner _)
     (lower-int-literal/tier0 inner)]
    [_
     (unsupported! e
                   "Tier 0 body must be an Int literal (use Tier 1 for arithmetic)")]))

;; ============================================================
;; Helpers
;; ============================================================

;; Default target triple. Linux x86_64 covers our CI runner. Override via
;; PROLOGOS_LLVM_TRIPLE env var when cross-compiling.
(define (default-target-triple)
  (or (getenv "PROLOGOS_LLVM_TRIPLE")
      "x86_64-unknown-linux-gnu"))
