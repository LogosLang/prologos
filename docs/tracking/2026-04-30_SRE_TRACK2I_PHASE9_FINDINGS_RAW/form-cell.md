cpu time: 18 real time: 19 gc time: 4
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
| form-cell | equality | ground | ✓ | ✗ | ✗ | ✗ | ✗ | — | ✓ | — |
| form-cell | equality | wider | ✓ | ✗ | ✗ | ✗ | ✗ | — | ✓ | — |

### Per-finding detail

Witnesses are footnoted (W1, W2, ...) below the table. Non-vacuity % surfaces evidence-strength asymmetries (e.g., SD-vee 3.5% vs SD-wedge 91.4% on type×equality wider — most SD-vee triples don't fire the hypothesis non-trivially).

| Domain | Relation | Depth | Property | Samples | Status | Triples | Hypothesis fired | Conclusion held | Non-vacuity % | Witness |
|---|---|---|---|---|---|---|---|---|---|---|
| form-cell | equality | ground | distributive | 7 | refuted | — | — | — | — | (W1) |
| form-cell | equality | ground | sd-vee | 7 | confirmed | 343 | 75 | 75 | 21.9% | — |
| form-cell | equality | ground | sd-wedge | 7 | confirmed | 343 | 123 | 123 | 35.9% | — |
| form-cell | equality | ground | modular | 7 | refuted | 272 | 81 | 80 | 29.8% | (W2) |
| form-cell | equality | ground | has-pseudo-complement-rel | 7 | confirmed | 49 | 49 | 49 | 100.0% | — |
| form-cell | equality | ground | has-pseudo-complement-abs | 7 | confirmed | 7 | 7 | 7 | 100.0% | — |
| form-cell | equality | ground | stone-identity | 7 | refuted | — | — | — | — | (W3) |
| form-cell | equality | ground | whitmans-condition | 7 | confirmed | 2401 | 1543 | 1543 | 64.3% | — |
| form-cell | equality | ground | relatively-complemented | 7 | refuted | — | — | — | — | (W4) |
| form-cell | equality | ground | sectionally-complemented | 7 | refuted | — | — | — | — | (W5) |
| form-cell | equality | ground | breadth-bound | 7 | refuted | — | — | — | — | (W6) |
| form-cell | equality | wider | distributive | 7 | refuted | — | — | — | — | (W1) |
| form-cell | equality | wider | sd-vee | 7 | confirmed | 343 | 75 | 75 | 21.9% | — |
| form-cell | equality | wider | sd-wedge | 7 | confirmed | 343 | 123 | 123 | 35.9% | — |
| form-cell | equality | wider | modular | 7 | refuted | 272 | 81 | 80 | 29.8% | (W2) |
| form-cell | equality | wider | has-pseudo-complement-rel | 7 | confirmed | 49 | 49 | 49 | 100.0% | — |
| form-cell | equality | wider | has-pseudo-complement-abs | 7 | confirmed | 7 | 7 | 7 | 100.0% | — |
| form-cell | equality | wider | stone-identity | 7 | refuted | — | — | — | — | (W3) |
| form-cell | equality | wider | whitmans-condition | 7 | confirmed | 2401 | 1543 | 1543 | 64.3% | — |
| form-cell | equality | wider | relatively-complemented | 7 | refuted | — | — | — | — | (W4) |
| form-cell | equality | wider | sectionally-complemented | 7 | refuted | — | — | — | — | (W5) |
| form-cell | equality | wider | breadth-bound | 7 | refuted | — | — | — | — | (W6) |

### Witness footnotes

**W1**: `(list (form-pipeline-value (seteq 'tagged) 'mock-tree-node-A '((reg-1 . val-1)) 'pos-A '#hasheq()) (form-pipeline-value (seteq) #f '() #f '#hasheq()) (form-pipeline-value (seteq 'grouped 'tagged) #f '() #f '#hasheq()))`

**W2**: `(list (form-pipeline-value (seteq 'tagged) 'mock-tree-node-A '((reg-1 . val-1)) 'pos-A '#hasheq()) (form-pipeline-value (seteq 'grouped 'tagged) #f '() #f '#hasheq()) (form-pipeline-value (seteq 'tagged) 'mock-tree-node-A '((reg-1 . val-1)) 'pos-A '#hasheq()))`

**W3**: `(list (form-pipeline-value (seteq) #f '() #f '#hasheq()) (form-pipeline-value (seteq 'done 'grouped 'tagged) #f '() #f '#hasheq()) (form-pipeline-value (seteq) #f '() #f '#hasheq()) (form-pipeline-value (seteq 'done 'grouped 'tagged) #f '() #f '#hasheq()))`

**W4**: `(list (form-pipeline-value (seteq 'tagged) 'mock-tree-node-A '((reg-1 . val-1)) 'pos-A '#hasheq()) (form-pipeline-value (seteq 'tagged) 'mock-tree-node-A '((reg-1 . val-1)) 'pos-A '#hasheq()) (form-pipeline-value (seteq 'tagged) 'mock-tree-node-A '((reg-1 . val-1)) 'pos-A '#hasheq()))`

**W5**: `(list (form-pipeline-value (seteq 'tagged) 'mock-tree-node-A '((reg-1 . val-1)) 'pos-A '#hasheq()) (form-pipeline-value (seteq 'tagged) 'mock-tree-node-A '((reg-1 . val-1)) 'pos-A '#hasheq()))`

**W6**: `(list (form-pipeline-value (seteq 'tagged) 'mock-tree-node-B '((reg-2 . val-2)) 'pos-B '#hasheq()) (form-pipeline-value (seteq 'tagged) 'mock-tree-node-A '((reg-1 . val-1)) 'pos-A '#hasheq()) (form-pipeline-value (seteq 'done) #f '() #f '#hasheq()) (form-pipeline-value (seteq 'grouped) #f '() #f '#hasheq()) (form-pipeline-value (seteq 'tagged) #f '() #f '#hasheq()))`

