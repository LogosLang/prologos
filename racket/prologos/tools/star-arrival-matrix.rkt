#lang racket/base
;; ============================================================================
;; THE STAR ARRIVAL MATRIX  —  CIU T6 D4.P4e-1a slice 1a-i
;; ============================================================================
;;
;; ⭐ WHY THIS FILE EXISTS. D4 §5.P4e-1 claimed the `postfix-star` mint reaches a
;; datum in "40 of 44 carrier x context spellings, across ELEVEN contexts", and
;; that claim was GENERATED — but the generator was never committed (`1476734b`
;; touched the design doc and the battery, nothing else). So at HEAD the number
;; was UNFALSIFIABLE: it could not be re-derived, extended, or audited from the
;; tree. The P4e-1a mini-audit regenerated it and found D4's frame reproduces
;; EXACTLY *as a 21% sub-frame* — the real surface is 10 carriers x 19 contexts,
;; because six carriers were never counted and nine contexts were never listed.
;;
;; **The last three blocking defects in this arc were all BAD ENUMERATIONS.**
;; This module is the fix in kind: the enumeration lives HERE, once, and both
;; consumers read it rather than copying it —
;;   · `tests/test-path-selection.rkt`  (the leak GATE, one row per cell)
;;   · this file's `main`               (the human-auditable dump)
;; Adding a carrier or a context is a ONE-LINE edit here and BOTH follow.
;; Do not inline either list anywhere else; that is the defect this replaces.
;;
;; Run the dump (from `racket/prologos/`, NOT the repo root — a `tools/` exists
;; at both levels and only this one resolves):
;;   racket tools/star-arrival-matrix.rkt
;; ============================================================================

(require racket/list racket/string racket/format racket/set
         "../parse-reader.rkt"
         (only-in "../rrb.rkt" rrb-to-list))

(provide star-carriers star-contexts star-prelude
         star-cell-source star-minting-carrier? star-arrival-context?
         star-last-token-type star-mints?)

