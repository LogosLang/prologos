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
;; EXACTLY *as a sub-frame* — the real surface is 11 minting carriers x 19 contexts
;; (the verify added `xs[0]*` to the audit's ten),
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
  '(("bracket-app"   "[f 1]%S%"     mint)   ;; ] closer
    ("paren-app"     "(f 1)%S%"     mint)   ;; ) closer
    ("select-brace"  "c{a}%S%"      mint)   ;; } closer — a USABLE carrier (Q_U35)
    ("bcast-brace"   "xs:{a}%S%"    mint)   ;; } closer — a USABLE carrier (Q_U35)
    ("quote-list"    "'[1 2]%S%"    mint)   ;; ⚠ uncounted by D4 §5.P4e-1
    ("pvec"          "@[1 2]%S%"    mint)   ;; ⚠ uncounted
    ("hset"          "#{1 2}%S%"    mint)   ;; ⚠ uncounted
    ("map-lit"       "{:a 1}%S%"    mint)   ;; ⚠ uncounted
    ("quasiquote"    "`[a 1]%S%"    mint)   ;; ⚠ uncounted
    ("mixfix-close"  ".(1 + 2)%S%"  mint)   ;; ⚠ uncounted — star AFTER the mixfix
    ("postfix-index" "xs[0]%S%"    mint)   ;; ⚠ the ONE arrival where the star shares a
                                       ;; datum list with a FOLDING sentinel
                                       ;; (`$postfix-index`) — missing from every
                                       ;; prior enumeration.
                                       ;; ⚠ It takes Q_U35's REFUSAL, not the fuse
                                       ;; — an earlier draft here called it "the
                                       ;; highest-value cell for the fuse", which
                                       ;; contradicted the shipped positive list.
                                       ;; `xs[0]` folds to `get`, and bracket-
                                       ;; postfix KEEPS its current semantics
                                       ;; outside the selection carrier (D4 §2.4,
                                       ;; owner: revisit at X.close) — so its
                                       ;; predecessor is NOT selection-shaped.
                                       ;; Monotone: the refusal can become a
                                       ;; meaning if §2.4's revisit puts brackets
                                       ;; on the carrier.
    ;; ---- controls: NOT minting. Three distinct mechanisms, one each. ----
    ("ord-bcast!"    "xs:0%S%"      symbol)   ;; shatters — no carrier token (DEFERRED 105)
    ("ord-dot!"      "x.0%S%"       symbol)   ;; shatters — no carrier token (DEFERRED 105)
    ("in-block!"     "m{0%S%}"     symbol)   ;; star is an ITEM inside the block
    ("path-literal!" "#p(a)%S%"     symbol)   ;; `#p(a)` is ONE token; no rparen precedes
    ("fuse-band!"    "c.a%S%"       none))) ;; ⚠ THE THIRD MECHANISM: no `*` TOKEN EXISTS
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

