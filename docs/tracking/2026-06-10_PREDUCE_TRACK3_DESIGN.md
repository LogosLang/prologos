# PReduce Track 3 Design — ι/DPO (the coverage multiplier)

**Status**: DESIGN OPENING (2026-06-10, autonomy loop iteration 40) — and the
D.2 §4 BLOCKING VERIFICATION is RESOLVED below, first item, as the lock requires.
**Why this track is the series' fulcrum now**: the Tracks 4/5 closes left free
ingestion + extraction + persistence all proven and waiting on ONE multiplier —
rule/ingestion COVERAGE. ι (pattern-match elimination, 235 head constructors in
the census) is that multiplier.

## §0 THE BLOCKING VERIFICATION (D.2 §4) — RESOLVED: catch-alls DO NOT survive

Static trace of compile-match-tree (macros.rkt:9217-9270, verified 2026-06-10):
1. All-variable rows (incl. wildcards) compile to the BASE CASE — bound bodies
   at dispatch-tree leaves, never arms.
2. Constructor dispatch builds reduce-arms for EVERY constructor of the type
   (declaration order; lookup-type-ctors), with later rows SPECIALIZED into
   each constructor's arm — the compiler already performs PATTERN COMPLETION.
3. Int-literal columns compile to equality chains (compile-int-dispatch), not
   arms at all. Empty rows → typed-hole __match-fail (the acceptance file's
   familiar hole noise) — incomplete matches are holes, not NAC-arms.

**Consequences**: ι rules ingested at ARM granularity carry NO implicit NACs —
every arm is constructor-keyed, disjoint by prop:ctor-desc-tag (the PRN
master's "no critical pairs by construction" finding applies directly). The
pattern-completion-vs-nac-spec CHOICE DOES NOT EXIST (completion is the
existing compiler's semantics); SM3 D1's recorded revisit clause DOES NOT
FIRE. Track 3 needs NO NAC machinery.

## §1 The design (radically simplified by §0)

ι on the e-graph mirrors δ exactly: a gated whnf hook at the ι arms
(scrutinee's class + the matched constructor select the arm; the redex
{(reduce scrut arms...), arm-result} memoizes as one e-class, digest-keyed).
The rule corpus registers as per-(type, ctor) tier-2 metadata under kernel
(the ctor-desc absorption pattern); user expr-reduce forms ride the same path
(their arms are equally ctor-keyed/disjoint). Critical pairs: none WITHIN ι
(§0); ACROSS rule kinds (ι×δ on the same class) resolve by lattice JOIN per
SM4 F4 — both contractums join the class; extraction picks by cost.

## §2 Phases

| Phase | Description | Status | Notes |
|---|---|---|---|
| 0 | The §0 verification | ✅ | this doc; static trace decisive |
| 1 | The ι ingestion hook (built-in eliminators: natrec/boolrec/listrec heads) | ⬜ | mirrors δ |
| 2 | User expr-reduce arms + the kernel metadata registration | ⬜ | |
| 3 | The coverage A/B (the multiplier measurement: re-run Tracks 4/5's A/Bs WITH ι coverage) | ⬜ | the series' payoff test |

## §3 The guard interaction

ι's scrutinee is a CAPTURE (the arm body may drop it — e.g., `| zero -> true`
discards the scrutinee) — the Phase-0 guard applies verbatim: an effect-headed
scrutinee skips the e-graph recording (native ι remains legacy-sound). No new
guard machinery; the capture-profile derivation extends to arm shapes.

## §4 Honest pre-registration (the Phase 3 A/B)

ι coverage touches the 1136ms reduce phase's dominant arm class (the 461-arm
census says ι/structural dispatch IS whnf's bulk). If the warm/extraction wins
still don't materialize WITH ι coverage, the next suspect is the per-position
overhead floor itself (the +52µs), and the answer becomes Zig/LLVM lowering
(SH), not more Racket-side coverage — that boundary is pre-registered HERE.
