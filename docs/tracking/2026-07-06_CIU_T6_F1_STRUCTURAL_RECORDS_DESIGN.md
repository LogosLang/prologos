# CIU Track 6, F1 — Structural Record & Collection Typing (Stage-3 Design, D.2)

**Status**: **Stage-3 D.2** — Pre-0 done (§7); independent adversarial critique done ([D.3 record](2026-07-06_CIU_T6_F1_STAGE3_CRITIQUE_D3.md), 4 BLOCKING + 12 SIGNIFICANT confirmed); collection reframe co-designed + owner-locked (D13/D14). This D.2 folds ALL of the above. Next: light re-verification of amended dispositions (§7b) → Stage-4.
**Date**: 2026-07-06 · **Owner**: Zee Larson · **Series/Track**: CIU Track 6, phase F1
**Co-design home**: [`2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md`](2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md) (§2a locked D1–D14; §3b rows research; §4a grounding). Research notes: [rows/coalgebra](../research/2026-07-06_ROWS_COALGEBRA_PROPAGATOR_NOTE.md).
**Verified-at**: HEAD `6d6a24ca` (coordinates re-verified there by main-session R-lens + the D.3 adjudicator; re-grep after drift).

## §1 Goal, scope, and the reframe

**One-sentence F1a job**: replace the elaborator's hardcoded `Open` value-type for unannotated keyword literals with a **ground row**, and teach the map-op typing arms to consume it — so `{:a 1}.a : Int` and `+ {:a 1}.a 1 ⇒ 2 : Int` (owner V5). The projection machinery already works when the value type is concrete (verified: `def am : (Map Keyword Int) := {:a 1}` → `am.a : Int` today).

**The reframe (D13/D14)**: this is not only about records. A record is a structural collection keyed by **Keyword**; a **tuple** is one keyed by **Nat (position)**; a **dictionary/array** is the **dyn-tailed uniform** instance of the same carrier. `@[1 "a"]` (heterogeneous vector) ERRORS today for the *same* reason `{:a 1 :b "x"}` would (one uniform element/value slot) — so heterogeneous collections are **net-new capability**, the positional dual of the record work. The 2×2:

|  | closed / heterogeneous (per-slot types) | dyn / uniform (one type + open tail) |
|---|---|---|
| **Keyword-keyed** | `{:a Int :b String}` — anonymous **record** | `(Map Keyword V)` — **dictionary** |
| **Nat-keyed** | `⟨Int, String, Bool⟩` — **tuple** (flavor A) | `(PVec V)` / array — homogeneous vector |

Plus **flavor B**: a variable-length container whose *elements* differ → `List`/`PVec` with a **union** element type (`'[{:a 1} {:b 2}]` : `List <{:a Int} | {:b Int}>`).

**F1a-core scope** (this slice): the Keyword-keyed closed row (records) + its full disposition + the D.3 blocker fixes. **F1a-col scope** (sibling slice, same CIU-T6 phase): flavor A (tuple minting + classifier) + flavor B (union-widening) — turns the critique's list-of-records "regression" into the feature. **Deferred**: dyn tails + `Open` deletion (F1a.2); width + Map↔schema seal (F1b); ρ/`Concat`/`DeepConcat` (F-row); variadic tuples, η, variants (later). No user-writable record/tuple *type* syntax in F1 (inferred + displayed only).

