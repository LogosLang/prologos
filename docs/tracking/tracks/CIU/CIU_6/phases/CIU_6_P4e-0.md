# CIU 6 — D4, §5.P4e-0

Part of [D4](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md), CIU 6's implementation design, split into its parts on 2026-11-06 (owner-approved). This file holds D4 as it stood at `3e76762d`, unchanged except link targets: D4 lines 9431–9764 are lines N-9424 here.

---

<a id="p4e-0"></a>

### §5.P4e-0 — the star MINT substrate  (opened 2026-08-08 · ⛔ **ATTEMPT 1 REVERTED 2026-08-09** · re-cut pending)

⛔ **STATUS: the MINT is REVERTED** (`d0ac2a58`). What shipped and stayed is the
IDENTIFIER band, which never needed a mint. The non-identifier carriers are
[DEFERRED 101](../../../../DEFERRED.md); attempt 3 is scoped by [Q_U30](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u30) (all seven
carriers, tokenizer repair included) and [Q_U31](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u31) (glued Sigma refused),
and opens from [the star-surface census](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#star-census).

**WHY ATTEMPT 1 FAILED, in one line**: it modelled the mint's blast radius as
*the selection surface*; it is **the whole reader**. Preparse form validators,
the angle/type grammar, the tree grouper's `result` and slice 7's subject-marking
all sit upstream or sideways of `segment-select-items`, and all four are where
the defects were. Attempt 2 (a count-preserving bare marker, designed only) was
refuted for the mirror reason — `segment-select-items` is reached ONLY from the
args of a `$select`/`$select-path` node, and the fold CLOSES the selection as it
folds left, so a non-sentinel marker never arrives.

**The mini-design and mini-audit below are KEPT AS WRITTEN**, including the
"count-changing" finding that turned out to be the root of the failure. They are
the record of a correct process reaching a wrong answer, and the delta between
what the mini-audit measured and what the census measured is the reusable part:
the audit read the two groupers and their siblings; it never asked *who else
counts items*.

**The one thing the mini-audit got right and should be reused**: the star mint IS
count-changing, and `bcast-step-trigger?`'s tree arm IS a behavioural no-op
byte-identical to its own `[else]`. Both verified twice.

#### Mini-design (protocol step 1)

- **Design reference**: [Q_U23](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u23) (the `*` unification + its CORRECTED
  lexical-dividend block) · [Q_U27](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u27) (the forced hybrid) ·
  [Q_U28](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u28) (shadowing matches `^`) · [Q_U29](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u29) (mid-star is a
  guided error in all three bands) · [§5.P4e](CIU_6_P4.md#p4e).
- **Obligations carried**: **DEFERRED 90**'s fix rides here (the continuation
  classifier must REJECT an unknown continuation instead of renaming to it; its
  precedence half is already discharged — Q_U29 plus the no-output-key
  principle) · the battery pin for the `*` refusal moves WITH its text ·
  DEFERRED 91's wrong advice sits on this path but is P4e-1's fix.
- **Principles in play**: **Correct-by-Construction** — the decline must be a
  positive test by SHAPE, so a future sentinel is excluded by construction; the
  `param-group-candidate?` repair is the in-tree precedent. **Decomplection** —
  two sources, ONE downstream meaning, so the consumer stays one arm.
  **Completeness** — the whole point of Q_U27 is that a ruled operator may not
  have an unspellable case.
- **Mantra check, honestly**: this is READER/PARSER work, so "on-network",
  "all-at-once" and "in parallel" do **not** bite, and claiming otherwise would
  be cataloguing. **One word does bite: STRUCTURALLY EMERGENT.** The mint must
  fall out of *adjacency* — a structural property `adjacent-to-base?` already
  computes and which "consults no token type" — and NOT out of an enumerated
  list of contexts. Q_U8 recorded that "six enumeration under-counts this arc";
  the enumeration is the drift, adjacency is the emergence.
- **Drift risks, named BEFORE code**: (i) enumerating carriers instead of
  leaning on type-blind adjacency · (ii) shipping the decline "as a list of
  one" — its own comment records that this already cost a BLOCKING regression ·
  (iii) letting the two groupers diverge (the F1b.7g class; `surface-rewrite`
  already hand-inlines a non-exported sibling) · (iv) making the splitter
  trailing-only *in effect* and silently admitting mid-star, violating Q_U29 ·
  (v) scope creep into semantics — the consumer here is a REFUSAL.

<a id="p4e-0-audit"></a>

#### Mini-audit (protocol step 2) — read at `da47cf2d`

**⭐ THE SLICE'S DEFINING FINDING: the star mint is COUNT-CHANGING, so it is the
`bcast-brace-trigger?` shape, NOT the `bcast-step-trigger?` shape.** `*` is
POSTFIX — it modifies the item BEFORE it — so the mint consumes the preceding
result item and wraps it (`0` + `*` → `($star-step 0)`, 2 items → 1). Its two
siblings differ exactly here, and the difference decides the tree twin:
- `bcast-step-trigger?` wraps the FOLLOWING token and is count-preserving, so
  **its tree arm is a behavioural NO-OP** — verified by reading:
  `surface-rewrite.rkt`'s arm is `(loop (+ i 1) (cons item result))`,
  **byte-identical to its own `[else]` two lines below**.
- `bcast-brace-trigger?` IS count-changing (3 items → 2), so its tree twin
  genuinely FUSES to one `'bcast-brace-group` node.
**The star follows the BRACE precedent**: the tree twin must fuse, and the
**Q_N3 v2 agreement guard gains a row** — proposed
`("x{a}*" '$star-step 'star-step-group "the postfix star mint, closer-adjacent")`,
using a closer-adjacent spelling so the starred item is the LAST item of the
line, which is what that guard inspects.

**The two sources and where each lives**:
| Head kind | Star's token state | Mechanism | Layer |
|---|---|---|---|
| ordinal, `}`/`]`/`)` closers, sub-blocks | ALREADY its own token, byte-adjacent | `adjacent-to-base?` mint (Q_U8 shape) | BOTH groupers |
| identifier (`database*`) | ALREADY FUSED into the symbol | `split-star-lexeme` (the `split-caret-lexeme` shape) | parser, in `segment-select-items` |
Both converge in `segment-select-items`, which has **4 call sites** — the ω
sub-inner, the block sub, the block, and `$select-path` (the bare dot path) —
so one splitter serves every identifier-headed surface, mirroring `split-step`'s
three sites.

**DEFERRED 90's fix site, read**: `split-caret-lexeme`'s continuation classifier
is a chain of exact-string compares with a **rename catch-all** at the bottom,
which is why `^_*` / `^a*` / `^*` all become labels. The fix is to reject a
continuation bearing an operator character before reaching that catch-all.

**The refusal being replaced**: the `#rx"[*]"` arm on the `$bcast-step` payload
is **ANY-star, not trailing-star**, and its own comment misdescribes it — so
Q_U29 is already this arm's behaviour, and the slice PROPAGATES it rather than
inventing it. Its battery pin matches `#rx"\\(flatten\\) is not implemented yet"`
and is the ONLY `*`-in-selection assertion in the battery.

<a id="p4e-0-a3"></a>

#### ATTEMPT 3, SLICE A — the `postfix-star` TOKEN TYPE  (opened 2026-08-10)

**The shape, and why it is not attempt 1.** [Q_U33](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u33) rules a token-**TYPE**
mint: a `*` byte-adjacent to a preceding CLOSER is re-typed from `'symbol` to
`'postfix-star` at `disambiguate-tokens`. **Counts do not move at any layer**, so
the ~416 count-gated validator arms never engage — that is the entire difference
from attempt 1, which minted by FUSION at the grouper and was silently absorbed.
The datum is unchanged (`token-entry->stx` gets an explicit arm returning the same
`'*` the `[else]` produced), following the `colon-annotation` promotion's own
precedent, so the corpus A/B baseline stays clean.

**Grounding**: mini-audit `wf_c062f617-251` (4 facets + completeness critic).
Its load-bearing correction is recorded at [Q_U33](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u33): **"at the tokenizer"
was the one home that does not work**, because a recognizer sees only the previous
CHARACTER and `>` is not a closer character.

**Coverage, measured.** Slice A mints on **4 of the 7** named carriers — `x{a}*`,
`xs:{a}*`, `[f x]*`, `(f x)*`. Not `m{0*}` (its `*` is an item INSIDE the brace,
not closer-adjacent — the in-block band, which `segment-select-items` owns) and
not `xs:0*` / `x.0*` (the tokenizer band — **slice B**, per Q_U30's R4). ⚠ The
carrier count is **three** that do not mint, not two; earlier prose said two.

<a id="p4e-0-a3-verifies"></a>

##### THREE verify rounds — every one found a BLOCKING defect in my own code

**⭐⭐ THREE ROUNDS, THREE BLOCKING DEFECTS, AND EVERY GREEN GATE WAS BLIND TO ALL
OF THEM.** In each round the battery, all five acceptance files, the
neighbourhood tests AND the corpus A/B were green over the defect. Rounds 2 and 3
found defects **in the fix for the round before** — which is the "widening a slice
mid-flight is where I introduce defects" pattern (Watching 9) playing out three
times in one slice. **Budget for the second AND third verify.**

**Round 1** (`wf_94041a76-dca`) — four defects, ranked:
- ⛔ **The mint fired on LIVE INFIX MULTIPLICATION.** `.((1 + 2)*(3 + 4))` → `21`
  at 0 errors with the `*` typed `postfix-star`. **A design problem, not a code
  bug**: `)*(` is genuinely both readings and no lookback separates them. Ruled by
  [Q_U34](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u34) — the mixfix gate.
- ⛔ **`a >>* b` minted.** The lookback read `token-rrb[i-1]`, the pass's INPUT,
  but `compose-merge?` folds two `>` into `>>` and skips an index — so the star
  saw a *consumed* second `>` (typed `rangle`) that does not exist in the output.
  The arm's own postcondition was false in its own output, and the mint was
  **sticky** across the second round. Fixed by reading `result`, the stream being
  built, which makes the postcondition true BY CONSTRUCTION.
- ⛔ **`1 >* 2` and `[f a >* b]` minted** — a bare `>` is typed `rangle` whether
  or not it closes anything. `rangle` was dropped from the closer set outright;
  no target carrier uses a `>` closer.
- ⚠ The glued Sigma mints. Pinned as an ACCIDENT with the sequencing constraint
  it carries (below), not repaired.

**Round 2** (`wf_2c0e6901-7c6`) — one blocking defect, in the fix itself:
- ⛔ **The frame stack pushed 4 of the 9 opener types while popping all 3
  closers.** `'[` `@[` `~[` `#{` `.{` were each a NET POP that ate the enclosing
  `'mixfix` frame, so the Q_U34 gate leaked straight back onto infix
  multiplication: `.('[1 2] + (1 + 2)*(3 + 4))` → `27` at 0 errors, minting.
  **This is the file's own 31d27c83 wrong-frame-pop class, committed 280 lines
  below the comment that names it.**
- Also: `in-mixfix?` used `memq` over the whole stack where the authoritative
  test is TOP-OF-STACK, over-reaching into brackets nested in mixfix (where `*`
  is measurably NOT infix — `.([+ 1 (1 + 2)*(3 + 4)])` is a type error).

**⭐ THE FIX WAS TO DELETE THE LIST, NOT TO EXTEND IT.** The opener enumeration is
now defined ONCE (`bracket-family-openers` / `brace-family-openers` /
`group-closer-types`) and consumed by BOTH frame stacks. `make-bracket-depth-rrb`'s
three literals were replaced by byte-identical constants, so its behaviour is
unchanged by construction. The stack also adopted the authoritative
kind-sensitive `lparen` push and top-of-stack test rather than inventing its own.

<a id="p4e-0-a3-method"></a>

##### Method findings — these outlast the slice

1. **⭐⭐ MY PROBE AND MY TEST SHARED THE IMPLEMENTATION'S BLIND SPOT.** I wrote a
   17-row frame-stack probe *specifically* to hunt leaks, and it missed the
   4-of-9 defect — because, like the code and like the test block, it only
   exercised `(` `[` `{`. **An instrument written from the implementation
   inherits the implementation's assumptions.** The guard rows must be derived
   from the AUTHORITATIVE enumeration, not from what the code happens to handle.
2. **⭐ A HAND-COPIED ENUMERATION IS THE DEFECT, AND THE FILE SAYS SO.** The tree
   already carried two copies of this opener set and records their disagreement
   by commit hash. The third copy diverged immediately. Prefer deleting the list
   to auditing it.
3. **⭐ A RESULT-NARROWING TEST HELPER FAILS RED FOR THE WRONG REASON.**
   `p4e-star-type` returns the FIRST lone `*`; `def a := .(1 * 2)` has an
   arithmetic star before the one under test, so a correct implementation
   reported RED. Same class as the `run-last` incident (P4c-4c §4.2), opposite
   sign — that one went falsely GREEN. Added `p4e-last-star-type`.
4. **The corpus A/B is a NULL INSTRUMENT for this mint** — measured **0 mints
   across all corpus files** (every `]*`-shaped grep hit is inside a comment).
   "The A/B baseline stays clean" is true and vacuous; all real coverage is the
   authored battery. Do not cite the A/B as evidence for this slice.
5. **The adjudicator sharpened or found the worst defect in BOTH rounds** — the
   infix-multiplication finding reached only one skeptic, and the 4-of-9 finding
   was independently reproduced by the adjudicator with a wider blast radius
   (60 false positives across nesting combinations). A skeptic's clearance is
   still not evidence.

<a id="p4e-0-a3-owed"></a>

##### ⛔ THE SEQUENCING CONSTRAINT SLICE A HANDS TO ITS CONSUMER

`<(x : Nat)* Nat>` is legal today, elaborates to `[Sigma Nat Nat]`, and **mints** —
its `*` follows `)`, a genuine closer, outside mixfix. No closer-set or gate
repair reaches it, and gating on angle frames was considered and REJECTED (a `<`
is typed `langle` whether it opens a group or is the less-than operator, so an
angle stack mis-nests on `a < b` and suppresses legitimate later mints).

It is harmless in slice A for one exact reason: **`tree-parser.rkt` finds the
Sigma `*` by LEXEME, not by type** (`grep -c token-entry-types tree-parser.rkt`
→ 0), so a type-only mint is invisible to it.

**[Q_U31](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u31)'s refusal of the glued Sigma MUST land before any consumer keys
on `postfix-star`** — otherwise a live Sigma type silently becomes a star step.
That is a Tier-A silent-wrong-answer deferred by exactly one slice, and it is
pinned in the battery so the constraint cannot be lost.

<a id="p4e-0-a3-round3"></a>

##### Round 3 (`wf_573914d7-b8b`) — the mirror image, and a fourth list copy

- ⛔ **A STRAY CLOSER inside mixfix over-popped the frame.**
  `.( } (1 + 2)*(3 + 4) )` → `21` at **0 errors**, the stray `}` eating the
  `'mixfix` frame so the star minted on live multiplication again. Exact mirror
  of round 2's under-push.
  **⭐ THE FINDING THAT MATTERS MORE THAN THE BUG: the authority for mixfix
  extent is `group-items`, NOT `make-bracket-depth-rrb`.** `group-items` carries
  a `close-type` and lets a NON-matching closer fall through as a plain item —
  which is why that probe still prints 21. The bracket-depth stack pops
  unconditionally and over-pops too, so **mirroring it faithfully reproduced its
  bug**. "It mirrors the authoritative one" was true and insufficient. The gate
  now pops only on the frame's own expected closer.
  ⚠ A **matching** `)` does close the group, so `.( ) (1 + 2)*(3 + 4) )` mints —
  correctly, and not silently: `.( )` is a LOUD per-command error ("Empty .( )
  mixfix expression") with the rest of the file still produced.
- ⚠ **`token-entry->compat` had no `postfix-star` arm** — the exported
  `tokenize-string` type changed while its value did not. Armed to report
  `'symbol`, the same remap that case already does for `pipe-right`/`clause-sep`.
  This is the sibling-inconsistency the `dot-ordinal` arm documents as "how the
  next reader gets misled".
- ⚠ **I had created a FOURTH copy of the list I had just made a constant for** —
  the star arm's own closer test was still the literal. Fixed, and the two
  `31d27c83` twins (`langle-matched?` / `has-matching-rangle?`) now share
  `all-group-openers` + `group-closer-types` as well. **Hand-copied opener lists
  in this file: 0.**
- ✅ The round confirmed the shared-enumeration substitution is **pure** — the
  constants are member-identical to the literals they replaced, so
  `make-bracket-depth-rrb` is unchanged by construction.

<a id="p4e-0-a3-flake"></a>

##### ⚠ THE SUITE IS INTERMITTENT, AND IT IS PRE-EXISTING — do not attribute it

Chasing a suspected regression cost real time and produced a fact worth keeping.
Two anomalies appeared during slice A's gating and **both are ambient**:

- **The suite's test COUNT varies.** `test-properties.rkt` is a RANDOMIZED
  property test (`gen:integer-in`); across **469 recorded full-suite runs** its
  case count is **13 in 411 and 8 in 55**. So a ±5 swing in the total is normal
  and says nothing about a change.
- **Full-suite runs fail intermittently at ~16%** — **74 of 469** historical runs
  recorded `all_pass=False`. Slice A saw 1 failure in 8 runs (12.5%), squarely on
  that baseline; the two failures were in DIFFERENT files (`test-mixfix-01`,
  `test-mixfix-02`), neither reproducible in isolation (5/5 and 4/4 clean).

⚠ **A 5-run base sample MISSED BOTH**, which is exactly how a pre-existing
intermittent gets attributed to whatever changed last. **Check
`data/benchmarks/timings.jsonl` — it records 469 runs with per-file counts and
`all_pass` — BEFORE running a base A/B.** One query answered in seconds what five
worktree suite runs could not.
⚠ Also re-learned: **do not compile while a suite is in flight.** One run was
contaminated that way and its failure sent me down the wrong path first.

<a id="p4e-0-b"></a>

#### SLICE B — the tokenizer repair (R4): BUILT, VERIFIED, ⛔ **REVERTED**  (2026-08-10)

**Status: ⛔ REVERTED. R4 is NOT independently landable** — see
[DEFERRED 105](../../../../DEFERRED.md). This is a SCOPING result, not a coding error, and it
is the piece the census's "unreachable without a tokenizer repair" phrasing left
open: the repair is necessary and **not sufficient**.

**What it did, and it worked at the token layer.** Both digit arms of
`recognize-dot-ordinal` / `recognize-colon-annotation` stopped before a trailing
`*` instead of declining on it; the mint's predecessor set gained
`colon-annotation` / `dot-ordinal`. `xs:0*` → `xs` `:0` `*` → `(xs ($bcast-step
:0) *)`; `x.0*` → `(x ($postfix-index 0) *)`. Six of the seven carriers minted;
battery 468 green, acceptance 84/84, every slice-A gate held.

**⛔ AND IT WAS A SILENT-WRONG-ANSWER REGRESSION.** 4 tokens → 3 makes the star a
separate DATUM ITEM, and item counts are load-bearing. `def w2 := [take2 p.0*]`
went from a loud `Too many arguments` at HEAD to **`w2 : Int defined.` / `10` at
zero errors**, the written flatten silently discarded and the `*` filling a
parameter slot. A `defr` fact row registered 2 rows instead of 4; a `bundle` went
from a guided refusal to inventing a type parameter. **Attempt 1's failure mode,
one slice later, in a narrower aperture** — violating the very property slice A's
shipped comment names as "the whole reason this is not attempt 1".

**⚠⚠ THE METHOD FINDING, which outlasts the slice: CONTAINMENT IS NOT A SAFETY
PROPERTY.** A verify axis measured **1,943/1,943 glued ≡ HEAD-spaced** and offered
it as *"the argument that makes the count change payable"*. It is a category
error: token-stream containment says HEAD *could* have produced this stream **from
different source text**, never that the written source's MEANING is preserved.
`xs:0 *` and `xs:0*` agreeing **is the defect**. An axis cleared the slice on it;
the adjudicator overturned that clearance and found a fourth defect none of the
three skeptics had. **A containment result must be restated as a meaning claim
before it counts as evidence.**

**WHY THE OBVIOUS FIX DOES NOT APPLY.** The identifier band is count-preserving
because it FUSES — `x.name*` is ONE token, the star riding inside the symbol
(`($dot-access name*)`) for `split-star-lexeme` to split later. The ordinal band
cannot: `$postfix-index`'s payload is `(string->number (substring lexeme 1))` and
must be NUMERIC, so a `.0*` lexeme yields **`#f`**. **The star has nowhere to live
in an ordinal payload** — which is also why the twins use `ascii-digit?` vs
`char-numeric?` and why "apply the same patch twice" was never the shape.

**WHAT R4 IS BLOCKED ON**: the star's DATUM REPRESENTATION — a wrapper sentinel
(`$star-step`, recorded in `reader-forms.rkt` as *"DELIBERATELY ABSENT … a
deferred RULING"*) or a widened `$postfix-index` arity. Both are **P4e-1
representation decisions**, not tokenizer work. ⚠ **Reopen R4 only after that
ruling**; the tokenizer diff is small and re-derivable, and DEFERRED 105 carries
it.

**Kept from the slice**: the stale co-migration pointer in
`recognize-colon-annotation` (it said `parser.rkt`; `fused-type-annot?` moved to
`reader-forms.rkt` at LET P4), plus the measured note that the co-migration is
narrower than it reads — that predicate already excludes digit-headed colon
symbols, so `:0`-shaped tokens were never in its domain.

