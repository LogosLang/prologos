# CIU 6 — D4, §Q8

Part of [D4](2026-07-28_CIU_T6_PATH_SELECTION_D4.md), CIU 6's implementation design, split into its parts on 2026-11-06 (owner-approved). This file holds D4 as it stood at `3e76762d`, unchanged except link targets: D4 lines 4699–4975 are lines N-4692 here.

---

<a id="q8"></a>

## §Q8 — THE LEXICAL GRAMMAR  ✅ *owner-reviewed 2026-07-28; NORMATIVE*

> **Review outcome**: adopted as written, with **one amendment — Q_M8**
> (ordinals are multi-digit in both bands; the draft's `:N` recommendation was
> withdrawn as wrongly-premised). Q8 now governs P1b-ii, P1b-iii and P2.

Written FROM the P1b-i probe results, not from leans. Every row is
probe-verified at `fc65ca54` unless marked `[P1b-ii]` / `[P1b-iii]` (the rows
those slices will add). Priorities are quoted from the registrations; **see
the invariant note at the end — priority is NOT the safety property.**

<a id="q8-1"></a>

### Q8.1 — The `.` band: SIX duties, in matching order

`.` is on six duties, not the four §8 R3 records. Two were unlisted: the
single-char FALLBACK (what `.{`, `.N` and a bare `.` all hit today) and the
DECIMAL POINT inside a number token.

| # | Form | Token (priority) | Discriminator after `.` | Status |
|---|---|---|---|---|
| 1 | `x...` | `rest-param` (89) | a second `.` | live |
| 2 | `m.:k` | `dot-key` (88) | `:` | **RETIRED** at P1a — token still lexes, marker seat converts |
| 3 | `.( … )` | `dot-lparen` (87) | `(` | live (mixfix) |
| 4 | `xs.*f` | `broadcast-access` (87) | `*` | **RETIRED** at P1a — as above |
| 5 | `x.name` | `dot-access` (86) | `ident-start?` AND **not** `:`, `{`, `*`, digit | live |
| 6 | `x.{…}` | `dot-lbrace` (87) | `{` | **live** since P1b-ii `1a1091d4` (registered parse-reader.rkt:1192) |
| — | `3.14` | `decimal-literal` (75) | anchors at a **DIGIT**, never at `.` | live — no overlap with the band |
| — | `x . y` | single-char symbol fallback | — | the catch-all; `.N` also lands here until P2 |

⚠ **CORRECTED 2026-07-29 (P2 audit `wf_22020418-a5f`) — this section
CONTRADICTED ITSELF, in normative text.** The table above has had SIX rows
since P1b-ii, but the Totality prose below said "five" and the row-6 Token
column still described the PRE-P1b-ii state (`*(fallback)* → dot-lbrace …
today falls to the single-char .`). §5.P2 inherited the five. **This is the
THIRD consecutive under-count of this one enumeration** (four → five → six),
and it matters beyond tidiness: §Q8.5 invariant 1's safety argument is
literally "prefix-disjoint from *all band members*", which is sound only if
the enumeration is complete.

**Totality**: the **six** band members test *different* second characters
(`.` / `:` / `(` / `*` / `{` / ident-start), and `recognize-dot-access`
excludes `:`, `{`, `*` and digits **explicitly** (parse-reader.rkt:734-739 —
the digit exclusion is real but REDUNDANT under `ident-start?`, which admits
no digits, so "double-guarded" is accurate and one guard is decorative). A
`dot-lbrace` insertion was therefore disjoint from all five that preceded it,
and a `.N` insertion is disjoint from all six. `.-1` LEXES CLEANLY as
dot-access with field `-1` (`ident-start?` admits `-` — **and `+`, so the
class is SIGNED, not negative: `x.+1` lexes identically**), so the carried
"`.-1` = classifier rejection" ruling is about a **well-formed token**, not a
shatter — P2 owns it when `.N` arrives, as a CONSUMER decision.

**The OPPOSING family was also under-counted, by 5×.** This section named only
`decimal-literal` as the digit-anchored competitor. **SIX** digit-anchored
recognizers currently claim the digit run after a dot — `decimal-literal`
(:286), `number` (:268), `exp-literal` (:309), `float-literal` (:352),
`posit-literal` (:409), `rat-literal` — and all six lose that claim to a
dot-anchored recognizer. That is why the **trailing-guard** question (Q_R2) is
not cosmetic: it decides five shapes that each lex as ONE numeric token today
(`x.0N` `x.1e3` `x.1/2` `x.1f` `x.1p8`). Two further unruled items in BOTH
bands: **leading zeros** (`x.007` → 7 today via `string->number` on `#e007`;
`:007` is one token since P1b-iii) and the **Unicode-digit crash**
(`char-numeric?` is Unicode-wide while `string->number` is not, so `٣` raises a
raw `exact?: contract violation` — `(char<=? #\0 c #\9)` is strictly safer and
is a NARROWING, not a competing definition, so the F1b.7g rule permits it).

