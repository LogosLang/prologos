cpu time: 1945604 real time: 2040801 gc time: 35734
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
| type | equality | ground | ✓ | ✓ | ✓ | ✓ | ✗ | — | ✓ | — |
| type | equality | wider | ✓ | ✓ | ✗ | ✗ | ✗ | — | ✓ | — |

### Per-finding detail

Witnesses are footnoted (W1, W2, ...) below the table. Non-vacuity % surfaces evidence-strength asymmetries (e.g., SD-vee 3.5% vs SD-wedge 91.4% on type×equality wider — most SD-vee triples don't fire the hypothesis non-trivially).

| Domain | Relation | Depth | Property | Samples | Status | Triples | Hypothesis fired | Conclusion held | Non-vacuity % | Witness |
|---|---|---|---|---|---|---|---|---|---|---|
| type | equality | ground | distributive | 6 | confirmed | 216 | 216 | 216 | 100.0% | — |
| type | equality | ground | sd-vee | 6 | confirmed | 216 | 74 | 74 | 34.3% | — |
| type | equality | ground | sd-wedge | 6 | confirmed | 216 | 122 | 122 | 56.5% | — |
| type | equality | ground | modular | 6 | confirmed | 216 | 90 | 90 | 41.7% | — |
| type | equality | ground | has-pseudo-complement-rel | 6 | confirmed | 36 | 36 | 36 | 100.0% | — |
| type | equality | ground | has-pseudo-complement-abs | 6 | confirmed | 6 | 6 | 6 | 100.0% | — |
| type | equality | ground | stone-identity | 6 | refuted | — | — | — | — | (W1) |
| type | equality | ground | whitmans-condition | 6 | confirmed | 1296 | 1079 | 1079 | 83.3% | — |
| type | equality | ground | relatively-complemented | 6 | refuted | — | — | — | — | (W2) |
| type | equality | ground | sectionally-complemented | 6 | refuted | — | — | — | — | (W3) |
| type | equality | ground | breadth-bound | 6 | confirmed | 6 | 6 | 6 | 100.0% | — |
| type | equality | wider | distributive | 58 | refuted | — | — | — | — | (W4) |
| type | equality | wider | sd-vee | 58 | confirmed | 195112 | 6814 | 6814 | 3.5% | — |
| type | equality | wider | sd-wedge | 58 | confirmed | 195112 | 178382 | 178382 | 91.4% | — |
| type | equality | wider | modular | 58 | confirmed | 195112 | 9918 | 9918 | 5.1% | — |
| type | equality | wider | has-pseudo-complement-rel | 58 | confirmed | 3364 | 3364 | 3364 | 100.0% | — |
| type | equality | wider | has-pseudo-complement-abs | 58 | confirmed | 58 | 58 | 58 | 100.0% | — |
| type | equality | wider | stone-identity | 58 | refuted | — | — | — | — | (W5) |
| type | equality | wider | whitmans-condition | 58 | confirmed | 11316496 | 10762127 | 10762127 | 95.1% | — |
| type | equality | wider | relatively-complemented | 58 | refuted | — | — | — | — | (W2) |
| type | equality | wider | sectionally-complemented | 58 | refuted | — | — | — | — | (W3) |
| type | equality | wider | breadth-bound | 58 | refuted | — | — | — | — | (W6) |

### Witness footnotes

**W1**: `(list (expr-Int) (expr-union (expr-Bool) (expr-union (expr-Nat) (expr-String))) (expr-Int) (expr-union (expr-Bool) (expr-union (expr-Int) (expr-union (expr-Nat) (expr-String)))))`

**W2**: `(list 'type-bot 'type-top (expr-Int))`

**W3**: `(list 'type-top (expr-Int))`

**W4**: `(list (expr-Pi 'm1 (expr-Bool) (expr-Bool)) (expr-Int) (expr-Pi 'm1 (expr-Int) (expr-Bool)))`

**W5**: `(list (expr-Int) (expr-union (expr-Bool) (expr-union (expr-Nat) (expr-union (expr-String) (expr-union (expr-Eq (expr-Bool) (expr-Int) (expr-Int)) (expr-union (expr-Eq (expr-Bool) (expr-Int) (expr-Bool)) (expr-union (expr-Eq (expr-Bool) (expr-Bool) (expr-Int)) (expr-union (expr-Eq (expr-Bool) (expr-Bool) (expr-Bool)) (expr-union (expr-Eq (expr-Int) (expr-Int) (expr-Int)) (expr-union (expr-Eq (expr-Int) (expr-Int) (expr-Bool)) (expr-union (expr-Eq (expr-Int) (expr-Bool) (expr-Int)) (expr-union (expr-Eq (expr-Int) (expr-Bool) (expr-Bool)) (expr-union (expr-Fin (expr-Bool)) (expr-union (expr-Fin (expr-Int)) (expr-union (expr-Map (expr-Bool) (expr-Bool)) (expr-union (expr-Map (expr-Bool) (expr-Int)) (expr-union (expr-Map (expr-Int) (expr-Bool)) (expr-union (expr-Map (expr-Int) (expr-Int)) (expr-union (expr-PVec (expr-Bool)) (expr-union (expr-PVec (expr-Int)) (expr-union (expr-Pi 'mw (expr-Bool) (expr-Bool)) (expr-union (expr-Pi 'm1 (expr-Bool) (expr-Bool)) (expr-union (expr-Pi 'mw (expr-Bool) (expr-Int)) (expr-union (expr-Pi 'm1 (expr-Bool) (expr-Int)) (expr-union (expr-Pi 'mw (expr-Int) (expr-Bool)) (expr-union (expr-Pi 'm1 (expr-Int) (expr-Bool)) (expr-union (expr-Pi 'mw (expr-Int) (expr-Int)) (expr-union (expr-Pi 'm1 (expr-Int) (expr-Int)) (expr-union (expr-Set (expr-Bool)) (expr-union (expr-Set (expr-Int)) (expr-union (expr-Sigma (expr-Bool) (expr-Bool)) (expr-union (expr-Sigma (expr-Bool) (expr-Int)) (expr-union (expr-Sigma (expr-Int) (expr-Bool)) (expr-union (expr-Sigma (expr-Int) (expr-Int)) (expr-union (expr-Vec (expr-Bool) (expr-Int)) (expr-union (expr-Vec (expr-Bool) (expr-Bool)) (expr-union (expr-Vec (expr-Int) (expr-Int)) (expr-union (expr-Vec (expr-Int) (expr-Bool)) (expr-union (expr-app (expr-Int) (expr-Int)) (expr-union (expr-app (expr-Int) (expr-Bool)) (expr-union (expr-app (expr-Bool) (expr-Int)) (expr-union (expr-app (expr-Bool) (expr-Bool)) (expr-union (expr-pair (expr-Int) (expr-Int)) (expr-union (expr-pair (expr-Int) (expr-Bool)) (expr-union (expr-pair (expr-Bool) (expr-Int)) (expr-union (expr-pair (expr-Bool) (expr-Bool)) (expr-union (expr-suc (expr-Int)) (expr-union (expr-suc (expr-Bool)) (expr-union (expr-lam 'mw (expr-Int) (expr-Int)) (expr-union (expr-lam 'mw (expr-Int) (expr-Bool)) (expr-union (expr-lam 'mw (expr-Bool) (expr-Int)) (expr-union (expr-lam 'mw (expr-Bool) (expr-Bool)) (expr-union (expr-lam 'm1 (expr-Int) (expr-Int)) (expr-union (expr-lam 'm1 (expr-Int) (expr-Bool)) (expr-union (expr-lam 'm1 (expr-Bool) (expr-Int)) (expr-lam 'm1 (expr-Bool) (expr-Bool)))))))))))))))))))))))))))))))))))))))))))))))))))))))) (expr-Int) (expr-union (expr-Bool) (expr-union (expr-Int) (expr-union (expr-Nat) (expr-union (expr-String) (expr-union (expr-Eq (expr-Bool) (expr-Int) (expr-Int)) (expr-union (expr-Eq (expr-Bool) (expr-Int) (expr-Bool)) (expr-union (expr-Eq (expr-Bool) (expr-Bool) (expr-Int)) (expr-union (expr-Eq (expr-Bool) (expr-Bool) (expr-Bool)) (expr-union (expr-Eq (expr-Int) (expr-Int) (expr-Int)) (expr-union (expr-Eq (expr-Int) (expr-Int) (expr-Bool)) (expr-union (expr-Eq (expr-Int) (expr-Bool) (expr-Int)) (expr-union (expr-Eq (expr-Int) (expr-Bool) (expr-Bool)) (expr-union (expr-Fin (expr-Bool)) (expr-union (expr-Fin (expr-Int)) (expr-union (expr-Map (expr-Bool) (expr-Bool)) (expr-union (expr-Map (expr-Bool) (expr-Int)) (expr-union (expr-Map (expr-Int) (expr-Bool)) (expr-union (expr-Map (expr-Int) (expr-Int)) (expr-union (expr-PVec (expr-Bool)) (expr-union (expr-PVec (expr-Int)) (expr-union (expr-Pi 'mw (expr-Bool) (expr-Bool)) (expr-union (expr-Pi 'm1 (expr-Bool) (expr-Bool)) (expr-union (expr-Pi 'mw (expr-Bool) (expr-Int)) (expr-union (expr-Pi 'm1 (expr-Bool) (expr-Int)) (expr-union (expr-Pi 'mw (expr-Int) (expr-Bool)) (expr-union (expr-Pi 'm1 (expr-Int) (expr-Bool)) (expr-union (expr-Pi 'mw (expr-Int) (expr-Int)) (expr-union (expr-Pi 'm1 (expr-Int) (expr-Int)) (expr-union (expr-Set (expr-Bool)) (expr-union (expr-Set (expr-Int)) (expr-union (expr-Sigma (expr-Bool) (expr-Bool)) (expr-union (expr-Sigma (expr-Bool) (expr-Int)) (expr-union (expr-Sigma (expr-Int) (expr-Bool)) (expr-union (expr-Sigma (expr-Int) (expr-Int)) (expr-union (expr-Vec (expr-Bool) (expr-Int)) (expr-union (expr-Vec (expr-Bool) (expr-Bool)) (expr-union (expr-Vec (expr-Int) (expr-Int)) (expr-union (expr-Vec (expr-Int) (expr-Bool)) (expr-union (expr-app (expr-Int) (expr-Int)) (expr-union (expr-app (expr-Int) (expr-Bool)) (expr-union (expr-app (expr-Bool) (expr-Int)) (expr-union (expr-app (expr-Bool) (expr-Bool)) (expr-union (expr-pair (expr-Int) (expr-Int)) (expr-union (expr-pair (expr-Int) (expr-Bool)) (expr-union (expr-pair (expr-Bool) (expr-Int)) (expr-union (expr-pair (expr-Bool) (expr-Bool)) (expr-union (expr-suc (expr-Int)) (expr-union (expr-suc (expr-Bool)) (expr-union (expr-lam 'mw (expr-Int) (expr-Int)) (expr-union (expr-lam 'mw (expr-Int) (expr-Bool)) (expr-union (expr-lam 'mw (expr-Bool) (expr-Int)) (expr-union (expr-lam 'mw (expr-Bool) (expr-Bool)) (expr-union (expr-lam 'm1 (expr-Int) (expr-Int)) (expr-union (expr-lam 'm1 (expr-Int) (expr-Bool)) (expr-union (expr-lam 'm1 (expr-Bool) (expr-Int)) (expr-lam 'm1 (expr-Bool) (expr-Bool))))))))))))))))))))))))))))))))))))))))))))))))))))))))))`

**W6**: `(list (expr-lam 'm1 (expr-Bool) (expr-Bool)) (expr-String) (expr-Nat) (expr-Bool) (expr-Int))`