## §2 Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| Pre-0 | Probes + baseline + acceptance file + `--check` runner | ✅ | §7; `record-field` struct SAFE; churn small; acceptance 26/26 baseline-green |
| D.3 | Independent adversarial critique (P/R/M/S/U) + adjudication | ✅ | [record](2026-07-06_CIU_T6_F1_STAGE3_CRITIQUE_D3.md); 4 BLOCKING + 12 SIGNIFICANT; 2 REFUTED |
| D.2 | Fold critique amendments + collection reframe | ✅ | this doc |
| re-verify | Light re-verification of amended dispositions (§7b) | ⬜ | probes/anchors reusable from D.3 |
| F1a-s1 | Carrier struct(s) through core pipeline (files 1–8 + `union-types.rkt` + walkers) + display | ✅ | 13 files; `expr-Record`/`record-field` + `record-map-field-types` helper; S1 union-sort-key + S2 walker audit done; `tests/test-record-node.rkt` (15); suite GREEN 8530/448/0; no behavior yet (nothing mints). unify classify (B3) + minting = s2/s3 |
| F1a-s2 | Literal inference + projection + **B1** + **B2** + Record<:Map subsumption + **the full map-op surface** (pulled fwd from s3) + Record↔Map coercion in unify/subtype (NEW, see below) | ✅ | `{:a 1}.a : Int` ✓, V5 ✓, heterogeneous per-field ✓, `idm r` subsumption canary ✓, exact assoc/dissoc/keys/vals/has-key/nil-safe-get ✓, closed-row-miss error ✓. Suite GREEN **8545/449/0**; acceptance 27/27 (`test-f1-records-acceptance.rkt` = suite gate); 4 display-churn tests flipped (incl. the T-2 contract file supersession, D7). Elaborator classifier + record-seed mint; smart-constructor helpers (`make-record`/`record-extend`/`record-lookup-field`/`record-remove`). See §11a. |
| F1a-s3 | Remaining record dispositions | ✅ | Grounding audit `wf_2d535113` → **B3 ✅ `a5c546c8`** (same-shape classify; prelude WS test) · **S10 ✅ already-s2** (`ground-expr?` arm; posture §11b) · **S3+B4 ✅ `83bd416f`** (fold/filter/map-vals Record arms BOTH checkers; both union arms; helpers; whnf wrappers; B4 canaries) · **S7 ✅ `d08e14bf`** (rich closed-row-miss via the #70-precedent hint walk; acceptance asserts the message) · **.pnet cross-module canary ✅ `d08e14bf`** (`test-record-pnet-cache.rkt`, the F2 two-run repro as a permanent test) · non-reachability notes §11b. Acceptance **37/37**; suite GREEN **8586/451/0** |
| F1a-s4 | Flip acceptance `;;N=>` to F1a targets + `het.z` + **S5** re-census (`test-mixed-map` T-2 contract) + `test-first-class-paths` flips + **cross-module .pnet canary** + prelude-loaded WS test (B3) + `--check` suite wrapper | ⬜ | |
| F1a-s5 | Full-suite gate + `bench-ab` vs §7.4 baseline + PIR-lite | ⬜ | |
| F1a-col | Flavor A (tuple node/mint + classifier) + Flavor B (union-widen on element-unify-failure, VISIBLE) | ⬜ | closes the different-shape-collection regression |
| F1a.2 | dyn tail live; `Open` relocation + node deletion (D1-b/D7) | ⬜ | own mini-design |
| F1b | Erasure-mode width + label-keyed depth; schema→Map free; Map→schema seal | ⬜ | own Stage-3 |

## §3 Grounded code facts (VERIFIED at `6d6a24ca`; ✏ = corrected from D.1 by the D.3 critique)

| Fact | Where |
|---|---|
| `Open` minted at exactly 2 sites, both the unannotated keyword-literal seed | `elaborator.rkt:2127`/`:2132`, comment `:2117` |
| Literal entry key/val exprs in-hand at mint (keys are `expr-keyword`) — but the seed is built at `:2129-2132` BEFORE entries elaborate (`:2138`): the all-keyword classifier needs an **entries-first** scan (§4.2) | `elaborator.rkt:2129-2145` |
| `{:a 1}` infers `(expr-Map ?km (expr-Open))` → the **Map arm** `:1512` (returns `vt`), NOT the schema arm `:1536` | `typing-core.rkt:1465-1473`, `:1512-1513` |
| **✏ B1**: annotated-literal checking is TERM-directed AND recurses to the seed: `map-assoc`-vs-`Map` (`:2428-2431`) → `map-empty`-vs-`Map` (`:2424-2426`) `(unify v1 v2)`; today `v1=Open` passes via `unify:574`. A Record seed there breaks it / flex-rigid-poisons `?V` | `typing-core:2424-2431`; `unify.rkt:574/583` |
| **✏ B2**: qtt has its OWN duplicated conversion fallback (`unify`→cumul→`subtype?`) that never calls typing-core `check` — a Record<:Map arm in typing-core is unreachable from `checkQ` | `qtt.rkt:2449-2463`; app-arm `:316-325` |
| **✏ B3**: `classify-whnf-problem` has NO Record case → Record-vs-Record unify falls to `'conv` → fails. Reached by list-element meta solving. `'[{:a 1} {:b 2}]` types today as `(List [Map Keyword Open])` (probe) | `unify.rkt:558-719`; `elaborator` list = cons chains |
| **✏ B4**: today's dynamic-key path DOES check the key (literal keys solve `?km:=Keyword`): `map-assoc q "str" 2` ERRORS today (probe) | `typing-core:1465-1473` |
| **✏ S1**: `union-sort-key` sends unknown nodes to `"9:other"`; `dedup` merges only ADJACENT equals → record-containing unions non-canonical (commutativity/idempotence fail) | `union-types.rkt:43-95`, `:103-111` |
| **✏ S2**: generic meta-walkers recurse on `struct?` only — `occurs?` (`unify:234-245`), `collect-meta-ids` (`metavar-store:915-922`), `ground-expr?` (`[_ #t]`) are BLIND to metas inside a raw assoc-list fields slot | those + `type-lattice.rkt has-unsolved-meta?` |
| **✏ S6**: stdlib **`map-merge` EXISTS** (right-priority), prelude-reachable, feeds `impl Lattice (Map K V)`; `map-merge {:a 1} {:b 2}` → `{:a 1 :b 2}` today (probe). D.1's "no map merge exists" was FALSE (D10 semantics lock unaffected) | `lib/prologos/book/maps.prologos:136-141`, `core/map.prologos:62-66`, `core/lattice.prologos:128/229-233` |
| **collection grounding** (probed): `@[1 2 3]`→`[PVec Int]`; `@[1 "a"]`→ERROR (single elem meta, `syntax.rkt:700`); `expr-Vec (elem-type length)` `:414`; `def v:(PVec <Int\|String>):=@[1 "a"]` CHECKS → `[PVec Int\|String]`; `pvec-nth v 0N`→`1 : Int\|String` (projection works; `0` Int errors — index-type, not union); union normalization FLATTENS (`<Int\|<String\|Bool>>`≡`Int\|String\|Bool`) | probes at HEAD |
| schema projection template + datum→expr; `closed?` consulted at 1 site (check dir) | `typing-core:1536-1548`, `:390-393`, `:351-386`, `:2444`; `schema-field` `macros.rkt:758` |
| `m.a`→`(map-get m :a)`; `m[i]`→`(get m i)`; `expr-get` (both typing-core `:1491`+qtt `:1221`) DELEGATES to infer (free); `map-get`'s `(expr-Map _ vt)` qtt arm `:1213` is INLINE | `macros.rkt:5064/5096/5119` vs `:5112` |
| literal `#p` get-in/update-in **desugar** to `map-get`/`map-assoc` nests at the elaborator (only DYNAMIC paths emit `expr-get-in`/`expr-update-in`) — REFUTES the "path-node flips undeliverable" critique claims | `elaborator.rkt:2242-2252`, `:2320-2337` |

## §4 The design

### §4.1 The carrier — one row, two surface presentations (D6 + D13)

```racket
;; syntax.rkt — the anonymous structural-row TYPE node (internal-only in F1: inferred + displayed, not parsed)
(struct expr-Record (key-domain fields tail) #:transparent)
;;   key-domain : 'keyword | 'nat        (D13 forward-compat: generalize NOW; F1a-core mints 'keyword only,
;;                                        'nat = tuples land in F1a-col. Q_B: a row is ALL-keyword or ALL-nat —
;;                                        homogeneous-key-domain invariant, enforced by the smart constructor.)
;;   fields     : canonical assoc ((label . record-field) ...)
;;                label = keyword-symbol (keyword-domain) | Nat (nat-domain);
;;                sorted by symbol<? / < per domain (smart-constructor-enforced canonical form).
;;   tail       : 'closed | 'dyn         (F1a mints 'closed. 'dyn = F1a.2 (+ must carry (K,V) bounds for the
;;                                        Q_E dictionary reading). ρ = row-kinded meta at F-row. Slot is expr-ready.)

(struct record-field (type presence) #:transparent)
;;   type     : an ORDINARY type expr/meta  (NO new meta domain)
;;   presence : 'present                    (F1a writes 'present only; 'optional|'absent|'unknown reserved,
;;                                           per D6 — the Malli-optional-keys + narrowing + presence-poly hook)
```

**Two surface nodes, one carrier (Q_A)**: the struct is the *carrier*; the *surface* distinction (record `{…}` vs tuple `@[…]`, and the two displays) is driven by `key-domain`. Whether the nat-domain tuple later gets a physically-distinct `expr-Tuple` struct sharing the field/tail helpers, or rides `key-domain='nat` on this struct, is an F1a-col call — both satisfy "two surface nodes"; the tag is less machinery. F1a-core commits the `key-domain` field so either lands without rework (the forward-compat crux — retrofitting a key-domain parameter after a keyword-only carrier hardens is the rework risk).

**Order-significance is FREE** (D14, verified by construction): `⟨Int,String⟩` = `{0↦Int, 1↦String}` and `⟨String,Int⟩` = `{0↦String, 1↦Int}` are different slot-maps ⇒ unequal — no non-commutative monoid needed for identity/meet. The `key-domain` tag's job is narrow: canonical form (keyword→sort-by-name; nat→already positional), the dense-prefix well-formedness check (nat only, trivially satisfied by literals), and width-applicability (tuples exact/no-width; records get width at F1b).

**Sorted assoc, not hasheq** (Pre-0 #2): determinism for serialization / display / structural `equal?`; n small. Canonicalize ONCE at row completion via a **smart constructor** (the only row producer) — supersedes D.1's "not per-extension" note (S12): user `assoc` builds rows post-literal, so per-op canonical maintenance is unavoidable and the smart constructor owns it.

**Well-formedness**: `is-type (expr-Record kd fs t)` at `Type 0` iff every field type `is-type` (mirrors `expr-Map` `:1445-1448`); `infer-level`→`lzero`. Duplicate labels impossible by construction.

**Record-meet (spec; F1a has ZERO call sites — F1a.2/M1 consume it; S12)**: split honestly into (a) pure-ground: per-field `type-lattice-meet` under the orientation flip (OSF generality-meet = our information-join); (b) meta-bearing: residuated (metas → `type-bot`, conservative). Field-*extension* (assoc right-priority overwrite) is a DIFFERENT non-monotone operation — name it "row extension", never "merge", to keep it clear of the future cell-merge. **Distributivity precondition RESOLVED** (S12/§7b): per-field `type-lattice-meet` distributes over unions BY CONSTRUCTION (`type-lattice.rkt:263-274`); equal?-level canonicity of the distributed form additionally needs the S1 `union-sort-key` fix.

**Records vs dictionaries (a load-bearing split; §6 challenges it)**: a *record/tuple* is a literal with a syntactically-known key set (keyword-literal keys / fixed positions); a *dictionary/array* is uniform with computed keys. F1a gives literals row types and leaves dictionaries/arrays as today; a non-literal key **degrades** to the dictionary view (§4.3, B4-gated). Per Q_E this is end-state (b): `expr-Map`/`PVec` are the dyn-tailed/uniform instances of the one carrier — the split is a *refinement* of D3's "one notion", not a third mechanism; the F1a `Record<:Map` arm is transitional (F1a.2 reworks it onto the dyn tail).

### §4.2 Elaboration + the classifier (the correctness pivot; B1)

`surf-map-literal` (`elaborator.rkt:2113-2145`) — restructure to **scan keys first** (S12 minor: the seed is currently built before entries elaborate; scan the surface keys before choosing the seed):

- **all keys keyword-literal** (non-empty) → **record seed** `(expr-map-empty (expr-Keyword) (expr-Record 'keyword '() 'closed))`. Zero new *term* nodes; the row rides the existing v-type slot; `infer` grows + returns it (§4.3). Empty `{}` → **unchanged** (today's Open seed; the empty-record reading waits for dyn tails, F1a.2 — deliberate).
- **any non-keyword key** → unchanged Open/dictionary seed.

`surf-pvec-literal` (`:2448`) — the **classifier** (F1a-col): homogeneous → `expr-PVec` (today); heterogeneous fixed → tuple (nat-domain row, flavor A, **tuple-by-default** per Q_D). Widening tuple→`PVec`-of-union is a monotone Galois projection on demand.

**B1 fix** (the seed must not break annotated literals): add a check arm at the `map-empty`-vs-`Map` site (`typing-core:2424`): when `v1` is an **empty closed `expr-Record`** seed, unify the KEY types only and **skip the value-unify** — the empty row asserts no fields, so it satisfies any `(Map K V)` and does not flex-rigid-poison a meta `?V`. Per-entry strictness is preserved by the `map-assoc`-vs-`Map` arm's `(check ctx v vt)` as the chain unwinds. This transcribes the seeded-`Open`'s annotation-satisfaction duty for the record seed, one arm. **Corrects D.1 §4.2's false "never consults the seed" claim.** Gated by acceptance canaries 9/14/16 + new `map-merge` canary at s2 (NOT s5).

### §4.3 Typing-arm disposition (F1a-s2/s3) — with all D.3 fixes

`R` = whnf-inferred `(expr-Record kd fs 'closed)`. All `typing-core` `infer` unless noted.

| Site | Disposition on `R` | Fix |
|---|---|---|
| `map-empty` `:1450` | v-type `expr-Record` → return it | |
| `map-assoc` `:1465` | keyword-lit key → `infer` v, **row-extend** right-priority (D10 exact extension). Non-literal key → **first `(check ctx k (expr-Keyword))`**; on fail `expr-error` (preserves today's rejection); on pass degrade `(expr-Map (expr-Keyword) (expr-Open))` | **B4** |
| `map-get` `:1512` / `get` `:1491` | keyword-lit: present → field type (**the goal**); absent → `expr-error` + closed-row-miss diagnostic. Non-literal: `(check k Keyword)` then `⋃fields` | B4 |
| `nil-safe-get` `:1585` + its **own union loop `:1587-1604`** | present → `field\|Nil`; absent+closed → `Nil`; **union loop must accept Record components** (drops them today → wrong Nil-only) | **S3** |
| `map-dissoc` `:1619` | keyword-lit → `R` minus field (exact); non-literal → B4-gated degrade | B4 |
| `map-size` `:1626`/`has-key` `:1634` | `Nat`/`Bool` (+ `R` arm) | |
| `map-keys` `:1643`/`vals` `:1651` | `(List Keyword)`/`(List ⋃fields)` | |
| **`map-fold-entries` `:1836` / `map-filter-entries` `:1850` / `map-map-vals` `:1861`** | operate through the derived uniform view (`K=Keyword`, `V=⋃fields`); today `[_ (expr-error)]` → Record regresses to hard error | **S3** |
| union arm of `map-get` `:1549-1568` | accept `expr-Record?` components; **miss policy = filter** the missing component (Q5; matches the arm's existing Map precedent; all-miss already errors). Do NOT copy `with-speculative-rollback` into new arms (§8) | S3/Q5 |
| **check-subsumption `:2700-2706`** (NEW) | `R <: (Map K V)`: labels vs `K`; `V` meta → solve `V := ⋃fields` (Galois α; empty row → succeed WITHOUT solving `V`, Q6); `V` concrete → per-field check | Q6 |
| **`unify.rkt` classify `:558-719`** (NEW, #14) | Record-vs-Record: equal key-domain + labels + tails → `(list 'sub per-field-goals)` (sorted zip); label mismatch → `'conv` + closed-row-miss. **Different-shape → union (F1a-col flavor B), NOT here** | **B3** |
| **`expr-update-in` `:1429`** (dynamic path) on `R` | **degrade** result to `(expr-Map Keyword Open)` (F1a; dyn tail subsumes F1a.2) — precise-but-unsound rejected (Q7). *Literal* update-in desugars → safe (no arm needed) | **S9**/Q7 |
| **`expr-get-in` / `expr-broadcast-get`** (dynamic) | unchanged (fresh meta, Record-indifferent) — one-line "unchanged" rows | S9 |
| **trait-resolution** `ground-expr?` + `expr->impl-key-str` | add `ground-expr?` Record arm (meta-bearing → not ground); posture: record types match no Map-headed instance head in F1a — annotation is the escape hatch (α-bridge is F1b/UCS-5) | **S10** |
| **qtt** `map-get` `:1213` + `map-assoc` `:1196` + **`map-dissoc` `:1244`** + the **conversion fallback `:2449-2463`** | delegate the TYPE to `(infer ctx e)` (the `:1215` schema-arm pattern), usage local; the fallback delegates type-comparison to typing-core `check` so the Record<:Map arm is reachable. map-assoc delegation is **unconditional**. Route any cell-level meta-solve through `solve-meta!` (pipeline.md Known Coupling) | **B2/S4** |

**Diagnostic transport (S7)**: `expr-error` is nullary — the closed-row-miss message needs a channel. Mechanism: a `typing-errors.rkt` hint arm matching `map-get`-on-Record-with-absent-keyword (Issue-#70 walk precedent), field list capped (~6 + "+N more"), typo-suggestion optional. If descoped, the `het.z` acceptance assertion downgrades to "is a type error".

**Generic-walker audit (S2, s1)**: extend `occurs?`, `collect-meta-ids`, `ground-expr?`, `has-unsolved-meta?` (+ grep the ~6 `struct->vector` walkers) with a pair?/list? recursion into `fields`, OR make the fields spine struct-based so the generic walk works unmodified. Regression tests: occurs-check meta-in-field; constraint-retry with a record-embedded meta. Propose the pipeline.md checklist addition ("sub-exprs inside a non-struct container → audit every generic walker").

**Untouched by F1a-core**: `unify:574-575` Open wildcard (D7 relocation = F1a.2); `subtype-predicate.rkt` (no record-subtype judgment, D11; width = F1b erasure-mode); the two term-directed check arms except the B1 seed guard; reduction/runtime (values stay CHAMP). **Coverage-gap check to close at s1** (D.3): `reduction.rkt` `whnf`/`nf`/`trivially-whnf?`/`definitely-not-map?` treatment of the new node.

### §4.4 `merge` / `deep-merge` (D10; corrected grounding S6)

**Correction**: stdlib `map-merge` (right-priority) **exists** and feeds `impl Lattice (Map K V)` — D10's *semantics* lock is unaffected (it already implements right-priority), but the merge-node mini-design must **disposition the live stdlib function** (Q4: retire-into-node — recommended — vs alias vs coexist). M1 typing (both sides `R`-ground): result row = right's fields + left's fields with labels absent-on-right (deep: recurse where both field types are records — finite trees, terminating). Non-ground → dyn-tail (F1a.2). M3 (F-row): `Concat`/`DeepConcat` residuated relational constraints, 3-cell fundep-directional propagator in the one solver. `map-merge {:a 1} {:b 2}` becomes a subsumption-arm canary (its polymorphic `(Map K ?V)` flow exercises the B1 flex-rigid path) — but **`map-merge` is prelude/stdlib** (verified §7b: unbound under `:no-prelude`), so this canary lives in the **prelude-loaded** WS test, not the `:no-prelude` acceptance file.

### §4.5 Open relocation (D7 — F1a.2 summary)

F1a leaves every non-literal `Open` path byte-identical. F1a.2: `'dyn` tail live ((Map K V)-annotations + dynamic-key degradations produce dyn-tailed rows carrying (K,V) bounds); transcribe Sekiyama–Igarashi `C_ConsL`/`C_ConsR` absorption into unify for dyn tails (`unify:574`'s duty, principled home); unknown-field projection on a dyn tail mints a fresh meta + records the observation; then delete `expr-Open` (~38 sites/11 files) with the two-role history recorded (docstring). D1-b closes there.

### §4.6 WS impact

No reader/parser/preparse change in F1a-core (`{:a 1}.a` already parses). Surface: **(1) display** — record → `{:a Int :b String}` (canonical order); nested nests; tuple (F1a-col) → `⟨Int, String⟩` (delimiter TBD); dyn tail (F1a.2) → `{:a Int | _}`; `expr-Map` unchanged. **Union display fix (S-minor)**: `pp-expr` prints unions bare `~a | ~a` (`pretty-print:718`) — the acceptance `;;N=>` targets `(List <Int | String>)` must use the ACTUAL convention (`Int | String`), not delimited. **(2) diagnostics** — closed-row miss names available fields (§4.3 S7). **(3) not user-writable** — `(Map K V)`/`schema` remain the annotation forms.

### §4.7 Acceptance (EXISTS, baseline-green 26/26; §7.5)

`examples/2026-07-06-ciu-t6-f1-records.prologos`, `:no-prelude`, self-verifying via `run-file.rkt --check`. s4 flips `;;N=>` to F1a targets + adds to the `:no-prelude` file: `het.z` closed-row miss (**append at file END** to avoid index renumber — S-minor); two dynamic-key canaries (Keyword key → degrade; String key → error, covering B4). **NEW prelude-loaded WS test file** (surfaces need `'[…]` list literals + stdlib `map-merge` = prelude): `'[{:a 1} {:a 2}]` same-shape (B3) + the different-shape named-regression/escape-hatch; `map-merge {:a 1} {:b 2}` + two-record `map-merge` (subsumption canary, §4.4); a `.pnet` **cross-module canary** (a Record-typed def in a lib module consumed downstream — the F2 detonation surface the single-file `:no-prelude` acceptance cannot reach; D.3 coverage gap). Plus `test-first-class-paths.rkt` `"1 : Open"`→`"1 : Int"` flips (`:113/:127`). **S10 blast-radius** (does trait dispatch on `(Map ?km Open)` literals succeed today?) quantified here via a prelude probe — the design posture (§4.3 S10) does not depend on the count.

## §5 SRE lattice lens (records + collections)

1. **Classification**: STRUCTURAL — labeled product of per-field/-position VALUE lattices, indexed by a support set + key-domain + tail.
2. **Algebraic properties**: per-slot = flat type lattice (join-semilattice + ⊤/⊥); support = powerset (Boolean); tail = 3-point info order. Whole = OSF-family feature lattice. **Meet vs union are DIFFERENT operations** (Q3 resolution): *meet* (same object) = D11 conjunction-of-facts (conflict ⇒ ⊤/contradiction — for tuples, position-i-Int ∧ position-i-String = ⊥); *collection-element* context = union (no meet taken). D6's "field-union formula" conflated them; now separated. **Distributivity RESOLVED** (§7b).
3. **Bridges**: (a) per-slot ↔ flat lattice (Galois, trivial). (b) row ↔ `(Map/PVec K V)` = the uniform-bound α(R) = `(… ⋃fields)`; the §4.3 subsumption arm IS this α. (c) row ↔ schema = up-shift embedding; seal = checked partial inverse + residual (F1b), NOT a lattice morphism (polarity boundary).
4. **Composition**: field types may be unions (normalized) or nested rows; least fixpoint of the labeled-product functor; no cycles (ground literals finite trees).
5. **Primary/derived**: literal ground row = PRIMARY; `(Map/PVec …⋃…)` view = DERIVED (α); tuple→PVec-of-union widening = a Galois projection (SRE Q5), realized as an on-network propagator NOT an ad-hoc cast.
6. **Hasse**: nodes = (support, per-slot assignments, key-domain, tail); edges = single-fact refinements. Per-slot independence ⇒ the diagram factors as a product = the parallel decomposition (per-slot ↔ compound-cell components at F-row; set-latch/broadcast per key). F1a: documentation; F-row: operational.

## §6 Principles gate (challenge column)

| Decision | Serves | Challenge |
|---|---|---|
| One carrier, two surface nodes, key-domain tag (Q_A) | Most-Generalizable-Interface + Decomplection (laws decomplected by the tag) | More-aligned than pure-one-node (leaks laws across key-domain) AND than two-fully-separate (duplicates machinery + reopens tuple-subtype). Matches frontier (unify substrate, split surface). **Active enforcement**: a law reading the carrier without checking the key-domain tag = latent law-crossing bug. |
| Records vs dictionaries split | Decomplection | Challenged "too syntactic?": the *literal* is the one place the key set is a fact (TS fresh-literal / Typed-Clojure complete-HMap precedent). Q_E frames it as a D3 refinement (dyn-tailed instance), not a 3rd mechanism. |
| Tuple-by-default (Q_D) | First-Class-by-Default | Records already first-class per-field; array-by-default (TS) discards proven per-position facts + needs `as const` ceremony. Widening is a monotone Galois step, so no expressiveness lost. |
| Degrade-to-dictionary on dynamic keys (B4-gated) | Honest scoping | Now key-CHECKED (B4) — not "byte-identical" (that was false); preserves today's rejections. F1a scope boundary, D7 relocation scheduled. |
| No record/tuple-subtype judgment (D11) | Decomplection; compositional safety | Extends to tuples verbatim (per-position conjunction; Tang non-existence warrants refinement-only). `subtype-predicate.rkt` untouched — verified safe (compound-type? excludes the node → `subtype?` degrades to `equal?`, no unsoundness). |
| Union-widening VISIBLE not silent (flavor B) | Correct-by-Construction | Tang: unbounded widening breaks principality — keep `List<Int\|String>` a user-visible outcome; run the SRE lattice check on the union merge; union is a monotone join (CALM-safe). |

**NTT-relevance**: F1a adds **zero propagators, zero cells** — value-type-lattice representation inside imperative `infer`/`check` (same status as all typing-core; on-network typing is PPN's turf). Network Reality Check honestly returns "function-call chain" — correct for this layer (verified: map ops are `#f`-registered imperative returns, `typing-propagators:2366`; ctor-desc is positional so the row node can't ride it). The NTT-model obligation attaches at **F-row** (rows-as-cells, `Concat` 3-cell propagator, set-latch per-key). F1a carries only the forward-compat obligations (§4.1 key-domain generalization; ordinary metas; per-slot components) that keep F-row's path clear.

## §7 Pre-0 results + §7b re-verification

**§7 Pre-0** (unchanged from D.1, executed 2026-07-06): (1) serializer probe ✅ `record-field` struct SAFE (generic walk + empirical round-trip; `reg2!` each). (2) field-rep micro ✅ not perf-driven (<0.05µs lookup; sorted-assoc on determinism). (3) census ✅ small on the display grep — **corrected by S5**: `test-mixed-map.rkt` is the PPN 4C T-2 "Open by Design" contract file with ~10 colon-less `"Open"` assertions the display grep MISSED → s4 is flip-or-retire *decision* work (~2× budget) + a T-2-supersession note. (4) baseline ✅ elaborate 16 / type_check 37 / qtt 6 / zonk 22 / reduce 45 ms. (5) acceptance ✅ Level-3 WS wiring verified. (6) `run-file.rkt --check` ✅ shipped.

**§7b re-verification (D.2, executed 2026-07-06)** — the D.3-amended dispositions, probed at HEAD:
- Flavor-B projection ✅ **de-risked**: `pvec-nth (v:(PVec <Int|String>)) 0N` → `1 : Int | String`. Earlier "gap" was `0`(Int)-vs-`0N`(Nat) index, not the union. Flavor B needs only inference-widening, no new projection arm.
- Union normalization ✅ associative/flattening (`<Int|<String|Bool>>` ≡ `<<Int|String>|Bool>` ≡ `Int|String|Bool`); record-containing unions need the S1 `union-sort-key` case for commutativity (on the amendment list).
- Order-from-position ✅ (by construction: `⟨Int,String⟩`≠`⟨String,Int⟩` are distinct slot-maps) — no non-commutative monoid needed for F1a.
- Ordered-rows/concat principal-types: no impossibility (Wikipedia/Wand/Morris–McKinna); the concat principal-types issue is key-domain-agnostic = the record-concat issue already solved by D10 residuation; Ur/Web existence proof. **Deferred to F-row, inherits D10.**
- Distributivity ✅ RESOLVED (holds by construction, `type-lattice.rkt:263-274`).

## §8 Risks (updated) + coverage gaps

- ~~pnet nested-struct~~ ✅ (Pre-0 #1). ~~distributivity~~ ✅ (§7b). ~~map-merge-exists~~ ✅ folded (S6).
- **Union-arm `with-speculative-rollback` inconsistency** (`:1549-1568`, the "retired" mechanism): F1a extends this arm (accept Record components) but must NOT propagate the shape into new arms; excise-or-defer is an s3 call (tracking note if deferred).
- **Union-widening principality** (flavor B): keep VISIBLE; SRE lattice check on the union merge; not-yet-probed that a computed record-union stays non-⊤ (F1a-col gate).
- **Heterogeneous projections become precise** → code silently flowing `Open` into arithmetic may surface real errors (strictly more sound; suite quantifies).
- **Different-shape record collections** = named regression in F1a-core (escape hatch: `: (List <r1|r2>)`, verified to check), closed by F1a-col; prelude-loaded WS test pins it.
- **Dense-prefix / variadic / η** = F-row/F1b (existence-proofed; not F1a).
- **Coverage gaps to close** (from D.3, s1/s4): `reduction.rkt` whnf treatment of the node; cross-module `.pnet` consumer canary; pattern-match/narrowing over record scrutinees (probably nil — types not patterns — but assert); record-TYPE vs map-VALUE display collision in error/REPL/LSP contexts; trait dispatch on `(Map ?km Open)` literals today (2-line probe to settle S10 blast radius).

## §9 Deferred (explicit)

Flavor A tuple mint + Flavor B union-widen (F1a-col, still CIU-T6); dyn tails + Open deletion (F1a.2); width + seal + `closed?` scan + rank≤2/weak-preservation docs (F1b); `merge`/`deep-merge` nodes + M1 (F1a.2-era); ρ/`Concat`/`DeepConcat`/ambiguity-check (F-row; UCS-5+SRE-5); variadic tuples + η-on-closed (later CIU, possibly dependent-typed per owner Q_C note); variants (F-variant); presence marks beyond `'present` (with schema optional-keys); user-writable record/tuple type syntax; V2–V4 selection syntax (track doc).

## §10 The seven questions — resolutions (co-design, 2026-07-06)

1. **Q1 heterogeneous collections** → DESIGN GOAL (D13/D14): flavor A (tuple, net-new capability, fixes `@[1 "a"]` error) + flavor B (union-element list, turns the "regression" into a feature). Classifier is the correctness pivot. (F1a-col.)
2. **Q2 D3 end-state** → **(b)** `expr-Map`/`PVec` = dyn-tailed/uniform instances of the one carrier; F1a `Record<:Map` arm transitional; dyn tail carries (K,V) at F1a.2.
3. **Q3 record-meet different supports** → tension DISSOLVED: meet = D11 conjunction (contradiction on conflict, tuples too); collection-element = union (no meet). D6-vs-D11 was meet-vs-union conflation.
4. **Q4 stdlib map-merge** → retire-into-node (recommended) when the merge node lands; rides Q2(b). D10 semantics unaffected.
5. **Q5 union-arm miss** → union-PRESERVE (neither filter nor error for the collection case); field present-in-some-arm → `Option`/refinement.
6. **Q6 empty corners** → empty-record = empty-tuple = unit (row-monoid identity); `{} <: (Map K ?V)` succeeds WITHOUT solving V; `map-vals {}` → `(List fresh-meta)`; dissoc-absent = identity; dynamic-get-on-`{}` = miss error.
7. **Q7 dynamic update-in** → degrade to dictionary view (sound); tuple case admits a sharper bounds-checked answer via known length (small win). Literal paths safe (desugar).

Plus the collection forks: **Q_A** one-carrier/two-nodes ✅; **Q_B** forbid mixed-key ✅; **Q_C** closed tuples v1, variadic deferred ✅; **Q_D** tuple-by-default ✅; **Q_E** end-state (b) ✅.

## §11 D.3 critique disposition (finding → resolution)

**BLOCKING** (all CONFIRMED): **B1** seed breaks annotated literals → §4.2 seed-check arm (s2). **B2** subsumption unreachable from qtt → §4.3 qtt-fallback delegate (s2). **B3** Record-vs-Record unify undispositioned → §4.3 classify case (same-shape, s3) + union-widen for different-shape (F1a-col) + prelude WS test. **B4** dynamic-key drops key check → §4.3 Keyword gate (s3).
**SIGNIFICANT** (all CONFIRMED, folded): S1 union-sort-key (§4.1/s1) · S2 walker audit (§4.3/s1) · S3 fold/filter/map-vals + nil-safe-get union (§4.3/s3) · S4 qtt dissoc (§4.3) · S5 census re-budget + T-2 (§7) · S6 map-merge exists (§3/§4.4) · S7 diagnostic transport (§4.3) · S8 third mint site (get-in projection maps) → extend the seed rule or name-the-regression (s2) · S9 dynamic update-in degrade (§4.3/Q7) · S10 trait-resolution posture (§4.3) · S11 empty corners (§4.3/Q6) · S12 record-meet spec split + smart-constructor + distributivity-resolved (§4.1).
**REFUTED** (do NOT descope): literal-path get-in/update-in flips ARE deliverable (elaborator desugars — §3 last row); the s4 flips stand.
**Coverage gaps** → §8.

## §11a F1a-s2 implementation notes (what shipped + the design refinement it revealed)

**Delivered (commit at s2 close)**: elaborator classifier (all-keyword literal → record seed `(map-empty Keyword (Record 'keyword '() 'closed))`, growing via the map-assoc infer arm); projection (`map-get`/`get` → `record-project`); B1 (empty-record seed-check arm, `typing-core:~2485`); Record<:Map subsumption (`record-<:-map?`, in check-subsumption + qtt fallback = B2); qtt map-assoc/map-get/dissoc delegation (S4); the **full map-op surface pulled forward from s3** (dissoc/keys/vals/size/has-key/nil-safe-get Record arms — minting records makes these encounter records, so leaving them erroring would be a regression); smart-constructor helpers in `syntax.rkt` (`make-record` canonicalizes right-priority + sorted; `record-extend`/`record-remove`/`record-lookup-field`). 4 display-churn test files flipped (`test-first-class-paths`, `test-mixed-map` [the T-2 "Open by Design" contract file — SUPERSEDED per D7, its α-Open-trust tests now assert the sound static behavior], `test-path-expressions`, `test-postfix-index-03`).

**DESIGN REFINEMENT (the implementation revealed, per the per-phase discipline)**: D.2 §4.3 said the Record→Map α is "a local **check** arm" and "F1a leaves `subtype-predicate.rkt`/`unify` untouched." **That was insufficient.** The α must ALSO be reachable from:
- **`subtype?` + `structural-subtype-ground?`** (`subtype-predicate.rkt`) — for **nested** subsumption: `(List Record) <: (List Map)` recurses through the covariant List walk (`structural-subtype-ground?`, NOT `subtype?` at top), so `record-subtypes-map?` (pure structural, V concrete) lives in both.
- **`classify-whnf-problem`** (`unify.rkt`) — for **polymorphic** subsumption: `'[{:a 1}] = (cons {:a 1} nil)` commits `cons`'s element param to the record, which then meets the `(List (Map K V))` annotation through `unify` (not check). A directional `(Record,Map)`+`(Map,Record)` coercion (always `record-subtypes-map?(record,map)`) reconciles the concrete-V case here; meta-V falls through to check-subsumption's meta-solving arm.

This is a **scope refinement, not a principle violation**: **D11 (no record<:record judgment) is preserved** — this is the record→Map **α bridge** (a record projected to its uniform-Map view, Q_E), reachable wherever a record meets a Map in a subsumption context. Concretely: `record-subtypes-map?` (pure, in `subtype-predicate.rkt`, provided to `unify`) for structural/nested; `record-<:-map?` (in `typing-core`, solves meta-V) for the top-level check arm. Regression that forced this: `postfix-index-03`'s `def xs : (List (Map Keyword Nat)) := '[{:age 25N} …]` (before s2 it worked via `(Map K Open)`'s `Open` unifying with `Nat`; records don't, so the bridge is required). **Amend D.2 §4.3's "untouched" claim accordingly.**

**Deferred to s3 (genuinely remaining)**: B3 Record-vs-Record same-shape unify classify case + the prelude-loaded WS test; B4 the acceptance dynamic-key canaries; S3 fold-entries/filter-entries/map-map-vals arms + the union-arm Record components; S7 the rich closed-row-miss diagnostic (currently a plain "Could not infer type"); S10 trait-resolution ground-expr? arm + posture; the cross-module `.pnet` canary. Flavor A/B = F1a-col.

## §11b F1a-s3 close notes (2026-07-06)

**Shipped**: B3 `a5c546c8` · S3+B4 `83bd416f` · S7+canary `d08e14bf` (details in the tracker row + commit messages). Suite GREEN 8586/451/0; acceptance 37/37.

**S10 posture (documented)**: record types match **no Map-headed instance head** in F1a — `expr->impl-key-str` has no Record case, so trait dispatch on a record-typed value yields a clean no-instance error, never a crash; `ground-expr?` has the Record arm (s1) so meta-bearing records don't misreport ground. The escape hatch is annotation (the record subsumes into `(Map K V)` via the α, and the Map-headed instance then matches). The α-bridge at constraint-argument position is F1b/UCS-5 material.

**B3 known limitation (documented in `a5c546c8`)**: a degenerate cross-command flow — a `def` that leaves an *unsolved meta* inside a record field's type, later force-solved by same-shape unification in a NEW command — hits `solve-meta!`'s unknown-metavariable path (pre-existing cross-command meta-staleness, surfaced not caused by B3; single-command flows are clean; zero suite hits).

**Non-reachability notes (asserted, not assumed)**:
- *Narrowing / match*: record-typed scrutinees flow through `match` cleanly (probed: literal-arm dispatch on a projected field + wildcard on the record value itself — 0 errors). Records are TYPES; map values aren't constructor patterns; no pattern-compiler arms needed in F1a.
- *Transients*: the transient-builder path (`expr-trrb`/`expr-tchamp` → persist) is dictionary-flow; records never arise there (record types mint only at the keyword-literal seed).
- *reduction sets*: `expr-Record` joined `trivially-whnf?`/nf-identity at s1 (a TYPE node, never in value position; runtime values remain champs).

**S7 check-path note**: the rich message rides `infer/err` (the #70 precedent). The `check/err` path (e.g. an annotated def whose body contains the miss) still gets the plain failure — extend the hint there only if it proves annoying in practice.