(define (star-carrier-expect c) (caddr c))
(define (star-minting-carrier? c) (eq? (star-carrier-expect c) 'mint))

;; ⭐ DEFERRED 127 — THE SPELLING DIMENSION. Every carrier source above used to
;; hardcode a bare `*`, so this matrix measured ONE spelling while claiming to
;; measure the mint. After a reader widening it would have reported full coverage
;; of a question it had stopped asking. The sources now carry `%S%`; the matrix
;; runs once per spelling and reports each.
(define star-spellings '("*" "*_" "*-" "*-_"))
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
(define (star-cell-source ctx carrier n [spelling "*"])
  (string-replace (string-replace (string-replace (cadr ctx) "%N%" (number->string n))
                                  "%C%" (cadr carrier))
                  "%S%" spelling))

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
  ;; ⚠⚠ DEFERRED 127 — THIS GATE USED TO BE `(string=? lexeme "*")`, the SAME
  ;; exact-lexeme shape as the mint it exists to verify, so a source whose only
  ;; star token was `*_` left `found` at #f and the matrix reported "does not
  ;; mint". It could not tell "correctly does not mint" from "I cannot see this
  ;; token" — and the CONTROLS passed for the second reason while claiming the
  ;; first. `'none` now names that case explicitly so blindness cannot read as
  ;; success.
  (let loop ([ts (rrb-to-list narrowed)] [found 'none])
    (cond [(null? ts) found]
          [(member (token-entry-lexeme (car ts)) star-spellings)
           (loop (cdr ts) (set-first (token-entry-types (car ts))))]
          [else (loop (cdr ts) found)])))

(define (star-mints? src) (eq? (star-last-token-type src) 'postfix-star))

;; ---------------------------------------------------------------------------
(module+ main
  (define n-carriers (length (filter star-minting-carrier? star-carriers)))
  (define n-contexts (length (filter star-arrival-context? star-contexts)))
  (printf "~a\nSTAR ARRIVAL MATRIX  —  ~a carriers x ~a contexts (+ controls)\n"
          (make-string 78 #\=) (length star-carriers) (length star-contexts))
  (printf "spellings: ~a\n~a\n" star-spellings (make-string 78 #\=))

  ;; ⭐ DEFERRED 127 — ONE PASS PER SPELLING. The old driver ran the bare `*`
  ;; only, so a widened reader would have been measured at full coverage for a
  ;; question it had stopped asking. Each spelling now reports its own totals,
  ;; and the CONTROLS are checked against a DECLARED expectation rather than
  ;; "must be 0" — a control that is silently invisible to the gate no longer
  ;; passes for the same reason a correct one does.
  (define (run-spelling sp)
    (printf "\n---- spelling `~a` ~a\n" sp (make-string (max 0 (- 60 (string-length sp))) #\-))
    (define total-mint
      (for/sum ([c (in-list star-carriers)])
        (define expect (star-carrier-expect c))
        (define outcomes
          (for/list ([k (in-list star-contexts)])
            (star-last-token-type (string-append star-prelude (star-cell-source k c 0 sp)))))
        (define per (for/sum ([o (in-list outcomes)]) (if (eq? o 'postfix-star) 1 0)))
        (define off (for/list ([o (in-list outcomes)] #:unless (eq? o expect)) o))
        (printf "  ~a ~a  mints in ~a of ~a~a\n"
                (if (eq? expect 'mint) "MINT" "ctrl")
                (~a (car c) #:min-width 14) (~a per #:min-width 2) (length star-contexts)
                (cond
                  [(eq? expect 'mint) ""]
                  [(null? off) (format "   <- ok, all ~a as declared" expect)]
                  [else (format "   <- ⚠ EXPECTED ~a, saw ~a" expect
                                (remove-duplicates off))]))
        per))
    (printf "  TOTAL MINTING CELLS: ~a   (expected ~a x ~a = ~a)~a\n"
            total-mint n-carriers n-contexts (* n-carriers n-contexts)
            (if (= total-mint (* n-carriers n-contexts)) "" "   <- ⚠ not full"))
    total-mint)

  (define bare (run-spelling "*"))
  (for ([sp (in-list (cdr star-spellings))]) (run-spelling sp))
  (printf "~a\n" (make-string 78 #\-))
  ;; D4 §5.P4e-1's frame: 4 carriers x 11 contexts = 44 cells, of which 40 ARRIVE.
  (printf "D4 §5.P4e-1 counted 40 arrivals (4 x 11 frame) — ~a% of the ~a measured here for `*`.\n"
          (inexact->exact (round (* 100 (/ 40.0 bare)))) bare)
  ;; ⚠ A non-bare spelling reporting 0 is the PRE-MINT state, not a defect —
  ;; slice 1b-v-A records it RED on purpose. It becomes the regression signal the
  ;; moment the reader widens.
  (printf "⚠ a non-`*` spelling at 0 is the PRE-MINT state (slice 1b-v); non-zero after the mint.\n"))