;; ---------------------------------------------------------------------------
;; THE CARRIERS — every shape in which a `*` can sit byte-adjacent to a CLOSER.
;;
;; A carrier mints iff its closing token's type is in `group-closer-types`
;; ('(rbracket rparen rbrace)) — that is the whole rule, and it is why the six
;; carriers D4 omitted are not speculative: `]` `}` `)` are all members.
;; The trailing `!` names a control that must NOT mint.
;; ---------------------------------------------------------------------------
(define star-carriers
  '(("bracket-app"   "[f 1]*"     #t)   ;; ] closer
    ("paren-app"     "(f 1)*"     #t)   ;; ) closer
    ("select-brace"  "c{a}*"      #t)   ;; } closer — a USABLE carrier (Q_U35)
    ("bcast-brace"   "xs:{a}*"    #t)   ;; } closer — a USABLE carrier (Q_U35)
    ("quote-list"    "'[1 2]*"    #t)   ;; ⚠ uncounted by D4 §5.P4e-1
    ("pvec"          "@[1 2]*"    #t)   ;; ⚠ uncounted
    ("hset"          "#{1 2}*"    #t)   ;; ⚠ uncounted
    ("map-lit"       "{:a 1}*"    #t)   ;; ⚠ uncounted
    ("quasiquote"    "`[a 1]*"    #t)   ;; ⚠ uncounted
    ("mixfix-close"  ".(1 + 2)*"  #t)   ;; ⚠ uncounted — star AFTER the mixfix
    ("postfix-index" "xs[0]*"    #t)   ;; ⚠ the ONE arrival where the star shares a
                                       ;; datum list with a FOLDING sentinel
                                       ;; (`$postfix-index`) — the highest-value
                                       ;; cell for the 1a-iii fuse, and it was
                                       ;; missing from every prior enumeration
    ;; ---- controls: NOT minting. Three distinct mechanisms, one each. ----
    ("ord-bcast!"    "xs:0*"      #f)   ;; shatters — no carrier token (DEFERRED 105)
    ("ord-dot!"      "x.0*"       #f)   ;; shatters — no carrier token (DEFERRED 105)
    ("in-block!"     "m{0*}"      #f)   ;; star is an ITEM inside the block
    ("path-literal!" "#p(a)*"     #f)   ;; `#p(a)` is ONE token; no rparen precedes
    ("fuse-band!"    "c.a*"       #f))) ;; ⚠ THE THIRD MECHANISM: no `*` TOKEN EXISTS
                                        ;; at all — it fuses into the identifier
                                        ;; band. The other controls have a `*` token
                                        ;; that fails the closer test; this one has
                                        ;; none, so it exercises a different arm.

;; ---------------------------------------------------------------------------
;; THE CONTEXTS — `~a` is the carrier hole.
;;
;; The first ten are D4 §5.P4e-1's own list; the nine after it were measured by
;; the P4e-1a mini-audit and were absent from every prior enumeration. `mixfix!`
;; is the control: Q_U34's gate means NOTHING mints there.
;;
;; ⚠ `let` appears THREE times on purpose. The seat is spelling-sensitive
;; (DEFERRED 106): the ALIGNED form folds, the NESTED-SHORTHAND form leaks a raw
;; sentinel at HEAD, and the BRACKET form fails differently. One row would miss it.
;; ---------------------------------------------------------------------------
;; `%N%` = a per-cell disambiguating index, `%C%` = the carrier fragment. Either
;; may appear any number of times. (This replaced a "one ~a means carrier, two
;; means index-then-carrier" heuristic, which could not express the
;; declare-AND-use shapes below and would have silently mis-formatted a template
;; wanting the carrier twice.)
(define star-contexts
  '(;; ---- D4 §5.P4e-1's ten ----
    ("command"         "%C%")
    ("def-rhs"         "def q%N% := %C%")
    ("app-arg"         "def q%N% := f %C%")
    ("bracket-app"     "def q%N% := [f %C%]")
    ("nested-bracket"  "def q%N% := [f [f %C%]]")
    ("map-value"       "def q%N% := {:k %C%}")
    ("vector-lit"      "def q%N% := @[%C%]")
    ("list-lit"        "def q%N% := '[%C%]")
    ("select-item"     "def q%N% := c{%C%}")
    ("defn-body"       "defn h%N% [z] %C%")
    ;; ---- the nine the inventory never listed ----
    ("pattern-pos"     "defn h%N%\n  | %C% -> 1\n  | z -> 2")
    ;; ⚠ DECLARE **AND DEFINE**. A bare `spec` emits NO OUTPUT LINE even when it
    ;; succeeds, so a batch of bare specs yields only the prelude's lines and an
    ;; output-grep gate is BLIND across the whole context — measured: 5 outputs
    ;; for 14 forms. The `defn` gives the context an observable channel.
    ("spec-type"       "spec s%N% %C% -> Int\ndefn s%N% [z] 1")
    ("set-lit"         "def q%N% := #{%C%}")
    ("let-nested"      "defn h%N% [z]\n  let k %C%\n    k")
    ("let-aligned"     "defn h%N% [z]\n  let k %C%\n      j 1\n    k")
    ("let-bracket"     "defn h%N% [z]\n  let [k %C%] k")
    ("match-scrut"     "defn h%N% [z]\n  match %C%\n    | w -> 1")
    ("quasiquote-body" "def q%N% := `[%C%]")
    ;; ⚠ DEFINE **AND INVOKE**, and the carrier is WRAPPED — `[f %C%]`, not bare.
    ;; `defmacro` alone emits no line, so the template is never expanded. But the
    ;; first cut also got the template SHAPE wrong: a bare `[f 1]*` is **TWO**
    ;; datums, `defmacro` requires exactly one, so every cell was rejected at
    ;; preparse with "defmacro requires: (defmacro name ($params...) template)"
    ;; and `datum-subst` NEVER RAN — while the context still produced 33 output
    ;; lines and therefore looked healthy. Caught by the slice's adversarial
    ;; verify. This is the Tier-O path `pipeline.md` names as the live abort
    ;; generator, so an inert row here is the most expensive kind.
    ("defmacro-tmpl"   "defmacro mm%N% [] [f %C%]\ndef v%N% := [mm%N%]")
    ;; ---- the control ----
    ("mixfix!"         "def q%N% := .(1 + %C%)")))

;; Definitions every cell's source needs to be well-formed.
(define star-prelude
  "defn f [z] z\ndef c := {:a 1}\ndef xs := @[{:a 1}]\ndef x := @[7]\ndef m := {:a 1}\n")

(define (star-minting-carrier? c) (caddr c))
(define (star-arrival-context? k) (not (regexp-match? #rx"!$" (car k))))

;; One cell's source fragment. `n` disambiguates binder names so many cells can
;; be BATCHED into one file (the gate does this: the per-call cost is env setup,
;; not per-form work, so 190 cells in 20 files instead of 190 process calls).
;;
;; ⚠ TAKES THE CARRIER **RECORD**, not its string — deliberately. The first cut
;; took the string and every caller passed the whole record; `format`'s `~a`
;; stringified it without complaint, so each cell's source was really
;; `def q0 := (bracket-app [f 1]* #t)`. That still contains the carrier text, so
;; the star still sat against `]`, so the mint tally still came out 190 and the
;; mutation tests still went red — **the instrument was malformed and every
;; check agreed with it.** Taking the record makes the mistake unrepresentable.
(define (star-cell-source ctx carrier n)
  (string-replace (string-replace (cadr ctx) "%N%" (number->string n))
                  "%C%" (cadr carrier)))

;; ---------------------------------------------------------------------------
;; MEASUREMENT — the token type of the LAST `*`.
;; ⚠ LAST, not first: `def q := .(1 * 2)` style sources carry an arithmetic `*`
;; BEFORE the one under test, and a first-match helper reports `symbol` so the
;; row fails for a reason unrelated to its name. That result-narrowing hazard
;; has already cost this track a false RED once.
;; ---------------------------------------------------------------------------
(define (star-last-token-type src)
  (register-default-token-patterns!)
  (define tok (tokenize-char-rrb (make-char-rrb-from-string src)))
  (define bd (make-bracket-depth-rrb tok src))
  (define-values (narrowed _changed?) (disambiguate-tokens tok bd))
  (let loop ([ts (rrb-to-list narrowed)] [found #f])
    (cond [(null? ts) found]
          [(string=? (token-entry-lexeme (car ts)) "*")
           (loop (cdr ts) (set-first (token-entry-types (car ts))))]
          [else (loop (cdr ts) found)])))

(define (star-mints? src) (eq? (star-last-token-type src) 'postfix-star))

;; ---------------------------------------------------------------------------
(module+ main
  (define n-carriers (length (filter star-minting-carrier? star-carriers)))
  (define n-contexts (length (filter star-arrival-context? star-contexts)))
  (printf "~a\nSTAR ARRIVAL MATRIX  —  ~a carriers x ~a contexts (+ controls)\n~a\n"
          (make-string 78 #\=) (length star-carriers) (length star-contexts)
          (make-string 78 #\=))
  (define total-mint
    (for/sum ([c (in-list star-carriers)])
      (define per
        (for/sum ([k (in-list star-contexts)])
          (if (star-mints? (string-append star-prelude (star-cell-source k c 0))) 1 0)))
      (printf "  ~a ~a  mints in ~a of ~a contexts~a\n"
              (if (star-minting-carrier? c) "MINT" "ctrl")
              (~a (car c) #:min-width 14) (~a per #:min-width 2) (length star-contexts)
              (if (star-minting-carrier? c) "" "   <- must be 0"))
      per))
  (printf "~a\nTOTAL MINTING CELLS: ~a   (expected ~a x ~a = ~a)\n"
          (make-string 78 #\-) total-mint n-carriers n-contexts (* n-carriers n-contexts))
  ;; D4 §5.P4e-1's frame: 4 carriers x 11 contexts = 44 cells, of which 40 ARRIVE.
  ;; Compare arrivals to arrivals — 40 against this file's minting total.
  (printf "D4 §5.P4e-1 counted 40 arrivals (4 x 11 frame) — ~a% of the ~a measured here.\n"
          (inexact->exact (round (* 100 (/ 40.0 total-mint)))) total-mint))
