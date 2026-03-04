#lang racket/base

;;;
;;; PROLOGOS ERRORS
;;; Structured error types for type checking, parsing, and elaboration.
;;; Each error carries a source location and enough context for readable messages.
;;;

(require racket/list
         racket/match
         racket/string
         "source-location.rkt")

(provide
 ;; Error structs
 (struct-out prologos-error)
 (struct-out type-mismatch-error)
 (struct-out unbound-variable-error)
 (struct-out multiplicity-error)
 (struct-out not-a-type-error)
 (struct-out not-a-function-error)
 (struct-out parse-error)
 (struct-out session-error)
 (struct-out inference-failed-error)
 (struct-out arity-error)
 (struct-out multi-arity-error)
 ;; Sprint 9: Structured inference errors
 (struct-out cannot-infer-param-error)
 (struct-out conflicting-constraints-error)
 (struct-out unsolved-implicit-error)
 (struct-out no-instance-error)
 (struct-out ambiguous-method-error)
 ;; Phase 6: Union type exhaustion
 (struct-out union-exhaustion-error)
 ;; Predicates
 prologos-error?
 ;; Formatting
 format-error)

;; ========================================
;; Error Hierarchy
;; ========================================

;; Base error: source location + message
(struct prologos-error (srcloc message) #:transparent)

;; Type mismatch: expected one type, got another
;; E3c: provenance — list of strings tracing the derivation chain (empty = no provenance)
(struct type-mismatch-error prologos-error (expected actual expr provenance) #:transparent)

;; Unbound variable reference
(struct unbound-variable-error prologos-error (name) #:transparent)

;; Multiplicity violation (QTT)
(struct multiplicity-error prologos-error (variable declared actual) #:transparent)

;; Expression used as a type but is not a valid type
(struct not-a-type-error prologos-error (expr) #:transparent)

;; Expected a function type in application position
(struct not-a-function-error prologos-error (expr type) #:transparent)

;; Parser error: malformed syntax
(struct parse-error prologos-error (datum) #:transparent)

;; Session type error
(struct session-error prologos-error (channel detail) #:transparent)

;; Type inference failed (could not synthesize a type)
(struct inference-failed-error prologos-error (expr) #:transparent)

;; Wrong number of arguments (with optional type for doc-like messages)
(struct arity-error prologos-error (form expected got func-type) #:transparent)

;; No matching clause in a multi-body defn (arity mismatch)
(struct multi-arity-error prologos-error (func-name user-args valid-arities) #:transparent)

;; Sprint 9: Cannot infer type of parameter (E1001)
(struct cannot-infer-param-error prologos-error (param-name hint) #:transparent)

;; Sprint 9: Conflicting type constraints (E1002)
(struct conflicting-constraints-error prologos-error
  (constraint-lhs constraint-rhs lhs-loc rhs-loc) #:transparent)

;; Sprint 9: Unsolved implicit argument (E1003)
(struct unsolved-implicit-error prologos-error (func-name meta-id hint) #:transparent)

;; Phase C: No trait instance found for a constraint (E1004)
;; trait-name: symbol (e.g., 'Eq)
;; type-args-str: string representation of the type arguments (e.g., "Foo")
(struct no-instance-error prologos-error (trait-name type-args-str) #:transparent)

;; Phase D: Ambiguous trait method name
;; method-name: symbol — the ambiguous method name (e.g., 'eq?)
;; trait-names: (listof symbol) — all traits that define this method
(struct ambiguous-method-error prologos-error (method-name trait-names) #:transparent)

;; Phase 6: Union type exhaustion — all branches failed (E1006)
;; branches: (listof string) — pretty-printed branch types
;; branch-mismatches: (listof string) — per-branch actual type or "<could not infer>"
;; expr-str: string — pretty-printed expression
;; Phase D3: derivation-chain: (listof (listof string)) — per-branch list of
;;   sub-failure labels showing what nested speculation paths were tried.
;;   Empty list = no chain info (backward compatible).
(struct union-exhaustion-error prologos-error
  (branches branch-mismatches expr-str derivation-chain) #:transparent)

;; ========================================
;; Error Formatting
;; ========================================

(define (format-error err)
  (define loc-str (format-srcloc (prologos-error-srcloc err)))
  (define msg (prologos-error-message err))
  (match err
    [(type-mismatch-error _ _ expected actual expr provenance)
     (string-join
      (append
       (list (format "Error at ~a" loc-str)
             (format "  ~a" msg)
             (format "  Expected: ~a" (format-val expected))
             (format "  Got:      ~a" (format-val actual))
             (if expr (format "  In expression: ~a" (format-val expr)) ""))
       (for/list ([step (in-list (or provenance '()))])
         (if (string-prefix? step "[diagnosis]")
             (format "    ~a" step)
             (format "    because: ~a" step))))
      "\n")]
    [(unbound-variable-error _ _ name)
     (string-join
      (list (format "Error at ~a" loc-str)
            (format "  Unbound variable: ~a" name))
      "\n")]
    [(multiplicity-error _ _ variable declared actual)
     (string-join
      (list (format "Error at ~a" loc-str)
            (format "  ~a" msg)
            (format "  Variable: ~a" variable)
            (format "  Declared multiplicity: ~a" declared)
            (format "  Actual usage: ~a" actual))
      "\n")]
    [(not-a-type-error _ _ expr)
     (string-join
      (list (format "Error at ~a" loc-str)
            (format "  ~a" msg)
            (format "  Expression: ~a" (format-val expr)))
      "\n")]
    [(not-a-function-error _ _ expr type)
     (string-join
      (list (format "Error at ~a" loc-str)
            (format "  ~a" msg)
            (format "  Expression: ~a" (format-val expr))
            (format "  Has type: ~a" (format-val type)))
      "\n")]
    [(parse-error _ _ datum)
     (string-join
      (list (format "Error at ~a" loc-str)
            (format "  ~a" msg)
            (if datum (format "  Near: ~a" datum) ""))
      "\n")]
    [(session-error _ _ channel detail)
     (string-join
      (list (format "Error at ~a" loc-str)
            (format "  ~a" msg)
            (format "  Channel: ~a" channel)
            (if detail (format "  ~a" detail) ""))
      "\n")]
    [(inference-failed-error _ _ expr)
     (string-join
      (list (format "Error at ~a" loc-str)
            (format "  ~a" msg)
            (format "  Expression: ~a" (format-val expr)))
      "\n")]
    [(arity-error _ _ form expected got func-type)
     (string-join
      (filter (lambda (s) (not (string=? s "")))
       (list (format "Error at ~a" loc-str)
             (format "  ~a" msg)
             (format "  Function: ~a" form)
             (format "  Expected ~a argument~a, got ~a"
                     expected (if (= expected 1) "" "s") got)
             (if func-type (format "  Signature: ~a" (format-val func-type)) "")))
      "\n")]
    [(multi-arity-error _ _ func-name user-args valid-arities)
     (string-join
      (list (format "Error at ~a" loc-str)
            (format "  ~a" msg)
            (format "  Function '~a' has clauses for ~a: ~a"
                    func-name
                    (if (= (length valid-arities) 1) "arity" "arities")
                    (string-join (map number->string valid-arities) ", "))
            (format "  Called with ~a argument~a"
                    user-args (if (= user-args 1) "" "s")))
      "\n")]
    ;; Sprint 9: E1001 — Cannot infer type of parameter
    [(cannot-infer-param-error _ _ param-name hint)
     (string-join
      (filter (lambda (s) (not (string=? s "")))
       (list (format "error[E1001]: cannot infer type of parameter '~a'" param-name)
             (format "  --> ~a" loc-str)
             (if hint (format "  = help: ~a" hint) "")))
      "\n")]
    ;; Sprint 9: E1002 — Conflicting type constraints
    [(conflicting-constraints-error _ _ lhs rhs lhs-loc rhs-loc)
     (string-join
      (list (format "error[E1002]: conflicting type constraints")
            (format "  --> ~a" loc-str)
            (format "  ~a" msg)
            (format "  = expected: ~a" lhs)
            (format "  = got:      ~a" rhs))
      "\n")]
    ;; Sprint 9: E1003 — Unsolved implicit argument
    [(unsolved-implicit-error _ _ func-name meta-id hint)
     (string-join
      (filter (lambda (s) (not (string=? s "")))
       (list (format "error[E1003]: unsolved implicit argument")
             (format "  --> ~a" loc-str)
             (format "  = could not determine implicit argument~a"
                     (if func-name (format " for '~a'" func-name) ""))
             (if hint (format "  = help: ~a" hint) "")))
      "\n")]
    ;; Phase C: E1004 — No trait instance found
    [(no-instance-error _ _ trait-name type-args-str)
     (string-join
      (list (format "error[E1004]: no instance found for (~a ~a)"
                    trait-name type-args-str)
            (format "  --> ~a" loc-str)
            (format "  ~a" msg)
            (format "  = help: add an impl for (~a ~a) or pass the dictionary explicitly"
                    trait-name type-args-str))
      "\n")]
    ;; Phase D: E1005 — Ambiguous trait method name
    [(ambiguous-method-error _ _ method-name trait-names)
     (string-join
      (list (format "error[E1005]: ambiguous trait method '~a'" method-name)
            (format "  --> ~a" loc-str)
            (format "  ~a" msg)
            (format "  = method '~a' is defined by multiple traits in scope: ~a"
                    method-name
                    (string-join (map symbol->string trait-names) ", "))
            (format "  = help: use the qualified accessor name to disambiguate (e.g., ~a-~a)"
                    (car trait-names) method-name))
      "\n")]
    ;; Phase 6+D4: E1006 — Union type exhaustion with optional derivation chains
    [(union-exhaustion-error _ _ branches branch-mismatches expr-str derivation-chain)
     (string-join
      (append
       (list (format "error[E1006]: expression does not match any branch of union type")
             (format "  --> ~a" loc-str))
       ;; Per-branch lines with optional derivation chain sub-lines
       (let ([chains (if (and derivation-chain (pair? derivation-chain))
                         derivation-chain
                         (make-list (length branches) '()))])
         (apply append
           (for/list ([br (in-list branches)]
                      [mm (in-list branch-mismatches)]
                      [chain (in-list chains)])
             (cons (format "  tried ~a — type mismatch (got: ~a)" br mm)
                   (for/list ([step (in-list chain)])
                     (if (string-prefix? step "[diagnosis]")
                         (format "    ~a" step)
                         (format "    because: ~a" step)))))))
       (list (format "  in expression: ~a" expr-str)
             (format "  = help: expression must match at least one branch of ~a" msg)))
      "\n")]
    [_ ;; base prologos-error
     (string-join
      (list (format "Error at ~a" loc-str)
            (format "  ~a" msg))
      "\n")]))

;; Format a value for display in error messages.
;; Uses write~ style for now; pretty-print will override this later.
(define (format-val v)
  (cond
    [(string? v) v]
    [else (format "~a" v)]))
