cpu time: 1729661 real time: 1813311 gc time: 29270
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
| type | subtype | ground | ✓ | ✓ | ✓ | ✓ | ✗ | — | ✓ | — |
| type | subtype | wider | ✓ | ✗ | ✗ | ✗ | ✗ | — | ✓ | — |

### Per-finding detail

Witnesses are footnoted (W1, W2, ...) below the table. Non-vacuity % surfaces evidence-strength asymmetries (e.g., SD-vee 3.5% vs SD-wedge 91.4% on type×equality wider — most SD-vee triples don't fire the hypothesis non-trivially).

| Domain | Relation | Depth | Property | Samples | Status | Triples | Hypothesis fired | Conclusion held | Non-vacuity % | Witness |
|---|---|---|---|---|---|---|---|---|---|---|
| type | subtype | ground | distributive | 6 | confirmed | 216 | 216 | 216 | 100.0% | — |
| type | subtype | ground | sd-vee | 6 | confirmed | 216 | 78 | 78 | 36.1% | — |
| type | subtype | ground | sd-wedge | 6 | confirmed | 216 | 114 | 114 | 52.8% | — |
| type | subtype | ground | modular | 6 | confirmed | 216 | 96 | 96 | 44.4% | — |
| type | subtype | ground | has-pseudo-complement-rel | 6 | confirmed | 36 | 36 | 36 | 100.0% | — |
| type | subtype | ground | has-pseudo-complement-abs | 6 | confirmed | 6 | 6 | 6 | 100.0% | — |
| type | subtype | ground | stone-identity | 6 | refuted | — | — | — | — | (W1) |
| type | subtype | ground | whitmans-condition | 6 | confirmed | 1296 | 1082 | 1082 | 83.5% | — |
| type | subtype | ground | relatively-complemented | 6 | refuted | — | — | — | — | (W2) |
| type | subtype | ground | sectionally-complemented | 6 | refuted | — | — | — | — | (W3) |
| type | subtype | ground | breadth-bound | 6 | confirmed | 6 | 6 | 6 | 100.0% | — |
| type | subtype | wider | distributive | 58 | refuted | — | — | — | — | (W4) |
| type | subtype | wider | sd-vee | 58 | confirmed | 195112 | 6786 | 6786 | 3.5% | — |
| type | subtype | wider | sd-wedge | 58 | confirmed | 195112 | 178166 | 178166 | 91.3% | — |
| type | subtype | wider | modular | 58 | refuted | 95961 | 6558 | 6557 | 6.8% | (W5) |
| type | subtype | wider | has-pseudo-complement-rel | 58 | confirmed | 3364 | 3364 | 3364 | 100.0% | — |
| type | subtype | wider | has-pseudo-complement-abs | 58 | confirmed | 58 | 58 | 58 | 100.0% | — |
| type | subtype | wider | stone-identity | 58 | refuted | — | — | — | — | (W6) |
| type | subtype | wider | whitmans-condition | 58 | confirmed | 11316496 | 10756434 | 10756434 | 95.1% | — |
| type | subtype | wider | relatively-complemented | 58 | refuted | — | — | — | — | (W2) |
| type | subtype | wider | sectionally-complemented | 58 | refuted | — | — | — | — | (W3) |
| type | subtype | wider | breadth-bound | 58 | refuted | — | — | — | — | (W7) |

### Witness footnotes

**W1**: `(list (expr-Int) (expr-union (expr-Bool) (expr-String)) (expr-Int) (expr-union (expr-Bool) (expr-union (expr-Int) (expr-String))))`

**W2**: `(list (expr-Nat) 'type-top (expr-Int))`

**W3**: `(list (expr-Int) (expr-Nat))`

**W4**: `(list (expr-Pi 'm1 (expr-Bool) (expr-Bool)) (expr-Int) (expr-Pi 'm1 (expr-Int) (expr-Bool)))`

**W5**: `(list (expr-Pi 'm1 (expr-Bool) (expr-Bool)) (expr-Pi 'm1 (expr-Int) (expr-Bool)) (expr-Pi 'm1 (expr-Bool) (expr-Bool)))`

**W6**: `(list (expr-Int) (expr-union (expr-Bool) (expr-union (expr-String) (expr-union (expr-Eq (expr-Bool) (expr-Int) (expr-Int)) (expr-union (expr-Eq (expr-Bool) (expr-Int) (expr-Bool)) (expr-union (expr-Eq (expr-Bool) (expr-Bool) (expr-Int)) (expr-union (expr-Eq (expr-Bool) (expr-Bool) (expr-Bool)) (expr-union (expr-Eq (expr-Int) (expr-Int) (expr-Int)) (expr-union (expr-Eq (expr-Int) (expr-Int) (expr-Bool)) (expr-union (expr-Eq (expr-Int) (expr-Bool) (expr-Int)) (expr-union (expr-Eq (expr-Int) (expr-Bool) (expr-Bool)) (expr-union (expr-Fin (expr-Bool)) (expr-union (expr-Fin (expr-Int)) (expr-union (expr-Map (expr-Bool) (expr-Bool)) (expr-union (expr-Map (expr-Bool) (expr-Int)) (expr-union (expr-Map (expr-Int) (expr-Bool)) (expr-union (expr-Map (expr-Int) (expr-Int)) (expr-union (expr-PVec (expr-Bool)) (expr-union (expr-PVec (expr-Int)) (expr-union (expr-Pi 'mw (expr-Bool) (expr-Bool)) (expr-union (expr-Pi 'm1 (expr-Bool) (expr-Bool)) (expr-union (expr-Pi 'mw (expr-Bool) (expr-Int)) (expr-union (expr-Pi 'm1 (expr-Bool) (expr-Int)) (expr-union (expr-Pi 'mw (expr-Int) (expr-Bool)) (expr-union (expr-Pi 'm1 (expr-Int) (expr-Bool)) (expr-union (expr-Pi 'mw (expr-Int) (expr-Int)) (expr-union (expr-Pi 'm1 (expr-Int) (expr-Int)) (expr-union (expr-Set (expr-Bool)) (expr-union (expr-Set (expr-Int)) (expr-union (expr-Sigma (expr-Bool) (expr-Bool)) (expr-union (expr-Sigma (expr-Bool) (expr-Int)) (expr-union (expr-Sigma (expr-Int) (expr-Bool)) (expr-union (expr-Sigma (expr-Int) (expr-Int)) (expr-union (expr-Vec (expr-Bool) (expr-Int)) (expr-union (expr-Vec (expr-Bool) (expr-Bool)) (expr-union (expr-Vec (expr-Int) (expr-Int)) (expr-union (expr-Vec (expr-Int) (expr-Bool)) (expr-union (expr-app (expr-Int) (expr-Int)) (expr-union (expr-app (expr-Int) (expr-Bool)) (expr-union (expr-app (expr-Bool) (expr-Int)) (expr-union (expr-app (expr-Bool) (expr-Bool)) (expr-union (expr-pair (expr-Int) (expr-Int)) (expr-union (expr-pair (expr-Int) (expr-Bool)) (expr-union (expr-pair (expr-Bool) (expr-Int)) (expr-union (expr-pair (expr-Bool) (expr-Bool)) (expr-union (expr-suc (expr-Int)) (expr-union (expr-suc (expr-Bool)) (expr-union (expr-lam 'mw (expr-Int) (expr-Int)) (expr-union (expr-lam 'mw (expr-Int) (expr-Bool)) (expr-union (expr-lam 'mw (expr-Bool) (expr-Int)) (expr-union (expr-lam 'mw (expr-Bool) (expr-Bool)) (expr-union (expr-lam 'm1 (expr-Int) (expr-Int)) (expr-union (expr-lam 'm1 (expr-Int) (expr-Bool)) (expr-union (expr-lam 'm1 (expr-Bool) (expr-Int)) (expr-lam 'm1 (expr-Bool) (expr-Bool))))))))))))))))))))))))))))))))))))))))))))))))))))))) (expr-Int) (expr-union (expr-Bool) (expr-union (expr-Int) (expr-union (expr-String) (expr-union (expr-Eq (expr-Bool) (expr-Int) (expr-Int)) (expr-union (expr-Eq (expr-Bool) (expr-Int) (expr-Bool)) (expr-union (expr-Eq (expr-Bool) (expr-Bool) (expr-Int)) (expr-union (expr-Eq (expr-Bool) (expr-Bool) (expr-Bool)) (expr-union (expr-Eq (expr-Int) (expr-Int) (expr-Int)) (expr-union (expr-Eq (expr-Int) (expr-Int) (expr-Bool)) (expr-union (expr-Eq (expr-Int) (expr-Bool) (expr-Int)) (expr-union (expr-Eq (expr-Int) (expr-Bool) (expr-Bool)) (expr-union (expr-Fin (expr-Bool)) (expr-union (expr-Fin (expr-Int)) (expr-union (expr-Map (expr-Bool) (expr-Bool)) (expr-union (expr-Map (expr-Bool) (expr-Int)) (expr-union (expr-Map (expr-Int) (expr-Bool)) (expr-union (expr-Map (expr-Int) (expr-Int)) (expr-union (expr-PVec (expr-Bool)) (expr-union (expr-PVec (expr-Int)) (expr-union (expr-Pi 'mw (expr-Bool) (expr-Bool)) (expr-union (expr-Pi 'm1 (expr-Bool) (expr-Bool)) (expr-union (expr-Pi 'mw (expr-Bool) (expr-Int)) (expr-union (expr-Pi 'm1 (expr-Bool) (expr-Int)) (expr-union (expr-Pi 'mw (expr-Int) (expr-Bool)) (expr-union (expr-Pi 'm1 (expr-Int) (expr-Bool)) (expr-union (expr-Pi 'mw (expr-Int) (expr-Int)) (expr-union (expr-Pi 'm1 (expr-Int) (expr-Int)) (expr-union (expr-Set (expr-Bool)) (expr-union (expr-Set (expr-Int)) (expr-union (expr-Sigma (expr-Bool) (expr-Bool)) (expr-union (expr-Sigma (expr-Bool) (expr-Int)) (expr-union (expr-Sigma (expr-Int) (expr-Bool)) (expr-union (expr-Sigma (expr-Int) (expr-Int)) (expr-union (expr-Vec (expr-Bool) (expr-Int)) (expr-union (expr-Vec (expr-Bool) (expr-Bool)) (expr-union (expr-Vec (expr-Int) (expr-Int)) (expr-union (expr-Vec (expr-Int) (expr-Bool)) (expr-union (expr-app (expr-Int) (expr-Int)) (expr-union (expr-app (expr-Int) (expr-Bool)) (expr-union (expr-app (expr-Bool) (expr-Int)) (expr-union (expr-app (expr-Bool) (expr-Bool)) (expr-union (expr-pair (expr-Int) (expr-Int)) (expr-union (expr-pair (expr-Int) (expr-Bool)) (expr-union (expr-pair (expr-Bool) (expr-Int)) (expr-union (expr-pair (expr-Bool) (expr-Bool)) (expr-union (expr-suc (expr-Int)) (expr-union (expr-suc (expr-Bool)) (expr-union (expr-lam 'mw (expr-Int) (expr-Int)) (expr-union (expr-lam 'mw (expr-Int) (expr-Bool)) (expr-union (expr-lam 'mw (expr-Bool) (expr-Int)) (expr-union (expr-lam 'mw (expr-Bool) (expr-Bool)) (expr-union (expr-lam 'm1 (expr-Int) (expr-Int)) (expr-union (expr-lam 'm1 (expr-Int) (expr-Bool)) (expr-union (expr-lam 'm1 (expr-Bool) (expr-Int)) (expr-lam 'm1 (expr-Bool) (expr-Bool)))))))))))))))))))))))))))))))))))))))))))))))))))))))))`

**W7**: `(list (expr-Eq (expr-Bool) (expr-Bool) (expr-Int)) (expr-Eq (expr-Bool) (expr-Bool) (expr-Bool)) (expr-String) (expr-Bool) (expr-Int))`

