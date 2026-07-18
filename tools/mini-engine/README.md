# mini-prologos — a pocket stratified-Datalog engine in the WS syntax

A ~300-line, dependency-free JavaScript engine that parses the
`defr` / `||` / `&>` / `solve` subset of Prologos WS-mode surface syntax and
evaluates it bottom-up: monotone joins to a Tarski fixpoint per stratum,
negation-as-failure only at stratum boundaries, with a round-by-round trace
and a one-flag CALM order-independence check.

**Provenance.** Built as the live in-browser engine for an interactive
explainer of Prologos's lattice/CALM foundations (the "First, Choose Your
Lattice" artifact, third in a series alongside Kuper's LVars dissertation,
Radul's propagation networks, and the CALM theorem paper). Packaged here as a
teaching and demo artifact — external contribution, not part of any Series
track.

**What it is NOT.** Not the Hyperlattice Compiler and not a Racket-pipeline
citizen. No types, traits, schemas, modes-as-contracts, tabling machinery,
`is`/functional goals, well-founded semantics, or the propagator substrate —
when it meets cyclic negation it refuses with an error that points at
`solver … :semantics well-founded`. It is a faithful miniature of the
*evaluation story* (S0 monotone rounds → quiescence gate → S1 NAF), useful
for demos, docs, and quick what-does-this-program-mean experiments.

## Files

| file | what |
|---|---|
| `mini-prologos.mjs` | the engine — pure ES module, no DOM, no deps |
| `cli.mjs` | Node runner with `--trace` and `--shuffle N` (CALM check) |
| `playground.html` | minimal browser playground (serve over HTTP) |
| `test.mjs` | assertions over the demo programs (`node test.mjs`) |
| `examples/prereqs.prologos` | transitive closure (relational-demo's course KB) |
| `examples/routing.prologos` | stratified NAF (WFLE acceptance §A4's blocked/reachable) |

## Quick start

```sh
cd tools/mini-engine
node test.mjs
node cli.mjs examples/prereqs.prologos 'solve (needs "CS401" req)' --trace --shuffle 20
node cli.mjs examples/routing.prologos 'solve (reachable "a" dest)' --trace
python3 -m http.server 8420   # then open http://localhost:8420/playground.html
```

Example output:

```
{:req "CS301"}
{:req "CS201"}
{:req "MA301"}
{:req "CS101"}
{:req "MA101"}

;; --- trace ---
;; S0 ground facts: prereq +5
;; S0 round 1: needs +5
;; S0 round 2: needs +3
;; S0 round 3: needs +1
;; quiescent — ...

;; CALM check: 20 shuffled schedules, fire counts 6–8, fixpoint IDENTICAL every run ✓
```

## Supported subset

```
ns <name>                          accepted, ignored
defr <name> [?a +b -c]             modes parsed, treated as documentation
  || "v1" "v2" ...                 fact rows: quoted strings, grouped by arity
  &> (goal) (goal) ...             rule clause; whitespace = conjunction,
                                   repeated &> = disjunction
goals    (rel a b) · (= a b) · (not (rel a b))
args     "quoted" = constant · bare symbol = logic variable
queries  solve (rel "const" var)   → list of binding maps
```

Semantics notes:

- **Evaluation** is naive round-based bottom-up per stratum; the trace labels
  rounds `S0 round 1 …` in the BSP spirit. Termination is structural: derived
  tuples live in set-union cells over a finite constant universe.
- **Stratification** is computed from negation edges; cyclic negation throws
  `non-stratifiable`, by design mirroring the default engine's refusal (the
  program wants the WFLE).
- **`not` goals** need ground arguments at evaluation time; the evaluator
  defers them behind positive goals within a clause where possible and throws
  an informative error otherwise.
- **CALM demos**: `evalProgram(rels, { shuffle })` takes any reordering
  function for rule sets and tuple iteration; `dbSignature` makes fixpoint
  equality checkable. `cli.mjs --shuffle N` packages the experiment.

## API

```js
import { solve, parseProgram, parseQuery, evalProgram,
         answers, dbSignature, shuffled } from './mini-prologos.mjs';

const { answers } = solve(programSrc, 'solve (needs "CS401" req)');
// → [{req: "CS301"}, …]

const rels = parseProgram(programSrc);
const res  = evalProgram(rels, { shuffle: shuffled });
// res.DB (name → Map), res.trace (rounds & gates), res.S (strata), res.fires
```
