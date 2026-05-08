cpu time: 266 real time: 279 gc time: 11
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
| session | equality | ground | ✗ | ✓ | ✗ | ✗ | ✗ | — | ✓ | — |
| session | equality | wider | ✗ | ✓ | ✗ | ✗ | ✗ | — | ✓ | — |

### Per-finding detail

Witnesses are footnoted (W1, W2, ...) below the table. Non-vacuity % surfaces evidence-strength asymmetries (e.g., SD-vee 3.5% vs SD-wedge 91.4% on type×equality wider — most SD-vee triples don't fire the hypothesis non-trivially).

| Domain | Relation | Depth | Property | Samples | Status | Triples | Hypothesis fired | Conclusion held | Non-vacuity % | Witness |
|---|---|---|---|---|---|---|---|---|---|---|
| session | equality | ground | distributive | 3 | refuted | — | — | — | — | (W1) |
| session | equality | ground | sd-vee | 3 | refuted | 6 | 3 | 2 | 50.0% | (W1) |
| session | equality | ground | sd-wedge | 3 | refuted | 6 | 3 | 2 | 50.0% | (W1) |
| session | equality | ground | modular | 3 | confirmed | 27 | 9 | 9 | 33.3% | — |
| session | equality | ground | has-pseudo-complement-rel | 3 | refuted | 2 | 2 | 1 | 100.0% | (W2) |
| session | equality | ground | has-pseudo-complement-abs | 3 | confirmed | 3 | 3 | 3 | 100.0% | — |
| session | equality | ground | stone-identity | 3 | confirmed | 0 | 0 | 0 | 100.0% | — |
| session | equality | ground | whitmans-condition | 3 | confirmed | 81 | 75 | 75 | 92.6% | — |
| session | equality | ground | relatively-complemented | 3 | confirmed | 3 | 3 | 3 | 100.0% | — |
| session | equality | ground | sectionally-complemented | 3 | refuted | — | — | — | — | (W3) |
| session | equality | ground | breadth-bound | 3 | confirmed | 3 | 3 | 3 | 100.0% | — |
| session | equality | wider | distributive | 29 | refuted | — | — | — | — | (W1) |
| session | equality | wider | sd-vee | 29 | refuted | 32 | 3 | 2 | 9.4% | (W1) |
| session | equality | wider | sd-wedge | 29 | refuted | 32 | 3 | 2 | 9.4% | (W1) |
| session | equality | wider | modular | 29 | confirmed | 24389 | 841 | 841 | 3.4% | — |
| session | equality | wider | has-pseudo-complement-rel | 29 | refuted | 2 | 2 | 1 | 100.0% | (W2) |
| session | equality | wider | has-pseudo-complement-abs | 29 | confirmed | 29 | 29 | 29 | 100.0% | — |
| session | equality | wider | stone-identity | 29 | confirmed | 0 | 0 | 0 | 100.0% | — |
| session | equality | wider | whitmans-condition | 29 | confirmed | 707281 | 706469 | 706469 | 99.9% | — |
| session | equality | wider | relatively-complemented | 29 | confirmed | 29 | 29 | 29 | 100.0% | — |
| session | equality | wider | sectionally-complemented | 29 | refuted | — | — | — | — | (W3) |
| session | equality | wider | breadth-bound | 29 | refuted | — | — | — | — | (W4) |

### Witness footnotes

**W1**: `(list (sess-end) (sess-svar 0) #f)`

**W2**: `(list (sess-end) (sess-svar 0))`

**W3**: `(list (sess-end) (sess-end))`

**W4**: `(list (sess-dsend (expr-Bool) (sess-end)) (sess-dsend (expr-Bool) (sess-svar 0)) #f (sess-svar 0) (sess-end))`