**`.N` is MULTI-DIGIT (ruled Q_M8).** P2's `.N` recognizer anchors at the
**dot** and takes `digit+` (not one digit). It is prefix-disjoint from
`decimal-literal` (which anchors at a **digit**, never at a dot) and from all
six band members.

⚠ **CORRECTED 2026-07-29 — "it fixes a SILENT WRONG ANSWER … both at 0 errors"
was a LAYER ERROR.** The readings below are real but **reader-layer only**. END
TO END every rational-class form is **LOUD**, because the stranded bare `|.|`
symbol is unbound. Re-probed at `c5153685` via `tools/run-file.rkt`:
`m.0` / `m.1.2` / `m.10.20` → `ERROR: Unbound variable`; `m.-1` → `ERROR: Could
not infer type`; **4 errors**, not 0. The defect is a live MIS-LEXING that
produces a MISLEADING error — not a silent wrong value.

**Consequence for the failing-test-first obligation** (this is why the
correction matters rather than being pedantry): the honest pin is **TWO-LAYER** —
(a) a reader/datum pin (`($decimal-literal 6/5)` today → `(get (get x 1) 2)`
after), and (b) an end-to-end pin framed *"was a misleading error, now computes
the right value"*. A pin written as *"was silently 6/5 at 0 errors"* **cannot
fail for the reason it claims**, which is this arc's hazard 4 (already the
source of one vacuous pin and two mis-premised fixtures). Four of the P2
audit's six facets caught this independently.

Probe-measured at `b389479b`, re-confirmed at `c5153685`, today:

| Source | Today | Why |
|---|---|---|
| `x.10` | `(x \|.\| 10)` | falls to the single-char `.` fallback |
| `x.1.2` | `(x \|.\| ($decimal-literal 6/5))` | **the RATIONAL bug** — `decimal-literal` anchors at the `1` |
| `x.10.20` | `(x \|.\| ($decimal-literal 51/5))` | same class, multi-digit |

A dot-anchored `digit+` recognizer kills the rational **structurally**: the
tokenizer consumes `.1` at the dot, then `.2`, so `decimal-literal` never gets to
anchor. Multi-digit is therefore not an extra — it is the same one-line `digit+`
that fixes `x.1.2`.

<a id="q8-2"></a>

### Q8.2 — The `{` band: TWO lexical rows, and a separate GROUPING table

⚠ **The `{` order is not a lexical order at all**, and Q8 must say so. Only
two `{` recognizers exist; every other bucket is a GROUPING decision made
from token POSITIONS.

| Lexical | Token (priority) |
|---|---|
| `#{…}` set | `hash-lbrace` (91) |
| `{…}` | `lbrace` (30) |

| Grouping (WS ONLY) | Rule | Status |
|---|---|---|
| spaced `f {…}` | never a select block | must not change (largest population is BINDERS) |
| adjacent reader-form head `racket{…}` | head-symbol precedence — checked FIRST | `[P1b-iii]`; keeps `$brace-params` (spaced form is back-compat-pinned) |
| adjacent `x{…}` | select block | `[P1b-iii]` — **forced NEW sentinel** (Q_M6) |
| `.{…}` | descend-then-select | `[P1b-ii]`, plain `'rbrace` closer (Q_M5) |
| closing-delimiter-adjacent `f[x]{a}` | **undecided** — zero live sites | `[P1b-iii]` must RULE, not discover |

The sexp readtable binds `{` as a terminating macro with no positional
context, so this table is **structurally WS-only** — the Q_L2 divergence,
stated rather than discovered.

<a id="q8-3"></a>

### Q8.3 — The `:` seam: position AND adjacency

`:0`/`:1`/`:w`/`:m` are **not spare glyphs** — they are the QTT multiplicity
vocabulary (`colon-annotation`, priority 97), consumed at 18 sites. `users:0`
and `[fn [x :0 Int] x]` are **the same lexeme**.

| Form | Reading | Rule |
|---|---|---|
| `?x:Nat` (contiguous) | narrowing typed logic var | `narrow-var-annot` (96) — ONE token; **chains** `?x:A:B` included |
| `?m :name` (spaced) | logic var + keyword ARGUMENT | untouched — contiguity is the discriminator |
| `x:Int` | type annotation | binder/head position (POL.6) |
| `x :0 Int` | QTT multiplicity | binder position, **spaced** |
| `users:name` / `users:0` | broadcast `[P1b-iii]` | expression position **AND adjacent to a FOCUS-BEARING token** |
| `{:0 …}` | map key / multiplicity | preceded by an OPENER, not a focus — never broadcast |

