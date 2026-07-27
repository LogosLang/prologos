cpu time: 0 real time: 0 gc time: 0
## Phase 9 Findings — Comprehensive Lattice Variety Sweep

**Generated**: by `tools/run-phase9-sweep.rkt`
**Sweep params**: per-ctor-count 2, depth ∈ {0 (ground), 1 (wider)}
**Domains × relations swept**:
- `type × (equality subtype)`
- `session × (equality)`
- `form-cell × (equality)`
- `spec-cell × (equality)`

### Variety-placement summary

Each row places a `(domain × relation × depth)` lattice into the PTF lattice hierarchy. ✓ = property holds empirically; ✗ = refuted with witness; — = untested (no relation in registry, or property not testable on these samples). `(W)` = Whitman's W (free-lattice membership criterion, Nation 1982 Theorem 5.55/6.9).

| Domain | Relation | Depth | SD | Modular | Distributive | Heyting | Stone | Boolean | (W) | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| spec-cell | equality | ground | ✗ | ✗ | ✗ | ✗ | ✗ | — | ✓ | — |
| spec-cell | equality | wider | ✗ | ✗ | ✗ | ✗ | ✗ | — | ✓ | — |

### Per-finding detail

Witnesses are footnoted (W1, W2, ...) below the table. Non-vacuity % surfaces evidence-strength asymmetries (e.g., SD-vee 3.5% vs SD-wedge 91.4% on type×equality wider — most SD-vee triples don't fire the hypothesis non-trivially).

| Domain | Relation | Depth | Property | Samples | Status | Triples | Hypothesis fired | Conclusion held | Non-vacuity % | Witness |
|---|---|---|---|---|---|---|---|---|---|---|
| spec-cell | equality | ground | distributive | 5 | refuted | — | — | — | — | (W1) |
| spec-cell | equality | ground | sd-vee | 5 | refuted | 39 | 11 | 10 | 28.2% | (W1) |
| spec-cell | equality | ground | sd-wedge | 5 | refuted | 39 | 33 | 32 | 84.6% | (W1) |
| spec-cell | equality | ground | modular | 5 | refuted | 40 | 31 | 30 | 77.5% | (W2) |
| spec-cell | equality | ground | has-pseudo-complement-rel | 5 | refuted | 6 | 6 | 5 | 100.0% | (W3) |
| spec-cell | equality | ground | has-pseudo-complement-abs | 5 | refuted | — | — | — | — | (W4) |
| spec-cell | equality | ground | stone-identity | 5 | refuted | — | — | — | — | (W5) |
| spec-cell | equality | ground | whitmans-condition | 5 | confirmed | 625 | 546 | 546 | 87.4% | — |
| spec-cell | equality | ground | relatively-complemented | 5 | refuted | — | — | — | — | (W6) |
| spec-cell | equality | ground | sectionally-complemented | 5 | refuted | — | — | — | — | (W7) |
| spec-cell | equality | ground | breadth-bound | 5 | confirmed | 5 | 5 | 5 | 100.0% | — |
| spec-cell | equality | wider | distributive | 5 | refuted | — | — | — | — | (W1) |
| spec-cell | equality | wider | sd-vee | 5 | refuted | 39 | 11 | 10 | 28.2% | (W1) |
| spec-cell | equality | wider | sd-wedge | 5 | refuted | 39 | 33 | 32 | 84.6% | (W1) |
| spec-cell | equality | wider | modular | 5 | refuted | 40 | 31 | 30 | 77.5% | (W2) |
| spec-cell | equality | wider | has-pseudo-complement-rel | 5 | refuted | 6 | 6 | 5 | 100.0% | (W3) |
| spec-cell | equality | wider | has-pseudo-complement-abs | 5 | refuted | — | — | — | — | (W4) |
| spec-cell | equality | wider | stone-identity | 5 | refuted | — | — | — | — | (W5) |
| spec-cell | equality | wider | whitmans-condition | 5 | confirmed | 625 | 546 | 546 | 87.4% | — |
| spec-cell | equality | wider | relatively-complemented | 5 | refuted | — | — | — | — | (W6) |
| spec-cell | equality | wider | sectionally-complemented | 5 | refuted | — | — | — | — | (W7) |
| spec-cell | equality | wider | breadth-bound | 5 | confirmed | 5 | 5 | 5 | 100.0% | — |

### Witness footnotes

**W1**: `(list (spec-cell-value 'foo 'mock-Int-surf #f #f) (spec-cell-value 'foo 'mock-Bool-surf #f #f) (spec-cell-value 'bar 'mock-Int-surf #f #f))`

**W2**: `(list (spec-cell-value 'foo 'mock-Int-surf #f #f) (spec-cell-value 'foo 'mock-Bool-surf #f #f) (spec-cell-value #f #f #f #t))`

**W3**: `(list (spec-cell-value 'foo 'mock-Int-surf #f #f) (spec-cell-value #f #f #f #f))`

**W4**: `(list (spec-cell-value 'foo 'mock-Int-surf #f #f))`

**W5**: `(list (spec-cell-value 'foo 'mock-Int-surf #f #f) (spec-cell-value 'collision-top #f #f #t) (spec-cell-value #f #f #f #f) (spec-cell-value 'collision-top #f #f #t))`

**W6**: `(list (spec-cell-value #f #f #f #f) (spec-cell-value #f #f #f #t) (spec-cell-value 'foo 'mock-Int-surf #f #f))`

**W7**: `(list (spec-cell-value #f #f #f #t) (spec-cell-value 'foo 'mock-Int-surf #f #f))`

