#lang racket/base

(require racket/set)

;;;
;;; PPN Track 0: Parse Domain Lattice Definitions
;;;
;;; Defines lattice structs, merge functions, and bot/top values for the
;;; propagator-based parsing infrastructure. Each lattice is designed to
;;; be registered with the propagator network as an sre-domain-compatible
;;; lattice spec.
;;;
;;; Lattice domains:
;;; - Token: set-once (bot → value, ATMS for rare ambiguity)
;;; - Surface: derivation set (per-item cells, set-union merge)
;;; - Demand: demand set (set-union merge, Right Kan exchange mechanism)
;;; - Core: trivial (bot → value, ATMS-tagged)
;;;
;;; See: docs/tracking/2026-03-26_PPN_TRACK0_LATTICE_DESIGN.md
;;;

(provide
 ;; Token lattice
 (struct-out token-cell-value)
 token-bot token-top token-bot?
 token-lattice-merge
 token-contradicts?

 ;; Surface (parse) lattice
 (struct-out parse-item)
 (struct-out derivation-node)
 (struct-out parse-cell-value)
 parse-bot parse-top parse-bot?
 parse-lattice-merge
 parse-contradicts?

 ;; Demand lattice
 (struct-out demand)
 (struct-out demand-cell-value)
 demand-bot demand-bot?
 demand-lattice-merge

 ;; Core lattice
 core-bot core-top core-bot?
 core-lattice-merge
 core-contradicts?

 ;; Helpers
 make-token
 make-parse-item
 make-derivation-node
 make-demand)


;; ============================================================
;; Phase 1: Token Lattice (set-once)
;; ============================================================
;;
;; NTT: :lattice :set-once
;; Tokens are written once by the lexer. No join exists between
;; two different ground token values. ATMS branches handle the
;; rare ambiguous case (identifier vs keyword).
;;
;; Bot = unclassified position. Top = lexer error.