**Q_M1's discriminator, as measured** (re-verified at `b389479b`): of **289**
live multiplicity tokens, **287 are spaced** and the other **2 are preceded by
`{`**; **zero are adjacent to a focus-bearing token**. So the rule is adjacency
to a *focus-bearing* token — position alone is insufficient, and this is the
same shape as `is-postfix?`'s `(pair? result)` conjunct. *(An earlier draft said
291/289/2 — a regex-boundary artifact; the shape and conclusion are unchanged.)*

**Multi-digit `:N` — RULED Q_M8: the digit run WIDENS to N.** See §3 Q_M8. The
draft recommendation here ("do not add a digits-only recognizer") was **withdrawn
as wrongly-premised** — it treated `:`+digit as QTT-owned space. It is not:
`recognize-colon-annotation` accepts **12** lexemes (`:0`–`:9`, `:w`, `:m`) while
`mult-annot?` (parser.rkt:3904) accepts **3** (`:0 :1 :w`). Nine of the twelve
ALREADY lex as one token and are ALREADY not multiplicities.

<a id="q8-4"></a>

### Q8.4 — `*` and `<`

| Form | Finding |
|---|---|
| `:diags*` | `*` GLUES (`recognize-keyword` delegates to `ident-continue?`, and that delegation **is** the F1b.7g anti-drift fix). `int*`/`trait*` are live identifiers, so a charset change is forbidden — the split must happen at a **CONSUMER**. Prior art: `validate-selection-paths` already splits `^` off a keyword lexeme and handles a whole-segment `"*"`. |
| `:<` disclose | **SAFE as of `fc65ca54`.** The hazard was never `:<` — a bare depth-0 `<` swallowed identically, and so did `def p := 1 < 2` / `def q := 3 > 4` with no colon and no brace. Fixed by the Q_M4 bound; `users:<{a}` + a later `>` now reads as three forms. |

<a id="q8-5"></a>

### Q8.5 — Standing invariants

1. **Prefix-disjointness, NOT priority, is the safety property.** Priorities
   TIE in two places — the **87 group is THREE-WAY** since P1b-ii
   (`dot-lparen` / `broadcast-access` / `dot-lbrace`; *corrected 2026-07-29 —
   this said "two places … both 87", stale in arity*), and
   `nil-dot-key`/`nil-dot-access` are both 92 — and the registry is a plain
   `(make-hash)` sorted descending with a `for/or` FIRST-match — **ties break
   by unspecified hash order**. A new recognizer must be prefix-disjoint and
   must not rely on its number. *The code already says this better than the
   doc did: parse-reader.rkt:1188-1191 — "safe because the three are
   PREFIX-DISJOINT (`(` / `*` / `{`), not because of the number".*
   Corollary verified at P2: the scan advances by the matched length, so an
   INTERIOR dot is structurally unreachable as an anchor — `3.14` is consumed
   whole at the `3`, which is a stronger argument than "no overlap".
