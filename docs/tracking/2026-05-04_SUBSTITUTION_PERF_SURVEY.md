# Substitution Performance — Bug Analysis and Survey of Solutions

**Date**: 2026-05-04
**Topic**: O(N²) blow-up in Prologos's `subst` / `shift` and how the literature handles this class of bug.
**Status**: Research note; informs a future PM-series or new dedicated track.

## 1. The bug

Prologos's reducer uses **naive eager de Bruijn substitution**. Every `subst k s body` walks the body to materialize the substitution; every time it crosses a binder, it calls `(shift 1 (add1 cutoff) s)` on the substitution argument; `shift` recursively walks the argument tree.

When the substitution argument grows linearly with the workload — which happens whenever a tail-recursive function accumulates a value (parser, fold, reducer, etc.) — per-call `shift` cost grows linearly, and per-iteration × N iterations = **O(N²)**.

### Empirical signature

Pitfall #31, measured against the OCapN Syrup decoder (`decode-many-acc`):

| Counter | N=1 | N=5 | Ratio |
|---|---|---|---|
| input length (bytes) | 9 | 37 | 4.1x |
| wall time | 1750 ms | 47 495 ms | **27.1x ≈ N²** |
| `subst-nodes` | 4 243 | 83 887 | 19.8x ≈ N² |
| **`shift-nodes`** | **4 116** | **206 472** | **50.2x — above N²** |
| `whnf-calls` | 463 | 1 480 | 3.2x (sub-linear from memo) |
| `cache-time` | 3 ms | 17 ms | 5.7x — **0.04% of total** |

The cache (which I initially blamed) is innocent. `shift` is the bottleneck.

### Mechanism

1. `decode-many-acc` accumulates `(cons v acc)` per iteration. After K iterations the accumulator has K elements.
2. The recursive call `(decode-many-acc dec s end terminator (cons v acc))` triggers a beta-reduction.
3. Beta-reduction calls `subst k s body` on the function body.
4. The body has multiple nested binders. Each binder traversal in `subst` calls `(shift 1 cutoff s)` on the substitution argument `s`.
5. `s` contains the accumulator; `shift` walks every node of `s` to rebuild it with shifted bvar indices.
6. Total `shift` work per iteration ≈ (number-of-binder-traversals × |s|) = O(K).
7. Sum over N iterations of `decode-many-acc`: **Σ K = O(N²)**.

