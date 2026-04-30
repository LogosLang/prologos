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
    [(0 1) (lower-program/main-only forms)]
    [else
     (error 'lower-program
            "tier ~a not yet implemented (Tier 0–1 at this commit)"
            (current-llvm-tier))]))

;; Guard: raise unsupported-llvm-node unless current tier is at least min-tier.
(define (require-tier! min-tier node feature-name)
  (when (< (current-llvm-tier) min-tier)
    (unsupported! node
                  (format "~a requires Tier ~a (current Tier ~a)"
                          feature-name min-tier (current-llvm-tier)))))

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
;; Tier 0–1 — single `def main : Int` lowered to @main
;; ============================================================

(define (lower-program/main-only forms)
  (match forms
    [(list (list 'def 'main type body))
     (lower-main type body)]
    [_
     (error 'lower-program/main-only
            "Tiers 0–1 expect a single 'main' top-form; got ~v" forms)]))

(define (lower-main type body)
  (unless (expr-Int? type)
    (unsupported! type "main must currently have type Int"))
  ;; Builder state for the entry basic block.
  (define instrs '())
  (define counter 0)
  (define (emit! s) (set! instrs (cons s instrs)))
  (define (fresh!)
    (set! counter (+ counter 1))
    (format "%t~a" counter))
  (define abs-needed? (box #f))
  (define final-val (lower-int-expr body emit! fresh! abs-needed?))
  (define decls
    (cond
      [(unbox abs-needed?)
       "declare i64 @llvm.abs.i64(i64, i1)\n\n"]
      [else ""]))
  (string-append
   (format "; ModuleID = 'prologos-tier~a'\n" (current-llvm-tier))
   "target triple = \"" (default-target-triple) "\"\n"
   "\n"
   decls
   "define i64 @main() {\n"
   "entry:\n"
   (apply string-append
          (map (lambda (s) (string-append s "\n"))
               (reverse instrs)))
   "  ret i64 " final-val "\n"
   "}\n"))

;; lower-int-expr : Expr × (String->Void) × (->String) × Box[Bool] -> String
;; Returns the LLVM value reference (literal or %tN) for the i64 result.
;; emit! appends an instruction line; fresh! returns a new SSA name.
;; abs-needed? is set when @llvm.abs.i64 is used so the declaration is added.
(define (lower-int-expr e emit! fresh! abs-needed?)
  (define (recur x) (lower-int-expr x emit! fresh! abs-needed?))
  (define (binop op a b)
    (define av (recur a))
    (define bv (recur b))
    (define t (fresh!))
    (emit! (format "  ~a = ~a i64 ~a, ~a" t op av bv))
    t)
  (match e
    ;; -- Tier 0 --
    [(expr-int n)
     (unless (exact-integer? n)
       (unsupported! e "expr-int with non-integer payload"))
     (number->string n)]
    [(expr-ann inner _)
     (recur inner)]

    ;; -- Tier 1: Int arithmetic --
    [(expr-int-add a b)
     (require-tier! 1 e "expr-int-add")
     (binop "add" a b)]
    [(expr-int-sub a b)
     (require-tier! 1 e "expr-int-sub")
     (binop "sub" a b)]
    [(expr-int-mul a b)
     (require-tier! 1 e "expr-int-mul")
     (binop "mul" a b)]
    [(expr-int-div a b)
     ;; LLVM sdiv: signed integer division (truncating toward zero).
     ;; Division by zero is LLVM-undefined; matches Tier 1 unsafety budget.
     (require-tier! 1 e "expr-int-div")
     (binop "sdiv" a b)]
    [(expr-int-mod a b)
     ;; LLVM srem: signed remainder. Sign matches dividend.
     (require-tier! 1 e "expr-int-mod")
     (binop "srem" a b)]
    [(expr-int-neg a)
     (require-tier! 1 e "expr-int-neg")
     (define av (recur a))
     (define t (fresh!))
     (emit! (format "  ~a = sub i64 0, ~a" t av))
     t]
    [(expr-int-abs a)
     (require-tier! 1 e "expr-int-abs")
     (set-box! abs-needed? #t)
     (define av (recur a))
     (define t (fresh!))
     ;; @llvm.abs.i64 with poison-on-INT_MIN = false: returns INT_MIN as-is.
     (emit! (format "  ~a = call i64 @llvm.abs.i64(i64 ~a, i1 false)" t av))
     t]

    [_
     (unsupported! e
                   (format "no Tier ~a lowering for this node"
                           (current-llvm-tier)))]))

;; ============================================================
;; Helpers
;; ============================================================

;; Default target triple. Linux x86_64 covers our CI runner. Override via
;; PROLOGOS_LLVM_TRIPLE env var when cross-compiling.
(define (default-target-triple)
  (or (getenv "PROLOGOS_LLVM_TRIPLE")
      "x86_64-unknown-linux-gnu"))