(struct token-cell-value
  (type          ;; symbol: 'identifier, 'keyword, 'number, 'string,
                 ;;         'operator, 'delimiter, 'whitespace, 'indent,
                 ;;         'dedent, 'newline, 'string-start, 'string-end,
                 ;;         'reader-macro, 'eof
   lexeme        ;; string: the actual character sequence
   span-start    ;; exact-nonneg-integer: start position in source
   span-end      ;; exact-nonneg-integer: end position in source
   indent-level  ;; exact-nonneg-integer: column of first non-whitespace
   indent-delta  ;; symbol: 'indent | 'dedent | 'same | #f
   )
  #:transparent)

;; Sentinels
(define token-bot 'token-bot)
(define token-top 'token-error)

(define (token-bot? v) (eq? v token-bot))

;; Set-once merge: bot → value (ok). Value → same value (idempotent).
;; Value → different value = contradiction (top).
(define (token-lattice-merge a b)
  (cond
    [(eq? a token-bot) b]
    [(eq? b token-bot) a]
    [(eq? a token-top) token-top]
    [(eq? b token-top) token-top]
    ;; Both are token-cell-value: check equality
    [(and (token-cell-value? a) (token-cell-value? b))
     (if (and (eq? (token-cell-value-type a) (token-cell-value-type b))
              (equal? (token-cell-value-lexeme a) (token-cell-value-lexeme b))
              (= (token-cell-value-span-start a) (token-cell-value-span-start b)))
         a  ;; same token — idempotent
         token-top)]  ;; different tokens at same position — contradiction
    [else token-top]))

(define (token-contradicts? v)
  (eq? v token-top))

;; Constructor helper
(define (make-token type lexeme start end indent-level [indent-delta #f])
  (token-cell-value type lexeme start end indent-level indent-delta))


;; ============================================================
;; Phase 2: Surface (Parse) Lattice — derivation-only (lfp)
;; ============================================================
;;
;; NTT: :lattice :value with set-union merge
;; Per-item cells (one per Earley item). Merge = derivation set union.
;; Elimination ordering deferred to Track 5 (WF-LE newtype pattern).
;; ATMS handles elimination in the interim via assumption retraction.
;;
;; Provenance is structural: derivation-node.children IS the trace.
;; The SPPF structure carries provenance for free (traced monoidal).

;; An Earley item: production + dot position + origin
(struct parse-item
  (production   ;; symbol: grammar production name
   dot          ;; exact-nonneg-integer: position of dot in RHS
   origin       ;; exact-nonneg-integer: start position of this item
   span-end     ;; exact-nonneg-integer: current end position
   )
  #:transparent)

;; A derivation tree node (SPPF-like, carries provenance via children)
(struct derivation-node
  (item           ;; parse-item: which item this derives
   children       ;; list of derivation-node: sub-derivations (= trace)
   assumption-id  ;; any | #f: ATMS tag for this derivation
   cost           ;; real: tropical enrichment (default 0, used by Track 6)
   )
  #:transparent)

;; A parse cell value: set of derivation alternatives
(struct parse-cell-value
  (derivations)   ;; seteq of derivation-node
  #:transparent)

;; Sentinels
(define parse-bot (parse-cell-value (seteq)))
(define parse-top 'parse-error)

(define (parse-bot? v)
  (and (parse-cell-value? v)
       (set-empty? (parse-cell-value-derivations v))))

;; Merge = set union of derivation sets (monotone: only adds alternatives)
(define (parse-lattice-merge a b)
  (cond
    [(eq? a parse-top) parse-top]
    [(eq? b parse-top) parse-top]
    [(and (parse-cell-value? a) (parse-cell-value? b))
     (define merged (set-union (parse-cell-value-derivations a)
                               (parse-cell-value-derivations b)))
     ;; Identity preservation: if no new derivations added, return original
     (cond
       [(= (set-count merged) (set-count (parse-cell-value-derivations a))) a]
       [(= (set-count merged) (set-count (parse-cell-value-derivations b))) b]
       [else (parse-cell-value merged)])]
    ;; One is bot (empty parse-cell-value)
    [(parse-cell-value? a) a]
    [(parse-cell-value? b) b]
    [else parse-top]))

(define (parse-contradicts? v)
  (eq? v parse-top))

;; Constructor helpers
(define (make-parse-item production dot origin span-end)
  (parse-item production dot origin span-end))

(define (make-derivation-node item children [assumption-id #f] [cost 0])
  (derivation-node item children assumption-id cost))


;; ============================================================
;; Phase 3: Demand Lattice
;; ============================================================
;;
;; NTT: :lattice :value with set-union merge
;; Demands are the internal state of Right Kan inter-strata exchanges.
;; Populated by higher strata requesting information from lower strata.
;; Monotone: demands only accumulate, never retract.
;;
;; Position is domain-specific (char offset, span, cell-id, DT path).
;; Specificity is an open symbol (each domain defines its own levels).
;; Priority connects to tropical cost (0 = highest priority).

(struct demand
  (target-domain  ;; symbol: 'token, 'surface, 'type, 'narrowing (extensible)
   position       ;; any: domain-specific position identifier
   specificity    ;; symbol: domain-specific (open, not enum)
   source-stratum ;; symbol: which stratum generated this demand
   priority       ;; exact-nonneg-integer: 0 = highest (tropical connection)
   )
  #:transparent)

(struct demand-cell-value
  (demands)       ;; seteq of demand
  #:transparent)

;; Sentinels
(define demand-bot (demand-cell-value (seteq)))

(define (demand-bot? v)
  (and (demand-cell-value? v)
       (set-empty? (demand-cell-value-demands v))))

;; Merge = set union (monotone: demands only accumulate)
(define (demand-lattice-merge a b)
  (cond
    [(and (demand-cell-value? a) (demand-cell-value? b))
     (define merged (set-union (demand-cell-value-demands a)
                               (demand-cell-value-demands b)))
     ;; Identity preservation
     (cond
       [(= (set-count merged) (set-count (demand-cell-value-demands a))) a]
       [(= (set-count merged) (set-count (demand-cell-value-demands b))) b]
       [else (demand-cell-value merged)])]
    [(demand-cell-value? a) a]
    [(demand-cell-value? b) b]
    [else (demand-cell-value (seteq))]))

;; Constructor helper
(define (make-demand target-domain position specificity source-stratum [priority 0])
  (demand target-domain position specificity source-stratum priority))


;; ============================================================
;; Core Lattice (trivial)
;; ============================================================
;;
;; Core cells hold elaborated AST nodes. Deterministic given
;; (surface, type). Ambiguity handled by ATMS tagging on surface
;; and type lattices. The core lattice is just: bot → value.

(define core-bot 'core-bot)
(define core-top 'core-error)

(define (core-bot? v) (eq? v core-bot))

;; Core merge: set-once (same as token, but for AST nodes)
(define (core-lattice-merge a b)
  (cond
    [(eq? a core-bot) b]
    [(eq? b core-bot) a]
    [(eq? a core-top) core-top]
    [(eq? b core-top) core-top]
    [(equal? a b) a]  ;; idempotent
    [else core-top])) ;; different values = contradiction

(define (core-contradicts? v)
  (eq? v core-top))