Source code references (commit `c1eb221`):
- [`shift`](https://github.com/LogosLang/prologos/blob/c1eb221/racket/prologos/substitution.rkt#L24) (substitution.rkt:24) — recursive walk
- [`subst`](https://github.com/LogosLang/prologos/blob/c1eb221/racket/prologos/substitution.rkt#L482) (substitution.rkt:482) — calls shift on every binder traversal
- [`decode-many-acc`](https://github.com/LogosLang/prologos/blob/c1eb221/racket/prologos/lib/prologos/ocapn/syrup-wire.prologos#L324-L335) — the user-level workload that triggers it

## 2. Why this is a textbook problem

The substitution-vs-environment trade-off is one of the foundational implementation questions in lambda-calculus interpreters. It's covered in:

- **Pierce, Benjamin C.** *Types and Programming Languages* (MIT Press, 2002), §5.3 "De Bruijn Indices" and §6.3 "Substitution". TAPL gives the exact naive `shift`/`subst` definitions Prologos uses, AND points out the performance trap: "this implementation is exponentially less efficient than it could be."
- **Cardelli, L., and Wegner, P.** "On Understanding Types, Data Abstraction, and Polymorphism" (ACM Comp. Surveys, 1985) — early analysis of the cost of substitution-based evaluation.

The standard fixes have been known since the late 1980s.

## 3. Survey of solutions

Ranked by how directly each maps to Prologos's situation.

### 3.1 Stored `looseBVarRange` + shift short-circuit (Lean 4)

**Cite**: Lean 4's `Expr` representation. Source: [`Lean/Expr.lean`](https://github.com/leanprover/lean4/blob/master/src/Lean/Expr.lean), specifically the `data : Expr.Data` field carrying `hash`, `looseBVarRange`, `approxDepth`, and `hasFVar`/`hasMVar`/`hasLooseBVars` flags.

> Each `Expr` carries a precomputed `looseBVarRange : UInt32`, the maximum (free) bound-variable index appearing in its subtree. The `lift` operation (= our `shift`) is:
> ```
> def lift (e : Expr) (depth shift : Nat) : Expr :=
>   if e.looseBVarRange ≤ depth then e   -- O(1) short-circuit
>   else ... recursive walk ...
> ```

This makes `shift` O(1) whenever the cutoff exceeds all free bvars in the argument. For our `(cons v acc)` workload, `looseBVarRange = 1` (the let-bound `v` and `acc` are at indices 0 and 1). Once `subst` has crossed two binders, `shift` becomes O(1) — no recursion needed.

**Fit for Prologos**: very direct. The change is a single `UInt32` field on each of the ~327 `expr-*` structs in `syntax.rkt`, populated at construction (analogous to Racket's `gen:equal+hash` in `expr-meta`). The constructor wrapper computes `looseBVarRange` from children's already-precomputed values in O(1) per construction. This is the **option 1** in the pitfall #31 PIR.

**References**:
- Lean source: [src/Lean/Expr.lean](https://github.com/leanprover/lean4/blob/master/src/Lean/Expr.lean) (`looseBVarRange`, `Expr.lift`, `Expr.lowerLooseBVars`)
- Lean's elaborator paper: de Moura & Ullrich, "The Lean 4 Theorem Prover and Programming Language" (CADE 2021). Discusses the `Expr` data layout including `looseBVarRange`.
- Coq's `Constr` has an analogous device (`Vars.lift`/`liftn` with similar short-circuiting via the `term_size` and structural traversal; less aggressive than Lean's).

### 3.2 Normalization by Evaluation (NbE)

**Cite**: Berger & Schwichtenberg, "An Inverse of the Evaluation Functional for Typed λ-Calculus" (LICS 1991). Foundational paper introducing NbE. Abel's PhD thesis ([Abel 2013, "Normalization by Evaluation: Dependent Types and Impredicativity"](http://www2.tcs.ifi.lmu.de/~abel/habil.pdf)) is the comprehensive modern treatment.

> NbE evaluates a term to a *semantic value* in a domain that uses host-language functions for binders (closures), then *quotes* the value back to a syntactic term when needed. Substitution is replaced by environment lookup at the leaf: per beta-reduction is O(1), `shift` doesn't appear.

```
type value = VLam of (value → value) | VApp of value × value | VVar of int | ...

eval env (Lam body) = VLam (λv. eval (v :: env) body)   -- O(1); body untouched
eval env (App f x)  = apply (eval env f) (eval env x)
eval env (BVar i)   = List.nth env i                     -- substitution at the leaf
```

**Used by**: Agda (Norell's PhD thesis 2007 + GHC-backed evaluator), Coq's `vm_compute` and `native_compute`, Idris 2 ([Brady 2021, "Idris 2: Quantitative Type Theory in Practice"](https://www.type-driven.org.uk/edwinb/papers/idris2.pdf)), Lean 4's reducer (uses NbE-style closures for normalization). Andreas Abel's TT-related proof assistants all use NbE.

**Fit for Prologos**: theoretically the right answer. Avoids the bug class entirely. But it's a **rewrite of the reducer** — Prologos's `whnf-impl`, `nf`, `subst`, `shift` all need replacing. Multi-month track. Worth doing eventually for self-hosting performance.

**References**:
- Abel, A. *Normalization by Evaluation: Dependent Types and Impredicativity.* Habilitation thesis, LMU Munich, 2013.
- Brady, E. "Idris 2: Quantitative Type Theory in Practice." ECOOP 2021.
- Coquand, T., and Huet, G. "The Calculus of Constructions." Information and Computation, 1988.

### 3.3 Explicit Substitutions (λσ-calculus)

**Cite**: **Abadi, Cardelli, Curien, Lévy.** "Explicit Substitutions." Proc. POPL 1990; *Journal of Functional Programming* 1(4), 1991. The foundational paper. ([PDF](https://web.cs.ucla.edu/~palsberg/course/cs232/papers/AbadiCarLev-pomi91.pdf).)

> Substitution becomes a *syntactic* operation `e[σ]` that's reduced lazily. Subst calls don't walk the term — they attach `[σ]` to the head. Reduction propagates `[σ]` into subterms only as needed, and *composes* substitutions when they meet.

```
e[σ][τ]  ⇒  e[σ ∘ τ]              -- composition rule
(λ.e)[σ] ⇒  λ.(e[1 · (σ ∘ ↑)])    -- pushing σ under a binder
```

The classic ACCL calculus, plus the simpler λυ ([Curien-Hardin-Lévy "Confluence Properties of Weak and Strong Calculi of Explicit Substitutions" JACM 1996](https://dl.acm.org/doi/10.1145/233551.233558)) and λx ([Bloo & Rose 1995](https://www.win.tue.nl/~bloo/research/lambda-x.ps)) variants.

**Used by**: Coq's kernel uses a variant of explicit substitutions ([Barras 1996, "Coq en Coq"](https://www.lri.fr/~barras/publi/coqincoq.pdf)). The Edinburgh LF (Twelf) and the Beluga project use related ideas.

**Fit for Prologos**: medium-large refactor of the AST + reducer. New `expr-subst` constructor; new reduction rules. Theoretically elegant. In practice, looseBVarRange-style annotations achieve most of the same wins with less invasive change.

**References**:
- Abadi, M., Cardelli, L., Curien, P.-L., Lévy, J.-J. "Explicit Substitutions." POPL 1990 / JFP 1(4) 1991.
- Curien, P.-L., Hardin, T., Lévy, J.-J. "Confluence Properties of Weak and Strong Calculi of Explicit Substitutions." JACM 43(2), 1996.
- Barras, B. "Coq en Coq." INRIA TR 3026, 1996.

### 3.4 Hash-Consing / Structural Sharing

**Cite**: Filliâtre & Conchon, "Type-Safe Modular Hash-Consing." ([ML Workshop 2006](https://www.lri.fr/~filliatr/publis/hash-consing2.pdf), [JFP 2009](https://www.lri.fr/~filliatr/publis/hash-consing-jfp.pdf)). Comprehensive treatment of hash-consing in OCaml.

> Intern all expressions through a hashtable so that structurally equal expressions share identity. `equal?` becomes `eq?` (O(1)). Combined with content-hashes, every cache lookup, every `equal?` test in pattern matching, every `hashtable-ref` becomes O(1).

**Used by**: GHC's `Type` system for type-equality testing (Sulzmann et al. 2007); Coq's `Constr` interns terms during normalization; SMT solvers universally hash-cons (Z3, CVC5).

**Fit for Prologos**: complementary to looseBVarRange. With hash-consing, even the cases where `shift` does have to walk become much cheaper because each `expr-app`/`expr-lam` allocation goes through an intern table. But hash-consing alone doesn't solve the O(N²) blow-up — the walks still happen, they just allocate less.

**References**:
- Filliâtre, J.-C., Conchon, S. "Type-Safe Modular Hash-Consing." ACM ML Workshop 2006.
- Goubault, J. "HimML: Standard ML with fast sets and hash tables." ACM Symposium on Lisp and Functional Programming, 1994 (early hash-consing implementation).
- Sulzmann, M., et al. "System F with Type Equality Coercions." TLDI 2007 (GHC's Type system).

### 3.5 Higher-Order Abstract Syntax (HOAS / PHOAS)

**Cite**: Pfenning & Elliott, "Higher-Order Abstract Syntax." PLDI 1988. ([PDF](https://www.cs.cmu.edu/~fp/papers/pldi88.pdf).)

> Use the meta-language's own binders to represent object-language binders. Substitution is meta-language application: `subst x v body = body v` if `body` is a meta-level function. Eliminates the bug class entirely at the cost of giving up syntactic introspection of bodies.

**Used by**: Twelf, Beluga, the LF family. Coq's `Reflect` library and Idris's `quotation` interface use Parametric HOAS variants ([Chlipala 2008, "Parametric Higher-Order Abstract Syntax for Mechanized Semantics"](http://adam.chlipala.net/papers/PhoasICFP08/)).

**Fit for Prologos**: not directly applicable. Would require giving up direct manipulation of expression trees, which Prologos's elaborator and propagator network depend on heavily. NbE captures most of HOAS's benefit while keeping introspection.

## 4. Comparison table

| Approach | Asymptotic fix | Effort for Prologos | Side benefits | Risk |
|---|---|---|---|---|
| 3.1 looseBVarRange | shift becomes O(1) when cutoff > range | Medium: 327 structs × 1 field, mechanical | Helps all reduction, not just decoder | Low — additive |
| 3.2 NbE rewrite | substitution eliminated entirely | Very high: months; rewrite reducer | Major perf win for everything | Medium — large diff |
| 3.3 Explicit subst | substitution work amortized | High: AST extension + reducer rewrite | Theoretically elegant | Medium |
| 3.4 Hash-consing | constant-factor everywhere; no asymptotic improvement | Medium: intern table + struct change | Faster cache lookups, smaller heap | Low |
| 3.5 HOAS | eliminates bug | Very high; incompatible with current AST | — | Very high — breaks elaborator |

## 5. Recommendation

**Implement 3.1 (looseBVarRange) first.** It's the smallest change that addresses the measured workload, has direct precedent in Lean, and doesn't preclude later moves to NbE.

Concrete plan:

1. Add a `loose-bvar-range : Fixnum` field to every `expr-*` struct in `syntax.rkt`.
2. Define `compute-loose-bvar-range : Expr → Fixnum` by structural recursion (max of children, +1 under `expr-lam`/`expr-Pi`/`expr-Sigma`, special case for `expr-bvar`).
3. Wrap each struct constructor with a `#:guard` that fills the field at allocation time, in O(1) using already-computed children's values.
4. Modify `shift`'s entry to short-circuit: `(if (≤ (loose-bvar-range e) cutoff) e ...)`.
5. Re-run `tests/test-bridge-perf.rkt`. Expect N=5 to drop from 47 s to <10 s; expect linear scaling for N=10/20.
6. Full suite green. PIR.

Estimated effort: 5–9 hours focused work, in line with the original investigation document's content-hash estimate. The migration is mechanical (one field per struct) so a Racket macro can generate the boilerplate.

**Defer 3.2 (NbE) for a future track.** Worth doing for self-hosting performance and for theoretical cleanliness, but it's a multi-month rewrite that the OCapN port doesn't need to wait for.

**3.4 (hash-consing) is complementary** — once we have content-hashes (which the looseBVarRange field can co-locate with a content-hash field), hash-consing is a follow-up of a few hours.

## 6. References (consolidated)

1. **Abadi, M., Cardelli, L., Curien, P.-L., Lévy, J.-J.** "Explicit Substitutions." *POPL 1990 / JFP 1(4) 1991.* https://web.cs.ucla.edu/~palsberg/course/cs232/papers/AbadiCarLev-pomi91.pdf
2. **Abel, A.** *Normalization by Evaluation: Dependent Types and Impredicativity.* Habilitation thesis, LMU Munich, 2013. http://www2.tcs.ifi.lmu.de/~abel/habil.pdf
3. **Barras, B.** "Coq en Coq." INRIA Research Report 3026, 1996.
4. **Berger, U., Schwichtenberg, H.** "An Inverse of the Evaluation Functional for Typed λ-Calculus." *LICS 1991.*
5. **Brady, E.** "Idris 2: Quantitative Type Theory in Practice." *ECOOP 2021.* https://www.type-driven.org.uk/edwinb/papers/idris2.pdf
6. **Chlipala, A.** "Parametric Higher-Order Abstract Syntax for Mechanized Semantics." *ICFP 2008.* http://adam.chlipala.net/papers/PhoasICFP08/
7. **Coquand, T., Huet, G.** "The Calculus of Constructions." *Information and Computation, 1988.*
8. **Curien, P.-L., Hardin, T., Lévy, J.-J.** "Confluence Properties of Weak and Strong Calculi of Explicit Substitutions." *JACM 43(2), 1996.* https://dl.acm.org/doi/10.1145/233551.233558
9. **de Moura, L., Ullrich, S.** "The Lean 4 Theorem Prover and Programming Language." *CADE 2021.*
10. **Filliâtre, J.-C., Conchon, S.** "Type-Safe Modular Hash-Consing." *ACM ML Workshop 2006 / JFP 2009.* https://www.lri.fr/~filliatr/publis/hash-consing-jfp.pdf
11. **Pfenning, F., Elliott, C.** "Higher-Order Abstract Syntax." *PLDI 1988.* https://www.cs.cmu.edu/~fp/papers/pldi88.pdf
12. **Pierce, B. C.** *Types and Programming Languages.* MIT Press, 2002. Chapter 5–6.
13. **Sulzmann, M., et al.** "System F with Type Equality Coercions." *TLDI 2007.*

## 7. Cross-references in the Prologos repo

- `docs/tracking/2026-04-27_GOBLIN_PITFALLS.md` § #31 — original bug catalog entry
- `docs/tracking/2026-05-04_DECODER_PERF_INVESTIGATION.md` — first analysis (incorrectly identified the cache as the cause)
- `docs/tracking/2026-05-04_DECODER_PERF_FIX_PIR.md` — three failed fixes + correct identification of `shift` as the bottleneck via instrumentation
- `racket/prologos/tests/test-bridge-perf.rkt` — the scaling-behavior diagnostic that produces the empirical signature
- `racket/prologos/substitution.rkt` — site of the bug; `shift` and `subst` definitions
- `racket/prologos/syntax.rkt` — site of the recommended fix (add `loose-bvar-range` field to ~327 `expr-*` structs)
