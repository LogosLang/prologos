# SRE Track 2G: Algebraic Domain Awareness — Stage 2 Audit

**Date**: 2026-03-30
**Auditor**: Claude + manual verification
**Scope**: Current SRE implementation state relevant to Track 2G
**Method**: grep-backed code inspection of sre-core.rkt, ctor-registry.rkt, unify.rkt, session-propagators.rkt

---

## 1. Current sre-domain Struct (sre-core.rkt:81-99)

9 fields. NO algebraic-class or property fields.

| Field | Type | Purpose |
|-------|------|---------|
| name | symbol | Domain identifier ('type, 'session) |
| merge-registry | (relation-name → merge-fn) | Per-relation merge dispatch |
| contradicts? | (val → bool) | Top/contradiction detection |
| bot? | (val → bool) | Bottom detection |
| bot-value | value | The ⊥ element |
| top-value | value | The ⊤ element |
| meta-recognizer | (expr → bool) or #f | Metavariable detection |
| meta-resolver | (expr → cell-id or #f) or #f | Context-dependent cell lookup |
| dual-pairs | assoc-list or #f | Constructor pairing for duality |

**Production domains: 2**
- `type-sre-domain` (unify.rkt:77-88) — merge: type-lattice-merge, subtype-merge, duality-merge, phantom-merge
- `session-sre-domain` (session-propagators.rkt:264-275) — merge: session-lattice-merge

**No central domain registry.** Domains referenced as module-level variables.

## 2. Current sre-relation Struct (sre-core.rkt:169-180)

4 fields. Properties field EXISTS (Track 2F deliverable).

| Field | Type | Purpose |
|-------|------|---------|
| name | symbol | Relation identifier |
| properties | (seteq symbol) | Algebraic properties of the endomorphism |
| propagator-ctor | callback or #f | Fire function factory |
| merge-key | symbol | Registry lookup key |

**5 built-in relations:**

| Relation | Properties |
|----------|-----------|
| sre-equality | {identity, requires-binder-opening} |
| sre-subtype | {order-preserving} |
| sre-subtype-reverse | {order-preserving} |
| sre-duality | {antitone, involutive} |
| sre-phantom | {trivial} |

**Property checks in codebase (4 call sites):**
- `requires-binder-opening`: lines 412, 487, 503 — controls whether decomposition opens binders
- `antitone`: line 878 — controls value flipping during duality decomposition

## 3. Variance-Map Registry (sre-core.rkt:246-271)

**HARDCODED hash table.** Maps `(relation-name, variance) → sub-relation`. No extension API.

40 entries covering 5 relations × 8 variance values (`+`, `-`, `=`, `ø`, `same-domain`, `cross-domain`, `#f`, fallback).

`derive-sub-relation(relation, variance)` at lines 262-271: single hash-ref lookup.

## 4. ctor-registry.rkt (785 lines)

**ctor-desc struct: 10 fields** including `component-variances` and `component-lattices`.

**28 registered constructors:**
- Type domain: 11 (Pi, Sigma, app, Eq, Vec, Fin, pair, lam, PVec, Set, Map)
- Data domain: 9 (cons, nil, some, none, suc, zero, pair, ok, err)
- Session domain: 8 (sess-send, sess-recv, sess-dsend, sess-drecv, sess-async-send, sess-async-recv, sess-mu)

Component variances are per-registration (`'(= - +)` for Pi, `'(cross-domain same-domain)` for session constructors).

## 5. What Track 2F Delivers

**Implemented:**
- `sre-relation.properties` field (seteq of symbols)
- `sre-relation-has-property?` (line 274)
- `derive-sub-relation` via variance-maps (lines 246-271)
- Cross-domain variance annotations on session constructors
- 5 built-in relations with correct algebraic properties

**NOT implemented (despite Track 2F design doc mentioning):**
- No `register-algebraic-kind!` API
- No extension point for adding new relations or variance mappings
- No `algebraic-kind` struct or registry
- Variance-map is hardcoded, not extensible

## 6. Existing Algebraic Property Checks in Codebase

**ZERO domain-level algebraic checks exist.** No code anywhere checks:
- Is this domain distributive?
- Does this domain have pseudo-complements?
- Is the merge residuated?
- Is the domain Boolean?

The only algebraic checks are RELATION-level (endomorphism properties): `antitone`, `requires-binder-opening`.

`idempotent` appears 32 times but only in termination-analysis.rkt, io-bridge.rkt, capability-inference.rkt — NOT in SRE infrastructure.

## 7. Domain Operations Inventory

| Operation | type-sre-domain | session-sre-domain |
|-----------|-----------------|-------------------|
| merge/join | 4 functions (per relation) | 1 function |
| meet | NONE | NONE |
| bot | type-bot | sess-bot |
| top | type-top | sess-top |
| complement | NONE | NONE |
| pseudo-complement | NONE | NONE |
| residual | NONE | NONE |

**Can test these properties with current operations:**
- Commutativity: YES (merge(a,b) == merge(b,a))
- Associativity: YES (merge(merge(a,b),c) == merge(a,merge(b,c)))
- Idempotence: YES (merge(a,a) == a)

**Cannot test without additional operations:**
- Distributivity: needs MEET (a ⊔ (b ⊓ c) = (a ⊔ b) ⊓ (a ⊔ c))
- Complementation: needs complement operation
- Pseudo-complement: needs meet + implication
- Residuation: needs meet + adjunction test

## 8. File Sizes and Dependencies

| File | Lines | Role |
|------|-------|------|
| sre-core.rkt | 926 | Core SRE: domain, relation, decomposition |
| ctor-registry.rkt | 785 | Constructor descriptors, component variances |
| unify.rkt | 1090 | Type domain, unification propagators |
| session-propagators.rkt | 623 | Session domain, duality propagators |
| type-lattice.rkt | 364 | Type lattice merge operations |
| **Total** | **3788** | **SRE infrastructure** |

**sre-core.rkt imports:** racket/list, racket/set, propagator.rkt, ctor-registry.rkt
**Importers of sre-core.rkt:** driver.rkt, elaborator-network.rkt, session-propagators.rkt, unify.rkt

## 9. Critical Findings for Track 2G Design

### What EXISTS (build on)
1. Relation-level properties (seteq on sre-relation) — proven pattern, 4 call sites
2. Per-domain merge functions — introspectable if wrapped
3. Bot/top values per domain — can test lattice bounds
4. 28 ctor-descs with component variances — structural decomposition exists
5. `sre-relation-has-property?` API — extensible to domain properties

### What's MISSING (must build)
1. Domain-level property declarations or inference
2. Meet operations for ANY domain (blocks distributivity, residuation tests)
3. Complement operations (blocks Boolean, Heyting detection)
4. Extension API for variance-maps (currently hardcoded)
5. Central domain registry (domains are module-level variables, not registered)
6. Any introspection of merge function behavior (commutativity, etc.)

### Key Constraint
**No meet operation exists for any domain.** This means:
- Distributivity testing requires adding meet
- Heyting pseudo-complement requires meet
- Residuation requires meet
- Boolean complement requires meet

Meet is the most significant infrastructure gap. Without it, many algebraic properties are untestable. Track 2G must either (a) require domains to provide meet alongside merge, or (b) limit initial properties to those testable with join-only (commutativity, associativity, idempotence, monotonicity).
