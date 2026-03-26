# Self-Describing Serialization as Typed Hypergraph Grammar

**Stage**: 0 (Research Note — conversational synthesis)
**Date**: 2026-03-25
**Series touches**: PPN (primary), NTT, PM Track 10B, Self-Hosting

**Related documents**:
- [Hypergraph Rewriting + Propagator-Native Parsing](2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — HR grammars as propagator networks
- [Tropical Optimization + Network Architecture](2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md) — cost-weighted grammar operations
- [NTT Syntax Design](../tracking/2026-03-22_NTT_SYNTAX_DESIGN.md) — serialize/deserialize forms (Level 3)
- [Track 10 PIR](../tracking/2026-03-24_PM_TRACK10_PIR.md) — "data at rest, closures derived on demand" (6 instances)
- [PM Track 10 Design](../tracking/2026-03-24_PM_TRACK10_DESIGN.md) — current .pnet ad-hoc format

---

## 1. The Core Insight: Serialization and Deserialization Are Grammar Duals

Serialization decomposes an in-memory structure (struct tree, network
state) into a linear byte sequence. Deserialization composes a byte
sequence back into the structure. These are the GENERATE and RECOGNIZE
directions of the same grammar.

| Direction | Grammar operation | Prologos analog |
|-----------|------------------|-----------------|
| Serialize | Generate (pretty-print) | SRE decomposition (struct → components) |
| Deserialize | Recognize (parse) | SRE reconstruction (components → struct) |
| Grammar | Type description | NTT network type |

If the grammar is a hypergraph grammar (from PPN research), then:
- Serialization = hypergraph rewriting: decompose the in-memory graph
  into a linear sequence via HR production rules applied in reverse
- Deserialization = hypergraph rewriting: compose the linear sequence
  into the in-memory graph via HR production rules applied forward
- The grammar rules = the type description that both directions share

## 2. The Self-Describing Format

A three-part serialization format where the data carries its own grammar:

```
Part 0: Fixed-size header
  - Magic bytes (format identifier)
  - Version number (meta-grammar version)
  - Grammar size (byte count for Part 1)
  Every reader understands Part 0 — it's the bootstrap.

Part 1: Grammar rules
  - Written in a fixed meta-grammar that Part 0's version specifies
  - Describes the types, constructors, and encoding for Part 2
  - IS the type description for the data
  - Can include: struct definitions, lattice types, cell types,
    foreign function references, gensym tables

Part 2: Data
  - Serialized according to Part 1's grammar
  - A parser generated from Part 1's rules can deserialize Part 2
  - A generator derived from Part 1's rules produced Part 2
```

### Precedents

| System | Schema | Wire format | Self-describing? |
|--------|--------|-------------|-----------------|
| Protocol Buffers | .proto files | Varint + tag encoding | No (schema external) |
| Apache Avro | JSON schema in file header | Binary encoding | YES (schema in header) |
| ASN.1 | ASN.1 schema | BER/DER encoding | Partial (OID references) |
| MessagePack | Implicit (dynamic typing) | Binary encoding | Implicit |
| **Prologos .pnet** | **HR grammar rules** | **HR-generated binary** | **YES (grammar embedded)** |

The innovation: the grammar rules in Part 1 are expressed in Prologos's
own hypergraph grammar formalism — not in an external schema language.
This means a Prologos program can define, type-check, and compose
serialization formats as first-class values.

## 3. NTT Integration

If the grammar IS a type (an NTT network type), then:

```prologos
;; The serialization grammar as a typed spec
serialize ModuleState : Serializer ModuleNet
  :format :pnet-v2
  :grammar
    struct-rule expr-Pi   [mult domain codomain]  :tag 0x01
    struct-rule expr-app  [func arg]              :tag 0x02
    struct-rule expr-lam  [mult type body]        :tag 0x03
    ...
    foreign-ref-rule :encoding (module-path . binding-name)
    gensym-rule      :encoding symbol$$N
  :where [RoundTrip serialize deserialize]  ;; adjunction law

;; The deserializer is the ADJOINT — derived automatically
deserialize ModuleState : Deserializer ModuleNet
  :from serialize
  :validates [FormatVersion SourceHash]
  :fallback elaborate-from-source
```

The `:where [RoundTrip serialize deserialize]` constraint is the
adjunction law: `deserialize(serialize(x)) = x` (modulo gensym identity).
The type system verifies this structurally from the grammar rules.

## 4. The Duality: Serializer = Pretty-Printer, Deserializer = Parser

This duality is not metaphorical — it's structural:

| Parser operation | Serializer operation |
|-----------------|---------------------|
| Read token | Write byte |
| Match production rule | Apply production rule (reverse) |
| Build AST node | Decompose AST node |
| Handle ambiguity (multiple parses) | Handle representation choice (multiple encodings) |
| Error on invalid input | Error on unserializable value |

In the PPN framework, a parser is a propagator network that accumulates
parse state on a lattice. A serializer is the SAME network run in the
opposite direction — the lattice ascent for parsing becomes lattice
descent for serialization.

For the SRE: `structural-relate(cell, Form(sub-cells))` is the
decomposition step. In parsing, it builds structure from tokens. In
serialization, it decomposes structure into bytes. Same SRE primitives,
different direction.

## 5. Self-Describing Format for Cross-Version Compatibility

The self-describing property solves the bootstrapping problem:

**Scenario**: Prologos v2 changes `expr-Pi` to have 4 fields instead of
3 (adds an effect annotation). A `.pnet` file from v1 has 3-field Pi.
A v2 compiler needs to read it.

**Without self-describing format**: The v2 tag table has a 4-field Pi
constructor. Deserializing a 3-field Pi from v1 fails (arity mismatch).
Manual migration code needed.

**With self-describing format**: The `.pnet` file carries its grammar
(Part 1). The v2 compiler reads the v1 grammar, sees 3-field Pi, and
either: (a) constructs a 3-field Pi and lets a migration propagator
fill the 4th field, or (b) reports the version mismatch with the exact
structural difference (grammar diff).

The grammar diff between versions IS the migration spec. It shows
exactly which types changed, which fields were added/removed, and
what the structural transformation is. This is a typed, machine-readable
changelog for the serialization format.

## 6. Implications for Self-Hosting

If the serialization format is self-describing:

1. The first compiler (Racket-hosted) writes `.pnet` files with the
   grammar embedded
2. The self-hosted compiler reads `.pnet` files using the embedded grammar
   — no need to hardcode the format
3. When the self-hosted compiler changes the format, it writes new
   `.pnet` files with the new grammar — the Racket-hosted compiler can
   still read them (cross-version compatibility)
4. The bootstrapping chain: Racket compiler → `.pnet` with grammar →
   self-hosted compiler reads grammar → self-hosted compiler writes
   new `.pnet` with updated grammar → repeat

## 7. Connection to Tropical Optimization

The grammar can carry cost annotations (from OE research):

```prologos
serialize ModuleState : Serializer ModuleNet
  :grammar
    struct-rule expr-Pi [mult domain codomain]
      :tag 0x01
      :cost 3       ;; 3 bytes overhead per Pi node
    compact-rule expr-Pi [domain codomain]
      :tag 0x81
      :cost 2       ;; 2 bytes — omit mult when it's mw (80% case)
      :when [eq? mult mw]
```

The tropical semiring selects the cheapest valid encoding. Common
patterns (mult=mw) use compact encodings. Rare patterns use full
encodings. The grammar optimization is automatic — the cost lattice
picks the minimum-cost derivation.

## 8. Research Questions

1. **Can the meta-grammar (Part 0's format for Part 1) be expressed
   in Prologos itself?** If so, the entire stack is self-describing
   — the meta-grammar describes how to read grammars, which describe
   how to read data.

2. **What is the categorical structure of grammar duality?** The
   serialize/deserialize adjunction. Is it a Galois connection between
   the "in-memory" lattice and the "on-disk" lattice? If so, the
   bridge abstraction from NTT applies directly.

3. **Can grammar composition give us format adapters?** If format A
   has grammar G_A and format B has grammar G_B, is there a grammar
   morphism G_A → G_B that serves as a format converter? This would
   make format migration a grammar transformation, not ad-hoc code.

4. **Does the PPN infrastructure handle both parsing directions
   natively?** A propagator network that parses (bytes → structure)
   should also serialize (structure → bytes) by running in reverse.
   Is this true for arbitrary HR grammars, or only for a restricted
   class?

## 9. Proposed Organization

| Timeline | Scope | Deliverable |
|----------|-------|-------------|
| Short-term (Track 10B) | Keep current ad-hoc .pnet format | Works, tested, fast |
| Medium-term (PPN Track 0) | Design grammar-based serialization as part of lattice design | Grammar spec for .pnet format |
| Medium-term (PPN Track 2) | Implement grammar-driven serializer/deserializer | Replace write/read with grammar-generated I/O |
| Long-term (self-hosting) | Self-describing format with embedded grammar | Cross-version compatibility, bootstrapping |

The transition from ad-hoc to grammar-based can be incremental:
wrap current `.pnet` content in Part 0/1/2 structure, where Part 1
describes the current `struct->vector` + `write`/`read` format.
When PPN Track 2 delivers grammar-driven I/O, Part 1 switches to
a real grammar and Part 2 switches to grammar-generated encoding.
