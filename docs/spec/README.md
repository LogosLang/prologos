# Prologos Language Specification

Living grammar and type system specification for Prologos — a functional-logic language unifying dependent types, session types, linear types (QTT), logic programming, and propagators.

## Structure

```
docs/spec/
  grammar.ebnf          Formal W3C EBNF syntax specification
  grammar.org           Literate org-mode grammar with examples
  ott/
    prologos.ott        Ott type system specification
    prologos-rules.tex  LaTeX wrapper for generated rules
    Makefile            Build targets for LaTeX generation
  README.md             This file
```

## Artifacts

### grammar.ebnf — Formal EBNF Grammar

W3C-style EBNF (ISO 14977 variant) covering the complete surface syntax:
- Lexical grammar (tokens, literals, comments, whitespace rules)
- Module system (ns, imports, exports)
- Declarations (def, defn, spec, data, trait, impl, bundle, defmacro)
- Type expressions (Pi, Sigma, arrows, unions, universes, dependent types)
- Expressions (application, lambda, match, pipes, quotes, collections)
- Pattern syntax (constructors, wildcards, bindings)
- Session types and processes (from formal spec)
- S-expression fallback mode
- Whitespace reader rules

### grammar.org — Literate Grammar

Org-mode document with prose explanations and example code for each grammar section. Renders as readable documentation. Structure:

1. Introduction (modes, design principles)
2. Lexical Grammar (comments, identifiers, literals, brackets)
3. Type Expressions (base, parameterized, arrows, dependent, unions)
4. Expressions (application, lambda, match, pipes, quotes, collections)
5. Declarations (ns, imports, def, defn, spec, data, trait, impl, macros)
6. QTT multiplicities
7. Dependent types and eliminators
8. Full program example
9. Appendices (sexp mode, WS reader rules, desugaring table)

### ott/ — Type System Specification

Ott specification defining:
- **Syntax**: expressions, types, contexts, multiplicities, session types
- **Reduction**: WHNF, full normalization, definitional equality
- **Typing**: bidirectional inference/checking, type formation, level inference
- **QTT**: usage tracking, compatibility, top-level checking
- **Sessions**: duality, session operations
- **Processes**: typed process calculus with channel contexts

## Building

### Ott → LaTeX → PDF

Prerequisites: [Ott](https://github.com/ott-tool/ott), pdflatex

```sh
cd docs/spec/ott
make          # Generate prologos-generated.tex from .ott
make pdf      # Generate prologos-rules.pdf (requires pdflatex)
make clean    # Remove generated files
```

### Org → HTML/PDF

```sh
# In Emacs:
#   Open grammar.org
#   C-c C-e h h   (export to HTML)
#   C-c C-e l p   (export to PDF via LaTeX)

# Or from command line:
emacs --batch -l org --eval '(find-file "grammar.org")' \
  --eval '(org-html-export-to-html)'
```

## Source References

These specifications are derived from three formal sources:

| Source | Location | Description |
|--------|----------|-------------|
| Maude spec | `maude/` | 10 modules, 150+ tests — equational specification |
| PLT Redex | `racket/prologos/redex/` | 12 files, 100+ tests — operational semantics |
| Racket impl | `racket/prologos/` | Reader, parser, elaborator, type checker |

Plus the standard library (`lib/prologos/`, 85+ .prologos files) and example files.

## Keeping in Sync

These are **living documents** — they should be updated when the language surface changes. Key touchpoints:

- **New syntax**: Update `grammar.ebnf` productions and `grammar.org` examples
- **New type rules**: Update `ott/prologos.ott` judgments
- **New AST nodes**: Likely need updates to all three artifacts
- **New built-in operations**: Add to relevant EBNF sections