2. **Adjacency lives in TOKEN POSITIONS. Any rule keyed on it must be decided
   at or before GROUPING** — because the *consumers* downstream of grouping
   cannot recover it. *(P1b-i learned this the hard way: a datum-layer fusion
   of `?x` + `:Nat` absorbed unrelated keywords.)*
   ⚠ **CORRECTED 2026-07-29 — the old illustration was FALSE at HEAD and
   misleading in a dangerous direction.** It read: "`x{a b}` ≡ `x {a b}`
   byte-identical as datums." Probed at `c5153685`: `x{a}` → `((x
   ($select-brace a)))` vs `x {a}` → `((x ($brace-params a)))`, and `x[0]` →
   `((x ($postfix-index 0)))` vs `x [0]` → `((x (0)))`. They are **distinct**
   — because P1a/P1b-iii took this very lesson and moved the decision to
   grouping via `adjacent-to-base?` (parse-reader.rkt:2632). The old text
   described the PRE-FIX state and implied "the datum layer can't tell, so
   don't bother checking." **No facet caught this; the completeness critic
   did.**
   Scope note for P2: the **dot band has NO adjacency gate at all** —
   `adjacent-to-base?` is called only from the bracket arm (:2692-2694) and
   the brace arm (:2750). `x .0` and `x. 0` both read `((x |.| 0))`, so a
   dot-anchored recognizer fires regardless of the preceding space. Ruled
   Q_R3: the dot band stays adjacency-free (`.k` never enforced it either;
   retrofitting the whole band is out of P2's scope, and the blast radius is
   nil by census).
3. **New sentinels owe NINE registrations — this invariant used to say TWO, and
   ONE OF THOSE TWO WAS A NO-OP.** ⚠ Corrected at P1b-iii after the P1b-ii
   regression. The old text ("`pattern-var?` and tree-parser's inline
   skip-list") was written ONE COMMIT BEFORE the regression it was meant to
   prevent, and **under-specified by exactly the amount that let it through**:
   tree-parser.rkt:662's memq is **DEAD CODE** (both cond arms terminate in a
   `(char=? (string-ref s 0) #\:)` test, so a `$`-headed item fails the arm
   regardless, and every member of the list starts with `$` or is `quote`).
   The real surface, verified at `88b3019a`:

   ⚠ **CORRECTED AGAIN 2026-07-29 (P2 audit).** The token layer below was
   written from an OPENER's shape and under-specifies for a SELF-CONTAINED
   token by exactly the amount that would let one through — *the identical
   failure mode this invariant was corrected for at P1b-iii.* Twice now, an
   enumeration written from one member's shape has missed the next
   differently-shaped member. **Read the applicability column, not just the
   list.** Four coordinates were also stale (audited at `88b3019a`; `a6af2761`
   moved them) — including the fusion gate this invariant exists to name.

   **Token layer** — applicability depends on the token's SHAPE:

   | | Site | OPENER (e.g. `dot-lbrace`) | SELF-CONTAINED (e.g. `.N`, `dot-access`) |
   |---|---|---|---|
   | a | the recognizer | required | required |
   | b | `register-token-pattern!` | required | required |
   | **f** | **`token-entry->stx`'s `case type`** (parse-reader.rkt:2264; copy the `dot-access` template at :2265-2270) | required | **REQUIRED — and a miss is SILENT** |
   | c | `langle-matched?` opener set (:1486) | required | **N/A** — no closer |
   | d | its `has-matching-rangle?` TWIN (:2570, keep IDENTICAL) | required | **N/A** |
   | e | the extent frame dispatch (:1503-1539) | required | **N/A** |
   | — | the test oracle's THIRD copy of the opener list (tests/test-parse-reader.rkt:1174) | required | **N/A** |

   **Site f is the one no enumeration had ever named, and it fails SILENTLY**:
   a new token type with no `case type` arm falls through BOTH `[else]`s —
   :2262 `[else (string->symbol lexeme)]` and :2342 `[else (make-stx value …)]`
   — yielding the bare symbol `|.1|`. No raise, no diagnostic, wrong datum.
   Note also that site 1 below ("`group-items` arm") names the CALLER (:2648 →
   :2734/:2828/…), not the minting function; `token-entry->compat`'s value
   `[else]` (:2092) is a test-only twin.

   **Sentinel/tag layer** (EVERY new sentinel):
   1. `group-items` arm (parse-reader.rkt) — mints the datum sentinel
   2. `group-items-to-tree` (surface-rewrite.rkt) — **SILENT if missed, and
      load-bearing**: a non-error tree surf can REPLACE preparse's error surf
   3. tree-parser dispatch arm — its `else` **silently** calls `parse-expr-tree`
      for any node with children; "Unhandled form" is UNREACHABLE from a group tag
   4. **`pattern-var?` (macros.rkt)** — **LOUD whole-file abort if missed.**
      This is the P1b-ii regression
   5. preparse opacity (macros.rkt:**1999** — *was cited :1988*)
   6. sub-form recursion skip (macros.rkt:**2560** — *was cited :2536*)
   7. `combine-foreign-blocks` head test (macros.rkt:**2445** — *was :2444*) — if head-relevant
   8. **`access-sentinel?` (macros.rkt:**5493** — ⚠ *was cited :5446, a 47-line
      drift in the very site this invariant was corrected to NAME; :5446 is the
      `dot-access?` comment*) + the `rewrite-dot-access` fold
      arm** — ⚠ **named by NO enumeration before P1b-iii, and the site that
      produced P1b-ii's carried residual.** Without it the sentinel never fuses
      onto its base, stays a separate sibling, and every guided error it owns
      becomes unreachable in arity-checking contexts
   9. the parser head-dispatch arm (parser.rkt, modelled on :829)

   **Silent-degradation tier** — pre-existing and family-wide, NOT chargeable to
   a new sentinel: `pp-datum` (pretty-print.rkt, handles 11 heads and **no
   access sentinels at all**) and `tools/form-deps.rkt:42`.

   **The structural reading**: nine hand-maintained enumerations is the disease,
   not the checklist's length. `pattern-var?` in particular is a NEGATIVE list
   defaulting to "this IS a pattern variable" — the same inverted polarity
   `definitely-not-map?` had before P2.b slice 1 inverted it. See DEFERRED
   § "CIU T6 D4.P1b-ii spin-offs" item 3.
4. **Both reader modes, always.** WS and sexp diverge by construction here
   (adjacency, `.{`), so a census in one mode proves nothing about the other.

