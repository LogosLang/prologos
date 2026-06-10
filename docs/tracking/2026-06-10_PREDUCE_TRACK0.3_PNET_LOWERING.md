# PReduce Track 0.3 — .pnet Extension + LLVM Lowering Interface (D.3)

**Created**: 2026-06-10 · **Status**: CLOSED 2026-06-10 (design track — schemas frozen; Track 5 implements)
**Inputs**: D.1 (§3/§6/§7 binding) + D.2 (tier-1 census); panel `wf_7250f731-04d` (2 clusters,
grounded at main HEAD 533bfcab); mempalace probes (A3 anchor status; pnet format history);
owner decisions (sign-off package / container+payload / merge timing).

## §1 Verified grounding

pnet tuple = 24 positional entries (indices 0-23; 17 registries at 7-23); PNET_VERSION=1
EXISTS but is an equality gate (mismatch = whole-file stale; no per-section versioning);
additive length-tolerant reads are already de facto (indices 14-23 landed that way).
Encoding = textual write/read + atomic rename; gensym symbol$$N uids are
TRAVERSAL-ORDER-dependent (forbidden in any content-hash domain); networks = sentinels;
procedures = '(foreign-proc name) stubs. Invalidation = path:mtime + driver.zo mtime.
**Content-hash reality**: structural identity today is equal-hash-code/eq-hash-code
throughout (champ.rkt:202+; cell-ops.rkt:122-125) — NO cross-run/version/platform
stability contract; `sha256-bytes` VERIFIED present in Racket 9.0 base (executed);
NO canonical byte encoder exists anywhere in racket/prologos (grep clean). The Zig
PoC/LoweredPNET consumer is OUT-OF-TREE, unpinned (engineering-anchors A3: not frozen,
interface undocumented).

## §2 The identity sign-off package (owner-adopted; the track's only non-reversible rulings)

**PCE/1 canonical encoding**: deterministic byte encoding over the loc-free de Bruijn
canonical term domain — explicit little-endian; hash/map iteration sorted by encoded key
bytes; uninterned symbols EXCLUDED by admission; float/posit byte rules defined with the
golden vectors at implementation; kind-byte DOMAIN SEPARATION prefixes every digest.
Hash = `sha256-bytes` over PCE/1 bytes. **The three D3 rulings**: (i) effectful
occurrences use deterministic (epoch × occurrence-path) keys, never structural hashes;
(ii) the Merkle child-digest rule governs effectful children inside pure parents;
(iii) the positive `:opaque` facet is load-bearing (absence-from-index alone carries no
congruence safety). **The two key-space closures**: (iv) the session-local effectful
digest is STRUCTURALLY EXCLUDED from the persisted hash domain — an admission-guard
ERROR, not an implied property; (v) the question-store key gains a **rule-set-digest**
component — key = (source-e-class-content-hash × cost-criterion-id × rule-set-digest ×
worldview-bitmask?) — so rule evolution invalidates stale extractions BY KEY.
**Single-hasher rule**: ONE module (`pce.rkt`) owns encoding+hashing; the golden-vector
generator IS that library (two-producer hazard named); the reference encoder + golden
vectors are IN 0.3's deliverable scope (they generate the freeze artifact).

## §3 The container: .pnet/2 (owner-adopted)

Tagged-section container — additive evolution as a FORMAT PROPERTY: named sections;
unknown-tag-skip; header-first staleness check; reserved-tag policy; the question store
is a SIDECAR file with nothing mtime-shaped in its validity (key-embedded validity per
§2; epoch GC). One-time global cold rebuild accepted. New sections: `'eclass-ground`
(content-hash → canonical form + best + regime tag; ground tier-1 only),
`'rules-tier1` (the SM3 schema as data, incl. nac-spec + reserved worldview slot),
`'cells` (cell-record: SRE domain/merge NAMES + declared-properties + classification +
**per-cell enrichment annotation** — the verified day-one documented obligation),
`'propagators` (RESERVED sub-section, non-normative candidate fields; trigger = NTT
design / SH Track 1 round-trip green slice).

## §4 The substrate-call boundary (payload tier 2′, owner-adopted)

The lowering consumer reads: chosen extractions (question store) + per-cell enrichment
annotations + tier-1 rules — **extract-then-lower honored**: extraction runs on our
side; the consumer executes chosen forms, not a raw e-graph (the "network state IS the
IR" claim is satisfied at the CELL-record level — state, names, properties — while the
executable-network payload is the reserved 'propagators seam; A0-paper language must
not outrun this spec). Direct-to-LLVM (not MLIR) per the standing commitment.
**SH Track 1 seam**: the frozen cell-record IS the joint schema (merge closures
re-derive by NAME at load — the two-tier shape); divergence is structurally prevented
by one schema rather than discipline.

## §5 Owner actions + gates (tracker rows)

1. **PoC pinning** (OWNER): identify the Zig PoC branch, archive source, document its
   current read interface (engineering-anchors A3 TODO inherited here).
2. **First-consumer-integration gate**: the boundary spec is normative-from-our-side
   (collaborator rebases); validated at the first real consumer integration.
3. PCE/1 golden vectors = the cross-language conformance artifact (Zig consumer tests
   against them, not against our source).

## §6 Track 5 implements / 0.3 specified

0.3 delivers: this frozen schema + the PCE/1 spec + reference encoder + golden vectors +
the reserved seams. Track 5 implements: serialize-time projection, sidecar store + GC,
section writers/readers, the .pnet/2 migration (cold rebuild), per-module e-class
sections — gated per §7.4 on D5 cache-hit data (the rewrites registry earns its keep
first).

## §7 Master amendments (this commit)

Track 0.3 row → ✅ CLOSED with D.3 linked; Track 0 row → ✅ (all three sub-deliverables
closed; series founding complete); Track 5 row gains the PCE/golden-vector + .pnet/2
migration notes.
